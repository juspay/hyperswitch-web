let saveDetailsCssStyle = (themeObj: CardThemeType.themeClass) => {
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
let make = (~isChecked, ~setIsChecked) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let showPaymentMethodsScreen = Recoil.useRecoilValueFromAtom(RecoilAtoms.showPaymentMethodsScreen)
  let {business, customMessageForCardTerms} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let customCardPaymentConfig = CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs(
    ~paymentMethod="card",
    ~paymentMethodType="card",
  )

  let customMessageConfig =
    customCardPaymentConfig
    ->Option.map(config => config.message)
    ->Option.getOr(PaymentType.defaultPaymentMethodMessage)

  let css = saveDetailsCssStyle(themeObj)
  let onChange = ev => {
    let target = ev->ReactEvent.Form.target
    let value = target["checked"]
    LoggerUtils.logInputChangeInfo("saveDetails", loggerState)
    setIsChecked(_ => value)
  }
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (checkboxState, checkedState, checkBoxLabelState) = isChecked
    ? ("Checkbox--checked", "CheckboxInput--checked", "CheckboxLabel--checked")
    : ("", "", "")

  let saveCardCheckboxLabel = if showPaymentMethodsScreen {
    localeString.saveCardDetails
  } else if customMessageConfig.value->Option.isSome {
    customMessageConfig.value->Option.getOr("")
  } else if customMessageForCardTerms->String.length > 0 {
    customMessageForCardTerms
  } else {
    localeString.cardTerms(business.name)
  }

  <div
    className={`Checkbox ${checkboxState} flex flex-row gap-2 items-center`}
    tabIndex=0
    onKeyDown={event => {
      let key = JsxEvent.Keyboard.key(event)
      let keyCode = JsxEvent.Keyboard.keyCode(event)
      if key == "Enter" || keyCode == 13 {
        setIsChecked(prev => !prev)
      }
    }}
    role="checkbox"
    ariaChecked={isChecked ? #"true" : #"false"}
    ariaLabel={isChecked ? "Deselect to avoid saving card details" : "Select to save card details"}>
    <style> {React.string(css)} </style>
    <label className={`container CheckboxInput ${checkedState}`}>
      <input tabIndex={-1} type_={`checkbox`} checked={isChecked} onChange />
      <div className={`checkmark CheckboxInput ${checkedState}`} />
      <div className={`CheckboxLabel ${checkBoxLabelState} ml-2 w-11/12 opacity-50 text-xs`}>
        {React.string(saveCardCheckboxLabel)}
      </div>
    </label>
  </div>
}
