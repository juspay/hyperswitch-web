let useCardProps = (~logger, ~supportedCardBrands, ~cardType) => {
  open LoggerUtils
  open CardUtils
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (cardNumber, setCardNumber) = React.useState(_ => "")
  let (cardExpiry, setCardExpiry) = React.useState(_ => "")
  let (cvcNumber, setCvcNumber) = React.useState(_ => "")
  let (zipCode, setZipCode) = React.useState(_ => "")

  let (cardError, setCardError) = React.useState(_ => "")
  let (cvcError, setCvcError) = React.useState(_ => "")
  let (expiryError, setExpiryError) = React.useState(_ => "")

  let (displayPincode, setDisplayPincode) = React.useState(_ => false)
  let (isFocus, setIsFocus) = React.useState(_ => false)
  let (blurState, setBlurState) = React.useState(_ => false)

  let cardRef = React.useRef(Nullable.null)
  let expiryRef = React.useRef(Nullable.null)
  let cvcRef = React.useRef(Nullable.null)
  let zipRef = React.useRef(Nullable.null)
  let prevCardBrandRef = React.useRef("")

  let (isCardValid, setIsCardValid) = React.useState(_ => None)
  let (isExpiryValid, setIsExpiryValid) = React.useState(_ => None)
  let (isCVCValid, setIsCVCValid) = React.useState(_ => None)
  let (isZipValid, setIsZipValid) = React.useState(_ => None)
  let (isCardSupported, setIsCardSupported) = React.useState(_ => None)
  let cardBrand = getCardBrand(cardNumber)
  let (cardBrand, setCardBrand) = React.useState(_ => cardBrand)

  React.useEffect(() => {
    setIsCardSupported(_ =>
      PaymentUtils.checkIsCardSupported(cardNumber, cardBrand, supportedCardBrands)
    )
    None
  }, (supportedCardBrands, cardNumber))

  React.useEffect(() => {
    let obj = getobjFromCardPattern(cardBrand)
    let cvcLength = obj.maxCVCLength
    if (
      cvcNumberInRange(cvcNumber, cardBrand)->Array.includes(true) &&
        cvcNumber->String.length == cvcLength
    ) {
      blurRef(cvcRef)
    }
    None
  }, (cvcNumber, cardNumber))

  React.useEffect(() => {
    if prevCardBrandRef.current !== "" {
      setCvcNumber(_ => "")
      setCardExpiry(_ => "")
      setIsExpiryValid(_ => None)
      setIsCVCValid(_ => None)
    }
    prevCardBrandRef.current = cardBrand
    None
  }, [cardBrand])

  React.useEffect(() => {
    let cardError = switch (
      isCardSupported->Option.getOr(true),
      isCardValid->Option.getOr(true),
      cardNumber->String.length == 0,
    ) {
    | (_, _, true) => ""
    | (true, true, _) => ""
    | (true, _, _) => localeString.inValidCardErrorText
    | (_, _, _) => CardUtils.getCardBrandInvalidError(~cardBrand, ~localeString)
    }
    let cardError = isCardValid->Option.isSome ? cardError : ""
    setCardError(_ => cardError)
    None
  }, [isCardValid, isCardSupported])

  React.useEffect(() => {
    setCvcError(_ => isCVCValid->Option.getOr(true) ? "" : localeString.inCompleteCVCErrorText)
    None
  }, [isCVCValid])

  React.useEffect(() => {
    setExpiryError(_ =>
      switch (isExpiryValid, isExpiryComplete(cardExpiry)) {
      | (Some(true), true) => ""
      | (Some(false), true) => localeString.pastExpiryErrorText
      | (Some(_), false) => localeString.inCompleteExpiryErrorText
      | (None, _) => ""
      }
    )
    None
  }, (isExpiryValid, isExpiryComplete(cardExpiry)))

  React.useEffect(() => {
    setCardBrand(_ => cardNumber->CardUtils.getCardBrand)
    None
  }, [cardNumber])

  let changeCardNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    logInputChangeInfo("cardNumber", logger)
    let card = val->formatCardNumber(cardType)
    let clearValue = card->clearSpaces
    setCardValid(clearValue, cardBrand, setIsCardValid)
    if (
      focusCardValid(clearValue, cardBrand) &&
      PaymentUtils.checkIsCardSupported(clearValue, cardBrand, supportedCardBrands)->Option.getOr(
        false,
      )
    ) {
      handleInputFocus(~currentRef=cardRef, ~destinationRef=expiryRef)
    }
    if card->String.length > 6 && cardNumber->pincodeVisibility {
      setDisplayPincode(_ => true)
    } else if card->String.length < 8 {
      setDisplayPincode(_ => false)
    }

    setCardNumber(_ => card)
    if card->String.length == 0 {
      setIsCardValid(_ => Some(false))
    }
  }

  let changeCardExpiry = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    logInputChangeInfo("cardExpiry", logger)
    let formattedExpiry = val->formatCardExpiryNumber
    if isExipryValid(formattedExpiry) {
      handleInputFocus(~currentRef=expiryRef, ~destinationRef=cvcRef)
    }
    setExpiryValid(formattedExpiry, setIsExpiryValid)
    setCardExpiry(_ => formattedExpiry)
  }

  let changeCVCNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    logInputChangeInfo("cardCVC", logger)
    let cvc = val->formatCVCNumber(cardBrand)
    setCvcNumber(_ => cvc)
    if cvc->String.length > 0 && cvcNumberInRange(cvc, cardBrand)->Array.includes(true) {
      zipRef.current->Nullable.toOption->Option.forEach(input => input->focus)->ignore
    }

    if cvc->String.length > 0 && cvcNumberInRange(cvc, cardBrand)->Array.includes(true) {
      setIsCVCValid(_ => Some(true))
    } else {
      setIsCVCValid(_ => None)
    }
  }

  let changeZipCode = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    logInputChangeInfo("zipCode", logger)
    setZipCode(_ => val)
  }

  let onZipCodeKeyDown = ev => {
    commonKeyDownEvent(ev, zipRef, cvcRef, zipCode, cvcNumber, setCvcNumber)
  }

  let onCvcKeyDown = ev => {
    commonKeyDownEvent(ev, cvcRef, expiryRef, cvcNumber, cardExpiry, setCardExpiry)
  }

  let onExpiryKeyDown = ev => {
    commonKeyDownEvent(ev, expiryRef, cardRef, cardExpiry, cardNumber, setCardNumber)
  }

  let handleCardBlur = ev => {
    let cardNumber = ReactEvent.Focus.target(ev)["value"]
    if cardNumberInRange(cardNumber, cardBrand)->Array.includes(true) && calculateLuhn(cardNumber) {
      setIsCardValid(_ =>
        PaymentUtils.checkIsCardSupported(cardNumber, cardBrand, supportedCardBrands)
      )
    } else if cardNumber->String.length == 0 {
      setIsCardValid(_ => Some(false))
    } else {
      setIsCardValid(_ => Some(false))
    }
  }

  let handleElementFocus = React.useMemo(() => {
    isFocus => {
      setIsFocus(_ => isFocus)
    }
  }, (isCardValid, isCVCValid, isExpiryValid, isZipValid))

  let handleExpiryBlur = ev => {
    let cardExpiry = ReactEvent.Focus.target(ev)["value"]
    if cardExpiry->String.length > 0 && getExpiryValidity(cardExpiry) {
      setIsExpiryValid(_ => Some(true))
    } else if cardExpiry->String.length == 0 {
      setIsExpiryValid(_ => None)
    } else {
      setIsExpiryValid(_ => Some(false))
    }
  }

  let handleCVCBlur = ev => {
    let cvcNumber = ReactEvent.Focus.target(ev)["value"]
    if (
      cvcNumber->String.length > 0 && cvcNumberInRange(cvcNumber, cardBrand)->Array.includes(true)
    ) {
      setIsCVCValid(_ => Some(true))
    } else if cvcNumber->String.length == 0 {
      setIsCVCValid(_ => None)
    } else {
      setIsCVCValid(_ => Some(false))
    }
  }

  let handleZipBlur = ev => {
    let zipCode = ReactEvent.Focus.target(ev)["value"]
    if zipCode === "" {
      setIsZipValid(_ => Some(false))
    } else {
      setIsZipValid(_ => Some(true))
    }
  }
  let paymentType = CardThemeType.PaymentMethodsManagement

  let maxCardLength = React.useMemo(() => {
    getMaxLength(cardNumber)
  }, (cardNumber, cardBrand))
  let icon = React.useMemo(() => {
    <CardSchemeComponent cardNumber paymentType cardBrand setCardBrand />
  }, (cardType, paymentType, cardBrand, cardNumber))
  let cardProps: CardUtils.cardProps = {
    isCardValid,
    setIsCardValid,
    isCardSupported,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    icon,
    cardError,
    setCardError,
    maxCardLength,
    cardBrand,
  }

  let expiryProps: CardUtils.expiryProps = {
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    onExpiryKeyDown,
    expiryError,
    setExpiryError,
  }

  let cvcProps: CardUtils.cvcProps = {
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    setCvcNumber,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    onCvcKeyDown,
    cvcError,
    setCvcError,
  }

  let zipProps: CardUtils.zipProps = {
    isZipValid,
    setIsZipValid,
    zipCode,
    changeZipCode,
    handleZipBlur,
    zipRef,
    onZipCodeKeyDown,
    displayPincode,
  }

  (cardProps, expiryProps, cvcProps, zipProps)
}
