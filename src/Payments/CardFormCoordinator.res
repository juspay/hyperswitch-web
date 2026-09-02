/* CardFormCoordinator — hidden 0x0 hosted iframe that OWNS CardForm confirm for both
   surface families (vault save/update; payments Flow A `usePaymentIntent`).
   Per-field MessageChannel ports deliver each field's FULL snapshot INCLUDING raw SAD;
   the coordinator folds them into its own cache and raw values NEVER touch the merchant
   window — only the masked confirm-result union is posted back.
   It also relays the detected brand onto the cvc port and routes `doFocus` on the
   `focusReady` false→true edge. Settle is exactly-once with an 8s hang backstop. */

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
  /* the confirm mutex is a session/api concern, not a card-input one — classified ApiError
     so the vault surface matches the payments `confirm_in_progress` envelope. */
  let resolvedType = switch typeOverride {
  | Some(t) => t
  | None =>
    switch code {
    | "validation_error" | "incomplete_field_set" => ValidationError
    | "session_expired"
    | "session_consumed"
    | "tokenization_failed"
    | "confirm_in_progress" => ApiError
    | _ => CardError
    }
  }
  let errorDict = Dict.make()
  errorDict->Dict.set("code", code->JSON.Encode.string)
  errorDict->Dict.set("message", resolvedMessage->JSON.Encode.string)
  errorDict->Dict.set("type", resolvedType->errorTypeToString->JSON.Encode.string)
  let resultDict = Dict.make()
  resultDict->Dict.set("status", "error"->JSON.Encode.string)
  resultDict->Dict.set("error", errorDict->JSON.Encode.object)
  resultDict->JSON.Encode.object
}

type flowASuccessPayload = {
  token: string,
  paymentMethodId: option<string>,
  brand: string,
  last4: string,
  expiryMonth: string,
  expiryYear: string,
}
type flowBSuccessPayload = {
  cvcToken: string,
  brand: string,
  last4: string,
}
type failurePayload = {
  code: string,
  message: option<string>,
  locale: string,
  typeOverride: option<errorType>,
}

type confirmOutcome =
  | FlowASuccess(flowASuccessPayload)
  | FlowBSuccess(flowBSuccessPayload)
  | Failure(failurePayload)

let buildConfirmResult = (~outcome: confirmOutcome): JSON.t =>
  switch outcome {
  | FlowASuccess(payload) =>
    /* Hardening (same as pre-move): `paymentMethodId=None` is legal (VGS
       aliases); `Some("")` is a decode bug and demotes to tokenization_failed. */
    let pmIdMissing = switch payload.paymentMethodId {
    | Some(s) => s == ""
    | None => false
    }
    if payload.token == "" || pmIdMissing {
      makeErrorResult(
        ~code="tokenization_failed",
        ~message="vault confirm response was missing token / payment_method_id",
        (),
      )
    } else {
      let cardDict =
        [
          ("brand", payload.brand->JSON.Encode.string),
          ("last4", payload.last4->JSON.Encode.string),
          ("expiryMonth", payload.expiryMonth->JSON.Encode.string),
          ("expiryYear", payload.expiryYear->JSON.Encode.string),
        ]->Dict.fromArray
      let pmIdJson = switch payload.paymentMethodId {
      | Some(s) => s->JSON.Encode.string
      | None => JSON.Encode.null
      }
      [
        ("status", "success"->JSON.Encode.string),
        ("token", payload.token->JSON.Encode.string),
        ("paymentMethodId", pmIdJson),
        ("card", cardDict->JSON.Encode.object),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object
    }
  | FlowBSuccess(payload) =>
    if payload.cvcToken == "" {
      makeErrorResult(
        ~code="tokenization_failed",
        ~message="vault Flow B (saved-card CVC recollect) response was missing cvcToken",
        (),
      )
    } else {
      let cardDict =
        [
          ("brand", payload.brand->JSON.Encode.string),
          ("last4", payload.last4->JSON.Encode.string),
        ]->Dict.fromArray
      [
        ("status", "success"->JSON.Encode.string),
        ("cvcToken", payload.cvcToken->JSON.Encode.string),
        ("card", cardDict->JSON.Encode.object),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object
    }
  | Failure(payload) =>
    makeErrorResult(
      ~code=payload.code,
      ~message=?payload.message,
      ~locale=payload.locale,
      ~typeOverride=?payload.typeOverride,
      (),
    )
  }

/* Per-group port key shape: "<groupId>:<fieldName>" — the mounter
   (`CoordinatorMount`) composes these deterministically. */
let portKey = (~groupId: string, ~fieldName: string): string => `${groupId}:${fieldName}`

/* The coordinator's per-field cache entry: the most recent FULL port-plane
   payload (incl. RAW SAD — never relaid to the merchant window). */
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
  // masked result post — the confirm-result union is the ONLY thing the group sees.
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

  /* a field is CONFIRMED-invalid only when it HAS a validation status and that status is
     false; an absent status is pristine (first-keystroke race) and must NOT reject. The
     non-empty check still covers untouched fields. */
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

  /* attach a frame listener per registered port under this group's prefix; safe to overwrite
     because the registry closes superseded ports on epoch replacement. */
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
                SadPortRegistry.postFrame(
                  ~key=portKey(~groupId, ~fieldName="cardCvc"),
                  CardFormPortProtocol.makePortFrame(
                    ~kind=CardFormPortProtocol.kindDetectedCardBrand,
                    ~payload=cardBrand->JSON.Encode.string,
                  ),
                )->ignore
              }
              /* Focus progression: false→true edge per field, default-absent
                 → false; cardCvc is terminal (nextFieldFor returns None). */
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
            /* ADMISSION GATE: a misrouted coordinator iframe must FAIL LOUDLY rather than silently
               drop the caller's confirm slot. */
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
          /* the group's mutex latches BEFORE posting any confirm command, so the coordinator never
             sees two in-flight commands for one group and needs no inner gate. */
          } else if command === "initiateConfirm" {
            let flowKind = dict->getString("flow", "save")
            let isVaultCommand = flowKind === "save" || flowKind === "update"
            /* family gating: payments commands must not run on a vault coordinator or vice versa —
               misrouting fails loud rather than landing in the wrong arm. */
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
              /* payments flows are fire-and-forget: the network outcome rides the unchanged
                 `submitSuccessful` broadcast. The coordinator posts the paymentConfirmAck/Fail pair so
                 the outer group can settle its confirm mutex. */
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
                  /* Flow B — saved-card CVC recollect via `savedCardBody`: payment_token, card_cvc and
                     customer_id from the clientList's intent_data; customer_acceptance always attached. */
                  let paymentToken = dict->getString("paymentToken", "")
                  let customerId = switch paymentMethodListValue {
                  | Loaded(data)
                  | LoadError(data) =>
                    data->getDictFromJson->getDictFromDict("intent_data")->getString("customer_id", "")
                  | _ => ""
                  }
                  /* gate the dispatch when the clientList carried no customer_id — do NOT silently drop the
                     key from the body. */
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
              /* exactly-once sink for the vault arm. Deliberately NO deadline: every branch
                 below settles — the four validation guards and the credential guard settle
                 synchronously, and both POSTs settle in BOTH their `then` and their `catch`
                 (a null body counts as an HTTP failure). An 8s timer here could only pre-empt a
                 slow-but-successful vault save and report `tokenization_failed` for a card that
                 WAS stored — the worst outcome available. */
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
                      let vaultTokenData = VaultHelpers.decodeVaultTokenData(response)
                      settle(
                        buildConfirmResult(
                          ~outcome=FlowASuccess({
                            token: vaultTokenData.token,
                            paymentMethodId: None,
                            brand: vaultTokenData.brand,
                            last4: vaultTokenData.last4Digits,
                            expiryMonth: vaultTokenData.expiryMonth,
                            expiryYear: vaultTokenData.expiryYear,
                          }),
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
                  // flow === "update" — saved-card CVC recollect.
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
                      let vaultTokenData = VaultHelpers.decodeVaultTokenData(response)
                      settle(
                        buildConfirmResult(
                          ~outcome=FlowBSuccess({
                            cvcToken: vaultTokenData.token,
                            brand: dict->getString("savedCardBrand", ""),
                            last4: dict->getString("savedCardLast4", ""),
                          }),
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

  /* the coordinator INTENTIONALLY emits no window-plane `ready` beacon — the field iframes
     arm Hyper.res's first-ready-wins latch and a coordinator beacon would pre-empt it. */
  React.null
}
