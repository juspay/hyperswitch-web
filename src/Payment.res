open CardUtils
open CardThemeType
open CardTheme
open LoggerUtils
open RecoilAtoms

let setUserError = message => {
  Utils.postFailedSubmitResponse(~errortype="validation_error", ~message)
}

@react.component
let make = (~paymentMode, ~integrateError, ~logger) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let cardScheme = Recoil.useRecoilValueFromAtom(cardBrand)
  let showFields = Recoil.useRecoilValueFromAtom(showCardFieldsAtom)
  let selectedOption = Recoil.useRecoilValueFromAtom(selectedOptionAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let paymentToken = Recoil.useRecoilValueFromAtom(paymentTokenAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let {iframeId} = keys

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

  let intent = PaymentHelpers.usePaymentIntent(Some(logger), Card)

  let cardRef = React.useRef(Nullable.null)
  let expiryRef = React.useRef(Nullable.null)
  let cvcRef = React.useRef(Nullable.null)
  let zipRef = React.useRef(Nullable.null)

  let (isCardValid, setIsCardValid) = React.useState(_ => None)
  let (isExpiryValid, setIsExpiryValid) = React.useState(_ => None)
  let (isCVCValid, setIsCVCValid) = React.useState(_ => None)
  let (isZipValid, setIsZipValid) = React.useState(_ => None)
  let (isCardSupported, setIsCardSupported) = React.useState(_ => None)

  let (cardBrand, maxCardLength) = React.useMemo(() => {
    let brand = getCardBrand(cardNumber)
    let maxLength = getMaxLength(cardNumber)
    let isNotBancontact = selectedOption !== "bancontact_card" && brand == ""
    !showFields && isNotBancontact ? (cardScheme, maxLength) : (brand, maxLength)
  }, (cardNumber, cardScheme, showFields))

  let supportedCardBrands = React.useMemo(() => {
    let cardPaymentMethod =
      paymentMethodListValue.payment_methods->Array.find(ele => ele.payment_method === "card")

    switch cardPaymentMethod {
    | Some(cardPaymentMethod) =>
      let cardNetworks = cardPaymentMethod.payment_method_types->Array.map(ele => ele.card_networks)
      let cardNetworkNames =
        cardNetworks->Array.map(ele =>
          ele->Array.map(
            val => val.card_network->CardUtils.getCardStringFromType->String.toLowerCase,
          )
        )
      Some(
        cardNetworkNames
        ->Array.reduce([], (acc, ele) => acc->Array.concat(ele))
        ->Utils.getUniqueArray,
      )
    | None => None
    }
  }, [paymentMethodListValue])

  let checkIsCardSupported = cardNumber => {
    let cardBrand = cardNumber->CardUtils.getCardBrand
    let clearValue = cardNumber->clearSpaces
    if cardValid(clearValue, cardBrand) {
      switch supportedCardBrands {
      | Some(brands) => Some(brands->Array.includes(cardBrand->String.toLowerCase))
      | None => Some(true)
      }
    } else {
      None
    }
  }

  React.useEffect(() => {
    setIsCardSupported(_ => checkIsCardSupported(cardNumber))
    None
  }, (supportedCardBrands, cardNumber))

  let cardType = React.useMemo1(() => {
    cardBrand->getCardType
  }, [cardBrand])

  React.useEffect(() => {
    let obj = getobjFromCardPattern(cardBrand)
    let cvcLength = obj.maxCVCLenth
    if (
      cvcNumberInRange(cvcNumber, cardBrand)->Array.includes(true) &&
        cvcNumber->String.length == cvcLength
    ) {
      blurRef(cvcRef)
    }
    None
  }, (cvcNumber, cardNumber))

  let changeCardNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    logInputChangeInfo("cardNumber", logger)
    let card = val->formatCardNumber(cardType)
    let clearValue = card->clearSpaces
    setCardValid(clearValue, setIsCardValid)
    if cardValid(clearValue, cardBrand) && checkIsCardSupported(clearValue)->Option.getOr(false) {
      handleInputFocus(~currentRef=cardRef, ~destinationRef=expiryRef)
    }
    if card->String.length > 6 && cardNumber->pincodeVisibility {
      setDisplayPincode(_ => true)
    } else if card->String.length < 8 {
      setDisplayPincode(_ => false)
    }
    setCardNumber(_ => card)
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
    if cardNumberInRange(cardNumber)->Array.includes(true) && calculateLuhn(cardNumber) {
      setIsCardValid(_ => checkIsCardSupported(cardNumber))
    } else if cardNumber->String.length == 0 {
      setIsCardValid(_ => None)
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

  let submitAPICall = (body, confirmParam) => {
    intent(
      ~bodyArr=body,
      ~confirmParam,
      ~handleUserError=false,
      ~manualRetry=isManualRetryEnabled,
      (),
    )
  }
  React.useEffect(() => {
    setCvcNumber(_ => "")
    setIsCVCValid(_ => None)
    setCvcError(_ => "")
    setCardError(_ => "")
    setExpiryError(_ => "")
    None
  }, (paymentToken.paymentToken, showFields))

  let submitValue = (_ev, confirmParam) => {
    let validFormat = switch paymentMode->getPaymentMode {
    | Card =>
      isCardValid->Option.getOr(false) &&
      isExpiryValid->Option.getOr(false) &&
      isCVCValid->Option.getOr(false)
    | CardNumberElement =>
      isCardValid->Option.getOr(false) &&
      checkCardCVC(getCardElementValue(iframeId, "card-cvc"), cardBrand) &&
      checkCardExpiry(getCardElementValue(iframeId, "card-expiry"))
    | _ => true
    }
    let cardNetwork = {
      if cardBrand != "" {
        [("card_network", cardNumber->CardUtils.getCardBrand->JSON.Encode.string)]
      } else {
        []
      }
    }
    if validFormat {
      let body = switch paymentMode->getPaymentMode {
      | Card =>
        let (month, year) = getExpiryDates(cardExpiry)

        PaymentBody.cardPaymentBody(
          ~cardNumber,
          ~month,
          ~year,
          ~cardHolderName="",
          ~cvcNumber,
          ~cardBrand=cardNetwork,
          (),
        )
      | CardNumberElement =>
        let (month, year) = getExpiryDates(getCardElementValue(iframeId, "card-expiry"))
        let localCvcNumber = getCardElementValue(iframeId, "card-cvc")
        PaymentBody.cardPaymentBody(
          ~cardNumber,
          ~month,
          ~year,
          ~cardHolderName="",
          ~cvcNumber=localCvcNumber,
          ~cardBrand=cardNetwork,
          (),
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

  let paymentType = React.useMemo1(() => {
    paymentMode->getPaymentMode
  }, [paymentMode])

  React.useEffect0(() => {
    let handleFun = (ev: Window.event) => {
      let json = try {
        ev.data->JSON.parseExn
      } catch {
      | _ => Dict.make()->JSON.Encode.object
      }
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("doBlur")->Option.isSome {
        logger.setLogInfo(~value="doBlur Triggered", ~eventName=BLUR, ())
        setBlurState(_ => true)
      } else if dict->Dict.get("doFocus")->Option.isSome {
        logger.setLogInfo(~value="doFocus Triggered", ~eventName=FOCUS, ())
        cardRef.current->Nullable.toOption->Option.forEach(input => input->focus)->ignore
      } else if dict->Dict.get("doClearValues")->Option.isSome {
        logger.setLogInfo(~value="doClearValues Triggered", ~eventName=CLEAR, ())
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
    Utils.handleMessage(handleFun, "Error in parsing sent Data")
  })

  React.useEffect(() => {
    let handleDoSubmit = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let jsonDict = json->Utils.getDictFromJson
      let confirm = jsonDict->ConfirmType.itemToObjMapper
      if confirm.doSubmit {
        submitValue(ev, confirm.confirmParams)
      }
    }
    Utils.handleMessage(handleDoSubmit, "")
  }, (cardNumber, cvcNumber, cardExpiry, isCVCValid, isExpiryValid, isCardValid))

  React.useEffect(() => {
    let cardError = if isCardSupported->Option.getOr(true) && isCardValid->Option.getOr(true) {
      ""
    } else if isCardSupported->Option.getOr(true) {
      localeString.inValidCardErrorText
    } else {
      localeString.cardBrandConfiguredErrorText(cardBrand)
    }
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

  let icon = React.useMemo(() => {
    let animate = cardType == NOTFOUND ? "animate-slideLeft" : "animate-slideRight"
    let cardBrandIcon = getCardBrandIcon(cardType, paymentType)
    <div className=animate> cardBrandIcon </div>
  }, (cardType, paymentType))

  let cardProps: CardUtils.cardProps = (
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
  )

  let expiryProps: CardUtils.expiryProps = (
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    onExpiryKeyDown,
    expiryError,
    setExpiryError,
  )

  let cvcProps: CardUtils.cvcProps = (
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
  )

  let zipProps: CardUtils.zipProps = (
    isZipValid,
    setIsZipValid,
    zipCode,
    changeZipCode,
    handleZipBlur,
    zipRef,
    onZipCodeKeyDown,
    displayPincode,
  )

  if integrateError {
    <ErrorOccured />
  } else {
    <RenderPaymentMethods
      paymentType cardProps expiryProps cvcProps zipProps handleElementFocus blurState isFocus
    />
  }
}
