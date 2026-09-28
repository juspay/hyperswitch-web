open Utils
open CardFormGroupShared

type fieldHandle = Types.fieldHandle

type groupConfig = {
  clientSecret: string,
  sdkAuthorization: string,
  publishableKey: option<string>,
  endpoint: option<string>,
  appearance: option<JSON.t>,
  locale: option<string>,
  logger: HyperLoggerTypes.loggerMake,
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
  let sdkAuthorization = config.sdkAuthorization
  let publishableKey = config.publishableKey->Option.getOr("")
  let endpoint = switch config.endpoint {
  | Some(e) => e
  | None => ApiEndpoint.getApiEndPoint(~publishableKey)
  }
  let appearance = config.appearance->Option.getOr(Dict.make()->JSON.Encode.object)
  let locale = config.locale->Option.getOr("en")
  let logger = config.logger
  logger.setLogInfo(~value="Card form created", ~eventName=CARD_FORM_FLOW)

  let fieldsRef: ref<Dict.t<fieldEntry>> = ref(Dict.make())
  let fields: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)
  let eventCallbacksRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())
  let deinitCallbacksRef: ref<array<unit => unit>> = ref([])


  let confirmingRef: ref<bool> = ref(false)

  let coordinatorConfirmPendingRef: ref<option<(string, JSON.t => unit)>> = ref(None)

  let settlePendingConfirm = (~confirmId: string="", result: JSON.t): unit =>
    switch coordinatorConfirmPendingRef.contents {
    | Some((pendingId, settle)) if confirmId === "" || confirmId === pendingId => settle(result)
    | _ => ()
    }

  let hasBeenReadyRef: ref<bool> = ref(false)

  let subscriptionEventsRef: ref<array<string>> = ref([])

  let coordinatorOptions = () =>
    [
      (
        "subscriptionEvents",
        subscriptionEventsRef.contents->Array.map(JSON.Encode.string)->JSON.Encode.array,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object

  let clientListDataPromise = PaymentHelpers.fetchClientList(
    ~clientSecret,
    ~publishableKey,
    ~logger,
    ~customPodUri="",
    ~endpoint,
    ~sdkAuthorization=Some(sdkAuthorization)->getNonEmptyOption,
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
        ("sdkAuthorization", sdkAuthorization->JSON.Encode.string),
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
                  ("options", coordinatorOptions()),
                  ("iframeId", groupInstanceId->JSON.Encode.string),
                  ("publishableKey", publishableKey->JSON.Encode.string),
                  ("endpoint", endpoint->JSON.Encode.string),
                  ("clientSecret", clientSecret->JSON.Encode.string),
                  ("sdkAuthorization", sdkAuthorization->JSON.Encode.string),
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
          } else if dict->getBool("paymentConfirmFail", false) {
            let errorMessage = dict->getString("errorMessage", "Card details incomplete or invalid")
            settlePendingConfirm(
              ~confirmId=dict->getString("confirmId", ""),
              groupFailureResponse(
                ~code="validation_error",
                ~errorType="validation_error",
                ~message=errorMessage,
              ),
            )
          } else if dict->getString("eventName", "") === "cardDetailsChange" {
            eventCallbacksRef.contents->Dict.get("change")->Option.forEach(cb => cb(json))
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
          ("sdkAuthorization", config.sdkAuthorization->JSON.Encode.string),
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
    let savedCardBrand = savedCardDict->savedCardNetwork
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
      options->getDictFromJson->getDictFromDict("savedCard")->getString("paymentToken", ""),
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
            let isConfirmFail = dict->getBool("paymentConfirmFail", false)
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
            } else if isConfirmFail {
              let errorMessage = dict->getString("errorMessage", "Card details incomplete or invalid")
              settlePendingConfirm(
                ~confirmId=dict->getString("confirmId", ""),
                groupFailureResponse(
                  ~code="validation_error",
                  ~errorType="validation_error",
                  ~message=errorMessage,
                ),
              )
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
                    [("elementType", "paymentsGroup"->JSON.Encode.string)]
                    ->Dict.fromArray
                    ->JSON.Encode.object
                  eventCallbacksRef.contents
                  ->Dict.get("ready")
                  ->Option.forEach(cb => cb(readinessPayload))
                } else if !readiness {
                  hasBeenReadyRef := false
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
        let savedCardToken =
          postFieldUpdate(~iframeRef, ~newOptions)->getString("paymentToken", "")
        if savedCardToken !== "" {
          savedCardTokenRef := savedCardToken
        }
      },
      ~logger,
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
  let isFromOurFrames = (ev: Types.event): bool => {
    let sdkOrigin = URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin
    isFromIframe(
      ~ev,
      ~iframe=coordinator.mountRef.contents->Option.map(mount => mount.iframe),
      ~origin=sdkOrigin,
    ) ||
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.some(entry =>
      isFromIframe(~ev, ~iframe=entry.iframeRef.contents->Nullable.toOption, ~origin=sdkOrigin)
    )
  }
  let attachSubmitRelay = () => {
    EventListenerManager.addSmartEventListener(
      "message",
      (ev: Types.event) => {
        let json = eventDataJson(ev)
        let dict = json->getDictFromJson
        let isDoSubmit = dict->getBool("doSubmit", false)
        if isDoSubmit && isFromOurFrames(ev) && !confirmingRef.contents {
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
      logger.setLogInfo(~value=`${fieldType} created`, ~eventName=CARD_FORM_FLOW)
      let subscriptionEventsChanged = mergeSubscriptionEvents(
        ~subscriptionEventsRef,
        ~fieldOptions=options,
      )
      ensureCoordinatorMounted()
      if subscriptionEventsChanged {
        postCoordinatorCommand(
          coordinator,
          [("paymentElementsUpdate", true->JSON.Encode.bool), ("options", coordinatorOptions())],
        )
      }
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

  // Only the outcome and its error code are logged — never the card values or the payment token.
  let logConfirmOutcome = (result: JSON.t) =>
    switch result->getDictFromJson->getDictFromDict("error")->Dict.get("code") {
    | Some(code) =>
      logger.setLogInfo(
        ~value=`confirmPayment failed: ${code->JSON.Decode.string->Option.getOr("")}`,
        ~eventName=CARD_FORM_FLOW,
        ~logType=ERROR,
      )
    | None => logger.setLogInfo(~value="confirmPayment succeeded", ~eventName=CARD_FORM_FLOW)
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

  let confirmPayment = (): promise<JSON.t> => {
    logger.setLogInfo(~value="confirmPayment initiated", ~eventName=CARD_FORM_FLOW)
    let outcome = if confirmingRef.contents {
      Promise.resolve(
        groupFailureResponse(
          ~code="confirm_in_progress",
          ~errorType="api_error",
          ~message="confirmPayment() already in progress",
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
              ~message="savedCard.paymentToken is required for the saved-card CVC flow",
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
            ~message="No card fields are mounted",
          ),
        )
      }
    }
    outcome->Promise.thenResolve(result => {
      logConfirmOutcome(result)
      result
    })
  }


  let deinit = (): unit => {
    logger.setLogInfo(~value="Card form deinitialized", ~eventName=CARD_FORM_FLOW)
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.forEach(entry => {
      try entry.handle.destroy() catch { | _ => () }
    })
    fieldsRef := Dict.make()
    fields := Dict.make()->JSON.Encode.object
    settlePendingConfirm(
      groupFailureResponse(
        ~code="group_deinitialized",
        ~errorType="server_error",
        ~message="deinit() was called while a confirm was in flight — the payment may still have gone through",
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
    confirmPayment,
    deinit,
    fields,
  }
  cardForm
}
