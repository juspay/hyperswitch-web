@react.component
let make = () => {
  open Utils

  let (linkToken, setLinkToken) = React.useState(_ => "")
  let (isReady, setIsReady) = React.useState(_ => false)
  let (pmAuthConnectorsArr, setPmAuthConnectorsArr) = React.useState(_ => [])
  let (publishableKey, setPublishableKey) = React.useState(_ => "")
  let (clientSecret, setClientSecret) = React.useState(_ => "")
  let (isForceSync, setIsForceSync) = React.useState(_ => false)
  let logger = React.useMemo(() => {
    OrcaLogger.make(~source=Elements(Payment), ~clientSecret, ~merchantId=publishableKey)
  }, (publishableKey, clientSecret))

  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let metaData = json->getDictFromJson->getDictFromDict("metadata")
      let linkToken = metaData->getString("linkToken", "")
      if linkToken->String.length > 0 {
        let pmAuthConnectorArray =
          metaData
          ->getArray("pmAuthConnectorArray")
          ->Array.map(ele => ele->JSON.Decode.string)

        setLinkToken(_ => linkToken)
        setPmAuthConnectorsArr(_ => pmAuthConnectorArray)
        setPublishableKey(_ => metaData->getString("publishableKey", ""))
        setClientSecret(_ => metaData->getString("clientSecret", ""))
        setIsForceSync(_ => metaData->getBool("isForceSync", false))
      }
    }
    Window.addEventListener("message", handle)
    handlePostMessage([("iframeMountedCallback", true->JSON.Encode.bool)])
    Some(() => {Window.removeEventListener("message", handle)})
  })

  React.useEffect(() => {
    PmAuthConnectorUtils.mountAllRequriedAuthConnectorScripts(
      ~pmAuthConnectorsArr,
      ~onScriptLoaded=authConnector => {
        switch authConnector->PmAuthConnectorUtils.pmAuthNameToTypeMapper {
        | PLAID => setIsReady(_ => true)
        | NONE => ()
        }
      },
      ~logger,
    )
    None
  }, [pmAuthConnectorsArr])

  let callbackOnSuccessOfPlaidPaymentsFlow = () => {
    open Promise
    let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]

    PaymentHelpers.retrievePaymentIntent(
      clientSecret,
      headers,
      ~optLogger=Some(logger),
      ~switchToCustomPod=false,
      ~isForceSync=true,
    )
    ->then(json => {
      let dict = json->getDictFromJson
      let status = dict->getString("status", "")
      let return_url = dict->getString("return_url", "")

      if (
        status === "succeeded" || status === "requires_customer_action" || status === "processing"
      ) {
        postSubmitResponse(~jsonData=json, ~url=return_url)
      } else if status === "failed" {
        postFailedSubmitResponse(
          ~errortype="confirm_payment_failed",
          ~message="Payment failed. Try again!",
        )
      } else {
        postFailedSubmitResponse(
          ~errortype="sync_payment_failed",
          ~message="Payment is processing. Try again later!",
        )
      }
      handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
      resolve(json)
    })
    ->then(_ => {
      resolve(Nullable.null)
    })
    ->catch(e => {
      logInfo(Console.log2("Retrieve Failed", e))
      resolve(Nullable.null)
    })
    ->ignore
  }

  React.useEffect(() => {
    if isReady && linkToken->String.length > 0 {
      let handler = Plaid.create({
        token: linkToken,
        onLoad: _ => {
          logger.setLogInfo(~value="Plaid SDK Loaded", ~eventName=PLAID_SDK)
        },
        onSuccess: (publicToken, _) => {
          handlePostMessage([
            ("isPlaid", true->JSON.Encode.bool),
            ("publicToken", publicToken->JSON.Encode.string),
          ])
          if isForceSync {
            callbackOnSuccessOfPlaidPaymentsFlow()
          }
        },
        onExit: _ => {
          if isForceSync {
            callbackOnSuccessOfPlaidPaymentsFlow()
          } else {
            handlePostMessage([
              ("fullscreen", false->JSON.Encode.bool),
              ("isPlaid", true->JSON.Encode.bool),
              ("isExited", true->JSON.Encode.bool),
              ("publicToken", ""->JSON.Encode.string),
            ])
          }
        },
      })

      handler.open_()
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
