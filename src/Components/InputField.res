open RecoilAtoms
open PaymentTypeContext

@react.component
let make = (
  ~isValid,
  ~id="",
  ~setIsValid,
  ~value,
  ~onChange,
  ~onBlur,
  ~onKeyDown=?,
  ~onFocus=?,
  ~rightIcon=React.null,
  ~errorString=?,
  ~errorStringClasses=?,
  ~fieldName="",
  ~type_="text",
  ~maxLength=?,
  ~pattern=?,
  ~placeholder="",
  ~className="",
  ~inputRef,
  ~isFocus,
  ~labelClassName="",
  ~paymentType: option<CardThemeType.mode>=?,
  ~autocomplete="on",
) => {
  open ElementType
  let {themeObj, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {innerLayout} = config.appearance
  let {readOnly} = Recoil.useRecoilValueFromAtom(optionAtom)
  let {iframeId, parentURL} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(elementOptions)
  let contextPaymentType = usePaymentType()
  let paymentType = paymentType->Option.getOr(contextPaymentType)

  let setFocus = (val: bool) => {
    switch onFocus {
    | Some(fn) => fn(val)
    | None => ()
    }
  }

  let backgroundClass = switch paymentType {
  | Card
  | CardCVCElement
  | CardExpiryElement
  | CardNumberElement
  | PaymentMethodCollectElement
  | Payment
  | PaymentMethodsManagement =>
    themeObj.colorBackground
  | _ => "transparent"
  }

  let getClassName = initialLabel => {
    if value->String.length == 0 {
      `${initialLabel}--empty`
    } else {
      switch isValid {
      | Some(valid) => valid ? `${initialLabel}--valid` : `${initialLabel}--invalid`
      | None => ""
      }
    }
  }
  let labelClass = getClassName("Label")
  let inputClass = getClassName("Input")
  let inputLogoClass = getClassName("InputLogo")
  let inputClassStyles = innerLayout === Spaced ? "Input" : "Input-Compressed"

  let focusClass = if isFocus || value->String.length > 0 {
    `mb-7 pb-1 pt-2 ${themeObj.fontSizeXs} transition-all ease-in duration-75`
  } else {
    "transition-all ease-in duration-75"
  }
  let floatinglabelClass = isFocus ? "Label--floating" : "Label--resting"

  let handleFocus = _ => {
    setFocus(true)
    setIsValid(_ => None)
    Utils.handleOnFocusPostMessage(~targetOrigin=parentURL)
  }

  let handleBlur = ev => {
    setFocus(false)
    onBlur(ev)
    Utils.handleOnBlurPostMessage(~targetOrigin=parentURL)
  }

  let direction = if type_ == "password" || type_ == "tel" {
    "ltr"
  } else {
    ""
  }

  let isValidValue = CardUtils.getBoolOptionVal(isValid)

  let (cardEmpty, cardComplete, cardInvalid, cardFocused) = React.useMemo(() => {
    let isCardDetailsEmpty =
      String.length(value) == 0
        ? `${options.classes.base} ${options.classes.empty} `
        : options.classes.base

    let isCardDetailsValid = isValidValue == "valid" ? ` ${options.classes.complete} ` : ""

    let isCardDetailsInvalid = isValidValue == "invalid" ? ` ${options.classes.invalid} ` : ""

    let isCardDetailsFocused = isFocus ? ` ${options.classes.focus} ` : ""

    (isCardDetailsEmpty, isCardDetailsValid, isCardDetailsInvalid, isCardDetailsFocused)
  }, (isValid, setIsValid, value, onChange, onBlur))

  let concatString = Array.join([cardEmpty, cardComplete, cardInvalid, cardFocused], "")

  React.useEffect(() => {
    Utils.messageParentWindow([
      ("id", iframeId->JSON.Encode.string),
      ("concatedString", concatString->JSON.Encode.string),
    ])
    None
  }, (isValid, setIsValid, value, onChange, onBlur))

  <div className="flex flex-col w-full" style={color: themeObj.colorText}>
    <RenderIf
      condition={fieldName->String.length > 0 &&
      config.appearance.labels == Above &&
      innerLayout === Spaced}>
      <div
        className={`Label ${labelClass} ${labelClassName}`}
        style={
          fontWeight: themeObj.fontWeightNormal,
          fontSize: themeObj.fontSizeLg,
          marginBottom: "5px",
          opacity: "0.6",
        }
        ariaHidden=true>
        {React.string(fieldName)}
      </div>
    </RenderIf>
    <div className="flex flex-row " style={direction: direction}>
      <div className="relative w-full">
        <input
          id
          style={
            background: options.disabled ? themeObj.disabledFieldColor : backgroundClass,
            padding: themeObj.spacingUnit,
            width: "-webkit-fill-available",
          }
          disabled={options.disabled || readOnly}
          ref={inputRef->ReactDOM.Ref.domRef}
          type_
          ?onKeyDown
          ?maxLength
          ?pattern
          className={`${inputClassStyles} ${inputClass} ${className} focus:outline-none transition-shadow ease-out duration-200`}
          placeholder={config.appearance.labels == Above ? placeholder : ""}
          value
          onChange
          onBlur=handleBlur
          onFocus=handleFocus
          autoComplete={autocomplete}
          ariaLabel={`Type to fill ${fieldName} input`}
        />
        <RenderIf condition={config.appearance.labels == Floating}>
          <div
            className={`Label ${floatinglabelClass} ${labelClass} absolute bottom-0 ml-3 ${focusClass} pointer-events-none`}
            style={
              marginBottom: {
                isFocus || value->String.length > 0 ? "" : themeObj.spacingUnit
              },
              fontSize: {isFocus || value->String.length > 0 ? themeObj.fontSizeXs : ""},
              opacity: "0.6",
            }
            ariaHidden=true>
            {React.string(fieldName)}
          </div>
        </RenderIf>
      </div>
      <div className={`InputLogo ${inputLogoClass} flex -ml-10 items-center`}> {rightIcon} </div>
    </div>
    <RenderIf condition={innerLayout === Spaced}>
      {switch errorString {
      | Some(val) =>
        <RenderIf condition={val->String.length > 0}>
          <div
            className={`Error pt-1 ${errorStringClasses->Option.getOr("")}`}
            style={
              color: themeObj.colorDangerText,
              fontSize: themeObj.fontSizeSm,
              alignSelf: "start",
              textAlign: "left",
            }>
            {React.string(val)}
          </div>
        </RenderIf>
      | None => React.null
      }}
    </RenderIf>
  </div>
}
