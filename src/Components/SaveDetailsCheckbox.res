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
  let customMessageSegments = CustomMessageText.useSegments(~message=customMessageConfig)
  let {localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)

  let handleChange = value => {
    LoggerUtils.logInputChangeInfo("saveDetails", loggerState)
    setIsChecked(_ => value)
  }

  let customMessage = customMessageSegments->CustomMessageUtils.segmentsToPlainText
  let isUsingCustomMessage = !showPaymentMethodsScreen && customMessage->String.length > 0

  let cardLabel = {
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

  let labelContent =
    paymentMethod == "card" &&
    isUsingCustomMessage &&
    customMessageSegments->CustomMessageText.hasElementSegment
      ? Some(
          <CustomMessageText
            message=customMessageConfig paymentMethod paymentMethodType textClassName="opacity-50"
          />,
        )
      : None

  let ariaLabelChecked = "Deselect to avoid saving " ++ ariaSubject
  let ariaLabelUnchecked = "Select to save " ++ ariaSubject

  <Checkbox
    isChecked onChange=handleChange label ?labelContent ariaLabelChecked ariaLabelUnchecked
  />
}
