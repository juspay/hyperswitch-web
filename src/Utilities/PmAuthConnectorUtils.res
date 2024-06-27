type pmAuthConnector = PLAID

let pmAuthNameToTypeMapper = authConnectorName => {
  switch authConnectorName {
  | "plaid" => PLAID
  }
}

let pmAuthConnectorToScriptUrlMapper = authConnector => {
  switch authConnector {
  | PLAID => "https://cdn.plaid.com/link/v2/stable/link-initialize.js"
  }
}

let mountAuthConnectorScript = (~authConnector, ~onScriptLoaded) => {
  let pmAuthConnectorScriptUrl =
    authConnector->Option.getOr("")->pmAuthNameToTypeMapper->pmAuthConnectorToScriptUrlMapper
  let pmAuthConnectorScript = Window.createElement("script")
  // logger.setLogInfo(~value="Plaid Sdk Script Loading", ~eventName=PLAID_SDK_SCRIPT, ())
  pmAuthConnectorScript->Window.elementSrc(pmAuthConnectorScriptUrl)
  //   plaidSdkScript->Window.elementOnerror(err => {

  //     // logInfo(Console.log2("ERROR DURING LOADING Plaid", err))
  //   })
  pmAuthConnectorScript->Window.elementOnload(_ => {
    Console.log("plaid script loaded!!!!!!!!1")
    // logger.setLogInfo(~value="TrustPay Script Loaded", ~eventName=PLAID_SDK_SCRIPT, ())
  })
  Window.body->Window.appendChild(pmAuthConnectorScript)
}

let mountAllRequriedAuthConnectorScripts = (~pmAuthConnectorsArr) => {
  pmAuthConnectorsArr->Array.forEach(item => {
    mountAuthConnectorScript(~authConnector=item, ~onScriptLoaded=() => {
      Console.log("loaded")
    })
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
