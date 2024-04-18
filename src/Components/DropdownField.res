type optionType = {
  value: string,
  label?: string,
  displayValue?: string,
}

let updateArrayOfStringToOptionsTypeArray = arrayOfString =>
  arrayOfString->Array.map(item => {
    value: item,
  })

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
  let dropdownRef = React.useRef(Nullable.null)
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
    if isDisplayValueVisible {
      let findDisplayValue =
        options
        ->Array.find((ele: optionType) => ele.value === value)
        ->Option.getOr({
          value: "",
        })

      switch setDisplayValue {
      | Some(fun) => fun(_ => findDisplayValue.displayValue->Option.getOr(value))
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
          ->Option.getOr({
            value: "",
          })
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

  let cursorClass = !disabled ? "cursor-pointer" : "cursor-not-allowed"
  <RenderIf condition={options->Array.length > 0}>
    <div className={`flex flex-col ${width}`}>
      <RenderIf condition={fieldName->String.length > 0 && appearance.labels == Above}>
        <div
          className={`Label `}
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
        <div className={`Input ${className} appearance-none relative`}>
          <RenderIf condition={isDisplayValueVisible && displayValue->Option.isSome}>
            <div
              className="absolute top-2.5 right-0 left-2 bottom-0 pointer-events-none bg-white rounded-sm">
              {React.string(displayValue->Option.getOr(""))}
            </div>
          </RenderIf>
          <select
            ref={dropdownRef->ReactDOM.Ref.domRef}
            style={ReactDOMStyle.make(
              ~background=disabled ? disbaledBG : themeObj.colorBackground,
              ~opacity=disabled ? "35%" : "",
              ~padding=themeObj.spacingUnit,
              ~width="100%",
              ~borderRadius="6px",
              (),
            )}
            name=""
            value
            disabled={readOnly || disabled}
            onChange=handleChange
            onFocus=handleFocus
            className={`appearance-none outline-none ${cursorClass} `}>
            {options
            ->Array.mapWithIndex((item, index) => {
              <option key={Int.toString(index)} value=item.value>
                {React.string(item.label->Option.getOr(item.value))}
              </option>
            })
            ->React.array}
          </select>
        </div>
        <RenderIf condition={config.appearance.labels == Floating}>
          <div
            className={`Label ${floatinglabelClass} absolute bottom-0 ml-3 ${focusClass}`}
            style={ReactDOMStyle.make(
              ~marginBottom={
                inputFocused || value->String.length > 0 ? "" : themeObj.spacingUnit
              },
              ~fontSize={
                inputFocused || value->String.length > 0 ? themeObj.fontSizeXs : ""
              },
              ~opacity="0.6",
              (),
            )}>
            {React.string(fieldName)}
          </div>
        </RenderIf>
        <div
          className="self-center absolute pointer-events-none"
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
