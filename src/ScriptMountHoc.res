@react.component
let make = (~children) => {
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let pmAuthConnectorsArr = PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(
    paymentMethodListValue.payment_methods,
  )

  PmAuthConnectorUtils.mountAllRequriedAuthConnectorScripts(~pmAuthConnectorsArr)
  children
}
