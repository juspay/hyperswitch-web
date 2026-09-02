open Utils
open CardFormGroupShared

type paymentMethodsSessionGroup = Types.paymentMethodsSessionGroup
type fieldHandle = Types.fieldHandle
type cardForm = Types.cardForm

type sessionState =
  | Active
  | Consumed
  | Deinitialized

type errorType = CardFormCoordinator.errorType

let makeErrorResult = (
  ~code: string,
  ~message: option<string>=?,
  ~locale: string="en",
  ~typeOverride: option<errorType>=?,
  (),
): JSON.t => {
  CardFormCoordinator.makeErrorResult(~code, ~message?, ~locale, ~typeOverride?, ())
}
let sessionExpiredResult = (~locale: string="en", ()): JSON.t =>
  makeErrorResult(~code="session_expired", ~locale, ())

let sessionConsumedResult = (~locale: string="en", ()): JSON.t =>
  makeErrorResult(~code="session_consumed", ~locale, ())

let confirmInFlightResult = (~locale: string="en", ()): JSON.t =>
  makeErrorResult(~code="confirm_in_progress", ~locale, ())

type flowASuccessPayload = CardFormCoordinator.flowASuccessPayload
type flowBSuccessPayload = CardFormCoordinator.flowBSuccessPayload
type failurePayload = CardFormCoordinator.failurePayload
type confirmOutcome = CardFormCoordinator.confirmOutcome

let buildConfirmResult = CardFormCoordinator.buildConfirmResult

let buildSyntheticSession = (
  ~pmSessionId: string,
  ~customerId: string,
  ~vaultType: string,
  ~vaultData: JSON.t,
): JSON.t => {
  let vaultDetailsDict = Dict.make()
  vaultDetailsDict->Dict.set("vault_type", vaultType->JSON.Encode.string)
  vaultDetailsDict->Dict.set("vault_data", vaultData)
  let sessionDict = Dict.make()
  sessionDict->Dict.set("payment_method_session_id", pmSessionId->JSON.Encode.string)
  sessionDict->Dict.set("customer_id", customerId->JSON.Encode.string)
  sessionDict->Dict.set("vault_details", vaultDetailsDict->JSON.Encode.object)
  sessionDict->Dict.set("associated_payment_methods", []->JSON.Encode.array)
  sessionDict->JSON.Encode.object
}

let parseExpiresAtMs = (expiresAtStr: string): float => {
  if expiresAtStr->String.length == 0 {
    0.0
  } else {
    try {
      Date.fromString(expiresAtStr)->Date.getTime
    } catch {
    | _ => 0.0
    }
  }
}

let isExpired = (~expiresAtMs: float): bool =>
  expiresAtMs > 0.0 && Date.now() >= expiresAtMs

type fieldEntry = {
  iframeRef: ref<Nullable.t<Dom.element>>,
  handle: fieldHandle,
  fieldType: string,
  savedCardBrandRef: ref<string>,
  savedCardLast4Ref: ref<string>,
  prevFocusReadyRef: ref<bool>,
}

let reshapeCardStateUpdateToChangePayload = CardFormShared.reshapeCardStateUpdateToChangePayload

let aliasBrandVocabulary = [
  ("Visa", "visa"),
  ("Mastercard", "mastercard"),
  ("AmericanExpress", "amex"),
  ("Discover", "discover"),
  ("JCB", "jcb"),
  ("DinersClub", "diners club"),
  ("UnionPay", "unionpay"),
]

let detectBrandFromAlias = (alias: string): string =>
  alias
  ->String.trim
  ->CardValidations.getAllMatchedCardSchemes
  ->Array.findMap(issuer =>
    aliasBrandVocabulary
    ->Array.find(((patternIssuer, _)) => patternIssuer == issuer)
    ->Option.map(((_, merchantBrand)) => merchantBrand)
  )
  ->Option.getOr("")

let make = (options: JSON.t): paymentMethodsSessionGroup => {
  let optionsDict = options->getDictFromJson

  let sdkAuthorizationRaw = optionsDict->getString("sdkAuthorization", "")
  let sdkAuth = sdkAuthorizationRaw->getSdkAuthorizationData
  let publishableKey = sdkAuth.publishableKey->Option.getOr("")
  let pmSessionId = sdkAuth.pmSessionId->Option.getOr("")
  let customerId = sdkAuth.customerId->Option.getOr("")

  let locale = optionsDict->getString("locale", "auto")
  let groupAppearance =
    optionsDict->Dict.get("appearance")->Option.getOr(Dict.make()->JSON.Encode.object)

  let sessionsDataRef: ref<JSON.t> = ref(JSON.Encode.null)
  let vaultCredentialsRef: ref<JSON.t> = ref(JSON.Encode.null)
  let sessionStateRef: ref<sessionState> = ref(Active)
  let confirmingRef: ref<bool> = ref(false)
  let expiresAtRef: ref<float> = ref(0.0)
  let eventCallbacksRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())

  let vgsBrokerRef: ref<option<VGSVaultBroker.vgsBrokerHandle>> = ref(None)

  let vgsSavedCardBrandRef: ref<string> = ref("")
  let vgsSavedCardLast4Ref: ref<string> = ref("")

  let lastDetectedBrandRef: ref<string> = ref("")

  let fieldsRef: ref<Dict.t<fieldEntry>> = ref(Dict.make())
  let fields: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)

  let groupInstanceId = uniqueId(~prefix=`vault-${pmSessionId}`)
  let coordinator = makeCoordinatorChannel(~groupId=groupInstanceId)
  let coordinatorListenerName = `onVaultCoordinator-${groupInstanceId}`
  let coordinatorConfirmPendingRef: ref<option<(string, JSON.t => unit)>> = ref(None)

  let syncCoordinatorSessions = () => {
    if sessionsDataRef.contents != JSON.Encode.null && coordinator.readyRef.contents {
      coordinator.mountRef.contents->Option.forEach(mount =>
        mount.iframe->Nullable.make->Window.iframePostMessage(
          [("sessions", sessionsDataRef.contents)]->Dict.fromArray,
        )
      )
    }
  }

  let attachCoordinatorListener = () => {
    let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.vaultSdkDomainUrl).origin
    EventListenerManager.addSmartEventListener(
      "message",
      (ev: Types.event) => {
        let isOurCoordinator = isFromIframe(
          ~ev,
          ~iframe=coordinator.mountRef.contents->Option.map(mount => mount.iframe),
          ~origin=innerIframeOrigin,
        )
        if isOurCoordinator {
          let json = eventDataJson(ev)
          let dict = json->getDictFromJson
          if dict->getBool("iframeMounted", false) {
            coordinator.readyRef := true
            flushPendingPorts(coordinator)
            syncCoordinatorSessions()
            flushPendingCoordinatorCommands(coordinator)
          } else {
            switch dict->Dict.get("confirmResult") {
            | Some(result) =>
              let confirmId = dict->getString("confirmId", "")
              switch coordinatorConfirmPendingRef.contents {
              | Some((pendingId, settle)) if pendingId == confirmId =>
                coordinatorConfirmPendingRef := None
                settle(result)
              | _ => ()
              }
            | None => ()
            }
          }
        }
      },
      coordinatorListenerName,
    )
  }

  let ensureCoordinatorMounted = () => {
    switch coordinator.mountRef.contents {
    | Some(_) => ()
    | None =>
      let groupConfigAsOptions =
        [
          ("sdkAuthorization", sdkAuthorizationRaw->JSON.Encode.string),
          ("publishableKey", publishableKey->JSON.Encode.string),
          ("appearance", groupAppearance),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      let mount = CoordinatorMount.create(
        ~parentContainer=Window.body,
        ~localSelectorString=groupInstanceId,
        ~elementIframeId="cardFormCoordinator",
        ~surfaceFamily="vault",
        ~groupId=groupInstanceId,
        ~sdkDomain=ApiEndpoint.vaultSdkDomainUrl,
      )
      coordinator.mountRef := Some(mount)
      attachCoordinatorListener()
      let (fullscreenRouter, fullscreenAnswerer) = CoordinatorMount.makeFullscreenFlows(
        ~mount,
        ~localSelectorString=groupInstanceId,
        ~sdkDomain=ApiEndpoint.vaultSdkDomainUrl,
        ~options=groupConfigAsOptions,
        ~appearance=groupAppearance,
      )
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenRouter(ev->eventToWindowEvent),
        `onVaultCoordinatorFullscreen-${groupInstanceId}`,
      )
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenAnswerer(ev->eventToWindowEvent),
        CoordinatorMount.fullscreenAnswerListenerName(groupInstanceId),
      )
    }
  }

  let vaultOptionDict = optionsDict->Dict.get("vault")->Option.flatMap(JSON.Decode.object)

  switch vaultOptionDict {
  | Some(vaultDict) => {
      let vaultType = vaultDict->getString("vault_type", "")
      let vaultData = vaultDict->Dict.get("vault_data")->Option.getOr(JSON.Encode.null)

      let syntheticSession = buildSyntheticSession(~pmSessionId, ~customerId, ~vaultType, ~vaultData)
      sessionsDataRef := syntheticSession

      let vaultMode = vaultType->VaultHelpers.getVaultModeFromName
      let loadedSession: PaymentType.loadType = Loaded(syntheticSession)
      let vaultConfigJson = VaultHelpers.buildVaultConfig(loadedSession, vaultMode)
      vaultCredentialsRef := vaultConfigJson
    }
  | None => {
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)
      PaymentHelpersV2.fetchPaymentManagementList(
        ~pmSessionId,
        ~endpoint,
        ~optLogger=None,
        ~customPodUri="",
        ~sdkAuthorization=sdkAuthorizationRaw,
      )
      ->Promise.then(sessionJson => {
        sessionsDataRef := sessionJson
        let sessionDict = sessionJson->getDictFromJson
        let expiresAt = sessionDict->getString("expires_at", "")
        expiresAtRef := parseExpiresAtMs(expiresAt)

        let vaultType =
          sessionDict->getDictFromDict("vault_details")->getString("vault_type", "")
        let vaultMode = vaultType->VaultHelpers.getVaultModeFromName
        let loadedSession: PaymentType.loadType = Loaded(sessionJson)
        let vaultConfigJson = VaultHelpers.buildVaultConfig(loadedSession, vaultMode)
        vaultCredentialsRef := vaultConfigJson
        syncCoordinatorSessions()
        Promise.resolve()
      })
      ->Promise.catch(err => {
        Console.error2("[PaymentMethodsSessionGroup] session fetch failed", err)
        Promise.resolve()
      })
      ->ignore
    }
  }

  let mapFieldTypeToInternalFieldName = CardFormShared.mapFieldTypeToInternalFieldName

  let detectVaultType = (): string => {
    let declaredType =
      optionsDict
      ->Dict.get("vault")
      ->Option.flatMap(JSON.Decode.object)
      ->Option.map(d => d->getString("vault_type", ""))
      ->Option.getOr("")
    if declaredType->String.length > 0 {
      declaredType
    } else if VGSVaultBroker.isVGSProvider(vaultCredentialsRef.contents) {
      "vgs"
    } else if vaultCredentialsRef.contents !== JSON.Encode.null {
      "hyperswitch"
    } else {
      "hyperswitch"
    }
  }

  let getOrCreateVgsBroker = (): option<VGSVaultBroker.vgsBrokerHandle> => {
    switch vgsBrokerRef.contents {
    | Some(broker) => Some(broker)
    | None =>
      let vaultDataDict =
        optionsDict
        ->Dict.get("vault")
        ->Option.flatMap(JSON.Decode.object)
        ->Option.flatMap(d => d->Dict.get("vault_data"))
        ->Option.flatMap(JSON.Decode.object)
      let fromCredentials = vaultCredentialsRef.contents->getDictFromJson
      let vaultId = switch vaultDataDict {
      | Some(d) => d->getString("vault_id", "")
      | None => fromCredentials->getString("vaultId", "")
      }
      let environment = switch vaultDataDict {
      | Some(d) => d->getString("environment", "")
      | None => fromCredentials->getString("environment", "")
      }
      if vaultId->String.length == 0 || environment->String.length == 0 {
        None
      } else {
        let broker = VGSVaultBroker.make(~pmSessionId, ~vaultId, ~environment, ~eventCallbacksRef)
        vgsBrokerRef := Some(broker)
        Some(broker)
      }
    }
  }

  let buildMountConfig = (~options: JSON.t, ~fieldId: string) => {
    let fieldOptionsDict = options->getDictFromJson
    let savedCardDict = fieldOptionsDict->getDictFromDict("savedCard")
    let savedCardBrand = savedCardDict->getString("brand", "")
    let appearance = resolveFieldAppearance(~fieldOptionsDict, ~groupAppearance)
    buildFieldMountConfig(
      ~paymentOptions=buildPaymentOptions(
        ~appearance,
        ~locale,
        ~credentialKeys=[
          ("sdkAuthorization", sdkAuthorizationRaw->JSON.Encode.string),
          ("pmSessionId", pmSessionId->JSON.Encode.string),
        ],
      ),
      ~options,
      ~fieldId,
      ~publishableKey,
      ~credentialKeys=[
        ("endpoint", ApiEndpoint.getVaultEndPoint(~publishableKey)->JSON.Encode.string),
      ],
      ~sdkSessionId=pmSessionId,
      ~loggerSource="hyper_vault",
      ~savedCardBrand,
    )
  }

  let findFieldOfType = (matchFieldType: string): option<fieldEntry> =>
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.find(entry => entry.fieldType === matchFieldType)

  let iframeOfFieldType = (matchFieldType: string): option<Dom.element> =>
    matchFieldType
    ->findFieldOfType
    ->Option.flatMap(entry => entry.iframeRef.contents->Nullable.toOption)

  let createFieldHandle = (fieldType: string, options: JSON.t, fieldId: string): fieldEntry => {
    let iframeRef: ref<Nullable.t<Dom.element>> = ref(Nullable.null)

    let eventHandlersRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())

    let savedCardDict = options->getDictFromJson->getDictFromDict("savedCard")
    let savedCardBrandRef = ref(savedCardDict->getString("brand", ""))
    let savedCardLast4Ref = ref(savedCardDict->getString("last4", ""))

    let prevFocusReadyRef = ref(false)

    let mountPostMessage = (mountedIframeRef, _selectorString, _sdkHandleOneClick) => {
      coordinator->openFieldPort(
        ~fieldIframe=mountedIframeRef,
        ~mountConfig=buildMountConfig(~options, ~fieldId)->JSON.Encode.object,
        ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      )
      if sessionsDataRef.contents != JSON.Encode.null {
        mountedIframeRef->Window.iframePostMessage(
          [("sessions", sessionsDataRef.contents)]->Dict.fromArray,
        )
      }
      seedCvcBrandOnMount(~fieldType, ~fieldIframe=mountedIframeRef, ~lastDetectedBrandRef)
    }

    let attachFieldListener = () => {
      let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.vaultSdkDomainUrl).origin
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
            let isCardTokenEvent = dict->getBool("cardTokenEvent", false)
            let isCardTokenFail = dict->getBool("cardTokenFail", false)
            let isCvcTokenEvent = dict->getBool("savedCardCvcTokenEvent", false)
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
            } else if isCardTokenEvent || isCardTokenFail || isCvcTokenEvent {
              ()
            } else {
              switch cardStateUpdate {
              | Some(stateJson) =>
                let stateDict = stateJson->getDictFromJson
                routeFocusAndBrand(
                  ~fieldType,
                  ~stateDict,
                  ~prevFocusReadyRef,
                  ~lastDetectedBrandRef,
                  ~iframeOfFieldType,
                )

                let errorMessage = stateDict->getString("error", "")
                let changePayload = reshapeCardStateUpdateToChangePayload(
                  ~fieldType,
                  ~stateJson,
                )
                eventHandlersRef.contents
                ->Dict.get("change")
                ->Option.forEach(cb => cb(changePayload))
                if errorMessage->String.length > 0 {
                  let errorPayload = {
                    let errDict = Dict.make()
                    errDict->Dict.set("elementType", fieldType->JSON.Encode.string)
                    errDict->Dict.set("iframeId", fieldId->JSON.Encode.string)
                    errDict->Dict.set("message", errorMessage->JSON.Encode.string)
                    errDict->JSON.Encode.object
                  }
                  eventHandlersRef.contents
                  ->Dict.get("error")
                  ->Option.forEach(cb => cb(errorPayload))
                }
              | None => ()
              }
            }
          }
        },
        `onVaultField-${fieldId}`,
      )
    }

    let fieldOptionsDict = options->getDictFromJson
    let appearanceJson = resolveFieldAppearance(~fieldOptionsDict, ~groupAppearance)
    let optionsForElement = optionsWithAppearance(~fieldOptionsDict, ~appearance=appearanceJson)

    let handle: fieldHandle = makeFieldElementAndHandle(
      ~optionsForElement,
      ~appearance=appearanceJson,
      ~iframeRef,
      ~mountPostMessage,
      ~sdkDomainUrl=ApiEndpoint.vaultSdkDomainUrl,
      ~surfaceFamily="vault",
      ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      ~groupId=groupInstanceId,
      ~listenerName=`onVaultField-${fieldId}`,
      ~eventHandlersRef,
      ~update=newOptions => {
        let newSavedCardDict = postFieldUpdate(~iframeRef, ~newOptions)
        let brand = newSavedCardDict->getString("brand", "")
        let last4 = newSavedCardDict->getString("last4", "")
        if brand !== "" {
          savedCardBrandRef := brand
        }
        if last4 !== "" {
          savedCardLast4Ref := last4
        }
      },
    )

    attachFieldListener()

    {
      iframeRef,
      handle,
      fieldType,
      savedCardBrandRef,
      savedCardLast4Ref,
      prevFocusReadyRef,
    }
  }

  let create = (fieldType: string, options: JSON.t): fieldHandle => {
    if sessionStateRef.contents != Active {
      Console.warn(
        `[PaymentMethodsSessionGroup] create("${fieldType}") called on consumed/deinitialized session`,
      )
      Types.defaultFieldHandle
    } else {
      switch mapFieldTypeToInternalFieldName(fieldType) {
      | "" => {
          Console.error(
            `[PaymentMethodsSessionGroup] invalid_field_type: ${fieldType}`,
          )
          Types.defaultFieldHandle
        }
      | _ =>
        let vaultType = detectVaultType()
        switch vaultType {
        | "vgs" =>
          switch getOrCreateVgsBroker() {
          | Some(broker) => {
              let fieldId = uniqueId(~prefix=fieldType)
              let savedCardDict = options->getDictFromJson->getDictFromDict("savedCard")
              let savedCardBrand = savedCardDict->getString("brand", "")
              let savedCardLast4 = savedCardDict->getString("last4", "")
              if (
                fieldType === "cardCvc" &&
                  (savedCardBrand->String.length > 0 || savedCardLast4->String.length > 0)
              ) {
                vgsSavedCardBrandRef := savedCardBrand
                vgsSavedCardLast4Ref := savedCardLast4
              }
              registerField(
                ~fields,
                ~fieldId,
                ~fieldType,
                ~extraMeta=[("provider", "vgs"->JSON.Encode.string)],
              )

              let uniqueSelectorRef: ref<option<string>> = ref(None)

              let fieldOptionsDict = options->getDictFromJson
              let optionsForBroker = optionsWithAppearance(
                ~fieldOptionsDict,
                ~appearance=resolveFieldAppearance(~fieldOptionsDict, ~groupAppearance),
              )

              let getFieldHandle = (): option<VGSTypes.field> => {
                switch broker.fieldsRef.contents->Dict.get(fieldId) {
                | Some(entry) => entry.fieldHandle->Option.map(VGSTypes.fieldFromJson)
                | None => None
                }
              }

              let handle: fieldHandle = {
                mount: selector => {
                  uniqueSelectorRef := Some(selector)
                  broker
                  .mountField(~fieldId, ~fieldType, ~selector, ~options=optionsForBroker)
                  ->Promise.catch(err => {
                    Console.error2(
                      `[PaymentMethodsSessionGroup] VGS mountField(${fieldType}, ${selector}) failed`,
                      err->Identity.anyTypeToJson,
                    )
                    Promise.resolve()
                  })
                  ->ignore
                },
                unmount: () => {
                  broker.unmountField(~fieldId)
                  uniqueSelectorRef := None
                },
                destroy: () => {
                  broker.unmountField(~fieldId)
                  uniqueSelectorRef := None
                },
                update: newOptions => {
                  broker.updateField(~fieldId, ~options=newOptions)
                  let newSavedCardDict = newOptions->getDictFromJson->getDictFromDict("savedCard")
                  let newSavedCardBrand = newSavedCardDict->getString("brand", "")
                  let newSavedCardLast4 = newSavedCardDict->getString("last4", "")
                  if newSavedCardBrand !== "" {
                    vgsSavedCardBrandRef := newSavedCardBrand
                  }
                  if newSavedCardLast4 !== "" {
                    vgsSavedCardLast4Ref := newSavedCardLast4
                  }
                },
                focus: () => {
                  switch getFieldHandle() {
                  | Some(vgsFieldHandle) =>
                    try {
                      vgsFieldHandle.focus->Option.forEach(invoke => invoke())
                    } catch {
                    | exn =>
                      Console.error2(
                        `[PaymentMethodsSessionGroup] VGS focus(${fieldId}) threw`,
                        exn->Identity.anyTypeToJson,
                      )
                    }
                  | None =>
                    Console.warn(
                      `[PaymentMethodsSessionGroup] VGS focus(${fieldId}) — field not yet mounted`,
                    )
                  }
                },
                blur: () => {
                  switch getFieldHandle() {
                  | Some(vgsFieldHandle) =>
                    try {
                      vgsFieldHandle.blur->Option.forEach(invoke => invoke())
                    } catch {
                    | exn =>
                      Console.error2(
                        `[PaymentMethodsSessionGroup] VGS blur(${fieldId}) threw`,
                        exn->Identity.anyTypeToJson,
                      )
                    }
                  | None =>
                    Console.warn(
                      `[PaymentMethodsSessionGroup] VGS blur(${fieldId}) — field not yet mounted`,
                    )
                  }
                },
                clear: () => {
                  switch getFieldHandle() {
                  | Some(vgsFieldHandle) =>
                    try {
                      let cleared = switch vgsFieldHandle.clear {
                      | Some(invoke) => {
                          invoke()
                          true
                        }
                      | None => false
                      }
                      if !cleared {
                        Console.warn(
                          `[PaymentMethodsSessionGroup] VGS clear(${fieldId}) — field has no clear() method; use update({placeholder: ..., validations: ...}) instead`,
                        )
                      }
                    } catch {
                    | exn =>
                      Console.error2(
                        `[PaymentMethodsSessionGroup] VGS clear(${fieldId}) threw`,
                        exn->Identity.anyTypeToJson,
                      )
                    }
                  | None =>
                    Console.warn(
                      `[PaymentMethodsSessionGroup] VGS clear(${fieldId}) — field not yet mounted`,
                    )
                  }
                },
                on: (event, cb) => {
                  let key = `${fieldId}::${event}`
                  eventCallbacksRef.contents->Dict.set(key, cb)
                },
              }
              handle
            }
          | None => {
              Console.error(
                `[PaymentMethodsSessionGroup] vault_type="vgs" declared but vault_data has no vault_id/environment — cannot mount`,
              )
              Types.defaultFieldHandle
            }
          }
        | "hyperswitch" =>
          ensureCoordinatorMounted()
          let fieldId = uniqueId(~prefix=fieldType)
          let entry = createFieldHandle(fieldType, options, fieldId)
          fieldsRef.contents->Dict.set(fieldId, entry)
          registerField(~fields, ~fieldId, ~fieldType)
          entry.handle
        | other => {
            Console.error(
              `[PaymentMethodsSessionGroup] unsupported_provider: vault_type "${other}" not yet supported`,
            )
            Types.defaultFieldHandle
          }
        }
      }
    }
  }

  let update = (_options: JSON.t): unit => {
    Console.warn(
      "[PaymentMethodsSessionGroup] session options are fixed at creation; create a new session to change them",
    )
  }

  let on = (event: string, cb: JSON.t => unit): unit => {
    eventCallbacksRef.contents->Dict.set(event, cb)
  }

  let emitGroupError = (envelope: JSON.t): unit => {
    eventCallbacksRef.contents->Dict.get("error")->Option.forEach(cb => cb(envelope))
  }

  let settleResult = (resolve: JSON.t => unit, result: JSON.t): unit => {
    let outcomeDict = result->getDictFromJson
    let isError = outcomeDict->getString("status", "") === "error"
    if isError {
      emitGroupError(result)
    }
    resolve(result)
  }

  let confirmVgsFlowA = (): promise<JSON.t> => {
    switch getOrCreateVgsBroker() {
    | None =>
      Promise.resolve(
        buildConfirmResult(
          ~outcome=Failure({
            code: "validation_error",
            message: Some(
              "VGS vault declared but vault_data missing vault_id/environment — cannot confirm",
            ),
            locale,
            typeOverride: Some(ValidationError),
          }),
        ),
      )
    | Some(broker) =>
      let cardNumberMounted =
        broker.fieldsRef.contents
        ->Dict.valuesToArray
        ->Array.some(entry => entry.fieldType === "cardNumber" && entry.fieldHandle->Option.isSome)
      if !cardNumberMounted {
        Promise.resolve(
          buildConfirmResult(
            ~outcome=Failure({
              code: "validation_error",
              message: Some(
                "cardNumber field not mounted — call cardForm.create(\"cardNumber\", opts) then mount() before confirm()",
              ),
              locale,
              typeOverride: None,
            }),
          ),
        )
      } else {
        confirmingRef := true
        broker
        .submitForm()
        ->Promise.then(result => {
          let resultDict = result->getDictFromJson
          let status = resultDict->getString("status", "")
          if status == "error" {
            confirmingRef := false
            let errDict = resultDict->getDictFromDict("error")
            let code = errDict->getString("code", "tokenization_failed")
            let message = errDict->getString("message", "")
            let envelope = buildConfirmResult(
              ~outcome=Failure({
                code,
                message: if message->String.length > 0 {
                  Some(message)
                } else {
                  None
                },
                locale,
                typeOverride: Some(ApiError),
              }),
            )
            emitGroupError(envelope)
            Promise.resolve(envelope)
          } else {
            sessionStateRef := Consumed
            let cardNumberAlias = resultDict->getString("card_number", "")
            let expMonth = resultDict->getString("card_exp_month", "")
            let expYear = resultDict->getString("card_exp_year", "")
            let brand = detectBrandFromAlias(cardNumberAlias)
            let last4 =
              cardNumberAlias->String.length >= 4
                ? cardNumberAlias->String.sliceToEnd(~start=cardNumberAlias->String.length - 4)
                : ""
            let envelope = buildConfirmResult(
              ~outcome=FlowASuccess({
                token: cardNumberAlias,
                paymentMethodId: None,
                brand,
                last4,
                expiryMonth: expMonth,
                expiryYear: expYear,
              }),
            )
            confirmingRef := false
            Promise.resolve(envelope)
          }
        })
        ->Promise.catch(_exn => {
          confirmingRef := false
          let envelope = buildConfirmResult(
            ~outcome=Failure({
              code: "tokenization_failed",
              message: Some("VGS submitForm rejected unexpectedly"),
              locale,
              typeOverride: Some(ApiError),
            }),
          )
          emitGroupError(envelope)
          Promise.resolve(envelope)
        })
      }
    }
  }

  let confirmVgsFlowB = (): promise<JSON.t> => {
    switch getOrCreateVgsBroker() {
    | None =>
      Promise.resolve(
        buildConfirmResult(
          ~outcome=Failure({
            code: "validation_error",
            message: Some(
              "VGS vault declared but vault_data missing vault_id/environment — cannot confirm Flow B (saved-card CVC recollect)",
            ),
            locale,
            typeOverride: Some(ValidationError),
          }),
        ),
      )
    | Some(broker) =>
      let cardCvcMounted =
        broker.fieldsRef.contents
        ->Dict.valuesToArray
        ->Array.some(entry => entry.fieldType === "cardCvc" && entry.fieldHandle->Option.isSome)
      if !cardCvcMounted {
        Promise.resolve(
          buildConfirmResult(
            ~outcome=Failure({
              code: "validation_error",
              message: Some(
                "cardCvc field not mounted — for saved-card recollect, call cardForm.create(\"cardCvc\", {savedCard: {brand, last4}}) then mount() before confirm()",
              ),
              locale,
              typeOverride: None,
            }),
          ),
        )
      } else {
        confirmingRef := true
        broker
        .submitForm()
        ->Promise.then(result => {
          let resultDict = result->getDictFromJson
          let status = resultDict->getString("status", "")
          if status == "error" {
            confirmingRef := false
            let errDict = resultDict->getDictFromDict("error")
            let code = errDict->getString("code", "tokenization_failed")
            let message = errDict->getString("message", "")
            let envelope = buildConfirmResult(
              ~outcome=Failure({
                code,
                message: if message->String.length > 0 {
                  Some(message)
                } else {
                  None
                },
                locale,
                typeOverride: Some(ApiError),
              }),
            )
            emitGroupError(envelope)
            Promise.resolve(envelope)
          } else {
            sessionStateRef := Consumed
            let cvcAlias = resultDict->getString("card_cvc", "")
            let brand = vgsSavedCardBrandRef.contents
            let last4 = vgsSavedCardLast4Ref.contents
            let envelope = buildConfirmResult(
              ~outcome=FlowBSuccess({cvcToken: cvcAlias, brand, last4}),
            )
            confirmingRef := false
            Promise.resolve(envelope)
          }
        })
        ->Promise.catch(_exn => {
          confirmingRef := false
          let envelope = buildConfirmResult(
            ~outcome=Failure({
              code: "tokenization_failed",
              message: Some("VGS submitForm rejected unexpectedly"),
              locale,
              typeOverride: Some(ApiError),
            }),
          )
          emitGroupError(envelope)
          Promise.resolve(envelope)
        })
      }
    }
  }

  let runCoordinatorRelay = (
    ~flow: string,
    ~savedCardBrand: string="",
    ~savedCardLast4: string="",
  ): promise<JSON.t> => {
    switch coordinator.mountRef.contents {
    | None =>
      Promise.resolve(
        buildConfirmResult(
          ~outcome=Failure({
            code: "tokenization_failed",
            message: Some(
              "cardFormCoordinator is not mounted — create + mount a hosted (non-VGS) card field before calling confirm()",
            ),
            locale,
            typeOverride: Some(ApiError),
          }),
        ),
      )
    | Some(_mount) =>
      Promise.make((resolve, _reject) => {
        let confirmId = `${Date.now()->Float.toString}-${Math.random()->Float.toString}`
        let settledRef = ref(false)
        let settle = result => {
          if !settledRef.contents {
            settledRef := true
            coordinatorConfirmPendingRef := None
            confirmingRef := false
            if result->getDictFromJson->getString("status", "") == "success" {
              sessionStateRef := Consumed
            }
            settleResult(resolve, result)
          }
        }
        coordinatorConfirmPendingRef := Some((confirmId, settle))
        postCoordinatorCommand(coordinator, [
          ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
          ("flow", flow->JSON.Encode.string),
          ("confirmId", confirmId->JSON.Encode.string),
          ("savedCardBrand", savedCardBrand->JSON.Encode.string),
          ("savedCardLast4", savedCardLast4->JSON.Encode.string),
          ("locale", locale->JSON.Encode.string),
        ])
      })
    }
  }

  let confirm = (): promise<JSON.t> =>
    if sessionStateRef.contents != Active {
      Promise.resolve(sessionConsumedResult(~locale, ()))
    } else if confirmingRef.contents {
      Promise.resolve(confirmInFlightResult(~locale, ()))
    } else if isExpired(~expiresAtMs=expiresAtRef.contents) {
      Promise.resolve(sessionExpiredResult(~locale, ()))
    } else {
      let incompleteFieldSet = () =>
        Promise.resolve(
          buildConfirmResult(
            ~outcome=Failure({
              code: "incomplete_field_set",
              message: None,
              locale,
              typeOverride: Some(ValidationError),
            }),
          ),
        )
      if detectVaultType() == "vgs" {
        let (numberMounted, cvcMounted) = switch vgsBrokerRef.contents {
        | Some(broker) => {
            let entries = broker.fieldsRef.contents->Dict.valuesToArray
            (
              entries->Array.some(e => e.fieldType === "cardNumber" && e.fieldHandle->Option.isSome),
              entries->Array.some(e => e.fieldType === "cardCvc" && e.fieldHandle->Option.isSome),
            )
          }
        | None => (false, false)
        }
        if numberMounted {
          confirmVgsFlowA()
        } else if cvcMounted {
          confirmVgsFlowB()
        } else {
          incompleteFieldSet()
        }
      } else {
        switch (findFieldOfType("cardNumber"), findFieldOfType("cardExpiry"), findFieldOfType("cardCvc")) {
        | (None, None, None) => incompleteFieldSet()
        | (Some(_field), _, _) =>
          confirmingRef := true
          runCoordinatorRelay(~flow="save")
        | (None, Some(_), _) =>
          incompleteFieldSet()
        | (None, None, Some(field)) =>
          confirmingRef := true
          runCoordinatorRelay(
            ~flow="update",
            ~savedCardBrand=field.savedCardBrandRef.contents,
            ~savedCardLast4=field.savedCardLast4Ref.contents,
          )
        }
      }
    }

  let deinit = (): unit => {
    if sessionStateRef.contents != Deinitialized {
      fieldsRef.contents
      ->Dict.valuesToArray
      ->Array.forEach(entry => {
        try {
          entry.handle.destroy()
        } catch {
        | _ => ()
        }
      })
      fieldsRef := Dict.make()

      vgsBrokerRef.contents->Option.forEach(broker => broker.unmountAll())
      vgsBrokerRef := None

      switch Window.querySelector(`script[data-vgs-script-loaded]`)->Nullable.toOption {
      | Some(script) =>
        try {
          script->Window.remove
        } catch {
        | _ => ()
        }
      | None => ()
      }

      fields := Dict.make()->JSON.Encode.object
      sessionStateRef := Deinitialized
      confirmingRef := false

      closeInstalledPorts(coordinator)
      coordinator.mountRef.contents->Option.forEach(
        mount => CoordinatorMount.teardown(~mount, ~pendingPorts=coordinator.pendingPortsRef.contents),
      )
      coordinator.pendingPortsRef := []
      coordinator.mountRef := None
      coordinator.readyRef := false
      coordinator.pendingCommandsRef := []
      coordinatorConfirmPendingRef.contents->Option.forEach(((_pendingId, settle)) =>
        settle(
          buildConfirmResult(
            ~outcome=Failure({
              code: "tokenization_failed",
              message: Some(
                "deinit() was called while a confirm was in flight — the card may still have been saved; check the payment method list before retrying",
              ),
              locale,
              typeOverride: Some(ApiError),
            }),
          ),
        )
      )
      coordinatorConfirmPendingRef := None
      EventListenerManager.removeSmartEventListener("message", coordinatorListenerName)
      EventListenerManager.removeSmartEventListener(
        "message",
        `onVaultCoordinatorFullscreen-${groupInstanceId}`,
      )
      EventListenerManager.removeSmartEventListener(
        "message",
        CoordinatorMount.fullscreenAnswerListenerName(groupInstanceId),
      )
    }
  }

  let cardForm = (): cardForm => {
    create,
    on,
    confirm,
    deinit,
    update,
    fields,
  }

  {
    cardForm,
    update,
    on,
    deinit,
    fields,
  }
}
