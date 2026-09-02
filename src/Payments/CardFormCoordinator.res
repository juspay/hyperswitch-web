open Utils
open JotaiAtoms

type errorType =
  | ValidationError
  | ApiError
  | CardError

let errorTypeToString = t =>
  switch t {
  | ValidationError => "validation_error"
  | ApiError => "api_error"
  | CardError => "card_error"
  }

let defaultErrorMessage = (~code: string): string =>
  switch code {
  | "session_expired" => "Payment method session has expired"
  | "session_consumed" => "Payment method session has already been consumed or deinitialized"
  | "confirm_in_progress" => "A confirm is already in flight for this payment method session"
  | "tokenization_in_progress" =>
    "A tokenization is already in flight for this payment method session"
  | "incomplete_field_set" =>
    "mount {cardNumber,cardExpiry,cardCvc} for tokenize or only cardCvc for saved-card recollect"
  | "validation_error" => "Validation failed for one or more fields"
  | "tokenization_failed" => "Card tokenization failed"
  | _ => "An unexpected error occurred"
  }

let resolveErrorMessage = (~code: string, ~locale: string, ~fallback: option<string>): string => {
  let _ = locale
  switch fallback {
  | Some(msg) if msg->String.length > 0 => msg
  | _ => defaultErrorMessage(~code)
  }
}

let makeErrorResult = (
  ~code: string,
  ~message: option<string>=?,
  ~locale: string="en",
  ~typeOverride: option<errorType>=?,
  (),
): JSON.t => {
  let resolvedMessage = resolveErrorMessage(~code, ~locale, ~fallback=message)
  let resolvedType = switch typeOverride {
  | Some(t) => t
  | None =>
    switch code {
    | "validation_error" | "incomplete_field_set" => ValidationError
    | "session_expired"
    | "session_consumed"
    | "tokenization_failed"
    | "tokenization_in_progress"
    | "confirm_in_progress" => ApiError
    | _ => CardError
    }
  }
  let errorDict = Dict.make()
  errorDict->Dict.set("code", code->JSON.Encode.string)
  errorDict->Dict.set("message", resolvedMessage->JSON.Encode.string)
  errorDict->Dict.set("type", resolvedType->errorTypeToString->JSON.Encode.string)
  let resultDict = Dict.make()
  resultDict->Dict.set("error", errorDict->JSON.Encode.object)
  resultDict->JSON.Encode.object
}

type failurePayload = {
  code: string,
  message: option<string>,
  locale: string,
  typeOverride: option<errorType>,
}

type confirmOutcome =
  | Success(JSON.t)
  | Failure(failurePayload)

let buildConfirmResult = (~outcome: confirmOutcome): JSON.t =>
  switch outcome {
  | Success(vaultResponse) => vaultResponse
  | Failure(payload) =>
    makeErrorResult(
      ~code=payload.code,
      ~message=?payload.message,
      ~locale=payload.locale,
      ~typeOverride=?payload.typeOverride,
      (),
    )
  }

let isErrorResult = (result: JSON.t): bool => {
  let dict = result->getDictFromJson
  dict->Dict.get("error")->Option.flatMap(JSON.Decode.object)->Option.isSome
}

let portKey = (~groupId: string, ~fieldName: string): string => `${groupId}:${fieldName}`

type fieldSnapshotEntry = {payload: JSON.t}

@react.component
let make = () => {
  let url = RescriptReactRouter.useUrl()
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let keys = Jotai.useAtomValue(keys)
  let sessions = Jotai.useAtomValue(sessions)
  let paymentMethodListValue = Jotai.useAtomValue(paymentMethodList)
  let customPodUri = Jotai.useAtomValue(customPodUri)

  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let surfaceFamilyStr = CardUtils.getQueryParamsDictforKey(url.search, "surfaceFamily")
  let surfaceFamily = surfaceFamilyStr == "" ? None : Some(surfaceFamilyStr)
  let groupId = CardUtils.getQueryParamsDictforKey(url.search, "groupId")
  let coordinatorFamily = PaymentSurfaceFamily.classifyCoordinatorFromUrl(
    ~componentName,
    ~surfaceFamily,
  )

  let fieldSnapshotsRef = React.useRef(Dict.make(): Dict.t<fieldSnapshotEntry>)
  let prevFocusReadyRef = React.useRef(Dict.make(): Dict.t<bool>)
  let lastBrandRef = React.useRef("")
  let confirmingRef = React.useRef(false)

  let (registryVersion, setRegistryVersion) = React.useState(() => 0)
  React.useEffect0(() => {
    let onRegistryChange = () => setRegistryVersion(v => v + 1)
    SadPortRegistry.addChangeListener(onRegistryChange)
    Some(() => SadPortRegistry.removeChangeListener(onRegistryChange))
  })

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let postConfirmResult = (~confirmId: string, result: JSON.t) => {
    messageParentWindow(
      [
        ("confirmResult", result),
        ("confirmId", confirmId->JSON.Encode.string),
        ("iframeId", keys.iframeId->JSON.Encode.string),
      ],
      ~targetOrigin=keys.parentURL,
    )
  }

  let vaultCredentials = React.useMemo1(
    () => VaultHelpers.getVaultCredentialsFromSessions(sessions),
    [sessions],
  )

  let aggregateRawValue = (pick: Dict.t<JSON.t> => string): string => {
    fieldSnapshotsRef.current
    ->Dict.valuesToArray
    ->Array.reduce("", (acc, entry) =>
      if acc !== "" {
        acc
      } else {
        let candidate = pick(entry.payload->getDictFromJson)
        if candidate !== "" {
          candidate
        } else {
          acc
        }
      }
    )
  }
  let aggregatedCardNumber = () =>
    aggregateRawValue(d => d->getString("rawCardNumber", ""))
  let aggregatedCardExpiry = () =>
    aggregateRawValue(d => d->getString("rawCardExpiry", ""))
  let aggregatedCvcNumber = () => aggregateRawValue(d => d->getString("rawCvc", ""))
  let aggregatedCardBrand = () => aggregateRawValue(d => d->getString("cardBrand", ""))

  let snapshotFieldStatus = fieldName =>
    fieldSnapshotsRef.current
    ->Dict.get(fieldName)
    ->Option.map(entry => entry.payload->getDictFromJson->getDictFromDict("fieldStatus"))
  let fieldConfirmedInvalid = (fieldName, hasStatusKey, isValidKey) =>
    switch snapshotFieldStatus(fieldName) {
    | Some(status) => {
        let boolOf = (dict, key) => dict->Dict.get(key)->Option.flatMap(JSON.Decode.bool)->Option.getOr(false)
        boolOf(status, hasStatusKey) && !boolOf(status, isValidKey)
      }
    | None => false
    }
  let cardNumberConfirmedInvalid = () =>
    fieldConfirmedInvalid("cardNumber", "hasCardValidationStatus", "isCardValid")
  let cardExpiryConfirmedInvalid = () =>
    fieldConfirmedInvalid("cardExpiry", "hasExpiryValidationStatus", "isExpiryValid")
  let cardCvcConfirmedInvalid = () =>
    fieldConfirmedInvalid("cardCvc", "hasCvcValidationStatus", "isCvcValid")
  let anyContributingFieldConfirmedInvalid = () =>
    cardNumberConfirmedInvalid() || cardExpiryConfirmedInvalid() || cardCvcConfirmedInvalid()

  let relayDetectedBrandToCvc = (brand: string) =>
    SadPortRegistry.postFrame(
      ~key=portKey(~groupId, ~fieldName="cardCvc"),
      CardFormPortProtocol.makePortFrame(
        ~kind=CardFormPortProtocol.kindDetectedCardBrand,
        ~payload=brand->JSON.Encode.string,
      ),
    )->ignore

  let seedDetectedBrandOnCvcRegistration = (fieldName: string) =>
    if fieldName === "cardCvc" && lastBrandRef.current !== "" {
      relayDetectedBrandToCvc(lastBrandRef.current)
    }

  React.useEffect(() => {
    SadPortRegistry.registry
    ->Dict.keysToArray
    ->Array.filter(key => String.startsWith(key, `${groupId}:`))
    ->Array.forEach(key => {
      switch SadPortRegistry.getPort(~key) {
      | Some(port) =>
        let fieldName = key->String.replace(`${groupId}:`, "")
        MessageChannelBinding.onPortMessage(port, ev => {
          let frameJson: JSON.t = ev.data->Identity.anyTypeToJson
          switch CardFormPortProtocol.decodePortFrame(frameJson) {
          | Some({kind, payload}) if kind === CardFormPortProtocol.kindFieldStateUpdate => {
              fieldSnapshotsRef.current->Dict.set(fieldName, {payload: payload})
              let cardBrand = payload->getDictFromJson->getString("cardBrand", "")
              if fieldName === "cardNumber" && cardBrand !== "" && cardBrand !== lastBrandRef.current {
                lastBrandRef.current = cardBrand
                relayDetectedBrandToCvc(cardBrand)
              }
              let focusReady =
                payload->getDictFromJson->getBool("focusReady", false)
              let prevReady = prevFocusReadyRef.current->Dict.get(fieldName)->Option.getOr(false)
              prevFocusReadyRef.current->Dict.set(fieldName, focusReady)
              if focusReady && !prevReady {
                CardFormShared.nextFieldFor(fieldName)->Option.forEach(nextFieldName => {
                  SadPortRegistry.postFrame(
                    ~key=portKey(~groupId, ~fieldName=nextFieldName),
                    CardFormPortProtocol.makePortFrame(
                      ~kind=CardFormPortProtocol.kindDoFocus,
                      ~payload=true->JSON.Encode.bool,
                    ),
                  )->ignore
                })
              }
            }
          | Some({kind, _}) =>
            Console.warn(`[CardFormCoordinator] dropped port frame on unknown kind "${kind}" (port "${key}")`)
          | None =>
            Console.warn(`[CardFormCoordinator] dropped un-decodable port frame (port "${key}")`)
          }
        })
        seedDetectedBrandOnCvcRegistration(fieldName)
      | None => ()
      }
    })
    None
  }, (registryVersion, groupId))

  React.useEffect(() => {
    let handleCommand = (ev: Window.event) => {
      if ev.source === iframeParent && (keys.parentURL === "*" || ev.origin === keys.parentURL) {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        let command = dict->getString("cardFormCoordinatorCommand", "")
        if command !== "" {
          let confirmId = dict->getString("confirmId", "")
          let errorLocale = dict->getString("locale", "en")
          if coordinatorFamily === PaymentSurfaceFamily.OtherCoordinatorFamily {
            postConfirmResult(
              ~confirmId,
              buildConfirmResult(
                ~outcome=Failure({
                  code: "tokenization_failed",
                  message: Some(
                    `cardFormCoordinator missing/unknown surfaceFamily (got "${surfaceFamilyStr}")`,
                  ),
                  locale: errorLocale,
                  typeOverride: Some(ApiError),
                }),
              ),
            )
          } else if command === "initiateConfirm" {
            let flowKind = dict->getString("flow", "save")
            let isVaultCommand = flowKind === "save" || flowKind === "update"
            let misroute = (isVaultCommand && coordinatorFamily !== PaymentSurfaceFamily.VaultCoordinator) || (
              !isVaultCommand && coordinatorFamily !== PaymentSurfaceFamily.PaymentsCoordinator
            )
            if misroute {
              if isVaultCommand {
                postConfirmResult(
                  ~confirmId,
                  buildConfirmResult(
                    ~outcome=Failure({
                      code: "tokenization_failed",
                      message: Some(
                        `vault "initiateConfirm" (${flowKind}) misrouted to a payments-family coordinator`,
                      ),
                      locale: errorLocale,
                      typeOverride: Some(ApiError),
                    }),
                  ),
                )
              } else {
                messageParentWindow(
                  [
                    ("paymentConfirmFail", true->JSON.Encode.bool),
                    (
                      "errorMessage",
                      `payments "initiateConfirm" (${flowKind}) misrouted to a vault-family coordinator`
                      ->JSON.Encode.string,
                    ),
                    ("iframeId", keys.iframeId->JSON.Encode.string),
                  ],
                  ~targetOrigin=keys.parentURL,
                )
              }
            } else if flowKind === "payments" || flowKind === "savedCardCvc" {
              let cardNumber = aggregatedCardNumber()
              let cardExpiry = aggregatedCardExpiry()
              let cvcNumber = aggregatedCvcNumber()
              let cardBrand = aggregatedCardBrand()
              if (
                flowKind === "payments" &&
                (cardNumber === "" || cardExpiry === "" || cvcNumber === "" ||
                anyContributingFieldConfirmedInvalid())
              ) {
                messageParentWindow(
                  [
                    ("paymentConfirmFail", true->JSON.Encode.bool),
                    ("errorMessage", "Card details incomplete or invalid"->JSON.Encode.string),
                    ("iframeId", keys.iframeId->JSON.Encode.string),
                  ],
                  ~targetOrigin=keys.parentURL,
                )
              } else if (
                flowKind === "savedCardCvc" && (cvcNumber === "" || cardCvcConfirmedInvalid())
              ) {
                messageParentWindow(
                  [
                    ("paymentConfirmFail", true->JSON.Encode.bool),
                    ("errorMessage", "CVC incomplete or invalid"->JSON.Encode.string),
                    ("iframeId", keys.iframeId->JSON.Encode.string),
                  ],
                  ~targetOrigin=keys.parentURL,
                )
              } else {
                let confirmParam: ConfirmType.confirmParams = {
                  return_url: Window.hrefWithoutSearch,
                  publishableKey: keys.publishableKey,
                }
                if flowKind === "payments" {
                  let (month, year) = CardUtils.getExpiryDates(cardExpiry)
                  let cardNetwork = [
                    (
                      "card_network",
                      cardBrand != "" ? cardBrand->JSON.Encode.string : JSON.Encode.null,
                    ),
                  ]
                  let body = PaymentBody.cardPaymentBody(
                    ~cardNumber,
                    ~month,
                    ~year,
                    ~cardHolderName=None,
                    ~cvcNumber,
                    ~cardBrand=cardNetwork,
                  )
                  intent(~handleUserError=false, ~bodyArr=body, ~confirmParam, ~iframeId=keys.iframeId)
                  messageParentWindow(
                    [("paymentConfirmAck", true->JSON.Encode.bool)],
                    ~targetOrigin=keys.parentURL,
                  )
                } else {
                  let paymentToken = dict->getString("paymentToken", "")
                  let customerId = switch paymentMethodListValue {
                  | Loaded(data)
                  | LoadError(data) =>
                    data->getDictFromJson->getDictFromDict("intent_data")->getString("customer_id", "")
                  | _ => ""
                  }
                  if customerId === "" {
                    messageParentWindow(
                      [
                        ("paymentConfirmFail", true->JSON.Encode.bool),
                        (
                          "errorMessage",
                          "saved-card confirm requires the customer payment-method list (clientList) to be loaded"
                          ->JSON.Encode.string,
                        ),
                        ("iframeId", keys.iframeId->JSON.Encode.string),
                      ],
                      ~targetOrigin=keys.parentURL,
                    )
                  } else {
                    let body = PaymentBody.savedCardBody(
                      ~paymentToken,
                      ~customerId,
                      ~cvcNumber,
                      ~requiresCvv=true,
                      ~isCustomerAcceptanceRequired=true,
                    )
                    intent(~handleUserError=false, ~bodyArr=body, ~confirmParam, ~iframeId=keys.iframeId)
                    messageParentWindow(
                      [("paymentConfirmAck", true->JSON.Encode.bool)],
                      ~targetOrigin=keys.parentURL,
                    )
                  }
                }
              }
            } else if confirmingRef.current {
              ()
            } else {
              confirmingRef.current = true
              let settledRef = ref(false)
              let settle = result => {
                if !settledRef.contents {
                  settledRef := true
                  confirmingRef.current = false
                  postConfirmResult(~confirmId, result)
                }
              }

              let flow = dict->getString("flow", "save")
              let cardNumber = aggregatedCardNumber()
              let cardExpiry = aggregatedCardExpiry()
              let cvcNumber = aggregatedCvcNumber()

              let (pmSessionId, vaultAuth) = switch vaultCredentials {
              | VaultHelpers.HyperswitchVault(creds) => (creds.pmSessionId, creds.sdkAuthorization)
              | _ => ("", "")
              }
              if flow !== "update" && (cardNumber === "" || cardExpiry === "" || cvcNumber === "") {
                settle(
                  buildConfirmResult(
                    ~outcome=Failure({
                      code: "validation_error",
                      message: Some("one or more card fields are incomplete"),
                      locale: errorLocale,
                      typeOverride: None,
                    }),
                  ),
                )
              } else if flow !== "update" && anyContributingFieldConfirmedInvalid() {
                settle(
                  buildConfirmResult(
                    ~outcome=Failure({
                      code: "validation_error",
                      message: Some("one or more card fields are invalid"),
                      locale: errorLocale,
                      typeOverride: None,
                    }),
                  ),
                )
              } else if flow === "update" && cvcNumber === "" {
                settle(
                  buildConfirmResult(
                    ~outcome=Failure({
                      code: "validation_error",
                      message: Some("cvc is incomplete"),
                      locale: errorLocale,
                      typeOverride: None,
                    }),
                  ),
                )
              } else if flow === "update" && cardCvcConfirmedInvalid() {
                settle(
                  buildConfirmResult(
                    ~outcome=Failure({
                      code: "validation_error",
                      message: Some("cvc is invalid"),
                      locale: errorLocale,
                      typeOverride: None,
                    }),
                  ),
                )
              } else if pmSessionId === "" || vaultAuth === "" {
                settle(
                  buildConfirmResult(
                    ~outcome=Failure({
                      code: "tokenization_failed",
                      message: Some("no hyperswitch vault credentials decoded from sessions"),
                      locale: errorLocale,
                      typeOverride: Some(ApiError),
                    }),
                  ),
                )
              } else {
                let pmSessionIdCopy = pmSessionId
                let vaultAuthCopy = vaultAuth
                if flow === "save" {
                  let (month, year) = CardUtils.getExpiryDates(cardExpiry)
                  PaymentHelpersV2.savePaymentMethod(
                    ~bodyArr=PaymentBody.cardTokenizationBody(~cardNumber, ~cvcNumber, ~month, ~year),
                    ~pmSessionId=pmSessionIdCopy,
                    ~sdkAuthorization=vaultAuthCopy,
                    ~logger=loggerState,
                  )
                  ->Promise.then(response => {
                    if response == JSON.Encode.null {
                      settle(
                        buildConfirmResult(
                          ~outcome=Failure({
                            code: "tokenization_failed",
                            message: Some("vault confirm POST returned null (HTTP failure)"),
                            locale: errorLocale,
                            typeOverride: Some(ApiError),
                          }),
                        ),
                      )
                    } else {
                      settle(
                        buildConfirmResult(
                          ~outcome=Success(response),
                        ),
                      )
                    }
                    Promise.resolve()
                  })
                  ->Promise.catch(_ => {
                    settle(
                      buildConfirmResult(
                        ~outcome=Failure({
                          code: "tokenization_failed",
                          message: Some("vault confirm POST rejected"),
                          locale: errorLocale,
                          typeOverride: Some(ApiError),
                        }),
                      ),
                    )
                    Promise.resolve()
                  })
                  ->ignore
                } else {
                  PaymentHelpersV2.updatePaymentMethod(
                    ~bodyArr=PaymentManagementBody.vaultUpdateCVVBody(~cvcNumber),
                    ~pmSessionId=pmSessionIdCopy,
                    ~logger=loggerState,
                    ~customPodUri,
                    ~sdkAuthorization=vaultAuthCopy,
                  )
                  ->Promise.then(response => {
                    if response == JSON.Encode.null {
                      settle(
                        buildConfirmResult(
                          ~outcome=Failure({
                            code: "tokenization_failed",
                            message: Some("vault update POST returned null (HTTP failure)"),
                            locale: errorLocale,
                            typeOverride: Some(ApiError),
                          }),
                        ),
                      )
                    } else {
                      settle(
                        buildConfirmResult(
                          ~outcome=Success(response),
                        ),
                      )
                    }
                    Promise.resolve()
                  })
                  ->Promise.catch(_ => {
                    settle(
                      buildConfirmResult(
                        ~outcome=Failure({
                          code: "tokenization_failed",
                          message: Some("vault update POST rejected"),
                          locale: errorLocale,
                          typeOverride: Some(ApiError),
                        }),
                      ),
                    )
                    Promise.resolve()
                  })
                  ->ignore
                }
              }
            }
          }
        }
      }
    }
    handleMessage(handleCommand, "")
  }, (keys, sessions, paymentMethodListValue, registryVersion, groupId))

  React.null
}
