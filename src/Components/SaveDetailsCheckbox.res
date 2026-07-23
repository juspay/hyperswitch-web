@react.component
let make = (~isChecked, ~setIsChecked) => {
  let showPaymentMethodsScreen = Jotai.useAtomValue(JotaiAtoms.showPaymentMethodsScreen)
  let {business, customMessageForCardTerms} = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let loggerState = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  let customMessageConfig = CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs(
    ~paymentMethod="card",
    ~paymentMethodType="debit",
  )
  let {localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)

  let handleChange = value => {
    LoggerUtils.logInputChangeInfo("saveDetails", loggerState)
    setIsChecked(_ => value)
  }

  let customMessageConfigValue = customMessageConfig.value->Option.getOr("")

  let saveCardCheckboxLabel = if showPaymentMethodsScreen {
    localeString.saveCardDetails
  } else if customMessageConfigValue->String.length > 0 {
    customMessageConfigValue
  } else if customMessageForCardTerms->String.length > 0 {
    customMessageForCardTerms
  } else {
    localeString.cardTerms(business.name)
  }

  <Checkbox
    isChecked
    onChange=handleChange
    label=saveCardCheckboxLabel
    ariaLabelChecked="Deselect to avoid saving card details"
    ariaLabelUnchecked="Select to save card details"
  />
}
