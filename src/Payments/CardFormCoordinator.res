// CardFormCoordinator — hidden 0×0 hosted iframe that OWNS CardForm confirm
// end-to-end for BOTH surface families (vault `save`/`update`; payments
// Flow A `usePaymentIntent`). See `docs/messagechannel-architecture-pitch.md`.
//
// THIS VERSION: P0.2-promoted from the P0.0 spike scaffold.
//
// Responsibilities (locked):
//   1. PORT-PLANE AGGREGATION — per-field MessageChannel ports (installed by
//      LoaderController from `ev.ports`, see SadPortRegistry) deliver each
//      field's FULL `cardStateUpdate` snapshot INCLUDING raw SAD. The
//      coordinator folds these into its own per-field cache; raw values
//      NEVER touch the merchant window.
//   2. BRAND RELAY — the latest non-empty `cardBrand` from cardNumber's port
//      stream is posted onto the cardCvc port as `detectedCardBrand` on
//      CHANGE of a non-empty brand.
//   3. FOCUS PROGRESSION — the `focusReady` false→true edge on a field's port
//      stream posts a `doFocus` port-frame to `CardFormShared.nextFieldFor`
//      (default-absent → false semantics; cardCvc is terminal).
//   4. CONFIRM OWNERSHIP — `initiateConfirm` from the group runs
//      `usePaymentIntent` (payments Flow A) or
//      `PaymentHelpersV2.{savePaymentMethod,updatePaymentMethod}` (vault).
//      Payments Flow A resolution rides the unchanged `submitSuccessful`
//      broadcast (consumed by Hyper.res:432) — we post NOTHING extra there.
//      Vault confirmations settle into the §4.4 union via
//      `buildConfirmResult` (MOVED here in P0.2 from
//      PaymentMethodsSessionGroup; the group aliases this module) and post
//      back as `{confirmResult, confirmId, iframeId}`.
//   5. SETTLE DISCIPLINE — exactly-once, group-wide-mutex, hang backstop,
//      reusing the `confirmSettleTimeoutMs` vocabulary (8s), mirroring the
//      vault group's former settle() structure.
//   6. SPIKE SCAFFOLDING — the `spikeCommand` protocol from P0.0 is retained
//      for the spike harness + P0.4 dogfood dogfood; it is retired in P1.
//
// Mount-window discipline: mount-config arrives via the standard
// LoaderController handshake; clientList/sessions arrive via the group's
// retargeted posts (LoaderController sets the atoms). Review SF-2 correction:
// there is NO "gate effect that blocks confirm until Loaded": the vault arm
// FAILS FAST when its sessions/credentials are missing, and the payments
// gate lives inside `usePaymentIntent`'s `switch paymentMethodList`
// (`PaymentHelpers.res`) — `None` decays to the `confirm_payment_failed`
// early-exit (no network call). Groups already wait for the coordinator's
// `iframeMounted` before flushing commands, which covers the LIST POST
// ordering in practice.
open Utils
open JotaiAtoms

// ── Move: §4.4 confirm-result union (was PaymentMethodsSessionGroup) ───────
// Verbatim move so the union contract stays byte-identical. The group module
// aliases these exports (P0.3) and its tests retarget here (P0.4).
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

// Locale resolution short-circuits on the EN default for now (mirrors the
// pre-move arm; non-EN translations are a separate thread).
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
  // The confirm mutex ("confirm_in_progress") is a session/api concern, not a
  // card-input concern — classified ApiError in the default arm so the vault
  // surface matches the payments CardForm's `confirm_in_progress` envelope.
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
  | FlowASuccess(p) =>
    // Hardening (same as pre-move): `paymentMethodId=None` is legal (VGS
    // aliases); `Some("")` is a decode bug and demotes to tokenization_failed.
    let pmIdMissing = switch p.paymentMethodId {
    | Some(s) => s == ""
    | None => false
    }
    if p.token == "" || pmIdMissing {
      makeErrorResult(
        ~code="tokenization_failed",
        ~message="vault confirm response was missing token / payment_method_id",
        (),
      )
    } else {
      let cardDict =
        [
          ("brand", p.brand->JSON.Encode.string),
          ("last4", p.last4->JSON.Encode.string),
          ("expiryMonth", p.expiryMonth->JSON.Encode.string),
          ("expiryYear", p.expiryYear->JSON.Encode.string),
        ]->Dict.fromArray
      let pmIdJson = switch p.paymentMethodId {
      | Some(s) => s->JSON.Encode.string
      | None => JSON.Encode.null
      }
      [
        ("status", "success"->JSON.Encode.string),
        ("token", p.token->JSON.Encode.string),
        ("paymentMethodId", pmIdJson),
        ("card", cardDict->JSON.Encode.object),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object
    }
  | FlowBSuccess(p) =>
    if p.cvcToken == "" {
      makeErrorResult(
        ~code="tokenization_failed",
        ~message="vault Flow B (saved-card CVC recollect) response was missing cvcToken",
        (),
      )
    } else {
      let cardDict =
        [
          ("brand", p.brand->JSON.Encode.string),
          ("last4", p.last4->JSON.Encode.string),
        ]->Dict.fromArray
      [
        ("status", "success"->JSON.Encode.string),
        ("cvcToken", p.cvcToken->JSON.Encode.string),
        ("card", cardDict->JSON.Encode.object),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object
    }
  | Failure(p) =>
    makeErrorResult(~code=p.code, ~message=?p.message, ~locale=p.locale, ~typeOverride=?p.typeOverride, ())
  }

// ── Settle vocabulary ───────────────────────────────────────────────────────
// Kept IDENTICAL to the groups: 8s round-trip budget, exactly-once settle,
// hang backstop via setTimeout. (Plan §4.4 / F5.)
let confirmSettleTimeoutMs = 8000

// Per-group port key shape: "<groupId>:<fieldName>" — the mounter composes
// these deterministically (CoordinatorMount in P0.3; the spike page for
// P0.4 dogfood).
let portKey = (~groupId: string, ~fieldName: string): string => `${groupId}:${fieldName}`

// The coordinator's per-field cache entry: the most recent FULL port-plane
// payload (incl. RAW SAD — never relaid to the merchant window).
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
  // Spike arms accept commands ONLY on spike harnesses — the dedicated
  // coordinator iframe must carry `spike=1` in its URL. Without this, any
  // same-origin page could window-post raws into the coordinator.
  let spikeEnabled = CardUtils.getQueryParamsDictforKey(url.search, "spike") === "1"

  let coordinatorFamily = PaymentSurfaceFamily.classifyCoordinatorFromUrl(
    ~componentName,
    ~surfaceFamily,
  )

  // ── Aggregate state ───────────────────────────────────────────────────────
  // fieldSnapshotsRef: latest per-field FULL port payload (incl. raw SAD).
  // prevFocusReadyRef: latch backing the focusReady false→true edge.
  // lastBrandRef: brand-relay cache (relay on CHANGE of a non-empty brand).
  // confirmingRef: group-wide mutex backing `confirm_in_progress`.
  let fieldSnapshotsRef = React.useRef(Dict.make(): Dict.t<fieldSnapshotEntry>)
  let prevFocusReadyRef = React.useRef(Dict.make(): Dict.t<bool>)
  let lastBrandRef = React.useRef("")
  let confirmingRef = React.useRef(false)

  let (registryVersion, setRegistryVersion) = React.useState(() => 0)
  React.useEffect0(() => {
    let bump = () => setRegistryVersion(v => v + 1)
    SadPortRegistry.addChangeListener(bump)
    Some(() => SadPortRegistry.removeChangeListener(bump))
  })

  // Real payments confirm dispatcher — legal here because the coordinator
  // runs INSIDE our own app.js bundle.
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)

  let postSpikeResult = (entries: array<(string, JSON.t)>) => {
    messageParentWindow(
      [("spikeResult", entries->Dict.fromArray->JSON.Encode.object)],
      ~targetOrigin=keys.parentURL,
    )
  }

  // Masked result post: the §4.4 union — the ONLY thing the group sees.
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

  // Aggregate a raw field across the coordinator's own port-plane cache.
  // `pick` selects that field's raw slot from ONE field snapshot; first
  // non-empty wins (the same guard the group's `!== ""` cache-on-change
  // carries: a stale frozen cache can never blank out a previously good
  // value).
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

  // ── Port-plane wiring ─────────────────────────────────────────────────────
  // For every registered port under this group's prefix, attach a frame
  // listener (overwritten cleanly on registry bumps because the registry
  // closes superseded ports for us on epoch replacement).
  React.useEffect(() => {
    SadPortRegistry.registry
    ->Dict.keysToArray
    ->Array.filter(key => String.startsWith(key, `${groupId}:`))
    ->Array.forEach(key => {
      switch SadPortRegistry.getPort(~key) {
      | Some(port) =>
        let fieldName = key->String.replace(`${groupId}:`, "")
        MessageChannelBinding.onPortMessage(port, ev => {
          let data: JSON.t = ev.data->Identity.anyTypeToJson
          switch CardFormPortProtocol.decodePortFrame(data) {
          | Some({kind, payload}) if kind === CardFormPortProtocol.kindFieldStateUpdate => {
              fieldSnapshotsRef.current->Dict.set(fieldName, {payload: payload})
              // Brand relay: cardNumber's non-empty brand, on CHANGE ONLY.
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
              // Focus progression: false→true edge per field, default-absent
              // → false; cardCvc is terminal (nextFieldFor returns None).
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

  // ── Command channel: spike commands (retire P1) + initiateConfirm ────────
  React.useEffect(() => {
    let handleCommand = (ev: Window.event) => {
      if ev.source === iframeParent && (keys.parentURL === "*" || ev.origin === keys.parentURL) {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        let command = dict->getString("cardFormCoordinatorCommand", "")
        if command !== "" {
          let confirmId = dict->getString("confirmId", "")
          // Merchant-passed locale echo (the groups thread `"locale"` onto
          // every confirm command) — failure envelopes settle in the
          // command's own locale so resolution surfaces stay consistent.
          let errorLocale = dict->getString("locale", "en")
          if coordinatorFamily === PaymentSurfaceFamily.OtherCoordinatorFamily {
            // ADMISSION GATE: misrouted coordinator iframes must FAIL LOUDLY
            // (mirrors PaymentMethodsSDK's InvalidSurfaceFamilyParams branch)
            // rather than silently drop the caller's confirm slot.
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
          // The group's confirm mutex latches BEFORE posting any confirm
          // command, so the coordinator never sees two in-flight commands
          // for one group and needs no inner confirming gate.
          } else if command === "initiateConfirm" {
            let flowKind = dict->getString("flow", "save")
            let isVaultCommand = flowKind === "save" || flowKind === "update"
            // Family gating: payments commands must not run on a vault
            // coordinator and vice-versa — misrouting fails loud, never
            // silently lands in the wrong arm.
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
              // ── Payments flows (Flow A / Flow B): fire-and-forget intent.
              // The network outcome rides the unchanged `submitSuccessful`
              // broadcast (`PaymentHelpers.intentCall` → `Hyper.res:440`).
              // The coordinator posts the `paymentConfirmAck` /
              // `paymentConfirmFail` pair so the outer group can settle its
              // F4 mutex — same vocabulary the per-field iframes used.
              let cardNumber = aggregatedCardNumber()
              let cardExpiry = aggregatedCardExpiry()
              let cvcNumber = aggregatedCvcNumber()
              let cardBrand = aggregatedCardBrand()
              if flowKind === "payments" && (cardNumber === "" || cardExpiry === "" || cvcNumber === "") {
                messageParentWindow(
                  [
                    ("paymentConfirmFail", true->JSON.Encode.bool),
                    ("errorMessage", "Card details incomplete or invalid"->JSON.Encode.string),
                    ("iframeId", keys.iframeId->JSON.Encode.string),
                  ],
                  ~targetOrigin=keys.parentURL,
                )
              } else if flowKind === "savedCardCvc" && cvcNumber === "" {
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
                  // Flow B — saved-card CVC recollect (mirrors the retired
                  // `SecureCardCvcV2Field`'s savedCardBody path):
                  // payment_token + card_token.card_cvc + customer_id from
                  // the clientList's intent_data. `customer_acceptance`
                  // always attached (matches SavedMethods' rule).
                  let paymentToken = dict->getString("paymentToken", "")
                  let customerId = switch paymentMethodListValue {
                  | Loaded(data)
                  | LoadError(data) =>
                    data->getDictFromJson->getDictFromDict("intent_data")->getString("customer_id", "")
                  | _ => ""
                  }
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
            } else if confirmingRef.current {
              ()
            } else {
              confirmingRef.current = true
              let settledRef = ref(false)
              let settleTimeoutRef = ref(None)
              let settle = result => {
                if !settledRef.contents {
                  settledRef := true
                  settleTimeoutRef.contents->Option.forEach(clearTimeout)
                  confirmingRef.current = false
                  postConfirmResult(~confirmId, result)
                }
              }
              settleTimeoutRef := Some(
                setTimeout(() => {
                  settle(
                    buildConfirmResult(
                      ~outcome=Failure({
                        code: "tokenization_failed",
                        message: Some(
                          "confirm relay timed out waiting for the coordinator vault POST — the coordinator may be degraded. Retry; the session is still active.",
                        ),
                        locale: errorLocale,
                        typeOverride: Some(ApiError),
                      }),
                    ),
                  )
                }, confirmSettleTimeoutMs),
              )

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
                      let d = VaultHelpers.decodeVaultTokenData(response)
                      settle(
                        buildConfirmResult(
                          ~outcome=FlowASuccess({
                            token: d.token,
                            paymentMethodId: None,
                            brand: d.brand,
                            last4: d.last4Digits,
                            expiryMonth: d.expiryMonth,
                            expiryYear: d.expiryYear,
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
                      let d = VaultHelpers.decodeVaultTokenData(response)
                      settle(
                        buildConfirmResult(
                          ~outcome=FlowBSuccess({
                            cvcToken: d.token,
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

        // ── Spike-scaffold commands (gated on the harness iframe's spike=1
        //    URL param — review GLM-N1; retire with P0.0 harness in P1) ────
        switch spikeEnabled ? dict->getString("spikeCommand", "") : "" {
        | "" => ()
        | "ping" =>
          postSpikeResult([
            ("kind", "ping"->JSON.Encode.string),
            ("ok", true->JSON.Encode.bool),
            ("componentName", componentName->JSON.Encode.string),
            ("surfaceFamily", surfaceFamilyStr->JSON.Encode.string),
            ("groupId", groupId->JSON.Encode.string),
          ])
        | "paymentsFlowA" => {
            let cardNumber = dict->getString("cardNumber", "")
            let cardExpiry = dict->getString("cardExpiry", "")
            let cvcNumber = dict->getString("cvcNumber", "")
            let returnUrl = dict->getString("returnUrl", Window.hrefWithoutSearch)
            if cardNumber === "" || cardExpiry === "" || cvcNumber === "" {
              postSpikeResult([("kind", "paymentsFlowA"->JSON.Encode.string), ("ok", false->JSON.Encode.bool)])
            } else {
              let (month, year) = CardUtils.getExpiryDates(cardExpiry)
              let cardBrand = dict->getString("cardBrand", "")
              let body = PaymentBody.cardPaymentBody(
                ~cardNumber,
                ~month,
                ~year,
                ~cardHolderName=None,
                ~cvcNumber,
                ~cardBrand=[("card_network", cardBrand !== "" ? cardBrand->JSON.Encode.string : JSON.Encode.null)],
              )
              let confirmParam: ConfirmType.confirmParams = {
                return_url: returnUrl,
                publishableKey: keys.publishableKey,
              }
              intent(~handleUserError=false, ~bodyArr=body, ~confirmParam, ~iframeId=keys.iframeId)
              postSpikeResult([
                ("kind", "paymentsFlowA"->JSON.Encode.string),
                ("ok", true->JSON.Encode.bool),
                ("dispatched", true->JSON.Encode.bool),
              ])
            }
          }
        | "vaultSave" => {
            let cardNumber = dict->getString("cardNumber", "")
            let cardExpiry = dict->getString("cardExpiry", "")
            let cvcNumber = dict->getString("cvcNumber", "")
            let (pmSessionId, vaultAuth) = switch vaultCredentials {
            | VaultHelpers.HyperswitchVault(creds) => (creds.pmSessionId, creds.sdkAuthorization)
            | _ => ("", "")
            }
            if cardNumber === "" || cardExpiry === "" || cvcNumber === "" {
              postSpikeResult([
                ("kind", "vaultSave"->JSON.Encode.string),
                ("ok", false->JSON.Encode.bool),
                ("error", "incomplete card payload"->JSON.Encode.string),
              ])
            } else if pmSessionId === "" || vaultAuth === "" {
              postSpikeResult([
                ("kind", "vaultSave"->JSON.Encode.string),
                ("ok", false->JSON.Encode.bool),
                ("error", "no hyperswitch vault credentials decoded from sessions"->JSON.Encode.string),
              ])
            } else {
              let (month, year) = CardUtils.getExpiryDates(cardExpiry)
              PaymentHelpersV2.savePaymentMethod(
                ~bodyArr=PaymentBody.cardTokenizationBody(~cardNumber, ~cvcNumber, ~month, ~year),
                ~pmSessionId,
                ~sdkAuthorization=vaultAuth,
                ~logger=loggerState,
              )
              ->Promise.then(response => {
                if response == JSON.Encode.null {
                  postSpikeResult([
                    ("kind", "vaultSave"->JSON.Encode.string),
                    ("ok", false->JSON.Encode.bool),
                    ("error", "vault confirm POST returned null (HTTP failure)"->JSON.Encode.string),
                  ])
                } else {
                  let d = VaultHelpers.decodeVaultTokenData(response)
                  postSpikeResult([
                    ("kind", "vaultSave"->JSON.Encode.string),
                    ("ok", (d.token !== "")->JSON.Encode.bool),
                    ("token", d.token->JSON.Encode.string),
                    ("brand", d.brand->JSON.Encode.string),
                    ("last4Digits", d.last4Digits->JSON.Encode.string),
                    ("expiryMonth", d.expiryMonth->JSON.Encode.string),
                    ("expiryYear", d.expiryYear->JSON.Encode.string),
                  ])
                }
                Promise.resolve()
              })
              ->Promise.catch(_ => {
                postSpikeResult([
                  ("kind", "vaultSave"->JSON.Encode.string),
                  ("ok", false->JSON.Encode.bool),
                  ("error", "vault confirm POST rejected"->JSON.Encode.string),
                ])
                Promise.resolve()
              })
              ->ignore
            }
          }
        | "vaultUpdate" => {
            let cvcNumber = dict->getString("cvcNumber", "")
            let (pmSessionId, vaultAuth) = switch vaultCredentials {
            | VaultHelpers.HyperswitchVault(creds) => (creds.pmSessionId, creds.sdkAuthorization)
            | _ => ("", "")
            }
            if cvcNumber === "" {
              postSpikeResult([
                ("kind", "vaultUpdate"->JSON.Encode.string),
                ("ok", false->JSON.Encode.bool),
                ("error", "missing cvcNumber"->JSON.Encode.string),
              ])
            } else if pmSessionId === "" || vaultAuth === "" {
              postSpikeResult([
                ("kind", "vaultUpdate"->JSON.Encode.string),
                ("ok", false->JSON.Encode.bool),
                ("error", "no hyperswitch vault credentials decoded from sessions"->JSON.Encode.string),
              ])
            } else {
              PaymentHelpersV2.updatePaymentMethod(
                ~bodyArr=PaymentManagementBody.vaultUpdateCVVBody(~cvcNumber),
                ~pmSessionId,
                ~logger=loggerState,
                ~customPodUri,
                ~sdkAuthorization=vaultAuth,
              )
              ->Promise.then(response => {
                if response == JSON.Encode.null {
                  postSpikeResult([
                    ("kind", "vaultUpdate"->JSON.Encode.string),
                    ("ok", false->JSON.Encode.bool),
                    ("error", "vault update POST returned null (HTTP failure)"->JSON.Encode.string),
                  ])
                } else {
                  let d = VaultHelpers.decodeVaultTokenData(response)
                  postSpikeResult([
                    ("kind", "vaultUpdate"->JSON.Encode.string),
                    ("ok", (d.token !== "")->JSON.Encode.bool),
                    ("cvcToken", d.token->JSON.Encode.string),
                    ("brand", d.brand->JSON.Encode.string),
                    ("last4Digits", d.last4Digits->JSON.Encode.string),
                  ])
                }
                Promise.resolve()
              })
              ->Promise.catch(_ => {
                postSpikeResult([
                  ("kind", "vaultUpdate"->JSON.Encode.string),
                  ("ok", false->JSON.Encode.bool),
                  ("error", "vault update POST rejected"->JSON.Encode.string),
                ])
                Promise.resolve()
              })
              ->ignore
            }
          }
        | "synthesize3dsFullscreen" => {
            // The EXACT message shape `PaymentHelpers.intentCall` posts for a
            // three_ds_invoke next action.
            let metaData =
              [
                ("threeDSData", Dict.make()->JSON.Encode.object),
                ("paymentIntentId", keys.clientSecret->Option.getOr("")->JSON.Encode.string),
                ("publishableKey", keys.publishableKey->JSON.Encode.string),
                ("sdkAuthorization", keys.sdkAuthorization->Option.getOr("")->JSON.Encode.string),
                ("headers", Dict.make()->JSON.Encode.object),
                ("url", Window.hrefWithoutSearch->JSON.Encode.string),
                ("iframeId", keys.iframeId->JSON.Encode.string),
                ("3dsMethodComp", "U"->JSON.Encode.string),
              ]->Dict.fromArray
            messageParentWindow(
              [
                ("fullscreen", true->JSON.Encode.bool),
                ("param", "3dsAuth"->JSON.Encode.string),
                ("iframeId", keys.iframeId->JSON.Encode.string),
                ("metadata", metaData->JSON.Encode.object),
              ],
              ~targetOrigin=keys.parentURL,
            )
            postSpikeResult([
              ("kind", "synthesize3dsFullscreen"->JSON.Encode.string),
              ("ok", true->JSON.Encode.bool),
            ])
          }
        | "redirect" => {
            let target = dict->getString("url", "")
            postSpikeResult([
              ("kind", "redirect"->JSON.Encode.string),
              ("ok", (target !== "")->JSON.Encode.bool),
              ("url", target->JSON.Encode.string),
            ])
            if target !== "" {
              openUrl(target)
            }
          }
        | other =>
          postSpikeResult([
            ("kind", "unknown"->JSON.Encode.string),
            ("ok", false->JSON.Encode.bool),
            ("command", other->JSON.Encode.string),
          ])
        }
      }
    }
    handleMessage(handleCommand, "")
  }, (keys, sessions, paymentMethodListValue, registryVersion, groupId))

  // Readiness: the coordinator INTENTIONALLY emits NO window-plane `ready`
  // beacon — the field iframes arm Hyper.res:143-153's first-ready-wins
  // latch; a coordinator beacon would be an earlier, non-field readiness
  // source (and would falsify the docs).

  // Spike-state beacons gate on the harness iframe's spike=1 flag so a normal
  // merchant page can never observe coordinator internals.
  React.useEffect(() => {
    if spikeEnabled {
      switch paymentMethodListValue {
      | Loaded(_) =>
        postSpikeResult([("kind", "pmList"->JSON.Encode.string), ("state", "Loaded"->JSON.Encode.string)])
      | LoadError(_) =>
        postSpikeResult([
          ("kind", "pmList"->JSON.Encode.string),
          ("state", "LoadError"->JSON.Encode.string),
        ])
      | _ => ()
      }
    }
    None
  }, [paymentMethodListValue])

  React.useEffect(() => {
    if spikeEnabled {
      switch sessions {
      | Loaded(_) =>
        postSpikeResult([
          ("kind", "sessions"->JSON.Encode.string),
          ("state", "Loaded"->JSON.Encode.string),
        ])
      | _ => ()
      }
    }
    None
  }, [sessions])

  // 0×0 by contract — the iframe element itself is hidden by the mounter
  // (CoordinatorMount / spike page); the inner document renders nothing.
  React.null
}
