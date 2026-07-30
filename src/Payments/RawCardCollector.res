open Utils
@react.component
let make = (
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
  ~isBancontact=false,
) => {
  let {themeObj, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let {parentURL} = Jotai.useAtomValue(JotaiAtoms.keys)
  let setComplete = Jotai.useSetAtom(JotaiAtoms.fieldsComplete)
  let {
    isCardValid,
    isCardSupported,
    updateCardSupport,
    cardNumber,
    setCardError,
    updateCardEligibilityError,
    cardBrand,
  } = cardProps
  let {isExpiryValid, cardExpiry, setExpiryError} = expiryProps
  let {isCVCValid, cvcNumber, setCvcError} = cvcProps

  let isCardDetailsValid =
    isCVCValid->Option.getOr(false) &&
    isCardValid->Option.getOr(false) &&
    isCardSupported->Option.getOr(false) &&
    isExpiryValid->Option.getOr(false)
  let complete = isCardDetailsValid
  let empty = cardNumber === "" || cardExpiry === "" || cvcNumber === ""
  let _ = CardCollectorBridge.useEmitCardState(
    ~cardNumber,
    ~cardExpiry,
    ~cvcNumber,
    ~cardBrand,
    ~complete,
    ~empty,
    ~isCardValid,
    ~isExpiryValid,
    ~isCvcValid=isCVCValid,
    ~emitRawCardNumber=true,
  )

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  React.useEffect0(() => {
    let handleEligibilityMessage = (ev: Window.event) => {
      // ParentCardComponent uses Window.iframePostMessage, which serializes the
      // payload. Parse the string before decoding the eligibility state.
      let dict = ev.data->safeParse->getDictFromJson
      if ev.source === iframeParent && ev.origin === parentURL {
        if dict->Dict.get("cardEligibilityStateUpdate")->Option.isSome {
          let eligibilityState =
            dict->getJsonObjectFromDict("cardEligibilityStateUpdate")->getDictFromJson
          updateCardEligibilityError(
            eligibilityState->getBool("hasError", false)
              ? Some(eligibilityState->getString("error", ""))
              : None,
          )
        }
        if dict->Dict.get("cardSupportStateUpdate")->Option.isSome {
          let supportState = dict->getJsonObjectFromDict("cardSupportStateUpdate")->getDictFromJson
          let receivedSupport =
            supportState->getBool("hasStatus", false)
              ? Some(supportState->getBool("supported", true))
              : None
          updateCardSupport(receivedSupport)
        }
      }
    }
    Window.addEventListener("message", handleEligibilityMessage)
    Some(() => Window.removeEventListener("message", handleEligibilityMessage))
  })

  let reportCardFieldErrors = () => {
    CardCollectorBridge.reportValidationErrors(
      ~cardNumber,
      ~cardExpiry,
      ~cvcNumber,
      ~cardBrand,
      ~isCardSupported,
      ~isFormValid=isCardDetailsValid,
      ~setCardError,
      ~setExpiryError,
      ~setCvcError,
      ~localeString,
    )
  }

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let isOuterValid = json->getDictFromJson->getBool("isOuterValid", true)
    if confirm.doSubmit {
      if (isBancontact || isCardDetailsValid) && isOuterValid {
        let (month, year) = CardUtils.getExpiryDates(cardExpiry)
        let rawCardData =
          [
            ("cardNumber", cardNumber->JSON.Encode.string),
            ("month", month->JSON.Encode.string),
            ("year", year->JSON.Encode.string),
            ("cvcNumber", cvcNumber->JSON.Encode.string),
            ("cardBrand", cardBrand->JSON.Encode.string),
          ]->Dict.fromArray
        messageParentWindow(
          [
            ("rawCardEvent", true->JSON.Encode.bool),
            ("rawCardData", rawCardData->JSON.Encode.object),
          ],
          ~targetOrigin=parentURL,
        )
      } else if !isBancontact {
        reportCardFieldErrors()
      }
    }
  }, (cardNumber, cardExpiry, cvcNumber, cardBrand, isCardDetailsValid, isBancontact, localeString))
  useSubmitPaymentDataFromParent(submitCallback, ~parentOrigin=parentURL)

  <div>
    <div className="flex flex-col" style={gridGap: themeObj.spacingGridColumn}>
      <div className="flex flex-col w-full" style={gridGap: themeObj.spacingGridColumn}>
        <CardFields cardProps expiryProps cvcProps isBancontact />
      </div>
    </div>
  </div>
}
