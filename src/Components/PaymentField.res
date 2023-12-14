open RecoilAtoms
open RecoilAtomTypes
@react.component
let make = (
  ~setValue=?,
  ~value: RecoilAtomTypes.field,
  ~onChange,
  ~onBlur=?,
  ~rightIcon=React.null,
  ~fieldName="",
  ~name="",
  ~type_="text",
  ~paymentType: CardThemeType.mode,
  ~maxLength=?,
  ~pattern=?,
  ~placeholder="",
  ~className="",
  ~inputRef,
) => {
  let {config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly} = Recoil.useRecoilValueFromAtom(optionAtom)
  let {parentURL} = Recoil.useRecoilValueFromAtom(keys)

  let (inputFocused, setInputFocused) = React.useState(_ => false)

  let handleFocus = _ => {
    setInputFocused(_ => true)
    switch setValue {
    | Some(fn) =>
      fn(.prev => {
        ...prev,
        isValid: None,
        errorString: "",
      })
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
  let focusClass = if inputFocused || value.value->Js.String2.length > 0 {
    `mb-7 pb-1 pt-2 ${themeObj.fontSizeXs} transition-all ease-in duration-75`
  } else {
    "transition-all ease-in duration-75"
  }
  let floatinglabelClass = inputFocused ? "Label--floating" : "Label--resting"
  let getClassName = initialLabel => {
    if value.value->Js.String2.length == 0 {
      `${initialLabel}--empty`
    } else {
      switch value.isValid {
      | Some(valid) => valid ? "" : `${initialLabel}--invalid`
      | None => ""
      }
    }
  }
  let labelClass = getClassName("Label")
  let inputClass = getClassName("Input")

  <div className="flex flex-col w-full" style={ReactDOMStyle.make(~color=themeObj.colorText, ())}>
    <RenderIf condition={fieldName->Js.String2.length > 0 && config.appearance.labels == Above}>
      <div
        className={`Label ${labelClass}`}
        style={ReactDOMStyle.make(
          ~fontWeight=themeObj.fontWeightNormal,
          ~fontSize=themeObj.fontSizeLg,
          ~marginBottom="5px",
          (),
        )}>
        {React.string(fieldName)}
      </div>
    </RenderIf>
    <div className="flex flex-row " style={ReactDOMStyle.make(~direction, ())}>
      <div className="relative w-full">
        <input
          style={ReactDOMStyle.make(
            ~background=backgroundClass,
            ~padding=themeObj.spacingUnit,
            ~width="100%",
            (),
          )}
          disabled=readOnly
          ref={inputRef->ReactDOM.Ref.domRef}
          type_
          name
          ?maxLength
          ?pattern
          className={`Input ${inputClass} ${className} focus:outline-none transition-shadow ease-out duration-200`}
          placeholder={config.appearance.labels == Above || config.appearance.labels == Never
            ? placeholder
            : ""}
          value={value.value}
          autoComplete="on"
          onChange
          onBlur=handleBlur
          onFocus=handleFocus
        />
        <RenderIf condition={config.appearance.labels == Floating}>
          <div
            className={`Label ${floatinglabelClass} ${labelClass} absolute bottom-0 ml-3 ${focusClass}`}
            style={ReactDOMStyle.make(
              ~marginBottom={
                inputFocused || value.value->Js.String2.length > 0 ? "" : themeObj.spacingUnit
              },
              ~fontSize={
                inputFocused || value.value->Js.String2.length > 0 ? themeObj.fontSizeXs : ""
              },
              (),
            )}>
            {React.string(fieldName)}
          </div>
        </RenderIf>
      </div>
      <div className={`relative flex -ml-10  items-center`}> {rightIcon} </div>
    </div>
    <RenderIf condition={value.errorString->Js.String2.length > 0}>
      <div
        className="Error pt-1"
        style={ReactDOMStyle.make(
          ~color=themeObj.colorDangerText,
          ~fontSize=themeObj.fontSizeSm,
          ~alignSelf="start",
          ~textAlign="left",
          (),
        )}>
        {React.string(value.errorString)}
      </div>
    </RenderIf>
  </div>
}
