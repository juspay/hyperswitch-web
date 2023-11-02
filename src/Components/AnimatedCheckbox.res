@react.component
let make = (~isChecked, ~setIsChecked) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let css = `.container {
  display: flex;
  cursor: pointer;
  position: relative;
  justify-content: center;
  align-items: center;
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
  let onChange = ev => {
    let target = ev->ReactEvent.Form.target
    let value = target["checked"]
    setIsChecked(_ => value)
  }
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (checkboxState, checkedState, checkBoxLabelSate) = isChecked
    ? ("Checkbox--checked", "CheckboxInput--checked", "CheckboxLabel--checked")
    : ("", "", "")

  <div className={`Checkbox ${checkboxState} flex flex-row gap-2 items-center`}>
    <style> {React.string(css)} </style>
    <label className={`container CheckboxInput ${checkedState}`}>
      <input type_=`checkbox` onChange />
      <div className={`checkmark CheckboxInput ${checkedState}`} />
      <div className={`CheckboxLabel ${checkBoxLabelSate} ml-2`}>
        {React.string(localeString.saveCardDetails)}
      </div>
    </label>
  </div>
}
