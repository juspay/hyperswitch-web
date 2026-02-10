open RecoilAtoms
open PaymentTypeContext
open AccessibilityUtils

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
  ~fieldName="",
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
  ~id="",
  ~isRequired=true,
  ~ariaPlaceholder=?,
) => {
  let {themeObj, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {innerLayout} = config.appearance
  let {readOnly} = Recoil.useRecoilValueFromAtom(optionAtom)
  let {parentURL} = Recoil.useRecoilValueFromAtom(keys)
  let contextPaymentType = usePaymentType()
  let paymentType = paymentType->Option.getOr(contextPaymentType)

  let (inputFocused, setInputFocused) = React.useState(_ => false)

  let handleFocus = _ => {
    setInputFocused(_ => true)
    switch setIsValid {
    | Some(fn) => fn(_ => None)
    | None => ()
    }
    Utils.handleOnFocusPostMessage(~targetOrigin=parentURL)
  }

  let handleBlur = ev => {
    setInputFocused(_ => false)

    switch onBlur {
    | Some(fn) => fn(ev)
    | None => ()
    }
    Utils.handleOnBlurPostMessage(~targetOrigin=parentURL)
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

  let ariaInvalid = isValid->getAriaInvalidState
  let errorId = id->getErrorId

  <div className="flex flex-col w-full" style={color: themeObj.colorText}>
    <RenderIf
      condition={fieldName->String.length > 0 &&
      config.appearance.labels == Above &&
      innerLayout === Spaced}>
      <label
        htmlFor=id
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
          id
          style={
            background: isDisabled ? themeObj.disabledFieldColor : backgroundClass,
            padding: themeObj.spacingUnit,
            width: fieldWidth,
            height,
          }
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
          autoComplete=autocomplete
          onChange
          onBlur=handleBlur
          onFocus=handleFocus
          ariaLabel=fieldName
          ariaInvalid
          ariaRequired=isRequired
          ariaDescribedby={isValid->Option.getOr(false) ? errorId : ""}
          ariaPlaceholder={ariaPlaceholder->Option.getOr("")}
        />
        <RenderIf condition={config.appearance.labels == Floating}>
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
    <RenderIf condition={innerLayout === Spaced}>
      {switch errorString {
      | Some(val) =>
        <RenderIf condition={val->String.length > 0}>
          <div
            id=errorId
            className="Error pt-1"
            style={
              color: themeObj.colorDangerText,
              fontSize: themeObj.fontSizeSm,
              alignSelf: "start",
              textAlign: "left",
            }
            role="alert"
            ariaLive=#polite>
            {React.string(val)}
          </div>
        </RenderIf>
      | None => React.null
      }}
    </RenderIf>
  </div>
}
