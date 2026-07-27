@react.component
let make = (
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
  ~isBancontact=false,
) => {
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {innerLayout} = config.appearance
  let {layout} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)

  let {
    isCardValid,
    setIsCardValid,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    icon,
    cardError,
    maxCardLength,
  } = cardProps
  let {
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    expiryError,
  } = expiryProps
  let {
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    cvcError,
  } = cvcProps

  let isCvcValidValue = CardUtils.getBoolOptionVal(isCVCValid)
  let (cardEmpty, cardComplete, cardInvalid) = CardUtils.useCardDetails(
    ~cvcNumber,
    ~isCVCValid,
    ~isCvcValidValue,
  )
  let compressedLayoutStyleForCvcError =
    innerLayout === Compressed && cvcError->String.length > 0 ? "!border-l-0" : ""

  <>
    <RenderIf condition={innerLayout === Compressed}>
      <div
        style={
          marginBottom: "5px",
          fontSize: themeObj.fontSizeLg,
          opacity: "0.6",
        }>
        {React.string(localeString.cardHeader)}
      </div>
    </RenderIf>
    <RenderIf condition={!isBancontact}>
      <PaymentInputField
        fieldName=localeString.cardNumberLabel
        isValid=isCardValid
        setIsValid=setIsCardValid
        value=cardNumber
        onChange=changeCardNumber
        onBlur=handleCardBlur
        rightIcon=icon
        errorString=cardError
        type_="tel"
        maxLength=maxCardLength
        inputRef=cardRef
        placeholder="1234 1234 1234 1234"
        className={innerLayout === Compressed && cardError->String.length > 0 ? "border-b-0" : ""}
        name=TestUtils.cardNoInputTestId
        autocomplete="cc-number"
      />
      <div
        className="flex flex-row w-full place-content-between"
        style={
          gridColumnGap: {innerLayout === Spaced ? themeObj.spacingGridRow : ""},
        }>
        <div className={innerLayout === Spaced ? "w-[47%]" : "w-[50%]"}>
          <PaymentInputField
            fieldName=localeString.validThruText
            isValid=isExpiryValid
            setIsValid=setIsExpiryValid
            value=cardExpiry
            onChange=changeCardExpiry
            onBlur=handleExpiryBlur
            errorString=expiryError
            type_="tel"
            maxLength=7
            inputRef=expiryRef
            placeholder=localeString.expiryPlaceholder
            name=TestUtils.expiryInputTestId
            autocomplete="cc-exp"
          />
        </div>
        <div className={innerLayout === Spaced ? "w-[47%]" : "w-[50%]"}>
          <PaymentInputField
            fieldName=localeString.cvcTextLabel
            isValid=isCVCValid
            setIsValid=setIsCVCValid
            value=cvcNumber
            onChange=changeCVCNumber
            onBlur=handleCVCBlur
            errorString=cvcError
            rightIcon={CardUtils.setRightIconForCvc(
              ~cardComplete,
              ~cardEmpty,
              ~cardInvalid,
              ~color=themeObj.colorIconCardCvcError,
              ~cvcIcon=layoutClass.cvcIcon,
            )}
            type_="tel"
            className={`tracking-widest w-full ${compressedLayoutStyleForCvcError}`}
            maxLength=4
            inputRef=cvcRef
            placeholder="123"
            name=TestUtils.cardCVVInputTestId
            autocomplete="cc-csc"
          />
        </div>
      </div>
      <RenderIf
        condition={innerLayout === Compressed &&
          (cardError->String.length > 0 ||
          cvcError->String.length > 0 ||
          expiryError->String.length > 0)}>
        <div
          className="Error pt-1"
          style={
            color: themeObj.colorDangerText,
            fontSize: themeObj.fontSizeSm,
            alignSelf: "start",
            textAlign: "left",
          }>
          {React.string("Invalid input")}
        </div>
      </RenderIf>
    </RenderIf>
  </>
}
