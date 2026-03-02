let checkboxCssStyle = (themeObj: CardThemeType.themeClass) => {
  `.container {
  display: flex;
  cursor: pointer;
  position: relative;
}

.container input {
  position: absolute;
  transform: scale(0);
}

.container input:checked ~ .checkmark {
  transform: rotate(45deg);
  height: 1em;
  width: .4em;
  border-color: ${themeObj.colorTextSecondary};
  border-top-color: transparent;
  border-left-color: transparent;
  border-radius: 0;
  margin-top: -2px;
  margin-left: 8px;
}

.container .checkmark {
  display: block;
  width: 1em;
  height: 1em;
  border: 2px solid ${themeObj.colorTextSecondary};
  border-radius: 2px;
  transition: all .3s;
}
`
}

@react.component
let make = (
  ~isChecked: bool,
  ~onChange: bool => unit,
  ~label: string,
  ~ariaLabelChecked: string="",
  ~ariaLabelUnchecked: string="",
) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let css = checkboxCssStyle(themeObj)
  let handleChange = ev => {
    let target = ev->ReactEvent.Form.target
    let value = target["checked"]
    onChange(value)
  }

  let (checkboxState, checkedState, checkBoxLabelState) = isChecked
    ? ("Checkbox--checked", "CheckboxInput--checked", "CheckboxLabel--checked")
    : ("", "", "")

  let ariaLabel = if ariaLabelChecked->String.length > 0 && ariaLabelUnchecked->String.length > 0 {
    isChecked ? ariaLabelChecked : ariaLabelUnchecked
  } else {
    ""
  }

  <div
    className={`Checkbox ${checkboxState} flex flex-row gap-2 items-center`}
    tabIndex=0
    onKeyDown={event => {
      let key = JsxEvent.Keyboard.key(event)
      let keyCode = JsxEvent.Keyboard.keyCode(event)
      if key == "Enter" || keyCode == 13 {
        onChange(!isChecked)
      }
    }}
    role="checkbox"
    ariaChecked={isChecked ? #"true" : #"false"}
    ariaLabel={ariaLabel->String.length > 0 ? ariaLabel : label}>
    <style> {React.string(css)} </style>
    <label className={`container CheckboxInput ${checkedState}`}>
      <input tabIndex={-1} type_={`checkbox`} checked={isChecked} onChange={handleChange} />
      <div className={`checkmark CheckboxInput ${checkedState}`} />
      <div
        className={`CheckboxLabel ${checkBoxLabelState} ml-2 opacity-50 text-xs select-none`}>
        {React.string(label)}
      </div>
    </label>
  </div>
}
