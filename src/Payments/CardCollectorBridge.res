open Utils

// Internal bridge shared by native raw-card and Hyperswitch-vault collectors.
// A field change is sent as one coherent snapshot so the outer host never
// renders a new validity flag with stale BIN/last4/expiry information.
let useEmitCardState = (
  ~cardNumber,
  ~cardExpiry,
  ~cvcNumber,
  ~cardBrand,
  ~complete,
  ~empty,
  ~isCardValid,
  ~isExpiryValid,
  ~isCvcValid,
  ~emitRawCardNumber=false,
  ~emitRawCardExpiry=false,
  ~emitRawCvc=false,
  // Keystroke-level focus-readiness, computed in the field's own iframe where
  // the timing decision belongs (brand-aware max length + Luhn for cardNumber
  // via CardUtils.focusCardValid; all-4-digits + validity for expiry;
  // maxCVCLength + validity for CVC). Emit-on-true keeps the envelope slim —
  // consumers default-absent to false. Do NOT infer this group-side from
  // `fieldStatus.complete`: that fires on isXxxValid+non-empty, not
  // max-length+Luhn, so it advances focus too early.
  ~focusReady=false,
  // MessageChannel Card Relay: when non-empty, the FULL snapshot
  // (incl. raw SAD) ALSO rides the field's MessageChannel port to the hidden
  // coordinator, while the window plane gets the SPLIT payload (raw keys
  // stripped). Empty string = the window-only path. Bundled
  // collectors never pass this — their shapes stay unchanged.
  ~portKey="",
) => {
  let {parentURL} = Jotai.useAtomValue(JotaiAtoms.keys)
  let cardInfo = React.useMemo(() => {
    PaymentEventData.buildCardInfo(
      ~cardNumber,
      ~expiry=cardExpiry,
      ~cvc=cvcNumber,
      ~brand=cardBrand,
    )
  }, (cardNumber, cardExpiry, cvcNumber, cardBrand))

  React.useEffect(() => {
    let fieldStatus =
      [
        ("complete", complete->JSON.Encode.bool),
        ("empty", empty->JSON.Encode.bool),
        ("isCvcEmpty", (cvcNumber === "")->JSON.Encode.bool),
        ("isCvcComplete", cardInfo.isCvcComplete->JSON.Encode.bool),
        ("isCardValid", isCardValid->Option.getOr(false)->JSON.Encode.bool),
        ("isExpiryValid", isExpiryValid->Option.getOr(false)->JSON.Encode.bool),
        ("isCvcValid", isCvcValid->Option.getOr(false)->JSON.Encode.bool),
        ("hasCardValidationStatus", isCardValid->Option.isSome->JSON.Encode.bool),
        ("hasExpiryValidationStatus", isExpiryValid->Option.isSome->JSON.Encode.bool),
        ("hasCvcValidationStatus", isCvcValid->Option.isSome->JSON.Encode.bool),
      ]->Dict.fromArray
    if portKey !== "" {
      // ── Dual-plane emission (MessageChannel Card Relay) ──────────────────
      // ONE encoder, one React memo, TWO payloads: window gets the SPLIT
      // state (raw keys stripped entirely — absent, never null), the
      // coordinator port gets the full snapshot (raws included, opt-in via
      // the same emit flags so bundled-collector semantics map 1:1 onto
      // relayed state). The port post is fire-and-forget: the coordinator
      // caches the latest snapshot per field — no ACK round-trip.
      let {windowPayload, portPayload} = CardFormPortProtocol.encodeFieldStateUpdate({
        cardBrand,
        fieldStatus: fieldStatus->JSON.Encode.object,
        cardInfo: cardInfo->PaymentEventData.cardInfoToJson,
        focusReady,
        rawCardNumber: emitRawCardNumber && cardNumber !== "" ? Some(cardNumber) : None,
        rawCardExpiry: emitRawCardExpiry && cardExpiry !== "" ? Some(cardExpiry) : None,
        rawCvc: emitRawCvc && cvcNumber !== "" ? Some(cvcNumber) : None,
      })
      messageParentWindow([("cardStateUpdate", windowPayload)], ~targetOrigin=parentURL)
      if !SadPortRegistry.postFrame(~key=portKey, portPayload) {
        // A registered-key drop is an integration-drift signal in dev;
        // never throw, never fall back to the window plane for raws.
        Console.warn(`[CardCollectorBridge] dropped port frame for unregistered portKey "${portKey}"`)
      }
    } else {
      // ── Single-plane emission (bundled collectors: window only) ────────────
      // Card-number / expiry / CVC raw values are opt-in: standalone per-field
      // vault iframes enable all three so the outer group can cache them and
      // inject them back into the cardNumber iframe's confirm payload. Bundled
      // collectors leave them off so PAN/CVC stay inside the same iframe.
      let stateEntries = [
        ("cardBrand", cardBrand->JSON.Encode.string),
        ("fieldStatus", fieldStatus->JSON.Encode.object),
        ("cardInfo", cardInfo->PaymentEventData.cardInfoToJson),
      ]
      let stateEntries = emitRawCardNumber
        ? stateEntries->Array.concat([("rawCardNumber", cardNumber->JSON.Encode.string)])
        : stateEntries
      let stateEntries = emitRawCardExpiry
        ? stateEntries->Array.concat([("rawCardExpiry", cardExpiry->JSON.Encode.string)])
        : stateEntries
      let stateEntries = emitRawCvc
        ? stateEntries->Array.concat([("rawCvc", cvcNumber->JSON.Encode.string)])
        : stateEntries
      // Emit-on-true: only include the key when the iframe believes focus
      // should move NOW. Group-side default-absent → false keeps the latch
      // semantics simple (transitions to true are the only ones that matter).
      let stateEntries = focusReady
        ? stateEntries->Array.concat([("focusReady", true->JSON.Encode.bool)])
        : stateEntries
      messageParentWindow(
        [("cardStateUpdate", stateEntries->Dict.fromArray->JSON.Encode.object)],
        ~targetOrigin=parentURL,
      )
    }
    None
  }, (
    cardInfo,
    cardBrand,
    cardNumber,
    cardExpiry,
    complete,
    empty,
    cvcNumber,
    isCardValid,
    isExpiryValid,
    isCvcValid,
    emitRawCardNumber,
    emitRawCardExpiry,
    emitRawCvc,
    focusReady,
    portKey,
  ))

  cardInfo
}

let reportValidationErrors = (
  ~cardNumber,
  ~cardExpiry,
  ~cvcNumber,
  ~cardBrand,
  ~isCardSupported,
  ~isFormValid,
  ~setCardError,
  ~setExpiryError,
  ~setCvcError,
  ~localeString: LocaleStringTypes.localeStrings,
) => {
  let reportUserError = message => postFailedSubmitResponse(~errortype="validation_error", ~message)

  if cardNumber === "" {
    setCardError(_ => localeString.cardNumberEmptyText)
    reportUserError(localeString.enterFieldsText)
  } else if isCardSupported->Option.getOr(true)->not {
    if cardBrand === "" {
      setCardError(_ => localeString.enterValidCardNumberErrorText)
      reportUserError(localeString.enterValidDetailsText)
    } else {
      let brandError = localeString.cardBrandConfiguredErrorText(cardBrand)
      setCardError(_ => brandError)
      reportUserError(brandError)
    }
  }
  if cardExpiry === "" {
    setExpiryError(_ => localeString.cardExpiryDateEmptyText)
    reportUserError(localeString.enterFieldsText)
  }
  if cvcNumber === "" {
    setCvcError(_ => localeString.cvcNumberEmptyText)
    reportUserError(localeString.enterFieldsText)
  }
  if !isFormValid {
    reportUserError(localeString.enterValidDetailsText)
  }
}
