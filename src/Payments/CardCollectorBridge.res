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
  /* focus-readiness is computed in the field's own iframe, where the timing decision belongs.
     Do NOT infer it group-side from `fieldStatus.complete`: that fires on isXxxValid plus
     non-empty, not max-length plus Luhn, so focus would advance too early. */
  ~focusReady=false,
  /* when non-empty, the FULL snapshot (raw SAD included) ALSO rides the field's MessageChannel
     port to the hidden coordinator, while the window plane gets the SPLIT payload with raw
     keys stripped. Empty means the window-only path; bundled collectors never pass it. */
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
      /* dual-plane emission: ONE encoder, one memo, TWO payloads — the window gets the SPLIT state
         (raw keys absent, never null), the coordinator port gets the full snapshot. The port post
         is fire-and-forget; the coordinator caches the latest snapshot per field. */
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
        /* A registered-key drop is an integration-drift signal in dev;
           never throw, never fall back to the window plane for raws. */
        Console.warn(`[CardCollectorBridge] dropped port frame for unregistered portKey "${portKey}"`)
      }
    } else {
      /* bundled collectors leave the raw opt-ins off so PAN and CVC stay inside the iframe;
         standalone per-field iframes enable them so the group can aggregate the confirm payload. */
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
      // emit-on-true; consumers default-absent to false, which keeps the latch simple.
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
