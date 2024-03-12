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
  let cardScheme = Recoil.useRecoilValueFromAtom(RecoilAtoms.cardBrand)
  let showFields = Recoil.useRecoilValueFromAtom(RecoilAtoms.showCardFieldsAtom)
  let selectedOption = Recoil.useRecoilValueFromAtom(selectedOptionAtom)
  let paymentToken = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentTokenAtom)
  let (token, _) = paymentToken

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

  let cardRef = React.useRef(Js.Nullable.null)
  let expiryRef = React.useRef(Js.Nullable.null)
  let cvcRef = React.useRef(Js.Nullable.null)
  let zipRef = React.useRef(Js.Nullable.null)

  let (isCardValid, setIsCardValid) = React.useState(_ => None)
  let (isExpiryValid, setIsExpiryValid) = React.useState(_ => None)
  let (isCVCValid, setIsCVCValid) = React.useState(_ => None)
  let (isZipValid, setIsZipValid) = React.useState(_ => None)

  let (cardBrand, maxCardLength) = React.useMemo3(() => {
    let brand = getCardBrand(cardNumber)
    let maxLength = getMaxLength(cardNumber)
    let isNotBancontact = selectedOption !== "bancontact_card" && brand == ""
    ((brand == "" && !showFields) || !showFields) && isNotBancontact
      ? (cardScheme, maxLength)
      : (brand, maxLength)
  }, (cardNumber, cardScheme, showFields))

  let clientTimeZone = dateTimeFormat(.).resolvedOptions(.).timeZone
  let clientCountry = Utils.getClientCountry(clientTimeZone)

  let countryNames = Utils.getCountryNames(Country.country)
  let countryProps = (clientCountry.countryName, countryNames)

  let (postalCodes, setPostalCodes) = React.useState(_ => [PostalCodeType.defaultPostalCode])

  React.useEffect2(() => {
    let obj = getobjFromCardPattern(cardBrand)
    let cvcLength = obj.maxCVCLenth
    if (
      cvcNumberInRange(cvcNumber, cardBrand)->Js.Array2.includes(true) &&
        cvcNumber->Js.String2.length == cvcLength
    ) {
      blurRef(cvcRef)
    }
    None
  }, (cvcNumber, cardNumber))

  React.useEffect0(() => {
    open Promise
    if paymentMode->getPaymentMode == Card {
      PostalCodeType.importPostalCode("./PostalCodes.bs.js")
      ->then(res => {
        setPostalCodes(_ => res.default)
        resolve()
      })
      ->catch(_ => {
        setPostalCodes(_ => [PostalCodeType.defaultPostalCode])
        resolve()
      })
      ->ignore
    }
    None
  })

  let changeCardNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    logInputChangeInfo("cardNumber", logger)
    let card = val->formatCardNumber(cardBrand->cardType)
    let clearValue = card->clearSpaces
    setCardValid(clearValue, setIsCardValid)
    if cardValid(clearValue, cardBrand) {
      handleInputFocus(~currentRef=cardRef, ~destinationRef=expiryRef)
    }
    if card->Js.String2.length > 6 && cardNumber->pincodeVisibility {
      setDisplayPincode(_ => true)
    } else if card->Js.String2.length < 8 {
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
    if cvc->Js.String2.length > 0 && cvcNumberInRange(cvc, cardBrand)->Js.Array2.includes(true) {
      zipRef.current->Js.Nullable.toOption->Belt.Option.forEach(input => input->focus)->ignore
    }

    if cvc->Js.String2.length > 0 && cvcNumberInRange(cvc, cardBrand)->Js.Array2.includes(true) {
      setIsCVCValid(_ => Some(true))
    } else {
      setIsCVCValid(_ => None)
    }
  }

  let changeZipCode = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    logInputChangeInfo("zipCode", logger)
    let regex = postalRegex(postalCodes, ())
    if regex !== "" && Js.Re.test_(regex->Js.Re.fromString, val) {
      blurRef(zipRef)
    }
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
    if cardNumberInRange(cardNumber)->Js.Array2.includes(true) && calculateLuhn(cardNumber) {
      setIsCardValid(_ => Some(true))
    } else if cardNumber->Js.String2.length == 0 {
      setIsCardValid(_ => None)
    } else {
      setIsCardValid(_ => Some(false))
    }
  }

  let handleElementFocus = React.useMemo4(() => {
    isFocus => {
      setIsFocus(_ => isFocus)
    }
  }, (isCardValid, isCVCValid, isExpiryValid, isZipValid))

  let handleExpiryBlur = ev => {
    let cardExpiry = ReactEvent.Focus.target(ev)["value"]
    if cardExpiry->Js.String2.length > 0 && getExpiryValidity(cardExpiry) {
      setIsExpiryValid(_ => Some(true))
    } else if cardExpiry->Js.String2.length == 0 {
      setIsExpiryValid(_ => None)
    } else {
      setIsExpiryValid(_ => Some(false))
    }
  }

  let handleCVCBlur = ev => {
    let cvcNumber = ReactEvent.Focus.target(ev)["value"]
    if (
      cvcNumber->Js.String2.length > 0 &&
        cvcNumberInRange(cvcNumber, cardBrand)->Js.Array2.includes(true)
    ) {
      setIsCVCValid(_ => Some(true))
    } else if cvcNumber->Js.String2.length == 0 {
      setIsCVCValid(_ => None)
    } else {
      setIsCVCValid(_ => Some(false))
    }
  }

  let handleZipBlur = ev => {
    let zipCode = ReactEvent.Focus.target(ev)["value"]
    let regex = postalRegex(postalCodes, ())
    if Js.Re.test_(regex->Js.Re.fromString, zipCode) || regex == "" {
      setIsZipValid(_ => Some(true))
    } else if zipCode->Js.String2.length == 0 {
      setIsZipValid(_ => None)
    } else {
      setIsZipValid(_ => Some(false))
    }
  }

  let submitAPICall = (body, confirmParam) => {
    intent(~bodyArr=body, ~confirmParam, ~handleUserError=false, ())
  }
  React.useEffect2(() => {
    setCvcNumber(_ => "")
    setIsCVCValid(_ => None)
    setCvcError(_ => "")
    setCardError(_ => "")
    setExpiryError(_ => "")
    None
  }, (token, showFields))

  let submitValue = (_ev, confirmParam) => {
    let validFormat = switch paymentMode->getPaymentMode {
    | Card =>
      isCardValid->Belt.Option.getWithDefault(false) &&
      isExpiryValid->Belt.Option.getWithDefault(false) &&
      isCVCValid->Belt.Option.getWithDefault(false)
    | CardNumberElement =>
      isCardValid->Belt.Option.getWithDefault(false) &&
      checkCardCVC(getCardElementValue(iframeId, "card-cvc"), cardBrand) &&
      checkCardExpiry(getCardElementValue(iframeId, "card-expiry"))
    | _ => true
    }
    let cardNetwork = {
      if cardBrand != "" {
        [("card_network", cardNumber->CardUtils.getCardBrand->Js.Json.string)]
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

  let paymentType = paymentMode->getPaymentMode

  React.useEffect0(() => {
    let handleFun = (ev: Window.event) => {
      let json = try {
        ev.data->Js.Json.parseExn
      } catch {
      | _ => Js.Dict.empty()->Js.Json.object_
      }
      let dict = json->Utils.getDictFromJson
      if dict->Js.Dict.get("doBlur")->Belt.Option.isSome {
        logger.setLogInfo(~value="doBlur Triggered", ~eventName=BLUR, ())
        setBlurState(_ => true)
      } else if dict->Js.Dict.get("doFocus")->Belt.Option.isSome {
        logger.setLogInfo(~value="doFocus Triggered", ~eventName=FOCUS, ())
        cardRef.current->Js.Nullable.toOption->Belt.Option.forEach(input => input->focus)->ignore
      } else if dict->Js.Dict.get("doClearValues")->Belt.Option.isSome {
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

  React.useEffect6(() => {
    let handleDoSubmit = (ev: Window.event) => {
      let json = ev.data->Js.Json.parseExn
      let jsonDict = json->Utils.getDictFromJson
      let confirm = jsonDict->ConfirmType.itemToObjMapper
      if confirm.doSubmit {
        submitValue(ev, confirm.confirmParams)
      }
    }
    Utils.handleMessage(handleDoSubmit, "")
  }, (cardNumber, cvcNumber, cardExpiry, isCVCValid, isExpiryValid, isCardValid))

  let cardBrandIcon = getCardBrandIcon(cardBrand->cardType, paymentMode->getPaymentMode)

  React.useEffect1(() => {
    setCardError(_ =>
      switch isCardValid {
      | Some(val) => val ? "" : localeString.inValidCardErrorText
      | None => ""
      }
    )
    None
  }, [isCardValid])

  React.useEffect1(() => {
    setCvcError(_ =>
      switch isCVCValid {
      | Some(val) => val ? "" : localeString.inCompleteCVCErrorText
      | None => ""
      }
    )
    None
  }, [isCVCValid])

  React.useEffect2(() => {
    setExpiryError(_ =>
      switch (isExpiryValid, isExipryComplete(cardExpiry)) {
      | (Some(true), true) => ""
      | (Some(false), true) => localeString.pastExpiryErrorText
      | (Some(_), false) => localeString.inCompleteExpiryErrorText
      | (None, _) => ""
      }
    )
    None
  }, (isExpiryValid, isExipryComplete(cardExpiry)))

  let animate = cardBrand->cardType == NOTFOUND ? "animate-slideLeft" : "animate-slideRight"
  let icon = <div className=animate> cardBrandIcon </div>

  let cardProps: CardUtils.cardProps = (
    isCardValid,
    setIsCardValid,
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
      paymentType
      cardProps
      expiryProps
      cvcProps
      zipProps
      handleElementFocus
      blurState
      countryProps
      isFocus
    />
  }
}
