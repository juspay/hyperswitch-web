@react.component
let make = (
  ~isChecked,
  ~setIsChecked,
  ~paymentMethod="card",
  ~paymentMethodType="debit",
  ~acceptance: option<PaymentMethodsRecord.customerAcceptanceSupport>=?,
) => {
  let showPaymentMethodsScreen = Jotai.useAtomValue(JotaiAtoms.showPaymentMethodsScreen)
  let {business, customMessageForCardTerms} = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let loggerState = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  let customMessageConfig = CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs(
    ~paymentMethod,
    ~paymentMethodType,
  )
  let {localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)

  let handleChange = value => {
    LoggerUtils.logInputChangeInfo("saveDetails", loggerState)
    setIsChecked(_ => value)
  }

  let cardLabel = {
    let customMessage = customMessageConfig.value->Option.getOr("")
    if showPaymentMethodsScreen {
      localeString.saveCardDetails
    } else if customMessage->String.length > 0 {
      customMessage
    } else if customMessageForCardTerms->String.length > 0 {
      customMessageForCardTerms
    } else {
      localeString.cardTerms(business.name)
    }
  }

  let (label, ariaSubject) = switch (paymentMethod, acceptance) {
  | ("card", _) => (cardLabel, "card details")
  | (_, Some(PartiallySupported)) => (
      localeString.savePaymentDetailsWhereverPossible,
      "payment details wherever possible",
    )
  | (_, _) => (localeString.savePaymentDetails, "payment details")
  }

  let ariaLabelChecked = "Deselect to avoid saving " ++ ariaSubject
  let ariaLabelUnchecked = "Select to save " ++ ariaSubject

  <Checkbox isChecked onChange=handleChange label ariaLabelChecked ariaLabelUnchecked />
}
