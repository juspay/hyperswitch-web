@react.component
let make = (~isChecked, ~setIsChecked) => {
  let showPaymentMethodsScreen = Recoil.useRecoilValueFromAtom(RecoilAtoms.showPaymentMethodsScreen)
  let {business, customMessageForCardTerms} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let customCardPaymentConfig = CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs(
    ~paymentMethod="card",
    ~paymentMethodType="debit",
  )
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let customMessageConfig =
    customCardPaymentConfig
    ->Option.map(config => config.message)
    ->Option.getOr(PaymentType.defaultPaymentMethodMessage)

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
    onChange={handleChange}
    label={saveCardCheckboxLabel}
    ariaLabelChecked="Deselect to avoid saving card details"
    ariaLabelUnchecked="Select to save card details"
  />
}
