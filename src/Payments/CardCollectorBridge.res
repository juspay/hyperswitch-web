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
) => {
  let {parentURL} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
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
    let stateEntries = [
      ("cardBrand", cardBrand->JSON.Encode.string),
      ("fieldStatus", fieldStatus->JSON.Encode.object),
      ("cardInfo", cardInfo->PaymentEventData.cardInfoToJson),
    ]
    let stateEntries = emitRawCardNumber
      ? stateEntries->Array.concat([("rawCardNumber", cardNumber->JSON.Encode.string)])
      : stateEntries
    messageParentWindow(
      [("cardStateUpdate", stateEntries->Dict.fromArray->JSON.Encode.object)],
      ~targetOrigin=parentURL,
    )
    None
  }, (
    cardInfo,
    cardBrand,
    cardNumber,
    complete,
    empty,
    cvcNumber,
    isCardValid,
    isExpiryValid,
    isCvcValid,
    emitRawCardNumber,
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
