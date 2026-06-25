open RecoilAtoms
@react.component
let make = (
  ~isValid=None,
  ~id="",
  ~setIsValid=?,
  ~value,
  ~onChange,
  ~onBlur=?,
  ~onKeyDown=?,
  ~onFocus=?,
  ~rightIcon=React.null,
  ~errorString=?,
  ~fieldName="",
  ~type_="text",
  ~maxLength=?,
  ~pattern=?,
  ~placeholder="",
  ~className="",
  ~inputRef,
  ~ariaRequired=false,
  ~fieldId=?,
) => {
  let options = Recoil.useRecoilValueFromAtom(elementOptions)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let (_inputFocused, setInputFocused) = React.useState(_ => false)
  let {parentURL, iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let elementType = PaymentTypeContext.usePaymentType()->CardThemeType.getPaymentModeToString

  let setFocus = (val: bool) => {
    switch onFocus {
    | Some(fn) => fn(val)
    | None => ()
    }
  }
  let setValid = val => {
    switch setIsValid {
    | Some(fn) => fn(_ => val)
    | None => ()
    }
  }

  let handleFocus = _ => {
    setFocus(true)
    setValid(None)
    setInputFocused(_ => true)
    Utils.handleOnFocusPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL)
  }

  let handleBlur = ev => {
    setFocus(false)
    switch onBlur {
    | Some(fn) => fn(ev)
    | None => ()
    }
  }

  let direction = if type_ == "password" || type_ == "tel" {
    "ltr"
  } else {
    ""
  }

  let inputId = fieldId->Option.getOr(id->String.length > 0 ? id : fieldName)
  let accessibleLabel = AccessibilityUtils.getAccessibleLabel(
    ~fieldName,
    ~placeholder,
    ~fallback=inputId,
  )
  let hasError = errorString->AccessibilityUtils.hasOptionalText
  let describedById = hasError ? Some(inputId ++ "-error") : None
  let ariaInvalid = AccessibilityUtils.ariaInvalid(~hasError, ~isValid)

  <div className={` flex flex-col w-full`} style={color: themeObj.colorText}>
    <RenderIf condition={fieldName->String.length > 0}>
      <label htmlFor={inputId}> {React.string(fieldName)} </label>
    </RenderIf>
    <div className="flex flex-row " style={direction: direction}>
      <input
        id={inputId}
        style={
          background: themeObj.colorBackground,
          padding: themeObj.spacingUnit,
          width: "100%",
        }
        disabled=options.disabled
        ref={inputRef->ReactDOM.Ref.domRef}
        type_
        ?onKeyDown
        ?maxLength
        ?pattern
        className={`Input ${className} focus:outline-none transition-shadow ease-out duration-200 border border-gray-300 focus:border-[#006DF9] rounded-md text-sm`}
        placeholder
        value
        onChange
        onBlur=handleBlur
        onFocus=handleFocus
        ariaLabel={accessibleLabel}
        ariaInvalid
        ariaRequired
        ariaDescribedby=?describedById
      />
      <div className={`flex -ml-10  items-center`}> {rightIcon} </div>
    </div>
    {switch errorString {
    | Some(val) =>
      <RenderIf condition={val->String.length > 0}>
        <LiveError
          text={val}
          className="py-1 text-xs text-red-600 transition-colors transition-border ease-out duration-200"
          id={inputId ++ "-error"}
        />
      </RenderIf>
    | None => React.null
    }}
  </div>
}
