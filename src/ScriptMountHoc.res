@react.component
let make = (~children) => {
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let pmAuthConnectorsDict = PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(
    paymentMethodListValue.payment_methods,
  )

  let pmAuthConnectorsArr =
    pmAuthConnectorsDict->PmAuthConnectorUtils.getAllRequiredPmAuthConnectors

  PmAuthConnectorUtils.mountAllRequriedAuthConnectorScripts(~pmAuthConnectorsArr)

  children
}
