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
  ~ariaRequired=false,
  ~fieldId=?,
) => {
  open ElementType
  let (eleClassName, setEleClassName) = React.useState(_ => "input-base")
  let {iframeId, parentURL} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(elementOptions)
  let contextPaymentType = usePaymentType()
  let paymentType = paymentType->Option.getOr(contextPaymentType)
  let elementType = contextPaymentType->CardThemeType.getPaymentModeToString

  let setFocus = (val: bool) => {
    switch onFocus {
    | Some(fn) => fn(val)
    | None => ()
    }
  }
  let setClass = val => {
    switch paymentType {
    | Card
    | CardCVCElement
    | CardExpiryElement
    | CardNumberElement
    | PaymentMethodCollectElement
    | PaymentMethodsManagement =>
      setEleClassName(_ => val)
    | _ => ()
    }
  }
  let textColor = switch isValid {
  | Some(val) => val ? "" : "#eb1c26"
  | None => ""
  }
  let setValidClasses = () => {
    switch isValid {
    | Some(val) => val ? setClass("input-complete") : setClass("input-invalid")
    | None => setClass("input-base")
    }
  }
  let handleFocus = _ => {
    if value->String.length == 0 {
      setClass("input-empty")
    } else if value->String.length > 0 {
      setValidClasses()
    }
    setFocus(true)
    setIsValid(_ => None)
    Utils.handleOnFocusPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL)
  }

  let handleBlur = ev => {
    if value->String.length == 0 {
      setClass("input-base")
    } else if value->String.length > 0 {
      setValidClasses()
    }
    setFocus(false)
    onBlur(ev)
    Utils.handleOnBlurPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL)
  }
  React.useEffect(() => {
    if value->String.length > 0 {
      setValidClasses()
    }
    None
  }, (value, isValid))

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

  <div className={` flex flex-col w-full`}>
    <RenderIf condition={fieldName->String.length > 0}>
      <label htmlFor={inputId} className={`${labelClassName}`}> {React.string(fieldName)} </label>
    </RenderIf>
    <div className="flex flex-row " style={direction: direction}>
      <input
        id={inputId}
        style={
          background: "transparent",
          width: "-webkit-fill-available",
          color: textColor,
        }
        disabled=options.disabled
        ref={inputRef->ReactDOM.Ref.domRef}
        type_
        ?onKeyDown
        ?maxLength
        ?pattern
        className={`${eleClassName} ${className} focus:outline-none transition-shadow ease-out duration-200`}
        placeholder
        value
        onChange
        onBlur=handleBlur
        onFocus=handleFocus
        autoComplete={autocomplete}
        ariaLabel={accessibleLabel}
        ariaInvalid
        ariaRequired
        ariaDescribedby=?describedById
      />
      <div className={`flex -ml-10  items-center`}> {rightIcon} </div>
    </div>
    {
      let errorClases = errorStringClasses->Option.getOr("")
      switch errorString {
      | Some(val) =>
        <RenderIf condition={val->String.length > 0}>
          <LiveError text={val} className={`py-1 ${errorClases}`} id={inputId ++ "-error"} />
        </RenderIf>
      | None => React.null
      }
    }
  </div>
}
