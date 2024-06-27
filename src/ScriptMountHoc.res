@react.component
let make = (~children, ~logger) => {
  let setIsPlaidReady = Recoil.useSetRecoilState(RecoilAtoms.isPlaidScriptReady)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let checkIfPmAuthConnectorRequriedAndMount = () => {
    let pmAuthConnectorsDict = PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(
      paymentMethodListValue.payment_methods,
    )

    let pmAuthConnectorsArr =
      pmAuthConnectorsDict->PmAuthConnectorUtils.getAllRequiredPmAuthConnectors

    PmAuthConnectorUtils.mountAllRequriedAuthConnectorScripts(
      ~pmAuthConnectorsArr,
      ~onScriptLoaded=authConnector => {
        switch authConnector->PmAuthConnectorUtils.pmAuthNameToTypeMapper {
        | PLAID => setIsPlaidReady(_ => true)
        | NONE => ()
        }
      },
      ~logger,
    )
  }

  checkIfPmAuthConnectorRequriedAndMount()

  children
}
