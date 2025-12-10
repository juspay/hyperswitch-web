let useCustomPaymentMethodConfigs = (~paymentMethod, ~paymentMethodType) => {
  let {paymentMethodsConfig} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)

  React.useMemo3(() => {
    paymentMethodsConfig
    ->Array.filter(paymentMethodConfig => paymentMethodConfig.paymentMethod == paymentMethod)
    ->Array.flatMap(paymentMethodConfig => paymentMethodConfig.paymentMethodTypes)
    ->Array.filter(paymentMethodTypeConfig =>
      paymentMethodTypeConfig.paymentMethodType == paymentMethodType
    )
    ->Array.get(0)
  }, (paymentMethod, paymentMethodType, paymentMethodsConfig))
}
