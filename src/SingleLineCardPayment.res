open RecoilAtoms
open CardUtils
@react.component
let make = (
  ~paymentType: CardThemeType.mode,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
  ~zipProps: CardUtils.zipProps,
  ~handleElementFocus,
  ~isFocus,
) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(elementOptions)
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  let {
    isCardValid,
    setIsCardValid,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    icon,
    maxCardLength,
  } = cardProps

  let {
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    onExpiryKeyDown,
  } = expiryProps

  let {
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    onCvcKeyDown,
  } = cvcProps

  let {
    isZipValid,
    setIsZipValid,
    zipCode,
    changeZipCode,
    handleZipBlur,
    zipRef,
    onZipCodeKeyDown,
    displayPincode,
  } = zipProps

  let isCardValidValue = getBoolOptionVal(isCardValid)
  let isExpiryValidValue = getBoolOptionVal(isExpiryValid)
  let isCVCValidValue = getBoolOptionVal(isCVCValid)
  let isZipValidValue = getBoolOptionVal(isZipValid)
  let (showPincode, pincodeClass) = React.useMemo(
    () => displayPincode ? ("block", "animate-slideLeft") : ("none", "animate-slideRight "),
    [displayPincode],
  )
  let checkLengthIsZero = item => String.length(item) == 0
  let checkValueIsValid = item => item == "valid"
  let checkValueIsInvalid = item => item == "invalid"

  let (cardEmpty, cardComplete, cardInvalid, cardFocused) = React.useMemo(() => {
    let isCardDetailsEmpty = Array.every(
      [cardNumber, cardExpiry, cvcNumber, zipCode],
      checkLengthIsZero,
    )
      ? `${options.classes.base} ${options.classes.empty} `
      : options.classes.base

    let isCardDetailsValid = Array.every(
      [isCardValidValue, isExpiryValidValue, isCVCValidValue, isZipValidValue],
      checkValueIsValid,
    )
      ? ` ${options.classes.complete} `
      : ``

    let isCardDetailsInvalid = Array.some(
      [isCardValidValue, isExpiryValidValue, isCVCValidValue, isZipValidValue],
      checkValueIsInvalid,
    )
      ? ` ${options.classes.invalid} `
      : ``

    let isCardDetailsFocused = isFocus ? ` ${options.classes.focus} ` : ``

    (isCardDetailsEmpty, isCardDetailsValid, isCardDetailsInvalid, isCardDetailsFocused)
  }, (cardProps, expiryProps, cvcProps, zipProps))

  let concatString = Array.join([cardEmpty, cardComplete, cardInvalid, cardFocused], "")

  React.useEffect(() => {
    Utils.messageParentWindow([
      ("id", iframeId->JSON.Encode.string),
      ("concatedString", concatString->JSON.Encode.string),
    ])
    None
  }, [concatString])

  <div disabled=options.disabled className="flex flex-col">
    <div className="flex flex-row m-auto w-full justify-between items-center">
      {<div className="flex flex-row w-full items-center">
        <RenderIf condition={!options.hideIcon}>
          <div className="w-[12%] relative flex items-center"> {icon} </div>
        </RenderIf>
        <div className="w-10/12">
          <InputField
            isValid=isCardValid
            setIsValid=setIsCardValid
            value=cardNumber
            onChange=changeCardNumber
            onBlur=handleCardBlur
            onFocus=handleElementFocus
            type_="tel"
            maxLength=maxCardLength
            inputRef=cardRef
            placeholder="1234 1234 1234 1234"
            isFocus
            autocomplete="cc-number"
            id="card-number-input"
            ariaPlaceholder=""
          />
        </div>
      </div>}
      {<div className="flex flex-row justify-end w-5/12">
        <div className="w-2/5">
          <InputField
            onKeyDown=onExpiryKeyDown
            isValid=isExpiryValid
            setIsValid=setIsExpiryValid
            value=cardExpiry
            onChange=changeCardExpiry
            onBlur=handleExpiryBlur
            onFocus=handleElementFocus
            type_="tel"
            paymentType
            maxLength=7
            inputRef=expiryRef
            placeholder=localeString.expiryPlaceholder
            isFocus
            autocomplete="cc-exp"
            id="card-expiry-input"
          />
        </div>
        <div className="w-1/5">
          <InputField
            onKeyDown=onCvcKeyDown
            isValid=isCVCValid
            setIsValid=setIsCVCValid
            value=cvcNumber
            onChange=changeCVCNumber
            onBlur=handleCVCBlur
            onFocus=handleElementFocus
            paymentType
            type_="tel"
            className={`tracking-widest w-auto`}
            maxLength=4
            inputRef=cvcRef
            placeholder="123"
            isFocus
            autocomplete="cc-csc"
            id="card-cvc-input"
            ariaPlaceholder=""
          />
        </div>
        <RenderIf condition={!options.hidePostalCode}>
          <div className={`w-2/5 ${pincodeClass} slowShow`} style={display: showPincode}>
            <InputField
              onKeyDown=onZipCodeKeyDown
              isValid=isZipValid
              setIsValid=setIsZipValid
              value=zipCode
              onChange=changeZipCode
              onBlur=handleZipBlur
              onFocus=handleElementFocus
              paymentType
              type_="tel"
              inputRef=zipRef
              placeholder="ZIP"
              isFocus
              id="zip-code-input"
              isRequired=false
              autocomplete="postal-code"
            />
          </div>
        </RenderIf>
      </div>}
    </div>
  </div>
}

let default = make
