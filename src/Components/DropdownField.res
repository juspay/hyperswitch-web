type optionType = {
  value: string,
  label?: string,
  displayValue?: string,
}

let updateArrayOfStringToOptionsTypeArrayWithUpperCaseLabel = arrayOfString =>
  arrayOfString->Array.map(item => {
    value: item,
    label: item->String.toUpperCase,
  })

let updateArrayOfStringToOptionsTypeArray = arrayOfString =>
  arrayOfString->Array.map(item => {
    value: item,
  })

let defaultValue = {
  value: "",
}

open RecoilAtoms
@react.component
let make = (
  ~appearance: CardThemeType.appearance,
  ~value,
  ~setValue,
  ~isDisplayValueVisible=false,
  ~displayValue=?,
  ~setDisplayValue=?,
  ~fieldName,
  ~options: array<optionType>,
  ~disabled=false,
  ~className="",
  ~width="w-full",
) => {
  let {themeObj, localeString, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly} = Recoil.useRecoilValueFromAtom(optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let dropdownRef = React.useRef(Nullable.null)
  let (inputFocused, setInputFocused) = React.useState(_ => false)
  let {parentURL} = Recoil.useRecoilValueFromAtom(keys)
  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced

  let handleFocus = _ => {
    setInputFocused(_ => true)
    Utils.handleOnFocusPostMessage(~targetOrigin=parentURL)
  }

  let handleChange = ev => {
    let target = ev->ReactEvent.Form.target
    let value = target["value"]

    // Log the dropdown change using fieldName
    if fieldName->String.length > 0 {
      LoggerUtils.logInputChangeInfo(fieldName, loggerState)
    }
    setValue(_ => value)
    if isDisplayValueVisible {
      let findDisplayValue =
        options
        ->Array.find(ele => ele.value === value)
        ->Option.getOr(defaultValue)

      switch setDisplayValue {
      | Some(setDisplayValue) =>
        setDisplayValue(_ => findDisplayValue.displayValue->Option.getOr(value))
      | None => ()
      }
    }
  }
  let disbaledBG = React.useMemo(() => {
    themeObj.colorBackground
  }, [themeObj])
  React.useEffect0(() => {
    if value === "" || !(options->Array.map(val => val.value)->Array.includes(value)) {
      setValue(_ =>
        (
          options
          ->Array.get(0)
          ->Option.getOr(defaultValue)
        ).value
      )
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
    <div className={`flex flex-col ${width}`}>
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
          }
          ariaHidden=true>
          {React.string(fieldName)}
        </div>
      </RenderIf>
      <div className="relative">
        <RenderIf condition={isDisplayValueVisible && displayValue->Option.isSome}>
          <div
            className="absolute top-[2px] left-[2px] right-0 bottom-[2px]  pointer-events-none rounded-sm z-20 whitespace-nowrap"
            style={
              background: disabled ? disbaledBG : themeObj.colorBackground,
              opacity: disabled ? "35%" : "",
              padding: themeObj.spacingUnit,
              width: "calc(100% - 22px)",
            }
            ariaHidden=true>
            {React.string(displayValue->Option.getOr(""))}
          </div>
        </RenderIf>
        <select
          ref={dropdownRef->ReactDOM.Ref.domRef}
          style={
            background: disabled ? disbaledBG : themeObj.colorBackground,
            opacity: disabled ? "35%" : "",
            padding: themeObj.spacingUnit,
            paddingRight: "22px",
            width: "100%",
          }
          name=""
          value
          disabled={readOnly || disabled}
          onChange=handleChange
          onFocus=handleFocus
          className={`${inputClassStyles} ${className} w-full appearance-none outline-none overflow-hidden whitespace-nowrap text-ellipsis ${cursorClass}`}
          ariaLabel={`${fieldName} option tab`}>
          {options
          ->Array.mapWithIndex((item, index) => {
            <option key={Int.toString(index)} value=item.value>
              {React.string(item.label->Option.getOr(item.value))}
            </option>
          })
          ->React.array}
        </select>
        <RenderIf condition={config.appearance.labels == Floating}>
          <div
            className={`Label ${floatinglabelClass} absolute bottom-0 ml-3 ${focusClass} pointer-events-none`}
            style={
              marginBottom: {
                inputFocused || value->String.length > 0 ? "" : themeObj.spacingUnit
              },
              fontSize: {
                inputFocused || value->String.length > 0 ? themeObj.fontSizeXs : ""
              },
              opacity: "0.6",
            }
            ariaHidden=true>
            {React.string(fieldName)}
          </div>
        </RenderIf>
        <div
          className="self-center absolute pointer-events-none"
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
