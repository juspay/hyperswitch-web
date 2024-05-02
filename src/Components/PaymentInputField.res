open RecoilAtoms
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
  ~paymentType: CardThemeType.mode,
  ~maxLength=?,
  ~pattern=?,
  ~placeholder="",
  ~appearance: CardThemeType.appearance,
  ~className="",
  ~inputRef,
) => {
  let {themeObj, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {innerLayout} = config.appearance
  let {readOnly} = Recoil.useRecoilValueFromAtom(optionAtom)
  let {parentURL} = Recoil.useRecoilValueFromAtom(keys)

  let (inputFocused, setInputFocused) = React.useState(_ => false)

  let handleFocus = _ => {
    setInputFocused(_ => true)
    switch setIsValid {
    | Some(fn) => fn(_ => None)
    | None => ()
    }
    Utils.handleOnFocusPostMessage(~targetOrigin=parentURL, ())
  }

  let handleBlur = ev => {
    setInputFocused(_ => false)

    switch onBlur {
    | Some(fn) => fn(ev)
    | None => ()
    }
    Utils.handleOnBlurPostMessage(~targetOrigin=parentURL, ())
  }

  let backgroundClass = switch paymentType {
  | Payment => themeObj.colorBackground
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
      | Some(valid) => valid ? "" : `${initialLabel}--invalid`
      | None => ""
      }
    }
  }
  let labelClass = getClassName("Label")
  let inputClass = getClassName("Input")
  let inputClassStyles = innerLayout === Spaced ? "Input" : "Input-Compressed"

  <div className="flex flex-col w-full" style={ReactDOMStyle.make(~color=themeObj.colorText, ())}>
    <RenderIf
      condition={fieldName->String.length > 0 &&
      appearance.labels == Above &&
      innerLayout === Spaced}>
      <div
        className={`Label ${labelClass}`}
        style={ReactDOMStyle.make(
          ~fontWeight=themeObj.fontWeightNormal,
          ~fontSize=themeObj.fontSizeLg,
          ~marginBottom="5px",
          ~opacity="0.6",
          (),
        )}>
        {React.string(fieldName)}
      </div>
    </RenderIf>
    <div className="flex flex-row " style={ReactDOMStyle.make(~direction, ())}>
      <div className={`relative w-full ${inputFieldClassName}`}>
        <input
          style={ReactDOMStyle.make(
            ~background=backgroundClass,
            ~padding=themeObj.spacingUnit,
            ~width=fieldWidth,
            ~height,
            (),
          )}
          disabled=readOnly
          ref={inputRef->ReactDOM.Ref.domRef}
          type_
          name
          ?maxLength
          ?pattern
          className={`${inputClassStyles} ${inputClass} ${className} focus:outline-none transition-shadow ease-out duration-200`}
          placeholder={appearance.labels == Above ? placeholder : ""}
          value
          autoComplete="on"
          onChange
          onBlur=handleBlur
          onFocus=handleFocus
        />
        <RenderIf condition={appearance.labels == Floating}>
          <div
            className={`Label ${floatinglabelClass} ${labelClass} absolute bottom-0 ml-3 ${focusClass} text-opacity-20 pointer-events-none`}
            style={ReactDOMStyle.make(
              ~marginBottom={
                inputFocused || value->String.length > 0 ? "" : themeObj.spacingUnit
              },
              ~fontSize={inputFocused || value->String.length > 0 ? themeObj.fontSizeXs : ""},
              ~opacity="0.6",
              (),
            )}>
            {React.string(fieldName)}
          </div>
        </RenderIf>
      </div>
      <div className={`relative flex -ml-10 items-center`}> {rightIcon} </div>
    </div>
    <RenderIf condition={innerLayout === Spaced}>
      {switch errorString {
      | Some(val) =>
        <RenderIf condition={val->String.length > 0}>
          <div
            className="Error pt-1"
            style={ReactDOMStyle.make(
              ~color=themeObj.colorDangerText,
              ~fontSize=themeObj.fontSizeSm,
              ~alignSelf="start",
              ~textAlign="left",
              (),
            )}>
            {React.string(val)}
          </div>
        </RenderIf>
      | None => React.null
      }}
    </RenderIf>
  </div>
}
