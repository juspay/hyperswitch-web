open RecoilAtoms
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
  ~fieldName="",
  ~type_="text",
  ~paymentType: CardThemeType.mode,
  ~maxLength=?,
  ~pattern=?,
  ~placeholder="",
  ~className="",
  ~inputRef,
  ~isFocus,
) => {
  open ElementType
  let (eleClassName, setEleClassName) = React.useState(_ => "input-base")
  let {iframeId, parentURL} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(elementOptions)

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
    | CardNumberElement =>
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
    Utils.handleOnFocusPostMessage(~targetOrigin=parentURL, ())
  }

  let handleBlur = ev => {
    if value->String.length == 0 {
      setClass("input-base")
    } else if value->String.length > 0 {
      setValidClasses()
    }
    setFocus(false)
    onBlur(ev)
    Utils.handleOnBlurPostMessage(~targetOrigin=parentURL, ())
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

  let isValidValue = CardUtils.getBoolOptionVal(isValid)

  let (cardEmpty, cardComplete, cardInvalid, cardFocused) = React.useMemo5(() => {
    let isCardDetailsEmpty =
      String.length(value) == 0
        ? `${options.classes.base} ${options.classes.empty} `
        : options.classes.base

    let isCardDetailsValid = isValidValue == "valid" ? ` ${options.classes.complete} ` : ""

    let isCardDetailsInvalid = isValidValue == "invalid" ? ` ${options.classes.invalid} ` : ""

    let isCardDetailsFocused = isFocus ? ` ${options.classes.focus} ` : ""

    (isCardDetailsEmpty, isCardDetailsValid, isCardDetailsInvalid, isCardDetailsFocused)
  }, (isValid, setIsValid, value, onChange, onBlur))

  let concatString = Array.joinWith([cardEmpty, cardComplete, cardInvalid, cardFocused], "")

  React.useEffect(() => {
    Utils.handlePostMessage([
      ("id", iframeId->JSON.Encode.string),
      ("concatedString", concatString->JSON.Encode.string),
    ])
    None
  }, (isValid, setIsValid, value, onChange, onBlur))

  <div className={` flex flex-col w-full`}>
    <RenderIf condition={fieldName->String.length > 0}>
      <div style={ReactDOMStyle.make()}> {React.string(fieldName)} </div>
    </RenderIf>
    <div className="flex flex-row " style={ReactDOMStyle.make(~direction, ())}>
      <input
        id
        style={ReactDOMStyle.make(
          ~background="transparent",
          ~width="-webkit-fill-available",
          ~color=textColor,
          (),
        )}
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
      />
      <div className={`flex -ml-10  items-center`}> {rightIcon} </div>
    </div>
    {switch errorString {
    | Some(val) =>
      <RenderIf condition={val->String.length > 0}>
        <div className="py-1" style={ReactDOMStyle.make()}> {React.string(val)} </div>
      </RenderIf>
    | None => React.null
    }}
  </div>
}
