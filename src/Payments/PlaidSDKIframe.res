@react.component
let make = () => {
  open Utils

  let (linkToken, setLinkToken) = React.useState(_ => "")
  let (isReady, setIsReady) = React.useState(_ => false)
  let (pmAuthConnectorsArr, setPmAuthConnectorsArr) = React.useState(_ => [])
  let (publishableKey, setPublishableKey) = React.useState(_ => "")
  let (clientSecret, setClientSecret) = React.useState(_ => "")
  let (isForceSync, setIsForceSync) = React.useState(_ => false)
  let logger = React.useMemo(
    () => HyperLogger.make(~source=Elements(Payment), ~clientSecret, ~merchantId=publishableKey),
    (publishableKey, clientSecret),
  )

  React.useEffect(() => {
    let handleParentWindowMessage = (ev: Window.event) => {
      let json = ev.data->safeParse
      let metaData = json->getDictFromJson->getDictFromDict("metadata")
      let linkToken = metaData->getString("linkToken", "")

      if linkToken->String.length > 0 {
        setLinkToken(_ => linkToken)
        setPmAuthConnectorsArr(_ =>
          metaData->getArray("pmAuthConnectorArray")->Array.map(JSON.Decode.string)
        )
        setPublishableKey(_ => metaData->getString("publishableKey", ""))
        setClientSecret(_ => metaData->getString("clientSecret", ""))
        setIsForceSync(_ => metaData->getBool("isForceSync", false))
      }
    }
    Window.addEventListener("message", handleParentWindowMessage)
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    Some(() => Window.removeEventListener("message", handleParentWindowMessage))
  }, [])

  React.useEffect(() => {
    PmAuthConnectorUtils.mountAllRequriedAuthConnectorScripts(
      ~pmAuthConnectorsArr,
      ~onScriptLoaded=authConnector => {
        if authConnector->PmAuthConnectorUtils.pmAuthNameToTypeMapper === PLAID {
          setIsReady(_ => true)
        }
      },
      ~logger,
    )
    None
  }, [pmAuthConnectorsArr])

  let callbackOnSuccessOfPlaidPaymentsFlow = async () => {
    let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]

    try {
      let json = await PaymentHelpers.retrievePaymentIntent(
        clientSecret,
        headers,
        ~optLogger=Some(logger),
        ~customPodUri="",
        ~isForceSync=true,
      )
      let dict = json->getDictFromJson
      let status = dict->getString("status", "")
      let return_url = dict->getString("return_url", "")

      switch status {
      | "succeeded" | "requires_customer_action" | "processing" =>
        postSubmitResponse(~jsonData=json, ~url=return_url)
      | "failed" =>
        postFailedSubmitResponse(
          ~errortype="confirm_payment_failed",
          ~message="Payment failed. Try again!",
        )
      | _ =>
        postFailedSubmitResponse(
          ~errortype="sync_payment_failed",
          ~message="Payment is processing. Try again later!",
        )
      }
      messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
    } catch {
    | e => logInfo(Console.log2("Retrieve Failed", e))
    }
  }

  let initializePlaid = () => {
    Plaid.create({
      token: linkToken,
      onLoad: _ => logger.setLogInfo(~value="Plaid SDK Loaded", ~eventName=PLAID_SDK),
      onSuccess: (publicToken, _) => {
        messageParentWindow([
          ("isPlaid", true->JSON.Encode.bool),
          ("publicToken", publicToken->JSON.Encode.string),
        ])
        if isForceSync {
          callbackOnSuccessOfPlaidPaymentsFlow()->ignore
        }
      },
      onExit: _ => {
        if isForceSync {
          callbackOnSuccessOfPlaidPaymentsFlow()->ignore
        } else {
          messageParentWindow([
            ("fullscreen", false->JSON.Encode.bool),
            ("isPlaid", true->JSON.Encode.bool),
            ("isExited", true->JSON.Encode.bool),
            ("publicToken", ""->JSON.Encode.string),
          ])
        }
      },
    }).open_()
  }

  React.useEffect(() => {
    if isReady && linkToken->String.length > 0 {
      initializePlaid()
    }

    None
  }, (isReady, linkToken, logger))

  <div
    className="PlaidIframe h-screen w-screen bg-black/40 backdrop-blur-sm m-auto"
    style={
      transition: "opacity .35s ease .1s,background-color 600ms linear",
      opacity: "100",
    }
  />
}
