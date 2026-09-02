type pmAuthConnector = PLAID | NONE
type isPmAuthConnectorReady = {plaid: bool}
let pmAuthNameToTypeMapper = authConnectorName => {
  switch authConnectorName {
  | "plaid" => PLAID
  | _ => NONE
  }
}

let pmAuthConnectorToScriptUrlMapper = authConnector => {
  switch authConnector {
  | PLAID => "https://cdn.plaid.com/link/v2/stable/link-initialize.js"
  | NONE => ""
  }
}

let mountAuthConnectorScript = (~authConnector, ~onScriptLoaded) => {
  let authConnector = authConnector->Option.getOr("")
  let pmAuthConnectorScriptUrl =
    authConnector->pmAuthNameToTypeMapper->pmAuthConnectorToScriptUrlMapper
  let pmAuthConnectorScript = Window.createElement("script")
  SdkRuntimeLogger.logResource(
    ~event=ScriptLoad(PmAuthConnectorScript, Progressed),
    ~message=`Pm Auth Connector ${authConnector} Script Loading`,
  )
  pmAuthConnectorScript->Window.elementSrc(pmAuthConnectorScriptUrl)
  pmAuthConnectorScript->Window.elementOnerror(_ => {
    SdkRuntimeLogger.logResource(
      ~event=ScriptLoad(PmAuthConnectorScript, Progressed),
      ~message=`Pm Auth Connector ${authConnector} Script Load Failure`,
    )
  })
  pmAuthConnectorScript->Window.elementOnload(_ => {
    onScriptLoaded(authConnector)
    SdkRuntimeLogger.logResource(
      ~event=ScriptLoad(PmAuthConnectorScript, Progressed),
      ~message=`Pm Auth Connector ${authConnector} Script Loaded`,
    )
  })
  Window.body->Window.appendChild(pmAuthConnectorScript)
}

let mountAllRequriedAuthConnectorScripts = (~pmAuthConnectorsArr, ~onScriptLoaded) => {
  pmAuthConnectorsArr->Array.forEach(item => {
    mountAuthConnectorScript(~authConnector=item, ~onScriptLoaded)
  })
}

let findPmAuthAllPMAuthConnectors = (
  paymentMethodListValue: array<PaymentMethodsRecord.methods>,
) => {
  let bankDebitPaymentMethodsArr =
    paymentMethodListValue->Array.filter(item => item.payment_method == "bank_debit")

  let pmAuthConnectorDict = Dict.make()

  bankDebitPaymentMethodsArr->Array.forEach(item => {
    item.payment_method_types->Array.forEach(item => {
      if item.pm_auth_connector->Option.isSome {
        pmAuthConnectorDict->Dict.set(item.payment_method_type, item.pm_auth_connector)
      }
    })
  })

  pmAuthConnectorDict
}

let getAllRequiredPmAuthConnectors = pmAuthConnectorsDict => {
  let requiredPmAuthConnectorsArr = pmAuthConnectorsDict->Dict.valuesToArray

  requiredPmAuthConnectorsArr->Array.filterWithIndex((item, idx) =>
    idx == requiredPmAuthConnectorsArr->Array.indexOf(item)
  )
}
