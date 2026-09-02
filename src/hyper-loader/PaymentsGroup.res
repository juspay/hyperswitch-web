/* Outer (merchant-page) CardForm factory for the payments surface, behind
   `hyper.widgets(options).cardForm()`.
   Confirm ownership sits in the hidden `cardFormCoordinator` iframe: fields ship their
   state to it over MessageChannel ports and the group posts only a CONTENT-FREE
   `initiateConfirm` frame. Raw card data rides ONLY the port plane; the window plane
   carries masked events. */

open Utils

type fieldHandle = Types.fieldHandle

type groupConfig = {
  clientSecret: string,
  publishableKey: option<string>,
  endpoint: option<string>,
  appearance: option<JSON.t>,
  locale: option<string>,
}

// `confirm()` is explicit because `hyper.confirmPayment()`'s fan-out never reaches group-mounted iframes.
type cardForm = {
  create: (string, JSON.t) => fieldHandle,
  update: JSON.t => unit,
  on: (string, JSON.t => unit) => unit,
  // fires only for events from a `create(<fieldType>, ...)` mount, unlike group-level `on`.
  onFieldEvent: (string, string, JSON.t => unit) => unit,
  confirm: unit => promise<JSON.t>,
  deinit: unit => unit,
  fields: ref<JSON.t>,
  fieldEvents: ref<JSON.t>,
}

type aggregatedStatus = CardFormShared.fieldFormStatus

let aggregatedStatusToString = CardFormShared.fieldFormStatusToString

let aggregatedStatusFromString = CardFormShared.fieldFormStatusFromString

let reshapeCardStateUpdateToChangePayload = CardFormShared.reshapeCardStateUpdateToChangePayload

type fieldEntry = {
  iframeRef: ref<Nullable.t<Dom.element>>,
  handle: fieldHandle,
  fieldType: string,
  lastStateRef: ref<option<JSON.t>>,
  // routed through this ref so focused/blurred one-shots survive the next cardStateUpdate.
  lastFormStatusRef: ref<option<aggregatedStatus>>,
  // a fresh fieldId per create(), so without explicit removal old listeners accumulate.
  listenerName: string,
  /* saved-card token captured at `create()`; the Flow B relay embeds it as `paymentToken`
     because the CVC iframe's mount config carries only the BRAND, never the token. */
  savedCardTokenRef: ref<string>,
  /* auto-focus advances only on the false→true edge of the iframe-emitted `focusReady`.
     Do NOT key this off `fieldStatus.complete` — the iframe owns the timing decision
     (brand-aware max length plus Luhn); the group merely routes `doFocus`. */
  prevFocusReadyRef: ref<bool>,
}

let mapFieldTypeToInternalFieldName = CardFormShared.mapFieldTypeToInternalFieldName

let nextFieldFor = CardFormShared.nextFieldFor

let computeGroupReadiness = (fieldsRef: ref<Dict.t<fieldEntry>>): bool => {
  let entries = fieldsRef.contents->Dict.valuesToArray
  let expectedFieldTypes = ["cardNumber", "cardExpiry", "cardCvc"]
  let hasAllFields = expectedFieldTypes->Array.every(expectedFieldType =>
    entries->Array.some(entry => entry.fieldType === expectedFieldType)
  )
  if !hasAllFields {
    false
  } else {
    entries->Array.every(entry =>
      switch entry.lastStateRef.contents {
      | Some(stateJson) =>
        let stateDict = stateJson->getDictFromJson
        let fieldStatus = stateDict->getDictFromDict("fieldStatus")
        fieldStatus->getBool("complete", false)
      | None => false
      }
    )
  }
}

/* the house error envelope — byte-identical to what `hyper.confirmPayment()` resolves with on
   failure (`Utils.getFailedSubmitResponse` → `{error: {type, message}}`) plus the group's
   legacy `code` nested INSIDE `error`. Additive: a merchant matching on `error.type` /
   `error.message` sees exactly the confirmPayment shape, and one matching the old
   `error.code` keeps working. Only the old TOP-LEVEL `status` key is gone. */
let groupFailureResponse = (~code: string, ~errorType: string, ~message: string): JSON.t => {
  let envelope = getFailedSubmitResponse(~errorType, ~message)
  let envelopeDict = envelope->getDictFromJson
  let errorDict = envelopeDict->getDictFromDict("error")
  errorDict->Dict.set("code", code->JSON.Encode.string)
  envelopeDict->Dict.set("error", errorDict->JSON.Encode.object)
  envelopeDict->JSON.Encode.object
}

/* port1 queued until the coordinator iframe mounts and flushes it. Shape lives in
   `CoordinatorMount` so its teardown can close ports that were never transferred. */
type pendingPort = CoordinatorMount.pendingPort

let makeCardForm = (~config: groupConfig): Types.cardForm => {
  let clientSecret = config.clientSecret
  let publishableKey = config.publishableKey->Option.getOr("")
  let endpoint = switch config.endpoint {
  | Some(e) => e
  | None => ApiEndpoint.getApiEndPoint(~publishableKey)
  }
  let appearance = config.appearance->Option.getOr(Dict.make()->JSON.Encode.object)
  let locale = config.locale->Option.getOr("en")

  let fieldsRef: ref<Dict.t<fieldEntry>> = ref(Dict.make())
  let fields: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)
  let fieldEvents: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)
  let fieldEventsCallbacksRef: ref<Dict.t<Dict.t<JSON.t => unit>>> = ref(Dict.make())
  let eventCallbacksRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())
  let deinitCallbacksRef: ref<array<unit => unit>> = ref([])

  let confirmDispatchedRef: ref<bool> = ref(false)

  /* per-group confirm mutex, LATCHED at dispatch until the confirm promise SETTLES — i.e.
     until the network outcome lands, not until the coordinator acks the dispatch. `settle` is
     its single owner; deinit() is the only other release. Two groups confirm independently. */
  let confirmingRef: ref<bool> = ref(false)

  /* the in-flight `confirm()` resolver, parked at dispatch and consumed EXACTLY ONCE by
     `submitSuccessful`, `paymentConfirmFail`, or deinit().

     The `confirmId` is carried for shape-parity with the vault sibling, but the payments
     outcome arrives on the standard `submitSuccessful` broadcast, which `PaymentHelpers`
     posts WITHOUT any confirmId (and the coordinator's `paymentConfirmFail` frame does not
     echo one either). So correlation is genuinely unavailable on this path: the match below
     falls back to the single-in-flight guarantee the confirm mutex already provides, and only
     enforces the id when a frame actually carries one. */
  let coordinatorConfirmPendingRef: ref<option<(string, JSON.t => unit)>> = ref(None)

  let settlePendingConfirm = (~confirmId: string="", result: JSON.t): unit =>
    switch coordinatorConfirmPendingRef.contents {
    | Some((pendingId, settle)) if confirmId === "" || confirmId === pendingId => settle(result)
    | _ => ()
    }

  /* readiness is latched so clearing one character does not silently retract `ready`.
     Edges only: rising re-emits `ready`, falling emits an explicit `unready`. */
  let hasBeenReadyRef: ref<bool> = ref(false)

  // pushed to the cardCvc iframe once per brand CHANGE, not per keystroke.
  let lastDetectedBrandRef: ref<string> = ref("")

  /* `usePaymentIntent` gates confirm on `paymentMethodList` reaching Loaded, else it
     short-circuits and NO network call fires. Group-mounted fields have no PreMountLoader
     forwarder, so fetch once here and forward at every mount. */
  let clientListDataPromise = PaymentHelpers.fetchClientList(
    ~clientSecret,
    ~publishableKey,
    ~logger=LoggerUtils.defaultLoggerConfig,
    ~customPodUri="",
    ~endpoint,
  )

  /* the hidden coordinator owns the confirm: the group relays masked commands in and reads
     masked `confirmResult` back, while per-field MessageChannels deliver raw SAD off-window.
     `groupInstanceId` is its selector and the `groupId` URL param; portEpoch replaces stale ports. */
  let groupInstanceId = `payments-${Date.now()->Float.toString}-${Math.random()->Float.toString->String.slice(~start=2, ~end=8)}`
  let portEpochCounterRef: ref<int> = ref(0)
  let pendingPortsRef: ref<array<pendingPort>> = ref([])
  // every portKey this group installed — deinit closes them in the per-document registry.
  let installedPortKeysRef: ref<array<string>> = ref([])
  let coordinatorMountRef: ref<option<CoordinatorMount.coordinatorMount>> = ref(None)
  let coordinatorReadyRef: ref<bool> = ref(false)
  let coordinatorListenerName = `onPaymentsCoordinator-${groupInstanceId}`

  /* commands QUEUE until the coordinator's `iframeMounted`, for exactly the reason ports do:
     the hidden iframe has no message listener until its React tree mounts, so a `confirm()`
     racing the boot would be dropped on the floor — and since `confirm()` stays pending until a
     real outcome, that would strand the merchant's `await` forever. This mirrors
     `hyper.confirmPayment()`, which awaits `isReadyPromise` before posting `doSubmit`. */
  let pendingCoordinatorCommandsRef: ref<array<array<(string, JSON.t)>>> = ref([])

  let postToCoordinator = (
    mount: CoordinatorMount.coordinatorMount,
    fields: array<(string, JSON.t)>,
  ) =>
    try mount.iframe->Nullable.make->Window.iframePostMessage(fields->Dict.fromArray) catch {
    | _ => ()
    }

  /* relays a masked command envelope; `flow`, `paymentToken` and `confirmId` ride the same
     frame. Raw SAD is never in the message — the coordinator reads it off its port registry. */
  let postCoordinatorCommand = (fields: array<(string, JSON.t)>) => {
    switch (coordinatorMountRef.contents, coordinatorReadyRef.contents) {
    | (Some(mount), true) => postToCoordinator(mount, fields)
    | _ =>
      pendingCoordinatorCommandsRef :=
        pendingCoordinatorCommandsRef.contents->Array.concat([fields])
    }
  }

  /* drained AFTER the `paymentElementCreate` envelope goes out, so a queued confirm lands
     BEHIND the config that hydrates the coordinator's keys. The queue is emptied before the
     loop so a re-entrant post cannot double-send. */
  let flushPendingCoordinatorCommands = () => {
    switch (coordinatorMountRef.contents, coordinatorReadyRef.contents) {
    | (Some(mount), true) =>
      let queuedCommands = pendingCoordinatorCommandsRef.contents
      pendingCoordinatorCommandsRef := []
      queuedCommands->Array.forEach(fields => postToCoordinator(mount, fields))
    | _ => ()
    }
  }

  let flushPendingPorts = () => {
    switch (coordinatorMountRef.contents, coordinatorReadyRef.contents) {
    | (Some(mount), true) =>
      pendingPortsRef.contents->Array.forEach(({fieldName, epoch, port}) => {
        CoordinatorMount.forwardPortToCoordinator(
          ~coordinatorIframe=mount.iframe->Nullable.make,
          ~groupId=groupInstanceId,
          ~fieldName,
          ~portEpoch=epoch,
          ~port,
        )
      })
      pendingPortsRef := []
    | _ => ()
    }
  }

  let attachCoordinatorListener = () => {
    EventListenerManager.addSmartEventListener(
      "message",
      (ev: Types.event) => {
        let isOurCoordinator =
          coordinatorMountRef.contents
          ->Option.map(coordinatorMount =>
            ev.source === coordinatorMount.iframe->Window.contentWindow &&
            ev.origin === URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin
          )
          ->Option.getOr(false)
        if isOurCoordinator {
          let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
          let dict = json->getDictFromJson
          if dict->getBool("iframeMounted", false) {
            /* coordinator booted: flush the queued port1 channels and the clientList snapshot. It also
               needs `keys.clientSecret`, which only a `paymentElementCreate` envelope hydrates. */
            coordinatorReadyRef := true
            flushPendingPorts()
            switch coordinatorMountRef.contents {
            | Some(mount) => {
              let coordinatorPaymentOptions =
                [
                  ("appearance", appearance),
                  ("fonts", []->JSON.Encode.array),
                  ("locale", locale->JSON.Encode.string),
                  ("clientSecret", clientSecret->JSON.Encode.string),
                  ("sdkAuthorization", ""->JSON.Encode.string),
                  ("pmSessionId", ""->JSON.Encode.string),
                ]
                ->Dict.fromArray
                ->JSON.Encode.object
              let coordinatorConfig =
                [
                  ("paymentElementCreate", true->JSON.Encode.bool),
                  ("otherElements", false->JSON.Encode.bool),
                  ("componentType", "payment"->JSON.Encode.string),
                  ("paymentOptions", coordinatorPaymentOptions),
                  ("options", Dict.make()->JSON.Encode.object),
                  /* MUST equal `groupInstanceId` (the coordinator's localSelectorString) — the intent's
                     `~iframeId` and the fullscreen router both key on it, or three_ds_invoke routing desyncs. */
                  ("iframeId", groupInstanceId->JSON.Encode.string),
                  ("publishableKey", publishableKey->JSON.Encode.string),
                  ("endpoint", endpoint->JSON.Encode.string),
                  ("clientSecret", clientSecret->JSON.Encode.string),
                  ("sdkSessionId", ""->JSON.Encode.string),
                  ("customPodUri", ""->JSON.Encode.string),
                  ("parentURL", "*"->JSON.Encode.string),
                  ("sdkHandleOneClickConfirmPayment", false->JSON.Encode.bool),
                  ("launchTime", Date.now()->JSON.Encode.float),
                  ("loggerSource", "hyper_payments_coordinator"->JSON.Encode.string),
                ]
                ->Dict.fromArray
              mount.iframe->Nullable.make->Window.iframePostMessage(coordinatorConfig)
              }
            | None => ()
            }
            /* any confirm() that raced the boot is dispatched HERE, after the config above —
               never dropped, so its promise cannot hang. */
            flushPendingCoordinatorCommands()
            clientListDataPromise
            ->Promise.then(json => {
              switch coordinatorMountRef.contents {
              | Some(mount) =>
                mount.iframe->Nullable.make->Window.iframePostMessage(
                  [("clientList", json)]->Dict.fromArray,
                )
              | None => ()
              }
              Promise.resolve()
            })
            // terminal catch: a clientList rejection must not bring the coordinator mount down.
            ->Promise.catch(err => {
              Console.error2("[PaymentsGroup] clientList fetch rejected — coordinator continues without pre-warmed list", err)
              Promise.resolve()
            })
            ->ignore
          } else if dict->getBool("paymentConfirmAck", false) {
            /* the ack means DISPATCHED, not SETTLED — the coordinator fires `intent(...)` and acks
               immediately, while the real outcome rides `submitSuccessful` seconds later. So it
               MUST NOT release the confirm mutex: doing so would let a second confirm() race the
               first one's in-flight POST. It only emits `confirmDispatched`. */
            confirmDispatchedRef := true
            let payload =
              [
                ("elementType", "paymentsCoordinator"->JSON.Encode.string),
                ("iframeId", groupInstanceId->JSON.Encode.string),
              ]
              ->Dict.fromArray
              ->JSON.Encode.object
            eventCallbacksRef.contents->Dict.get("confirmDispatched")->Option.forEach(cb => cb(payload))
          } else if dict->getBool("paymentConfirmFail", false) {
            /* pre-network validation failure raised by the coordinator BEFORE any API call, so no
               `submitSuccessful` will ever follow — this arm is terminal and must settle. */
            let errorMessage = dict->getString("errorMessage", "Card details incomplete or invalid")
            let errorPayload = {
              let errDict = Dict.make()
              errDict->Dict.set("elementType", "paymentsCoordinator"->JSON.Encode.string)
              errDict->Dict.set("iframeId", groupInstanceId->JSON.Encode.string)
              errDict->Dict.set("code", "validation_error"->JSON.Encode.string)
              errDict->Dict.set("message", errorMessage->JSON.Encode.string)
              errDict->JSON.Encode.object
            }
            eventCallbacksRef.contents->Dict.get("error")->Option.forEach(cb => cb(errorPayload))
            settlePendingConfirm(
              ~confirmId=dict->getString("confirmId", ""),
              groupFailureResponse(
                ~code="validation_error",
                ~errorType="validation_error",
                ~message=errorMessage,
              ),
            )
          } else {
            /* the real payment outcome: the coordinator's `intent(...)` broadcasts the SDK's
               standard `submitSuccessful` frame to the merchant window. Mirror
               `Hyper.res` `confirmPaymentWrapper` exactly — true resolves the backend response
               BODY (`data`), false resolves the WHOLE frame (which carries `error`). */
            switch dict->Dict.get("submitSuccessful") {
            | Some(submitSuccessfulJson) =>
              let succeeded = submitSuccessfulJson->JSON.Decode.bool->Option.getOr(false)
              let result = if succeeded {
                dict->Dict.get("data")->Option.getOr(Dict.make()->JSON.Encode.object)
              } else {
                json
              }
              settlePendingConfirm(~confirmId=dict->getString("confirmId", ""), result)
            | None => ()
            }
          }
        }
      },
      coordinatorListenerName,
    )
    deinitCallbacksRef.contents->Array.push(
      () => EventListenerManager.removeSmartEventListener("message", coordinatorListenerName),
    )
  }

  let ensureCoordinatorMounted = () => {
    switch coordinatorMountRef.contents {
    | Some(_) => ()
    | None =>
      let groupAppearance =
        config.appearance->Option.getOr(Dict.make()->JSON.Encode.object)
      let groupConfigAsOptions =
        [
          ("clientSecret", config.clientSecret->JSON.Encode.string),
          ("publishableKey", config.publishableKey->Option.getOr("")->JSON.Encode.string),
          ("locale", config.locale->Option.getOr("en")->JSON.Encode.string),
          ("appearance", groupAppearance),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      let mount = CoordinatorMount.create(
        ~parentContainer=Window.body,
        ~localSelectorString=groupInstanceId,
        ~elementIframeId="cardFormCoordinator",
        ~surfaceFamily="payments",
        ~groupId=groupInstanceId,
        ~sdkDomain=ApiEndpoint.sdkDomainUrl,
      )
      coordinatorMountRef := Some(mount)
      attachCoordinatorListener()
      // teardown is UNGATED — bare `{fullscreen:false}` frames carry no iframeId.
      let (fullscreenRouter, fullscreenAnswerer) = CoordinatorMount.makeFullscreenFlows(
        ~mount,
        ~localSelectorString=groupInstanceId,
        ~sdkDomain=ApiEndpoint.sdkDomainUrl,
        ~options=groupConfigAsOptions,
        ~appearance=groupAppearance,
      )
      // `Types.event` and `Window.event` are two record overlays of the SAME
      // MessageEvent; the Utils.eventToWindowEvent identity bridges them typed.
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenRouter(ev->eventToWindowEvent),
        `onPaymentsCoordinatorFullscreen-${groupInstanceId}`,
      )
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenAnswerer(ev->eventToWindowEvent),
        CoordinatorMount.fullscreenAnswerListenerName(groupInstanceId),
      )
      deinitCallbacksRef.contents->Array.push(() => {
        EventListenerManager.removeSmartEventListener(
          "message",
          `onPaymentsCoordinatorFullscreen-${groupInstanceId}`,
        )
        EventListenerManager.removeSmartEventListener(
          "message",
          CoordinatorMount.fullscreenAnswerListenerName(groupInstanceId),
        )
        CoordinatorMount.teardown(~mount, ~pendingPorts=pendingPortsRef.contents)
        coordinatorMountRef := None
        coordinatorReadyRef := false
      })
    }
  }

  let buildMountConfig = (~options: JSON.t, ~fieldId: string) => {
    /* `options` here is the PER-FIELD bag from `cardForm.create(type, opts)`; it must NOT
       shadow the group-level `appearance` bound at make() entry. */
    let fieldOptionsDict = options->getDictFromJson
    let savedCardDict = fieldOptionsDict->getDictFromDict("savedCard")
    let savedCardBrand = savedCardDict->getString("brand", "")
    let emptyJson = Dict.make()->JSON.Encode.object
    let fieldAppearance = fieldOptionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
    let appearance = if (
      fieldAppearance
      ->JSON.Decode.object
      ->Option.map(d => d->Dict.keysToArray->Array.length > 0)
      ->Option.getOr(false)
    ) {
      fieldAppearance
    } else {
      appearance
    }
    let redirectionFlagsDict =
      [
        ("shouldUseTopRedirection", JSON.Encode.bool(false)),
        ("shouldRemoveBeforeUnloadEvents", JSON.Encode.bool(false)),
      ]->Dict.fromArray
    /* appearance must be wrapped in the widgetOptions envelope `CardTheme.itemToObjMapper`
       expects — the raw merchant bag warns "Unknown Key" and drops the customizations. */
    let paymentOptions =
      [
        ("appearance", appearance),
        ("fonts", []->JSON.Encode.array),
        ("locale", locale->JSON.Encode.string),
        ("clientSecret", clientSecret->JSON.Encode.string),
        ("sdkAuthorization", ""->JSON.Encode.string),
        ("pmSessionId", ""->JSON.Encode.string),
      ]->Dict.fromArray->JSON.Encode.object
    [
      ("paymentElementCreate", true->JSON.Encode.bool),
      ("otherElements", false->JSON.Encode.bool),
      ("componentType", "payment"->JSON.Encode.string),
      ("paymentOptions", paymentOptions),
      ("options", options),
      ("iframeId", fieldId->JSON.Encode.string),
      ("publishableKey", publishableKey->JSON.Encode.string),
      ("endpoint", endpoint->JSON.Encode.string),
      ("clientSecret", clientSecret->JSON.Encode.string),
      ("sdkSessionId", ""->JSON.Encode.string),
      ("customPodUri", ""->JSON.Encode.string),
      ("parentURL", "*"->JSON.Encode.string),
      ("sdkHandleOneClickConfirmPayment", false->JSON.Encode.bool),
      ("launchTime", Date.now()->JSON.Encode.float),
      ("loggerSource", "hyper_payments_v2"->JSON.Encode.string),
      ("isSavedCardCvcFlow", false->JSON.Encode.bool),
      ("savedCardBrand", savedCardBrand->JSON.Encode.string),
      ("cardCollectionMode", "tokenise"->JSON.Encode.string),
      ("isBancontactCardFlow", false->JSON.Encode.bool),
      ("cardFlowType", "payment"->JSON.Encode.string),
      ("isTestMode", false->JSON.Encode.bool),
      ("customBackendUrl", ""->JSON.Encode.string),
      ("paymentId", ""->JSON.Encode.string),
      ("blockConfirm", false->JSON.Encode.bool),
      ("analyticsMetadata", Dict.make()->JSON.Encode.object),
      ("redirectionFlags", redirectionFlagsDict->JSON.Encode.object),
      ("locale", locale->JSON.Encode.string),
    ]->Dict.fromArray
  }

  let createFieldHandle = (fieldType: string, options: JSON.t, fieldId: string): fieldEntry => {
    let iframeRef: ref<Nullable.t<Dom.element>> = ref(Nullable.null)
    let lastStateRef: ref<option<JSON.t>> = ref(None)
    let lastFormStatusRef: ref<option<aggregatedStatus>> = ref(None)
    let eventHandlersRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())
    let listenerName = `onPaymentsV2Field-${fieldId}`

    /* no raw-value caching here: raw card data rides the off-window ports to the coordinator.
       The saved-card token is a Flow B hint embedded as `paymentToken` on the command. */
    let savedCardTokenRef = ref(
      options->getDictFromJson->getDictFromDict("savedCard")->getString("token", ""),
    )
    // latches the previous `focusReady` so the false→true edge posts `doFocus` exactly once.
    let prevFocusReadyRef = ref(false)

    let mountPostMessage = (mountedIframeRef, _selectorString, _sdkHandleOneClick) => {
      let config = buildMountConfig(~options, ~fieldId)
      /* ONE MessageChannel per field mount per portEpoch: `port2` rides WITH the mount-config
         transfer, `port1` queues for the coordinator and flushes on its `iframeMounted`. */
      portEpochCounterRef := portEpochCounterRef.contents + 1
      let epoch = portEpochCounterRef.contents
      let channel = MessageChannelBinding.makeChannel()
      let portKey = CardFormCoordinator.portKey(
        ~groupId=groupInstanceId,
        ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      )
      installedPortKeysRef := installedPortKeysRef.contents->Array.concat([portKey])
      CoordinatorMount.postFieldMountConfigWithPort(
        ~fieldIframe=mountedIframeRef,
        ~mountConfig=config->JSON.Encode.object,
        ~portKey,
        ~portEpoch=epoch,
        ~port=channel.port2,
      )
      pendingPortsRef := pendingPortsRef.contents->Array.concat([
        {
          fieldName: mapFieldTypeToInternalFieldName(fieldType),
          epoch,
          port: channel.port1,
        },
      ])
      flushPendingPorts()
      clientListDataPromise
      ->Promise.then(json => {
        mountedIframeRef->Window.iframePostMessage(
          [("clientList", json)]->Dict.fromArray,
        )
        Promise.resolve()
      })
      ->Promise.catch(err => {
        Console.error2("[PaymentsGroup] clientList fetch rejected — field continues without pre-warmed list", err)
        Promise.resolve()
      })
      ->ignore
      /* a cardCvc mounted after the user finished the cardNumber would never see a brand
         CHANGE, so seed it at handshake time with the brand we already learned. */
      if fieldType === "cardCvc" && lastDetectedBrandRef.contents !== "" {
        mountedIframeRef->Window.iframePostMessage(
          [("detectedCardBrand", lastDetectedBrandRef.contents->JSON.Encode.string)]->Dict.fromArray,
        )
      }
    }

    /* key on `ev.source === iframe.contentWindow` so multi-field groups don't cross-dispatch;
       the origin check guards against our own iframe being redirected mid-session. */
    let attachFieldListener = () => {
      let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => {
          let isOurIframe =
            iframeRef.contents
            ->Nullable.toOption
            ->Option.map(iframe =>
              ev.source === iframe->Window.contentWindow && ev.origin === innerIframeOrigin
            )
            ->Option.getOr(false)
          if isOurIframe {
            let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
            let dict = json->getDictFromJson
            let isReady = dict->getBool("ready", false)
            let isFocus = dict->getBool("focus", false)
            let isBlur = dict->getBool("blur", false)
            let isConfirmAck = dict->getBool("paymentConfirmAck", false)
            let isConfirmFail = dict->getBool("paymentConfirmFail", false)
            let isFormStatusChange = dict->getBool("formStatusChange", false)
            let cardStateUpdate = dict->Dict.get("cardStateUpdate")
            let payload =
              [
                ("elementType", fieldType->JSON.Encode.string),
                ("iframeId", fieldId->JSON.Encode.string),
              ]->Dict.fromArray->JSON.Encode.object
            if isReady {
              eventHandlersRef.contents->Dict.get("ready")->Option.forEach(cb => cb(payload))
            } else if isFocus {
              eventHandlersRef.contents->Dict.get("focus")->Option.forEach(cb => cb(payload))
            } else if isBlur {
              eventHandlersRef.contents->Dict.get("blur")->Option.forEach(cb => cb(payload))
            } else if isConfirmAck {
              /* same rule as the coordinator arm: ack == dispatched, never settled. `settle` is the
                 sole owner of the mutex and the backstop, so neither is touched here. */
              confirmDispatchedRef := true
              eventHandlersRef.contents
              ->Dict.get("confirmDispatched")
              ->Option.forEach(cb => cb(payload))
            } else if isConfirmFail {
              let errorMessage = dict->getString("errorMessage", "Card details incomplete or invalid")
              let errorPayload = {
                let errDict = Dict.make()
                errDict->Dict.set("elementType", fieldType->JSON.Encode.string)
                errDict->Dict.set("iframeId", fieldId->JSON.Encode.string)
                errDict->Dict.set("code", "validation_error"->JSON.Encode.string)
                errDict->Dict.set("message", errorMessage->JSON.Encode.string)
                errDict->JSON.Encode.object
              }
              eventHandlersRef.contents->Dict.get("error")->Option.forEach(cb => cb(errorPayload))
              /* terminal, like the coordinator's fail arm — settle rather than strand the caller.
                 (Today only the coordinator posts this pair; kept in sync so the invariant
                 "only `settle` releases the mutex" holds no matter who posts it.) */
              settlePendingConfirm(
                ~confirmId=dict->getString("confirmId", ""),
                groupFailureResponse(
                  ~code="validation_error",
                  ~errorType="validation_error",
                  ~message=errorMessage,
                ),
              )
            } else if isFormStatusChange {
              let rawStatus = dict->getString("status", "incomplete")
              let status =
                aggregatedStatusFromString(rawStatus)->Option.getOr(CardFormShared.Incomplete)
              let message = switch dict->Dict.get("message") {
              | Some(json) => json->JSON.Decode.string
              | None => None
              }
              let cardBrand = dict->getString("cardBrand", "")
              lastFormStatusRef := Some(status)
              let eventPayload = {
                let payloadDict = Dict.make()
                payloadDict->Dict.set("field", fieldType->JSON.Encode.string)
                payloadDict->Dict.set("elementType", fieldType->JSON.Encode.string)
                payloadDict->Dict.set("iframeId", fieldId->JSON.Encode.string)
                payloadDict->Dict.set(
                  "status",
                  status->aggregatedStatusToString->JSON.Encode.string,
                )
                switch message {
                | Some(messageText) =>
                  payloadDict->Dict.set("message", messageText->JSON.Encode.string)
                | None => ()
                }
                if cardBrand !== "" {
                  payloadDict->Dict.set("cardBrand", cardBrand->JSON.Encode.string)
                }
                payloadDict->JSON.Encode.object
              }
              eventHandlersRef.contents
              ->Dict.get("formStatusChange")
              ->Option.forEach(cb => cb(eventPayload))
              fieldEventsCallbacksRef.contents
              ->Dict.get(fieldType)
              ->Option.forEach(handlers =>
                handlers->Dict.get("formStatusChange")->Option.forEach(cb => cb(eventPayload))
              )
              eventCallbacksRef.contents
              ->Dict.get("formStatusChange")
              ->Option.forEach(cb => cb(eventPayload))
            } else {
              switch cardStateUpdate {
              | Some(stateJson) =>
                lastStateRef := Some(stateJson)
                let stateDict = stateJson->getDictFromJson
                /* the iframe decides WHEN focus advances; this only routes it. `prevFocusReadyRef` latches
                   the false→true edge so steady-state keystrokes do not re-fire `doFocus`. */
                let prevFocusReady = prevFocusReadyRef.contents
                let newFocusReady = stateDict->getBool("focusReady", false)
                prevFocusReadyRef := newFocusReady
                if newFocusReady && !prevFocusReady {
                  nextFieldFor(fieldType)->Option.forEach(nextFieldType => {
                    let nextIframe =
                      fieldsRef.contents
                      ->Dict.valuesToArray
                      ->Array.find(e => e.fieldType === nextFieldType)
                      ->Option.flatMap(entry => entry.iframeRef.contents->Nullable.toOption)
                    nextIframe->Option.forEach(iframe =>
                      iframe
                      ->Nullable.make
                      ->Window.iframePostMessage(
                        [("doFocus", true->JSON.Encode.bool)]->Dict.fromArray,
                      )
                    )
                  })
                }

                if fieldType === "cardNumber" {
                  let cardBrand = stateDict->getString("cardBrand", "")->CardUtils.normalizeCardBrand
                  if cardBrand !== "" && cardBrand !== lastDetectedBrandRef.contents {
                    lastDetectedBrandRef := cardBrand
                    let cvcIframe =
                      fieldsRef.contents
                      ->Dict.valuesToArray
                      ->Array.find(e => e.fieldType === "cardCvc")
                      ->Option.flatMap(entry => entry.iframeRef.contents->Nullable.toOption)
                    cvcIframe->Option.forEach(iframe =>
                      iframe
                      ->Nullable.make
                      ->Window.iframePostMessage(
                        [("detectedCardBrand", cardBrand->JSON.Encode.string)]->Dict.fromArray,
                      )
                    )
                  }
                }

                let changePayload = reshapeCardStateUpdateToChangePayload(
                  ~fieldType,
                  ~stateJson,
                )
                eventHandlersRef.contents
                ->Dict.get("change")
                ->Option.forEach(cb => cb(changePayload))
                // edge-triggered: rising fires `ready`, falling fires `unready`; steady states no-op.
                let readiness = computeGroupReadiness(fieldsRef)
                if readiness && !hasBeenReadyRef.contents {
                  hasBeenReadyRef := true
                  let readinessPayload =
                    [
                      ("elementType", "paymentsGroup"->JSON.Encode.string),
                      ("confirmDispatched", confirmDispatchedRef.contents->JSON.Encode.bool),
                    ]
                    ->Dict.fromArray
                    ->JSON.Encode.object
                  eventCallbacksRef.contents
                  ->Dict.get("ready")
                  ->Option.forEach(cb => cb(readinessPayload))
                } else if !readiness && hasBeenReadyRef.contents {
                  hasBeenReadyRef := false
                  let unreadyPayload =
                    [
                      ("elementType", "paymentsGroup"->JSON.Encode.string),
                      ("confirmDispatched", confirmDispatchedRef.contents->JSON.Encode.bool),
                    ]
                    ->Dict.fromArray
                    ->JSON.Encode.object
                  eventCallbacksRef.contents
                  ->Dict.get("unready")
                  ->Option.forEach(cb => cb(unreadyPayload))
                 }
               | None => ()
               }
             }
           }
         },
         listenerName,
       )
     }

    /* the merged appearance is ALSO injected into the positional `options` JSON, because
       LoaderPaymentElement reads `appearance.variables.cardFieldHeight` off its own bag. */
    let fieldOptionsDict = options->getDictFromJson
    let emptyJson = Dict.make()->JSON.Encode.object
    let fieldAppearance = fieldOptionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
    let appearanceJson = if (
      fieldAppearance
      ->JSON.Decode.object
      ->Option.map(d => d->Dict.keysToArray->Array.length > 0)
      ->Option.getOr(false)
    ) {
      fieldAppearance
    } else {
      appearance
    }
    let fieldOptionsWithAppearanceDict = fieldOptionsDict->Dict.copy
    fieldOptionsWithAppearanceDict->Dict.set("appearance", appearanceJson)
    let optionsForElement = fieldOptionsWithAppearanceDict->JSON.Encode.object
    let element = LoaderPaymentElement.make(
      "paymentMethodsSDK",
      optionsForElement,
      ref => {
        iframeRef := ref
      },
      [],
      mountPostMessage,
      ~appearance=appearanceJson,
      ~redirectionFlags=JotaiAtoms.defaultRedirectionFlags,
      ~sdkDomainUrl=ApiEndpoint.sdkDomainUrl,
      ~logger=None,
      ~confirmPayment=(_json => Promise.resolve(JSON.Encode.null)),
      ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      ~surfaceFamily="payments",
      ~groupId=groupInstanceId,
    )

    attachFieldListener()

    let handle: fieldHandle = {
      mount: selector => element.mount(selector),
      unmount: () => element.unmount(),
      destroy: () => {
        element.destroy()
        iframeRef := Nullable.null
        EventListenerManager.removeSmartEventListener(
          "message",
          `onPaymentsV2Field-${fieldId}`,
        )
      },
      update: newOptions => {
        iframeRef.contents->Window.iframePostMessage(
          [
            ("paymentElementsUpdate", true->JSON.Encode.bool),
            ("options", newOptions),
          ]->Dict.fromArray,
        )
        /* saved-card switch (Flow B): `savedCard.brand` must be a TOP-LEVEL postMessage key —
           LoaderController does not lift it out of a nested bag — and refresh the captured token. */
        let savedCardDict = newOptions->getDictFromJson->getDictFromDict("savedCard")
        let savedCardBrand = savedCardDict->getString("brand", "")
        if savedCardBrand !== "" {
          iframeRef.contents->Window.iframePostMessage(
            [("savedCardBrand", savedCardBrand->JSON.Encode.string)]->Dict.fromArray,
          )
        }
        let savedCardToken = savedCardDict->getString("token", "")
        if savedCardToken !== "" {
          savedCardTokenRef := savedCardToken
        }
      },
      focus: () => {
        iframeRef.contents->Window.iframePostMessage(
          [("doFocus", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      },
      blur: () => {
        iframeRef.contents->Window.iframePostMessage(
          [("doBlur", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      },
      clear: () => {
        iframeRef.contents->Window.iframePostMessage(
          [("doClearValues", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      },
      on: (event, cb) => {
        eventHandlersRef.contents->Dict.set(event, cb)
      },
    }

    // registered with the group deinit pool, so deinit() tears down routing even without destroy().
    deinitCallbacksRef.contents->Array.push(
      () => EventListenerManager.removeSmartEventListener("message", `onPaymentsV2Field-${fieldId}`),
    )

    {
      iframeRef,
      handle,
      fieldType,
      lastStateRef,
      lastFormStatusRef,
      listenerName,
      savedCardTokenRef,
      prevFocusReadyRef,
    }
  }

  let findFieldOfType = (matchFieldType: string): option<fieldEntry> => {
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.find(entry => entry.fieldType === matchFieldType)
  }

  /* `doSubmit` relay forwards Hyper's broadcast into the coordinator as a content-free
     `initiateConfirm`. The activity-name is unique per factory call so two groups coexist. */
  let doSubmitListenerName =
    `onPaymentsV2DoSubmit-${Date.now()->Float.toString}-${Math.random()
      ->Float.toString
      ->String.slice(~start=2, ~end=8)}`
  let attachSubmitRelay = () => {
    EventListenerManager.addSmartEventListener(
      "message",
      (ev: Types.event) => {
        /* deliberately NO ev.origin / ev.source check on this intake: `doSubmit` is a
           broadcast-by-design contract, and hearing a foreign one grants no power beyond re-invoking
           the already-exposed `group.confirm()` — the relay only posts into OUR OWN coordinator.
           The per-field listeners above consume field-emitted secrets and DO gate on source and origin. */
        let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
        let dict = json->getDictFromJson
        let isDoSubmit = dict->getBool("doSubmit", false)
        if isDoSubmit {
          // both flows post a coordinator command; raw SAD is never assembled group-side.
          switch findFieldOfType("cardNumber") {
          | Some(_entry) =>
            postCoordinatorCommand([
              ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
              ("flow", "payments"->JSON.Encode.string),
            ])
          | None =>
            findFieldOfType("cardCvc")->Option.forEach(entry => {
              let paymentToken = entry.savedCardTokenRef.contents
              if paymentToken !== "" {
                postCoordinatorCommand([
                  ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
                  ("flow", "savedCardCvc"->JSON.Encode.string),
                  ("paymentToken", paymentToken->JSON.Encode.string),
                ])
              }
            })
          }
        }
      },
      doSubmitListenerName,
    )
  }
  attachSubmitRelay()
  // without this the root-window listener leaks across group re-instantiations.
  deinitCallbacksRef.contents->Array.push(() => EventListenerManager.removeSmartEventListener("message", doSubmitListenerName))

  let create = (fieldType: string, options: JSON.t): fieldHandle => {
    switch mapFieldTypeToInternalFieldName(fieldType) {
    | "" => {
        Console.error(`[PaymentsGroup] invalid_field_type: ${fieldType}`)
        Types.defaultFieldHandle
      }
    | _ =>
      ensureCoordinatorMounted()
      let fieldId = `${fieldType}-${Date.now()->Float.toString}-${Math.random()->Float.toString->String.slice(~start=2, ~end=8)}`
      let entry = createFieldHandle(fieldType, options, fieldId)
      fieldsRef.contents->Dict.set(fieldId, entry)
      let fieldsDict = fields.contents->getDictFromJson
      let fieldMeta =
        [
          ("id", fieldId->JSON.Encode.string),
          ("type", fieldType->JSON.Encode.string),
        ]->Dict.fromArray->JSON.Encode.object
      fieldsDict->Dict.set(fieldId, fieldMeta)
      fields := fieldsDict->JSON.Encode.object

      if fieldEventsCallbacksRef.contents->Dict.get(fieldType)->Option.isNone {
        fieldEventsCallbacksRef.contents->Dict.set(fieldType, Dict.make())
      }
      let fieldEventsDict = fieldEvents.contents->getDictFromJson
      let poolMeta =
        [("fieldType", fieldType->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object
      fieldEventsDict->Dict.set(fieldType, poolMeta)
      fieldEvents := fieldEventsDict->JSON.Encode.object
      entry.handle
    }
  }

  let update = (newOptions: JSON.t): unit => {
    /* refuse immutable config changes loudly: `clientSecret` and `confirmParams` are baked into
       the mount-config, so an override would confirm against the OLD intent. */
    let newOptionsDict = newOptions->getDictFromJson
    let attemptsClientSecretMutation = newOptionsDict->Dict.get("clientSecret")->Option.isSome
    let attemptsConfirmParamsMutation = newOptionsDict->Dict.get("confirmParams")->Option.isSome
    if attemptsClientSecretMutation || attemptsConfirmParamsMutation {
      Console.warn(
        "[PaymentsGroup] update() refused: `clientSecret` and `confirmParams` are immutable after mount. " ++
        "Create a new group (or remount the fields) to switch intents.",
      )
    } else {
      fieldsRef.contents
      ->Dict.valuesToArray
      ->Array.forEach(entry => {
        entry.iframeRef.contents->Window.iframePostMessage(
          [
            ("paymentElementsUpdate", true->JSON.Encode.bool),
            ("options", newOptions),
          ]->Dict.fromArray,
        )
      })
    }
  }

  let on = (event: string, cb: JSON.t => unit): unit => {
    eventCallbacksRef.contents->Dict.set(event, cb)
  }

  /* dispatches the CONTENT-FREE `initiateConfirm` frame and returns a PENDING promise, exactly
     like `hyper.confirmPayment()`: it resolves only once the coordinator's real network outcome
     comes back on `submitSuccessful`, or on a pre-network `paymentConfirmFail`, or at deinit().
     Deliberately NO deadline — same as `hyper.confirmPayment()`, which carries none: the
     dispatch cannot be lost (queued until the coordinator is ready) and `PaymentHelpers.intentCall`
     broadcasts an outcome on every branch, so a timer could only ever pre-empt a real result and
     hand the merchant a bogus failure for a payment that actually went through.
     Like confirmPayment it NEVER rejects. `Promise.make`'s executor is synchronous, so the mutex
     is latched before `confirm()` returns and `confirm_in_progress` stays reachable. */
  let dispatchConfirm = (~flow: string, ~paymentToken: option<string>): promise<JSON.t> =>
    Promise.make((resolve, _reject) => {
      let confirmId = `${Date.now()->Float.toString}-${Math.random()->Float.toString}`
      let settledRef = ref(false)
      /* the ONE place the confirm mutex is released. Exactly-once, so a `submitSuccessful` that
         lands after deinit() already settled the promise is dropped. */
      let settle = (result: JSON.t) =>
        if !settledRef.contents {
          settledRef := true
          coordinatorConfirmPendingRef := None
          confirmingRef := false
          resolve(result)
        }
      confirmingRef := true
      coordinatorConfirmPendingRef := Some((confirmId, settle))
      postCoordinatorCommand(
        [
          ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
          ("flow", flow->JSON.Encode.string),
          ("confirmId", confirmId->JSON.Encode.string),
        ]->Array.concat(
          switch paymentToken {
          | Some(token) => [("paymentToken", token->JSON.Encode.string)]
          | None => []
          },
        ),
      )
    })

  /* explicit zero-arg confirm — `hyper.confirmPayment()`'s `doSubmit` never reaches
     group-mounted iframes. Guards: mutex → `confirm_in_progress`; cardNumber mounted → Flow A;
     only cardCvc → Flow B; nothing mounted → `validation_error`. Every early return now uses the
     same `{error: {type, message, code}}` envelope confirmPayment resolves with. */
  let confirm = (): promise<JSON.t> => {
    if confirmingRef.contents {
      Promise.resolve(
        groupFailureResponse(
          ~code="confirm_in_progress",
          ~errorType="api_error",
          ~message="confirm already in progress",
        ),
      )
    } else {
      switch (findFieldOfType("cardNumber"), findFieldOfType("cardCvc")) {
      | (Some(_entry), _) => dispatchConfirm(~flow="payments", ~paymentToken=None)
      | (None, Some(entry)) =>
        // Flow B — the coordinator's `savedCardCvc` arm owns the real confirm POST.
        let paymentToken = entry.savedCardTokenRef.contents
        if paymentToken === "" {
          Promise.resolve(
            groupFailureResponse(
              ~code="validation_error",
              ~errorType="validation_error",
              ~message="saved-card CVC flow requires a token — call cardForm.create(\"cardCvc\", {savedCard: {token, brand}}) or field.update({savedCard: {token, brand}}) before confirm()",
            ),
          )
        } else {
          dispatchConfirm(~flow="savedCardCvc", ~paymentToken=Some(paymentToken))
        }
      | (None, None) =>
        Promise.resolve(
          groupFailureResponse(
            ~code="validation_error",
            ~errorType="validation_error",
            ~message="no card fields mounted — mount cardNumber (+ cardExpiry/cardCvc) for a new card, or only cardCvc with {savedCard: {token, brand}} for saved-card recollect",
          ),
        )
      }
    }
  }

  // `onFieldEvent` and `fieldEvents` are NOT part of the `Types.cardForm` contract.
  let onFieldEvent = (fieldType: string, event: string, cb: JSON.t => unit): unit => {
    switch fieldEventsCallbacksRef.contents->Dict.get(fieldType) {
    | Some(pool) => pool->Dict.set(event, cb)
    | None => {
        let fresh = Dict.make()
        fresh->Dict.set(event, cb)
        fieldEventsCallbacksRef.contents->Dict.set(fieldType, fresh)
      }
    }
  }

  let deinit = (): unit => {
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.forEach(entry => {
      try entry.handle.destroy() catch { | _ => () }
    })
    fieldsRef := Dict.make()
    fields := Dict.make()->JSON.Encode.object
    fieldEvents := Dict.make()->JSON.Encode.object
    fieldEventsCallbacksRef := Dict.make()
    confirmDispatchedRef := false
    /* an in-flight confirm() is a PENDING promise with no deadline, so tearing the group down
       without settling it would strand the merchant's `await` forever. deinit() is the ONE
       genuinely terminal case where no outcome can ever arrive — the coordinator iframe and its
       listeners are about to be destroyed — so this settle is what makes the timer's removal
       safe. Settle first (that also releases the mutex), then belt-and-braces the refs below. */
    settlePendingConfirm(
      groupFailureResponse(
        ~code="group_deinitialized",
        ~errorType="server_error",
        ~message="cardForm.deinit() was called while a confirm was in flight — the payment may still have gone through; check the intent status",
      ),
    )
    confirmingRef := false
    // a confirm queued behind a coordinator that never booted must not outlive the group.
    pendingCoordinatorCommandsRef := []
    coordinatorConfirmPendingRef := None
    /* close the group's epoch ports BEFORE running deinitCallbacks (which strip the
       coordinator's DOM and listeners): ports must die before their listeners do. */
    installedPortKeysRef.contents->Array.forEach(key => SadPortRegistry.closePort(~key))
    installedPortKeysRef := []
    deinitCallbacksRef.contents->Array.forEach(cb => cb())
    deinitCallbacksRef := []
    pendingPortsRef := []
    coordinatorMountRef := None
    coordinatorReadyRef := false
  }

  let cardForm: cardForm = {
    create,
    update,
    on,
    onFieldEvent,
    confirm,
    deinit,
    fields,
    fieldEvents,
  }
  let publicCardForm: Types.cardForm = (cardForm :> Types.cardForm)
  publicCardForm
}

// deprecated alias — new code must use `makeCardForm`.
@deprecated("Use makeCardForm")
let make = (~config: groupConfig): Types.cardForm => makeCardForm(~config)
