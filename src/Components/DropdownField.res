open RecoilAtoms
@react.component
let make = (
  ~appearance: CardThemeType.appearance,
  ~value,
  ~setValue,
  ~fieldName,
  ~options,
  ~disabled=false,
  ~className="",
) => {
  let {themeObj, localeString, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly} = Recoil.useRecoilValueFromAtom(optionAtom)
  let dropdownRef = React.useRef(Js.Nullable.null)
  let (inputFocused, setInputFocused) = React.useState(_ => false)
  let {parentURL} = Recoil.useRecoilValueFromAtom(keys)

  let handleFocus = _ => {
    setInputFocused(_ => true)
    Utils.handleOnFocusPostMessage(~targetOrigin=parentURL, ())
  }

  let handleChange = ev => {
    let target = ev->ReactEvent.Form.target
    let value = target["value"]
    setValue(value)
  }
  let disbaledBG = React.useMemo1(() => {
    themeObj.colorBackground
  }, [themeObj])
  React.useEffect0(() => {
    if value === "" {
      setValue(_ => options->Belt.Array.get(0)->Belt.Option.getWithDefault(""))
    }
    None
  })

  let focusClass = if inputFocused || value->Js.String2.length > 0 {
    `mb-7 pb-1 pt-2 ${themeObj.fontSizeXs} transition-all ease-in duration-75`
  } else {
    "transition-all ease-in duration-75"
  }

  let floatinglabelClass = inputFocused ? "Label--floating" : "Label--resting"

  let cursorClass = !disabled ? "cursor-pointer" : "cursor-not-allowed"
  <RenderIf condition={options->Js.Array2.length > 0}>
    <div className="flex flex-col w-full">
      <RenderIf condition={fieldName->Js.String2.length > 0 && appearance.labels == Above}>
        <div
          className={`Label `}
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
          value
          disabled={readOnly || disabled}
          onChange=handleChange
          onFocus=handleFocus
          className={`Input ${className} w-full appearance-none outline-none ${cursorClass}`}>
          {options
          ->Js.Array2.mapi((item: string, i) => {
            <option key={string_of_int(i)} value=item> {React.string(item)} </option>
          })
          ->React.array}
        </select>
        <RenderIf condition={config.appearance.labels == Floating}>
          <div
            className={`Label ${floatinglabelClass} absolute bottom-0 ml-3 ${focusClass}`}
            style={ReactDOMStyle.make(
              ~marginBottom={
                inputFocused || value->Js.String2.length > 0 ? "" : themeObj.spacingUnit
              },
              ~fontSize={
                inputFocused || value->Js.String2.length > 0 ? themeObj.fontSizeXs : ""
              },
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
      </div>
    </div>
  </RenderIf>
}
