open RecoilAtoms
@react.component
let make = (
  ~value: RecoilAtomTypes.field,
  ~setValue: (
    . OrcaPaymentPage.RecoilAtomTypes.field => OrcaPaymentPage.RecoilAtomTypes.field,
  ) => unit,
  ~defaultSelected=true,
  ~fieldName,
  ~options,
  ~disabled=false,
  ~className="",
) => {
  let {config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly} = Recoil.useRecoilValueFromAtom(optionAtom)
  let dropdownRef = React.useRef(Js.Nullable.null)

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

  let handleChange = ev => {
    let target = ev->ReactEvent.Form.target
    let value = target["value"]
    setValue(.prev => {
      ...prev,
      value: value,
      errorString: "",
    })
  }
  let disbaledBG = React.useMemo1(() => {
    themeObj.colorBackground
  }, [themeObj])
  let cursorClass = !disabled ? "cursor-pointer" : "cursor-not-allowed"
  <RenderIf condition={options->Js.Array2.length > 0}>
    <div className="flex flex-col w-full" style={ReactDOMStyle.make(~color=themeObj.colorText, ())}>
      <RenderIf condition={fieldName->Js.String2.length > 0 && config.appearance.labels == Above}>
        <div
          className={`Label ${labelClass} `}
          style={ReactDOMStyle.make(
            ~fontWeight=themeObj.fontWeightNormal,
            ~fontSize=themeObj.fontSizeLg,
            ~marginBottom="5px",
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
            ~padding=themeObj.spacingUnit,
            ~width="100%",
            (),
          )}
          name=""
          value=value.value
          disabled={readOnly || disabled}
          onChange=handleChange
          className={`Input ${inputClass} ${className} w-full appearance-none outline-none ${cursorClass}`}>
          {defaultSelected
            ? React.null
            : <option value="" disabled={true} style={ReactDOMStyle.make(~opacity="70%", ())}>
                {React.string("Select")}
              </option>}
          {options
          ->Js.Array2.mapi((item: string, i) => {
            <option key={string_of_int(i)} value=item> {React.string(item)} </option>
          })
          ->React.array}
        </select>
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
    </div>
  </RenderIf>
}
