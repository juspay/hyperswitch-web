let useCustomPaymentMethodConfigs = (~paymentMethod, ~paymentMethodType=?) => {
  let {paymentMethodsConfig} = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let allowedPmTypeForCardPayment = ["debit", "credit"]

  React.useMemo3(() => {
    let methodLevelConfig =
      paymentMethodsConfig->Array.find(config => config.paymentMethod == paymentMethod)

    let methodLevelMessage =
      methodLevelConfig
      ->Option.map(config => config.message)
      ->Option.getOr(PaymentType.defaultPaymentMethodMessage)

    switch paymentMethodType {
    | None => methodLevelMessage
    | Some(pmType) =>
      let typeLevelMessage = methodLevelConfig->Option.flatMap(config =>
        config.paymentMethodTypes
        ->Array.filter(
          pmTypeConfig =>
            paymentMethod == "card"
              ? allowedPmTypeForCardPayment->Array.includes(pmTypeConfig.paymentMethodType)
              : pmTypeConfig.paymentMethodType == pmType,
        )
        ->Array.get(0)
        ->Option.map(pmTypeConfig => pmTypeConfig.message)
      )
      typeLevelMessage->Option.getOr(methodLevelMessage)
    }
  }, (paymentMethod, paymentMethodType, paymentMethodsConfig))
}
