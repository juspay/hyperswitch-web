open RecoilAtoms
open PaymentTypeContext

@react.component
let make = (
  ~isValid=Some(true),
  ~setIsValid=?,
  ~height="",
  ~fieldWidth="100%",
  ~inputFieldClassName="",
  ~value,
  ~onChange,
  ~onBlur=?,
  ~rightIcon=React.null,
  ~errorString=?,
  ~onFocus=?,
  ~fieldName="",
  ~isLabelHidden=false,
  ~name="",
  ~type_="text",
  ~maxLength=?,
  ~pattern=?,
  ~placeholder="",
  ~className="",
  ~inputRef,
  ~paymentType=?,
  ~isDisabled=false,
  ~autocomplete="on",
  ~ariaRequired=false,
  ~ariaLabel=?,
  ~fieldId=?,
) => {
  let {themeObj, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {innerLayout} = config.appearance
  let {readOnly} = Recoil.useRecoilValueFromAtom(optionAtom)
  let {parentURL, iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let contextPaymentType = usePaymentType()
  let paymentType = paymentType->Option.getOr(contextPaymentType)
  let elementType = contextPaymentType->CardThemeType.getPaymentModeToString

  let (inputFocused, setInputFocused) = React.useState(_ => false)

  let handleFocus = ev => {
    setInputFocused(_ => true)
    switch setIsValid {
    | Some(fn) => fn(_ => None)
    | None => ()
    }
    switch onFocus {
    | Some(fn) => fn(ev)
    | None => ()
    }

    Utils.handleOnFocusPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL)
  }

  let handleBlur = ev => {
    setInputFocused(_ => false)

    switch onBlur {
    | Some(fn) => fn(ev)
    | None => ()
    }
    Utils.handleOnBlurPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL)
  }

  let backgroundClass = switch paymentType {
  | Payment
  | PaymentMethodsManagement =>
    themeObj.colorBackground
  | _ => "transparent"
  }
  let direction = if type_ == "password" || type_ == "tel" {
    "ltr"
  } else {
    ""
  }
  let focusClass = if inputFocused || value->String.length > 0 {
    `mb-7 pb-1 pt-2 ${themeObj.fontSizeXs} transition-all ease-in duration-75`
  } else {
    "transition-all ease-in duration-75"
  }
  let floatinglabelClass = inputFocused ? "Label--floating" : "Label--resting"
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

  let inputId = fieldId->Option.getOr(name->String.length > 0 ? name : fieldName)
  let fallbackAccessibleLabel = AccessibilityUtils.getAccessibleLabel(
    ~fieldName,
    ~placeholder,
    ~fallback=inputId,
  )
  let accessibleLabel = ariaLabel->Option.getOr(fallbackAccessibleLabel)
  let hasError = errorString->AccessibilityUtils.hasOptionalText
  let describedById = hasError ? Some(inputId ++ "-error") : None
  let ariaInvalid = AccessibilityUtils.ariaInvalid(~hasError, ~isValid)
  let errorClassName =
    innerLayout === Spaced ? "Error pt-1" : AccessibilityUtils.visuallyHiddenClass
  let errorStyle: option<JsxDOM.style> =
    innerLayout === Spaced
      ? Some({
          color: themeObj.colorDangerText,
          fontSize: themeObj.fontSizeSm,
          alignSelf: "start",
          textAlign: "left",
        })
      : None

  <div className="flex flex-col w-full" style={color: themeObj.colorText}>
    <RenderIf
      condition={!isLabelHidden &&
      fieldName->String.length > 0 &&
      config.appearance.labels == Above &&
      innerLayout === Spaced}>
      <label
        htmlFor={inputId}
        className={`Label ${labelClass}`}
        style={
          fontWeight: themeObj.fontWeightNormal,
          fontSize: themeObj.fontSizeLg,
          marginBottom: "5px",
          opacity: "0.6",
        }>
        {React.string(fieldName)}
      </label>
    </RenderIf>
    <div className="flex flex-row " style={direction: direction}>
      <div className={`relative w-full ${inputFieldClassName}`}>
        <input
          style={
            background: isDisabled ? themeObj.disabledFieldColor : backgroundClass,
            padding: themeObj.spacingUnit,
            width: fieldWidth,
            height,
          }
          id={inputId}
          dataTestId={name}
          disabled={isDisabled || readOnly}
          ref={inputRef->ReactDOM.Ref.domRef}
          type_
          name
          ?maxLength
          ?pattern
          className={`${inputClassStyles} ${inputClass} ${className} focus:outline-none transition-shadow ease-out duration-200`}
          placeholder={config.appearance.labels == Above ? placeholder : ""}
          value
          autoComplete={autocomplete}
          onChange
          onBlur=handleBlur
          onFocus=handleFocus
          ariaLabel={accessibleLabel}
          ariaInvalid
          ariaRequired
          ariaDescribedby=?describedById
        />
        <RenderIf condition={!isLabelHidden && config.appearance.labels == Floating}>
          <div
            className={`Label ${floatinglabelClass} ${labelClass} absolute bottom-0 ml-3 ${focusClass} pointer-events-none`}
            style={
              marginBottom: {
                inputFocused || value->String.length > 0 ? "" : themeObj.spacingUnit
              },
              fontSize: {inputFocused || value->String.length > 0 ? themeObj.fontSizeXs : ""},
              opacity: "0.6",
            }
            ariaHidden=true>
            {React.string(fieldName)}
          </div>
        </RenderIf>
      </div>
      <div className={`InputLogo ${inputLogoClass} relative flex -ml-10 items-center`}>
        {rightIcon}
      </div>
    </div>
    {switch errorString {
    | Some(val) =>
      <RenderIf condition={val->String.length > 0}>
        <LiveError text={val} className=errorClassName style=?errorStyle id={inputId ++ "-error"} />
      </RenderIf>
    | None => React.null
    }}
  </div>
}
