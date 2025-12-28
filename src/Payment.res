open CardUtils
open CardThemeType
open CardTheme
open RecoilAtoms
open PaymentTypeContext
open CommonCardProps

let setUserError = message => {
  Utils.postFailedSubmitResponse(~errortype="validation_error", ~message)
}

@react.component
let make = (~paymentMode, ~integrateError, ~logger) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let (isFocus, setIsFocus) = React.useState(_ => false)

  let intent = PaymentHelpers.usePaymentIntent(Some(logger), Card)
  let isGiftCardOnlyPayment = GiftCardHooks.useIsGiftCardOnlyPayment()

  let paymentType = React.useMemo1(() => {
    paymentMode->getPaymentMode
  }, [paymentMode])

  let {cardProps, expiryProps, cvcProps, zipProps, blurState} = useCardForm(~logger, ~paymentType)
  let {isCardValid, setCardError, cardNumber, cardBrand} = cardProps
  let {isExpiryValid, setExpiryError, cardExpiry} = expiryProps
  let {isCVCValid, setCvcError, cvcNumber} = cvcProps
  let {isZipValid} = zipProps

  let handleElementFocus = React.useMemo(() => {
    isFocus => {
      setIsFocus(_ => isFocus)
    }
  }, (isCardValid, isCVCValid, isExpiryValid, isZipValid))
  React.useEffect(() => {
    switch (isCardValid, isExpiryValid, isCVCValid) {
    | (Some(cardValid), Some(expiryValid), Some(cvcValid)) =>
      CardUtils.emitIsFormReadyForSubmission(
        cardValid && expiryValid && cvcValid && areRequiredFieldsValid,
      )
    | _ => ()
    }
    None
  }, (isCardValid, isExpiryValid, isCVCValid, areRequiredFieldsValid))
  let submitAPICall = (body, confirmParam) => {
    intent(~bodyArr=body, ~confirmParam, ~handleUserError=false, ~manualRetry=isManualRetryEnabled)
  }

  let blockedBinsList = Recoil.useRecoilValueFromAtom(RecoilAtoms.blockedBins)
  let submitValue = (_ev, confirmParam) => {
    // Check if card is blocked
    let isCardBlocked = CardUtils.checkIfCardBinIsBlocked(
      cardNumber->CardValidations.clearSpaces,
      blockedBinsList,
    )

    let validFormat = switch paymentMode->getPaymentMode {
    | Card =>
      isCardValid->Option.getOr(false) &&
      isExpiryValid->Option.getOr(false) &&
      isCVCValid->Option.getOr(false) &&
      !isCardBlocked
    | CardNumberElement =>
      isCardValid->Option.getOr(false) &&
      checkCardCVC(getCardElementValue(iframeId, "card-cvc"), cardBrand) &&
      checkCardExpiry(getCardElementValue(iframeId, "card-expiry")) &&
      !isCardBlocked
    | _ => true
    }
    let cardNetwork = [
      ("card_network", cardBrand != "" ? cardBrand->JSON.Encode.string : JSON.Encode.null),
    ]
    if validFormat {
      let body = switch paymentMode->getPaymentMode {
      | Card =>
        let (month, year) = getExpiryDates(cardExpiry)

        PaymentBody.cardPaymentBody(
          ~cardNumber,
          ~month,
          ~year,
          ~cardHolderName=None,
          ~cvcNumber,
          ~cardBrand=cardNetwork,
        )
      | CardNumberElement =>
        let (month, year) = getExpiryDates(getCardElementValue(iframeId, "card-expiry"))
        let localCvcNumber = getCardElementValue(iframeId, "card-cvc")
        PaymentBody.cardPaymentBody(
          ~cardNumber,
          ~month,
          ~year,
          ~cardHolderName=None,
          ~cvcNumber=localCvcNumber,
          ~cardBrand=cardNetwork,
        )
      | _ => []
      }

      switch paymentMode->getPaymentMode {
      | Card
      | CardNumberElement =>
        submitAPICall(body, confirmParam)
      | _ => ()
      }
    } else {
      if cardNumber === "" {
        setCardError(_ => localeString.cardNumberEmptyText)
        setUserError(localeString.enterFieldsText)
      } else if isCardBlocked {
        setCardError(_ => localeString.blockedCardText)
        setUserError(localeString.blockedCardText)
      }
      if cardExpiry === "" {
        setExpiryError(_ => localeString.cardExpiryDateEmptyText)
        setUserError(localeString.enterFieldsText)
      }
      if cvcNumber === "" {
        setCvcError(_ => localeString.cvcNumberEmptyText)
        setUserError(localeString.enterFieldsText)
      }
      if !validFormat {
        setUserError(localeString.enterValidDetailsText)
      }
    }
  }

  React.useEffect(() => {
    open Utils
    let handleDoSubmit = (ev: Window.event) => {
      let json = ev.data->safeParse
      let jsonDict = json->getDictFromJson
      let confirm = jsonDict->ConfirmType.itemToObjMapper
      if confirm.doSubmit && !isGiftCardOnlyPayment {
        submitValue(ev, confirm.confirmParams)
      }
    }
    handleMessage(handleDoSubmit, "")
  }, (cardNumber, cvcNumber, cardExpiry, isCVCValid, isExpiryValid, isCardValid))

  if integrateError {
    <ErrorOccured />
  } else {
    <PaymentTypeContext.provider value={paymentType: paymentType}>
      <RenderPaymentMethods
        paymentType cardProps expiryProps cvcProps zipProps handleElementFocus blurState isFocus
      />
    </PaymentTypeContext.provider>
  }
}
