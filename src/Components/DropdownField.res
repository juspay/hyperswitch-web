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
  let dropdownRef = React.useRef(Nullable.null)
  let (inputFocused, setInputFocused) = React.useState(_ => false)
  let {parentURL} = Recoil.useRecoilValueFromAtom(keys)
  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced

  let handleFocus = _ => {
    setInputFocused(_ => true)
    Utils.handleOnFocusPostMessage(~targetOrigin=parentURL, ())
  }

  let handleChange = ev => {
    let target = ev->ReactEvent.Form.target
    let value = target["value"]
    setValue(value)
  }
  let disbaledBG = React.useMemo(() => {
    themeObj.colorBackground
  }, [themeObj])
  React.useEffect0(() => {
    if value === "" || !(options->Array.includes(value)) {
      setValue(_ => options->Array.get(0)->Option.getOr(""))
    }
    None
  })

  let focusClass = if inputFocused || value->String.length > 0 {
    `mb-7 pb-1 pt-2 ${themeObj.fontSizeXs} transition-all ease-in duration-75`
  } else {
    "transition-all ease-in duration-75"
  }

  let floatinglabelClass = inputFocused ? "Label--floating" : "Label--resting"
  let inputClassStyles = isSpacedInnerLayout ? "Input" : "Input-Compressed"

  let cursorClass = !disabled ? "cursor-pointer" : "cursor-not-allowed"
  <RenderIf condition={options->Array.length > 0}>
    <div className="flex flex-col w-full">
      <RenderIf
        condition={fieldName->String.length > 0 &&
        appearance.labels == Above &&
        isSpacedInnerLayout}>
        <div
          className={`Label `}
          style={
            fontWeight: themeObj.fontWeightNormal,
            fontSize: themeObj.fontSizeLg,
            marginBottom: "5px",
            opacity: "0.6",
          }>
          {React.string(fieldName)}
        </div>
      </RenderIf>
      <div className="relative">
        <select
          ref={dropdownRef->ReactDOM.Ref.domRef}
          style={
            background: disabled ? disbaledBG : themeObj.colorBackground,
            opacity: disabled ? "35%" : "",
            padding: themeObj.spacingUnit,
            width: "100%",
          }
          name=""
          value
          disabled={readOnly || disabled}
          onChange=handleChange
          onFocus=handleFocus
          className={`${inputClassStyles} ${className} w-full appearance-none outline-none ${cursorClass}`}>
          {options
          ->Array.mapWithIndex((item: string, i) => {
            <option key={Int.toString(i)} value=item> {React.string(item)} </option>
          })
          ->React.array}
        </select>
        <RenderIf condition={config.appearance.labels == Floating}>
          <div
            className={`Label ${floatinglabelClass} absolute bottom-0 ml-3 ${focusClass}`}
            style={
              marginBottom: {
                inputFocused || value->String.length > 0 ? "" : themeObj.spacingUnit
              },
              fontSize: {
                inputFocused || value->String.length > 0 ? themeObj.fontSizeXs : ""
              },
              opacity: "0.6",
            }>
            {React.string(fieldName)}
          </div>
        </RenderIf>
        <div
          className="self-center absolute"
          style={
            opacity: disabled ? "35%" : "",
            color: themeObj.colorText,
            left: localeString.localeDirection == "rtl" ? "1%" : "97%",
            top: "42%",
            marginLeft: localeString.localeDirection == "rtl" ? "1rem" : "-1rem",
          }>
          <Icon size=10 name={"arrow-down"} />
        </div>
      </div>
    </div>
  </RenderIf>
}
