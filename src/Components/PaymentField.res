open RecoilAtoms
open RecoilAtomTypes
open PaymentTypeContext
open AccessibilityUtils

@react.component
let make = (
  ~setValue=?,
  ~value: RecoilAtomTypes.field,
  ~valueDropDown=?,
  ~setValueDropDown=?,
  ~dropDownFieldName=?,
  ~dropDownOptions=?,
  ~onChange,
  ~onBlur=?,
  ~rightIcon=React.null,
  ~fieldName="",
  ~name="",
  ~type_="text",
  ~paymentType: option<CardThemeType.mode>=?,
  ~maxLength=?,
  ~pattern=?,
  ~placeholder="",
  ~className="",
  ~inputRef,
  ~displayValue=?,
  ~setDisplayValue=?,
  ~id="",
  ~isRequired=true,
  ~autocomplete="on",
) => {
  let {config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly} = Recoil.useRecoilValueFromAtom(optionAtom)
  let {parentURL} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced
  let contextPaymentType = usePaymentType()
  let paymentType = paymentType->Option.getOr(contextPaymentType)

  let (inputFocused, setInputFocused) = React.useState(_ => false)

  let {value, isValid, errorString} = value
  let hasError = isValid->Option.getOr(false)

  let handleFocus = _ => {
    setInputFocused(_ => true)
    switch setValue {
    | Some(fn) =>
      fn(prev => {
        ...prev,
        isValid: None,
        errorString: "",
      })
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
  let inputClassStyles = isSpacedInnerLayout ? "Input" : "Input-Compressed"

  let flexDirectionBasedOnType = type_ === "tel" ? "flex-row" : "flex-col"

  // Wrap onChange to include logging
  let wrappedOnChange = ev => {
    // Log the input change using the name parameter
    if name->String.length > 0 {
      LoggerUtils.logInputChangeInfo(name, loggerState)
    }
    // Call the original onChange handler
    onChange(ev)
  }

  let ariaInvalid = isValid->getAriaInvalidState
  let errorId = id->getErrorId

  <div className="flex flex-col w-full">
    <RenderIf
      condition={name === "phone" &&
      fieldName->String.length > 0 &&
      config.appearance.labels == Above &&
      isSpacedInnerLayout}>
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
    <div className={`flex ${flexDirectionBasedOnType} w-full`} style={color: themeObj.colorText}>
      <RenderIf condition={type_ === "tel"}>
        <DropdownField
          appearance=config.appearance
          value={valueDropDown->Option.getOr("")}
          setValue={setValueDropDown->Option.getOr(_ => ())}
          fieldName={dropDownFieldName->Option.getOr("")}
          options={dropDownOptions->Option.getOr([])}
          width="w-40 mr-2"
          displayValue={displayValue->Option.getOr("")}
          setDisplayValue={setDisplayValue->Option.getOr(_ => ())}
          isDisplayValueVisible=true
        />
      </RenderIf>
      <RenderIf
        condition={name !== "phone" &&
        fieldName->String.length > 0 &&
        config.appearance.labels == Above &&
        isSpacedInnerLayout}>
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
      <div className="flex flex-row w-full" style={direction: direction}>
        <div className="relative w-full">
          <input
            id
            style={
              background: backgroundClass,
              padding: themeObj.spacingUnit,
              width: "100%",
            }
            disabled=readOnly
            ref={inputRef->ReactDOM.Ref.domRef}
            type_
            name
            ?maxLength
            ?pattern
            className={`${inputClassStyles} ${inputClass} ${className} focus:outline-none transition-shadow ease-out duration-200`}
            placeholder={config.appearance.labels == Above || config.appearance.labels == Never
              ? placeholder
              : ""}
            value
            autoComplete=autocomplete
            onChange=wrappedOnChange
            onBlur=handleBlur
            onFocus=handleFocus
            ariaLabel=fieldName
            ariaInvalid
            ariaRequired=isRequired
            ariaDescribedby={hasError ? errorId : ""}
          />
          <RenderIf condition={config.appearance.labels == Floating}>
            <div
              className={`Label ${floatinglabelClass} ${labelClass} absolute bottom-0 ml-3 ${focusClass} pointer-events-none`}
              style={
                marginBottom: {
                  inputFocused || value->String.length > 0 ? "" : themeObj.spacingUnit
                },
                fontSize: {
                  inputFocused || value->String.length > 0 ? themeObj.fontSizeXs : ""
                },
                opacity: "0.6",
              }
              ariaHidden=true>
              {React.string(fieldName)}
            </div>
          </RenderIf>
        </div>
        <div className={`InputLogo ${inputLogoClass} relative flex -ml-10  items-center`}>
          {rightIcon}
        </div>
      </div>
      <RenderIf condition={errorString !== ""}>
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
          {React.string(errorString)}
        </div>
      </RenderIf>
    </div>
  </div>
}
