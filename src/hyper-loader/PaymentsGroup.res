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

// backstop: without it a missing ack/fail leaves the confirm mutex latched forever.
let confirmSettleTimeoutMs = 8000

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

  /* per-group confirm mutex, LATCHED at dispatch until the relay settles: released by the
     ack/fail arms, the settle-timeout backstop, or deinit(). Two groups confirm independently. */
  let confirmingRef: ref<bool> = ref(false)

  let confirmSettleTimeoutRef = ref(None)

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

  /* relays a masked command envelope; `flow`, `paymentToken` and `confirmId` ride the same
     frame. Raw SAD is never in the message — the coordinator reads it off its port registry. */
  let postCoordinatorCommand = fields => {
    try
      coordinatorMountRef.contents->Option.forEach(mount =>
        mount.iframe->Nullable.make->Window.iframePostMessage(fields->Dict.fromArray)
      )
    catch {
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
            // relay settled (ack) — release the confirm mutex and cancel the settle-timeout backstop.
            confirmDispatchedRef := true
            confirmingRef := false
            confirmSettleTimeoutRef.contents->Option.forEach(clearTimeout)
            confirmSettleTimeoutRef := None
            let payload =
              [
                ("elementType", "paymentsCoordinator"->JSON.Encode.string),
                ("iframeId", groupInstanceId->JSON.Encode.string),
              ]
              ->Dict.fromArray
              ->JSON.Encode.object
            eventCallbacksRef.contents->Dict.get("confirmDispatched")->Option.forEach(cb => cb(payload))
          } else if dict->getBool("paymentConfirmFail", false) {
            confirmingRef := false
            confirmSettleTimeoutRef.contents->Option.forEach(clearTimeout)
            confirmSettleTimeoutRef := None
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
      // `Types.event` and `Window.event` are the same message event; the cast keeps both exact.
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenRouter(%raw(`ev`)),
        `onPaymentsCoordinatorFullscreen-${groupInstanceId}`,
      )
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenAnswerer(%raw(`ev`)),
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
              confirmDispatchedRef := true
              // ack settles: release the mutex and cancel its backstop; whichever fires first owns it.
              confirmingRef := false
              confirmSettleTimeoutRef.contents->Option.forEach(clearTimeout)
              confirmSettleTimeoutRef := None
              eventHandlersRef.contents
              ->Dict.get("confirmDispatched")
              ->Option.forEach(cb => cb(payload))
            } else if isConfirmFail {
              confirmingRef := false
              confirmSettleTimeoutRef.contents->Option.forEach(clearTimeout)
              confirmSettleTimeoutRef := None
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

  /* explicit zero-arg confirm — `hyper.confirmPayment()`'s `doSubmit` never reaches
     group-mounted iframes. Guards: mutex → `confirm_in_progress`; cardNumber mounted → Flow A;
     only cardCvc → Flow B; nothing mounted → `validation_error`. */
  let confirm = (): promise<JSON.t> => {
    if confirmingRef.contents {
      Promise.resolve(
        [
          ("status", "error"->JSON.Encode.string),
          (
            "error",
            [
              ("code", "confirm_in_progress"->JSON.Encode.string),
              ("type", "api_error"->JSON.Encode.string),
              ("message", "confirm already in progress"->JSON.Encode.string),
            ]->Dict.fromArray->JSON.Encode.object,
          ),
        ]->Dict.fromArray->JSON.Encode.object,
      )
    } else {
      switch (findFieldOfType("cardNumber"), findFieldOfType("cardCvc")) {
      | (Some(_entry), _) => {
          confirmingRef := true
          postCoordinatorCommand([
            ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
            ("flow", "payments"->JSON.Encode.string),
            ("confirmId", `${Date.now()->Float.toString}-${Math.random()->Float.toString}`->JSON.Encode.string),
          ])
          /* the mutex LATCHES across the relay — releasing here would make the flag never observably
             true across an await, so `confirm_in_progress` would be unreachable. */
          confirmSettleTimeoutRef := Some(
            setTimeout(() => {
              confirmingRef := false
              confirmSettleTimeoutRef := None
            }, confirmSettleTimeoutMs),
          )
          // the real confirm result arrives on the inner iframe's `submitSuccessful` broadcast.
          Promise.resolve(
            [
              ("status", "initiated"->JSON.Encode.string),
              ("confirmDispatched", true->JSON.Encode.bool),
            ]->Dict.fromArray->JSON.Encode.object,
          )
        }
      | (None, Some(entry)) =>
        // Flow B — the coordinator's `savedCardCvc` arm owns the real confirm POST.
        let paymentToken = entry.savedCardTokenRef.contents
        if paymentToken === "" {
          Promise.resolve(
            [
              ("status", "error"->JSON.Encode.string),
              (
                "error",
                [
                  ("code", "validation_error"->JSON.Encode.string),
                  (
                    "message",
                    "saved-card CVC flow requires a token — call cardForm.create(\"cardCvc\", {savedCard: {token, brand}}) or field.update({savedCard: {token, brand}}) before confirm()"
                    ->JSON.Encode.string,
                  ),
                  ("type", "validation_error"->JSON.Encode.string),
                ]->Dict.fromArray->JSON.Encode.object,
              ),
            ]->Dict.fromArray->JSON.Encode.object,
          )
        } else {
          confirmingRef := true
          postCoordinatorCommand([
            ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
            ("flow", "savedCardCvc"->JSON.Encode.string),
            ("paymentToken", paymentToken->JSON.Encode.string),
            ("confirmId", `${Date.now()->Float.toString}-${Math.random()->Float.toString}`->JSON.Encode.string),
          ])
          // same latch discipline as Flow A; the coordinator posts the same ack/fail pair.
          confirmSettleTimeoutRef := Some(
            setTimeout(() => {
              confirmingRef := false
              confirmSettleTimeoutRef := None
            }, confirmSettleTimeoutMs),
          )
          Promise.resolve(
            [
              ("status", "initiated"->JSON.Encode.string),
              ("confirmDispatched", true->JSON.Encode.bool),
            ]->Dict.fromArray->JSON.Encode.object,
          )
        }
      | (None, None) =>
        Promise.resolve(
          [
            ("status", "error"->JSON.Encode.string),
            (
              "error",
              [
                ("code", "validation_error"->JSON.Encode.string),
                (
                  "message",
                  "no card fields mounted — mount cardNumber (+ cardExpiry/cardCvc) for a new card, or only cardCvc with {savedCard: {token, brand}} for saved-card recollect"
                  ->JSON.Encode.string,
                ),
                ("type", "validation_error"->JSON.Encode.string),
              ]->Dict.fromArray->JSON.Encode.object,
            ),
          ]->Dict.fromArray->JSON.Encode.object,
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
    confirmingRef := false
    // cancel any armed settle-timeout so a dead group's timer can't fire later.
    confirmSettleTimeoutRef.contents->Option.forEach(clearTimeout)
    confirmSettleTimeoutRef := None
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
