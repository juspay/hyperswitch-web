open Utils
open CardFormGroupShared

type fieldHandle = Types.fieldHandle

type groupConfig = {
  clientSecret: string,
  publishableKey: option<string>,
  endpoint: option<string>,
  appearance: option<JSON.t>,
  locale: option<string>,
}

let reshapeCardStateUpdateToChangePayload = CardFormShared.reshapeCardStateUpdateToChangePayload

type fieldEntry = {
  iframeRef: ref<Nullable.t<Dom.element>>,
  handle: fieldHandle,
  fieldType: string,
  lastStateRef: ref<option<JSON.t>>,
  savedCardTokenRef: ref<string>,
}

let mapFieldTypeToInternalFieldName = CardFormShared.mapFieldTypeToInternalFieldName

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

let groupFailureResponse = (~code: string, ~errorType: string, ~message: string): JSON.t => {
  let envelope = getFailedSubmitResponse(~errorType, ~message)
  let envelopeDict = envelope->getDictFromJson
  let errorDict = envelopeDict->getDictFromDict("error")
  errorDict->Dict.set("code", code->JSON.Encode.string)
  envelopeDict->Dict.set("error", errorDict->JSON.Encode.object)
  envelopeDict->JSON.Encode.object
}

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
  let eventCallbacksRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())
  let deinitCallbacksRef: ref<array<unit => unit>> = ref([])

  let confirmDispatchedRef: ref<bool> = ref(false)

  let confirmingRef: ref<bool> = ref(false)

  let coordinatorConfirmPendingRef: ref<option<(string, JSON.t => unit)>> = ref(None)

  let settlePendingConfirm = (~confirmId: string="", result: JSON.t): unit =>
    switch coordinatorConfirmPendingRef.contents {
    | Some((pendingId, settle)) if confirmId === "" || confirmId === pendingId => settle(result)
    | _ => ()
    }

  let hasBeenReadyRef: ref<bool> = ref(false)

  let clientListDataPromise = PaymentHelpers.fetchClientList(
    ~clientSecret,
    ~publishableKey,
    ~logger=LoggerUtils.defaultLoggerConfig,
    ~customPodUri="",
    ~endpoint,
  )

  let groupInstanceId = uniqueId(~prefix="payments")
  let coordinator = makeCoordinatorChannel(~groupId=groupInstanceId)
  let coordinatorListenerName = `onPaymentsCoordinator-${groupInstanceId}`

  let paymentsPaymentOptions = (~appearance: JSON.t) =>
    buildPaymentOptions(
      ~appearance,
      ~locale,
      ~credentialKeys=[
        ("clientSecret", clientSecret->JSON.Encode.string),
        ("sdkAuthorization", ""->JSON.Encode.string),
        ("pmSessionId", ""->JSON.Encode.string),
      ],
    )

  let attachCoordinatorListener = () => {
    EventListenerManager.addSmartEventListener(
      "message",
      (ev: Types.event) => {
        let isOurCoordinator = isFromIframe(
          ~ev,
          ~iframe=coordinator.mountRef.contents->Option.map(mount => mount.iframe),
          ~origin=URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin,
        )
        if isOurCoordinator {
          let json = eventDataJson(ev)
          let dict = json->getDictFromJson
          if dict->getBool("iframeMounted", false) {
            coordinator.readyRef := true
            flushPendingPorts(coordinator)
            switch coordinator.mountRef.contents {
            | Some(mount) => {
              let coordinatorPaymentOptions = paymentsPaymentOptions(~appearance)
              let coordinatorConfig =
                [
                  ("paymentElementCreate", true->JSON.Encode.bool),
                  ("otherElements", false->JSON.Encode.bool),
                  ("componentType", "payment"->JSON.Encode.string),
                  ("paymentOptions", coordinatorPaymentOptions),
                  ("options", Dict.make()->JSON.Encode.object),
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
            flushPendingCoordinatorCommands(coordinator)
            clientListDataPromise
            ->Promise.then(json => {
              switch coordinator.mountRef.contents {
              | Some(mount) =>
                mount.iframe->Nullable.make->Window.iframePostMessage(
                  [("clientList", json)]->Dict.fromArray,
                )
              | None => ()
              }
              Promise.resolve()
            })
            ->Promise.catch(err => {
              Console.error2("[PaymentsGroup] clientList fetch rejected — coordinator continues without pre-warmed list", err)
              Promise.resolve()
            })
            ->ignore
          } else if dict->getBool("paymentConfirmAck", false) {
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
    switch coordinator.mountRef.contents {
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
      coordinator.mountRef := Some(mount)
      attachCoordinatorListener()
      let (fullscreenRouter, fullscreenAnswerer) = CoordinatorMount.makeFullscreenFlows(
        ~mount,
        ~localSelectorString=groupInstanceId,
        ~sdkDomain=ApiEndpoint.sdkDomainUrl,
        ~options=groupConfigAsOptions,
        ~appearance=groupAppearance,
      )
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
        CoordinatorMount.teardown(~mount, ~pendingPorts=coordinator.pendingPortsRef.contents)
        coordinator.mountRef := None
        coordinator.readyRef := false
      })
    }
  }

  let buildMountConfig = (~options: JSON.t, ~fieldId: string) => {
    let fieldOptionsDict = options->getDictFromJson
    let savedCardDict = fieldOptionsDict->getDictFromDict("savedCard")
    let savedCardBrand = savedCardDict->getString("brand", "")
    let appearance = resolveFieldAppearance(~fieldOptionsDict, ~groupAppearance=appearance)
    buildFieldMountConfig(
      ~paymentOptions=paymentsPaymentOptions(~appearance),
      ~options,
      ~fieldId,
      ~publishableKey,
      ~credentialKeys=[
        ("endpoint", endpoint->JSON.Encode.string),
        ("clientSecret", clientSecret->JSON.Encode.string),
      ],
      ~sdkSessionId="",
      ~loggerSource="hyper_payments_v2",
      ~savedCardBrand,
      ~tailKeys=[("locale", locale->JSON.Encode.string)],
    )
  }

  let findFieldOfType = (matchFieldType: string): option<fieldEntry> =>
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.find(entry => entry.fieldType === matchFieldType)

  let createFieldHandle = (fieldType: string, options: JSON.t, fieldId: string): fieldEntry => {
    let iframeRef: ref<Nullable.t<Dom.element>> = ref(Nullable.null)
    let lastStateRef: ref<option<JSON.t>> = ref(None)
    let eventHandlersRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())
    let listenerName = `onPaymentsV2Field-${fieldId}`

    let savedCardTokenRef = ref(
      options->getDictFromJson->getDictFromDict("savedCard")->getString("token", ""),
    )
    let mountPostMessage = (mountedIframeRef, _selectorString, _sdkHandleOneClick) => {
      coordinator->openFieldPort(
        ~fieldIframe=mountedIframeRef,
        ~mountConfig=buildMountConfig(~options, ~fieldId)->JSON.Encode.object,
        ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      )
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
    }

    let attachFieldListener = () => {
      let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => {
          let isOurIframe = isFromIframe(
            ~ev,
            ~iframe=iframeRef.contents->Nullable.toOption,
            ~origin=innerIframeOrigin,
          )
          if isOurIframe {
            let json = eventDataJson(ev)
            let dict = json->getDictFromJson
            let isReady = dict->getBool("ready", false)
            let isFocus = dict->getBool("focus", false)
            let isBlur = dict->getBool("blur", false)
            let isConfirmAck = dict->getBool("paymentConfirmAck", false)
            let isConfirmFail = dict->getBool("paymentConfirmFail", false)
            let isCardFieldStatus =
              dict->getString("eventName", "") === SubscriptionEventTypes.cardFieldStatusEventName
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
              settlePendingConfirm(
                ~confirmId=dict->getString("confirmId", ""),
                groupFailureResponse(
                  ~code="validation_error",
                  ~errorType="validation_error",
                  ~message=errorMessage,
                ),
              )
            } else if isCardFieldStatus {
              let statusPayload = dict->getDictFromDict("payload")
              let rawStatus = statusPayload->getString("status", "incomplete")
              let status =
                CardFormShared.fieldFormStatusFromString(rawStatus)->Option.getOr(
                  CardFormShared.Incomplete,
                )
              let eventPayload = {
                let normalizedPayload = statusPayload->Dict.copy
                normalizedPayload->Dict.set(
                  "status",
                  status->CardFormShared.fieldFormStatusToString->JSON.Encode.string,
                )
                let envelope = Dict.make()
                envelope->Dict.set("elementType", fieldType->JSON.Encode.string)
                envelope->Dict.set("iframeId", fieldId->JSON.Encode.string)
                envelope->Dict.set(
                  "eventName",
                  SubscriptionEventTypes.cardFieldStatusEventName->JSON.Encode.string,
                )
                envelope->Dict.set("payload", normalizedPayload->JSON.Encode.object)
                envelope->JSON.Encode.object
              }
              let cardFieldStatusEvent = SubscriptionEventTypes.cardFieldStatusEventName
              eventHandlersRef.contents
              ->Dict.get(cardFieldStatusEvent)
              ->Option.forEach(cb => cb(eventPayload))
              eventCallbacksRef.contents
              ->Dict.get(cardFieldStatusEvent)
              ->Option.forEach(cb => cb(eventPayload))
            } else {
              switch cardStateUpdate {
              | Some(stateJson) =>
                lastStateRef := Some(stateJson)
                let changePayload = reshapeCardStateUpdateToChangePayload(
                  ~fieldType,
                  ~stateJson,
                )
                eventHandlersRef.contents
                ->Dict.get("change")
                ->Option.forEach(cb => cb(changePayload))
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

    let fieldOptionsDict = options->getDictFromJson
    let appearanceJson = resolveFieldAppearance(~fieldOptionsDict, ~groupAppearance=appearance)
    let optionsForElement = optionsWithAppearance(~fieldOptionsDict, ~appearance=appearanceJson)
    let handle: fieldHandle = makeFieldElementAndHandle(
      ~optionsForElement,
      ~appearance=appearanceJson,
      ~iframeRef,
      ~mountPostMessage,
      ~sdkDomainUrl=ApiEndpoint.sdkDomainUrl,
      ~surfaceFamily="payments",
      ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      ~groupId=groupInstanceId,
      ~listenerName,
      ~eventHandlersRef,
      ~update=newOptions => {
        let savedCardToken = postFieldUpdate(~iframeRef, ~newOptions)->getString("token", "")
        if savedCardToken !== "" {
          savedCardTokenRef := savedCardToken
        }
      },
    )

    attachFieldListener()

    deinitCallbacksRef.contents->Array.push(
      () => EventListenerManager.removeSmartEventListener("message", `onPaymentsV2Field-${fieldId}`),
    )

    {
      iframeRef,
      handle,
      fieldType,
      lastStateRef,
      savedCardTokenRef,
    }
  }

  let doSubmitListenerName = uniqueId(~prefix="onPaymentsV2DoSubmit")
  let attachSubmitRelay = () => {
    EventListenerManager.addSmartEventListener(
      "message",
      (ev: Types.event) => {
        let json = eventDataJson(ev)
        let dict = json->getDictFromJson
        let isDoSubmit = dict->getBool("doSubmit", false)
        if isDoSubmit {
          switch findFieldOfType("cardNumber") {
          | Some(_entry) =>
            postCoordinatorCommand(coordinator, [
              ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
              ("flow", "payments"->JSON.Encode.string),
            ])
          | None =>
            findFieldOfType("cardCvc")->Option.forEach(entry => {
              let paymentToken = entry.savedCardTokenRef.contents
              if paymentToken !== "" {
                postCoordinatorCommand(coordinator, [
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
  deinitCallbacksRef.contents->Array.push(() => EventListenerManager.removeSmartEventListener("message", doSubmitListenerName))

  let create = (fieldType: string, options: JSON.t): fieldHandle => {
    switch mapFieldTypeToInternalFieldName(fieldType) {
    | "" => {
        Console.error(`[PaymentsGroup] invalid_field_type: ${fieldType}`)
        Types.defaultFieldHandle
      }
    | _ =>
      ensureCoordinatorMounted()
      let fieldId = uniqueId(~prefix=fieldType)
      let entry = createFieldHandle(fieldType, options, fieldId)
      fieldsRef.contents->Dict.set(fieldId, entry)
      registerField(~fields, ~fieldId, ~fieldType)

      entry.handle
    }
  }

  let update = (newOptions: JSON.t): unit => {
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

  let dispatchConfirm = (~flow: string, ~paymentToken: option<string>): promise<JSON.t> =>
    Promise.make((resolve, _reject) => {
      let confirmId = `${Date.now()->Float.toString}-${Math.random()->Float.toString}`
      let settledRef = ref(false)
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
        coordinator,
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


  let deinit = (): unit => {
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.forEach(entry => {
      try entry.handle.destroy() catch { | _ => () }
    })
    fieldsRef := Dict.make()
    fields := Dict.make()->JSON.Encode.object
    confirmDispatchedRef := false
    settlePendingConfirm(
      groupFailureResponse(
        ~code="group_deinitialized",
        ~errorType="server_error",
        ~message="cardForm.deinit() was called while a confirm was in flight — the payment may still have gone through; check the intent status",
      ),
    )
    confirmingRef := false
    coordinator.pendingCommandsRef := []
    coordinatorConfirmPendingRef := None
    closeInstalledPorts(coordinator)
    deinitCallbacksRef.contents->Array.forEach(cb => cb())
    deinitCallbacksRef := []
    coordinator.pendingPortsRef := []
    coordinator.mountRef := None
    coordinator.readyRef := false
  }

  let cardForm: Types.cardForm = {
    create,
    update,
    on,
    confirm,
    deinit,
    fields,
  }
  cardForm
}
