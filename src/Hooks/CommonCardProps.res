open CardUtils
open CardThemeType
open LoggerUtils
open RecoilAtoms

let useCardForm = (~logger, ~paymentType) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let cardScheme = Recoil.useRecoilValueFromAtom(cardBrand)
  let showPaymentMethodsScreen = Recoil.useRecoilValueFromAtom(showPaymentMethodsScreen)
  let selectedOption = Recoil.useRecoilValueFromAtom(selectedOptionAtom)
  let blockedBinsList = Recoil.useRecoilValueFromAtom(blockedBins)
  let paymentToken = Recoil.useRecoilValueFromAtom(paymentTokenAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let paymentMethodListValueV2 = Recoil.useRecoilValueFromAtom(
    RecoilAtomsV2.paymentMethodListValueV2,
  )
  let (cardNumber, setCardNumber) = React.useState(_ => "")
  let (cardExpiry, setCardExpiry) = React.useState(_ => "")
  let (cvcNumber, setCvcNumber) = React.useState(_ => "")
  let (zipCode, setZipCode) = React.useState(_ => "")
  let (cardError, setCardError) = React.useState(_ => "")
  let (cvcError, setCvcError) = React.useState(_ => "")
  let (expiryError, setExpiryError) = React.useState(_ => "")

  let (displayPincode, setDisplayPincode) = React.useState(_ => false)
  let (blurState, setBlurState) = React.useState(_ => false)

  let cardRef = React.useRef(Nullable.null)
  let expiryRef = React.useRef(Nullable.null)
  let cvcRef = React.useRef(Nullable.null)
  let zipRef = React.useRef(Nullable.null)
  let isCoBadgedCardDetectedOnce = React.useRef(false)
  let prevCardBrandRef = React.useRef("")

  let (isCardValid, setIsCardValid) = React.useState(_ => None)
  let (isExpiryValid, setIsExpiryValid) = React.useState(_ => None)
  let (isCVCValid, setIsCVCValid) = React.useState(_ => None)
  let (isZipValid, setIsZipValid) = React.useState(_ => None)
  let (isCardSupported, setIsCardSupported) = React.useState(_ => None)

  let cardBrand = getCardBrand(cardNumber)
  let isNotBancontact = selectedOption !== "bancontact_card" && cardBrand == ""
  let (cardBrand, setCardBrand) = React.useState(_ =>
    !showPaymentMethodsScreen && isNotBancontact ? cardScheme : cardBrand
  )

  let cardBrand = CardUtils.getCardBrandFromStates(cardBrand, cardScheme, showPaymentMethodsScreen)
  let supportedCardBrands = React.useMemo(() => {
    switch (paymentType, GlobalVars.sdkVersion) {
    | (Payment, V2) => paymentMethodListValueV2->PaymentUtilsV2.getSupportedCardBrandsV2
    | _ => paymentMethodListValue->PaymentUtils.getSupportedCardBrands
    }
  }, (paymentMethodListValue, paymentMethodListValueV2))

  let maxCardLength = React.useMemo(() => {
    getMaxLength(cardBrand)
  }, (cardNumber, cardScheme, cardBrand, showPaymentMethodsScreen))

  React.useEffect(() => {
    setIsCardSupported(_ =>
      PaymentUtils.checkIsCardSupported(cardNumber, cardBrand, supportedCardBrands)
    )
    None
  }, (supportedCardBrands, cardNumber, cardBrand))

  let cardType = React.useMemo1(() => {
    cardBrand->getCardType
  }, [cardBrand])

  React.useEffect(() => {
    let obj = CardValidations.getobjFromCardPattern(cardBrand)
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
    setCvcNumber(_ => "")
    setCardExpiry(_ => "")
    setIsExpiryValid(_ => None)
    setIsCVCValid(_ => None)
    None
  }, [showPaymentMethodsScreen])

  React.useEffect(() => {
    if !isCoBadgedCardDetectedOnce.current {
      setCvcNumber(_ => "")
      setCardExpiry(_ => "")
      setIsExpiryValid(_ => None)
      setIsCVCValid(_ => None)
    }
    prevCardBrandRef.current = cardBrand
    None
  }, [cardBrand])

  React.useEffect(() => {
    setCvcNumber(_ => "")
    setIsCVCValid(_ => None)
    setCvcError(_ => "")
    setCardError(_ => "")
    setExpiryError(_ => "")
    None
  }, (paymentToken.paymentToken, showPaymentMethodsScreen))

  let changeCardNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    logInputChangeInfo("cardNumber", logger)
    let card = val->formatCardNumber(cardType)
    let clearValue = card->CardValidations.clearSpaces

    // Check if card BIN is blocked
    let isCardBlocked = CardUtils.checkIfCardBinIsBlocked(clearValue, blockedBinsList)
    if isCardBlocked {
      setCardError(_ => localeString.blockedCardText)
      setIsCardValid(_ => Some(false))
    } else {
      setCardValid(clearValue, cardBrand, setIsCardValid)
    }

    if (
      focusCardValid(clearValue, cardBrand) &&
      PaymentUtils.checkIsCardSupported(clearValue, cardBrand, supportedCardBrands)->Option.getOr(
        false,
      ) &&
      !isCardBlocked
    ) {
      handleInputFocus(~currentRef=cardRef, ~destinationRef=expiryRef)
    }
    if card->String.length > 6 && cardBrand->pincodeVisibility {
      setDisplayPincode(_ => true)
    } else if card->String.length < 8 {
      setDisplayPincode(_ => false)
    }
    setCardNumber(_ => card)
    if card->String.length == 0 && prevCardBrandRef.current !== "" {
      setCvcNumber(_ => "")
      setCardExpiry(_ => "")
      setIsExpiryValid(_ => None)
      setIsCVCValid(_ => None)
      setIsCardValid(_ => Some(false))
    }
  }

  let changeCardExpiry = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    logInputChangeInfo("cardExpiry", logger)
    let formattedExpiry = val->CardValidations.formatCardExpiryNumber
    if isExipryValid(formattedExpiry) {
      handleInputFocus(~currentRef=expiryRef, ~destinationRef=cvcRef)
      emitExpiryDate(formattedExpiry)
    }
    setExpiryValid(formattedExpiry, setIsExpiryValid)
    setCardExpiry(_ => formattedExpiry)
  }

  let changeCVCNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    logInputChangeInfo("cardCVC", logger)
    let cvc = val->CardValidations.formatCVCNumber(cardBrand)
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
  React.useEffect0(() => {
    open Utils
    let handleFun = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("doBlur")->Option.isSome {
        logger.setLogInfo(~value="doBlur Triggered", ~eventName=BLUR)
        setBlurState(_ => true)
      } else if dict->Dict.get("doFocus")->Option.isSome {
        logger.setLogInfo(~value="doFocus Triggered", ~eventName=FOCUS)
        cardRef.current->Nullable.toOption->Option.forEach(input => input->focus)->ignore
      } else if dict->Dict.get("doClearValues")->Option.isSome {
        logger.setLogInfo(~value="doClearValues Triggered", ~eventName=CLEAR)
        //clear all values
        setCardNumber(_ => "")
        setCardExpiry(_ => "")
        setCvcNumber(_ => "")
        setIsCardValid(_ => None)
        setCardError(_ => "")
        setCvcError(_ => "")
        setExpiryError(_ => "")
        setIsExpiryValid(_ => None)
        setIsCVCValid(_ => None)
      }
    }
    handleMessage(handleFun, "Error in parsing sent Data")
  })

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

  React.useEffect(() => {
    // Check if card is blocked first
    let isCardBlocked = CardUtils.checkIfCardBinIsBlocked(
      cardNumber->CardValidations.clearSpaces,
      blockedBinsList,
    )

    let cardError = switch (
      isCardSupported->Option.getOr(true),
      isCardValid->Option.getOr(true),
      cardNumber->String.length == 0,
      isCardBlocked,
    ) {
    | (_, _, _, true) => localeString.blockedCardText
    | (_, _, true, _) => ""
    | (true, true, _, _) => ""
    | (true, _, _, _) => localeString.inValidCardErrorText
    | _ => CardUtils.getCardBrandInvalidError(~cardBrand, ~localeString)
    }
    let cardError = isCardValid->Option.isSome ? cardError : ""
    setCardError(_ => cardError)
    None
  }, (isCardValid, isCardSupported, cardNumber, blockedBinsList))

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
    let validCardBrand = getFirstValidCardSchemeFromPML(
      ~cardNumber,
      ~enabledCardSchemes=supportedCardBrands->Option.getOr([]),
    )
    let newCardBrand = switch validCardBrand {
    | Some(brand) => brand
    | None => cardNumber->CardUtils.getCardBrand
    }
    setCardBrand(_ => newCardBrand)
    None
  }, [cardNumber])

  let icon = React.useMemo(() => {
    <CardSchemeComponent cardNumber paymentType cardBrand setCardBrand isCoBadgedCardDetectedOnce />
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

  {cardProps, expiryProps, cvcProps, zipProps, blurState}
}
