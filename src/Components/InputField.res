open RecoilAtoms
open PaymentTypeContext
open AccessibilityUtils

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
  ~isRequired=true,
  ~ariaPlaceholder=?,
) => {
  open ElementType
  let (eleClassName, setEleClassName) = React.useState(_ => "input-base")
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
    Utils.handleOnFocusPostMessage(~targetOrigin=parentURL)
  }

  let handleBlur = ev => {
    if value->String.length == 0 {
      setClass("input-base")
    } else if value->String.length > 0 {
      setValidClasses()
    }
    setFocus(false)
    onBlur(ev)
    Utils.handleOnBlurPostMessage(~targetOrigin=parentURL)
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

  let ariaInvalid = isValid->getAriaInvalidState
  let errorId = id->getErrorId

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
      <label htmlFor=id className=labelClassName> {React.string(fieldName)} </label>
    </RenderIf>
    <div className="flex flex-row " style={direction: direction}>
      <input
        id
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
        autoComplete=autocomplete
        ariaLabel=fieldName
        ariaInvalid
        ariaRequired=isRequired
        ariaDescribedby={isValid->Option.getOr(false) ? errorId : ""}
        ariaPlaceholder={ariaPlaceholder->Option.getOr("")}
      />
      <div className={`flex -ml-10  items-center`}> {rightIcon} </div>
    </div>
    {
      let errorClases = errorStringClasses->Option.getOr("")
      switch errorString {
      | Some(val) =>
        <RenderIf condition={val->String.length > 0}>
          <div id=errorId role="alert" ariaLive=#polite className={`py-1 ${errorClases}`}>
            {React.string(val)}
          </div>
        </RenderIf>
      | None => React.null
      }
    }
  </div>
}
