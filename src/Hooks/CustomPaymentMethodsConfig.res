let useCustomPaymentMethodConfigs = (~paymentMethod, ~paymentMethodType) => {
  let {paymentMethodsConfig} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let allowedPmTypeForCardPayment = ["debit", "credit"]
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

let useInstallmentConfig = (~paymentMethod) => {
  let {paymentMethodsConfig} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  React.useMemo2(() => {
    paymentMethodsConfig
    ->Array.filter(config => config.paymentMethod == paymentMethod)
    ->Array.get(0)
    ->Option.flatMap(c => c.installments)
  }, (paymentMethod, paymentMethodsConfig))
}
