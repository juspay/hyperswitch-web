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

let mountAuthConnectorScript = (
  ~authConnector,
  ~onScriptLoaded,
  ~logger: OrcaLogger.loggerMake,
) => {
  let authConnector = authConnector->Option.getOr("")
  let pmAuthConnectorScriptUrl =
    authConnector->pmAuthNameToTypeMapper->pmAuthConnectorToScriptUrlMapper
  let pmAuthConnectorScript = Window.createElement("script")
  logger.setLogInfo(
    ~value=`Pm Auth Connector ${authConnector} Script Loading`,
    ~eventName=PM_AUTH_CONNECTOR_SCRIPT,
  )
  pmAuthConnectorScript->Window.elementSrc(pmAuthConnectorScriptUrl)
  pmAuthConnectorScript->Window.elementOnerror(_ => {
    logger.setLogInfo(
      ~value=`Pm Auth Connector ${authConnector} Script Load Failure`,
      ~eventName=PM_AUTH_CONNECTOR_SCRIPT,
    )
  })
  pmAuthConnectorScript->Window.elementOnload(_ => {
    onScriptLoaded(authConnector)
    logger.setLogInfo(
      ~value=`Pm Auth Connector ${authConnector} Script Loaded`,
      ~eventName=PM_AUTH_CONNECTOR_SCRIPT,
    )
  })
  Window.body->Window.appendChild(pmAuthConnectorScript)
}

let mountAllRequriedAuthConnectorScripts = (
  ~pmAuthConnectorsArr,
  ~onScriptLoaded,
  ~logger: OrcaLogger.loggerMake,
) => {
  pmAuthConnectorsArr->Array.forEach(item => {
    mountAuthConnectorScript(~authConnector=item, ~onScriptLoaded, ~logger)
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
