open RecoilAtoms
open AccessibilityUtils

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
  ~isRequired=true,
  ~autocomplete="",
) => {
  let options = Recoil.useRecoilValueFromAtom(elementOptions)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let (_inputFocused, setInputFocused) = React.useState(_ => false)
  let {parentURL} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

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
    Utils.handleOnFocusPostMessage(~targetOrigin=parentURL)
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

  let ariaInvalid = isValid->getAriaInvalidState
  let errorId = id->getErrorId

  <div className={` flex flex-col w-full`} style={color: themeObj.colorText}>
    <RenderIf condition={fieldName->String.length > 0}>
      <label htmlFor={id} className="input-label"> {React.string(fieldName)} </label>
    </RenderIf>
    <div className="flex flex-row " style={direction: direction}>
      <input
        id
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
        ariaLabel=fieldName
        ariaInvalid
        ariaRequired=isRequired
        ariaDescribedby={isValid->Option.getOr(false) ? errorId : ""}
        autoComplete=autocomplete
      />
      <div className={`flex -ml-10  items-center`}> {rightIcon} </div>
    </div>
    {switch errorString {
    | Some(val) =>
      <RenderIf condition={val->String.length > 0}>
        <div
          id=errorId
          role="alert"
          ariaLive=#polite
          className="py-1 text-xs text-red-600 transition-colors transition-border ease-out duration-200">
          {React.string(val)}
        </div>
      </RenderIf>
    | None => React.null
    }}
  </div>
}
