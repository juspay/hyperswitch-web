let useCustomPaymentMethodConfigs = (~paymentMethod, ~paymentMethodType) => {
  let {paymentMethodsConfig} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let allowedPmTypeForCardPayment = ["card", "debit", "credit"]
  React.useMemo3(() => {
    paymentMethodsConfig
    ->Array.filter(paymentMethodConfig => paymentMethodConfig.paymentMethod == paymentMethod)
    ->Array.flatMap(paymentMethodConfig => paymentMethodConfig.paymentMethodTypes)
    ->Array.filter(paymentMethodTypeConfig =>
      paymentMethod == "card"
        ? allowedPmTypeForCardPayment->Array.includes(paymentMethodTypeConfig.paymentMethodType)
        : paymentMethodTypeConfig.paymentMethodType == paymentMethodType
    )
    ->Array.get(0)
  }, (paymentMethod, paymentMethodType, paymentMethodsConfig))
}
