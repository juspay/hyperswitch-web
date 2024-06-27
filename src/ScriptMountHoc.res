@react.component
let make = (~children) => {
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
        Console.log2("In Script mount", authConnector)

        switch authConnector->Option.getOr("")->PmAuthConnectorUtils.pmAuthNameToTypeMapper {
        | PLAID => setIsPlaidReady(_ => true)
        | NONE => ()
        }
      },
    )
  }

  checkIfPmAuthConnectorRequriedAndMount()

  children
}
