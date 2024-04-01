open RecoilAtoms
@react.component
let make = (
  ~value: RecoilAtomTypes.field,
  ~setValue: (
    OrcaPaymentPage.RecoilAtomTypes.field => OrcaPaymentPage.RecoilAtomTypes.field
  ) => unit,
  ~fieldName,
  ~options,
  ~disabled=false,
  ~className="",
) => {
  let {config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly} = Recoil.useRecoilValueFromAtom(optionAtom)
  let dropdownRef = React.useRef(Nullable.null)
  let (inputFocused, setInputFocused) = React.useState(_ => false)
  let {parentURL} = Recoil.useRecoilValueFromAtom(keys)

  let getClassName = initialLabel => {
    if value.value->String.length == 0 {
      `${initialLabel}--empty`
    } else {
      switch value.isValid {
      | Some(valid) => valid ? "" : `${initialLabel}--invalid`
      | None => ""
      }
    }
  }
  React.useEffect(() => {
    let initialValue = options->Array.get(0)->Option.getOr("")
    if (
      value.value === "" ||
      value.value === initialValue ||
      options->Array.includes(value.value)->not
    ) {
      setValue(prev => {
        ...prev,
        isValid: Some(true),
        value: initialValue,
      })
    }
    None
  }, [options->Array.get(0)->Option.getOr("")])
  let handleFocus = _ => {
    setInputFocused(_ => true)
    // setValue(.prev => {
    //   ...prev,
    //   isValid: None,
    //   errorString: "",
    // })
    Utils.handleOnFocusPostMessage(~targetOrigin=parentURL, ())
  }
  let focusClass = if inputFocused || value.value->String.length > 0 {
    `mb-7 pb-1 pt-2 ${themeObj.fontSizeXs} transition-all ease-in duration-75`
  } else {
    "transition-all ease-in duration-75"
  }
  let floatinglabelClass = inputFocused ? "Label--floating" : "Label--resting"

  let labelClass = getClassName("Label")
  let inputClass = getClassName("Input")

  let handleChange = ev => {
    let target = ev->ReactEvent.Form.target
    let value = target["value"]
    setValue(_ => {
      isValid: Some(true),
      value,
      errorString: "",
    })
  }
  let disbaledBG = React.useMemo(() => {
    themeObj.colorBackground
  }, [themeObj])
  let cursorClass = !disabled ? "cursor-pointer" : "cursor-not-allowed"
  <RenderIf condition={options->Array.length > 0}>
    <div className="flex flex-col w-full" style={ReactDOMStyle.make(~color=themeObj.colorText, ())}>
      <RenderIf condition={fieldName->String.length > 0 && config.appearance.labels == Above}>
        <div
          className={`Label ${labelClass} `}
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
      <div className="relative">
        <select
          ref={dropdownRef->ReactDOM.Ref.domRef}
          style={ReactDOMStyle.make(
            ~background=disabled ? disbaledBG : themeObj.colorBackground,
            ~opacity=disabled ? "35%" : "",
            ~padding="11px 20px 11px 11px",
            ~width="100%",
            (),
          )}
          name=""
          value=value.value
          disabled={readOnly || disabled}
          onFocus={handleFocus}
          onChange=handleChange
          className={`Input ${inputClass} ${className} w-full appearance-none outline-none ${cursorClass}`}>
          {options
          ->Array.mapWithIndex((item: string, i) => {
            <option key={Int.toString(i)} value=item> {React.string(item)} </option>
          })
          ->React.array}
        </select>
        <RenderIf condition={config.appearance.labels == Floating}>
          <div
            className={`Label ${floatinglabelClass} ${labelClass} absolute bottom-0 ml-3 ${focusClass}`}
            style={ReactDOMStyle.make(
              ~marginBottom={
                inputFocused || value.value->String.length > 0 ? "" : themeObj.spacingUnit
              },
              ~fontSize={
                inputFocused || value.value->String.length > 0 ? themeObj.fontSizeXs : ""
              },
              ~opacity="0.6",
              (),
            )}>
            {React.string(fieldName)}
          </div>
        </RenderIf>
        <div
          className="self-center absolute"
          style={ReactDOMStyle.make(
            ~opacity=disabled ? "35%" : "",
            ~color=themeObj.colorText,
            ~left=localeString.localeDirection == "rtl" ? "1%" : "97%",
            ~top="42%",
            ~marginLeft=localeString.localeDirection == "rtl" ? "1rem" : "-1rem",
            (),
          )}>
          <Icon size=10 name={"arrow-down"} />
        </div>
        <RenderIf condition={value.errorString->String.length > 0}>
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
    </div>
  </RenderIf>
}
