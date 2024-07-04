@react.component
let make = () => {
  open Utils

  let (linkToken, setLinkToken) = React.useState(_ => "")
  let (isReady, setIsReady) = React.useState(_ => false)
  let (pmAuthConnectorsArr, setPmAuthConnectorsArr) = React.useState(_ => [])
  let (publishableKey, setPublishableKey) = React.useState(_ => "")
  let (paymentId, setPaymentId) = React.useState(_ => "")
  let logger = React.useMemo(() => {
    OrcaLogger.make(~source=Loader, ~clientSecret=paymentId, ~merchantId=publishableKey, ())
  }, (publishableKey, paymentId))

  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let metaData = json->getDictFromJson->getDictFromDict("metadata")
      let linkToken = metaData->getString("linkToken", "")
      if linkToken->String.length > 0 {
        let pmAuthConnectorArray =
          metaData
          ->getArray("pmAuthConnectorArray")
          ->Array.map(ele => ele->JSON.Decode.string)

        setLinkToken(_ => linkToken)
        setPmAuthConnectorsArr(_ => pmAuthConnectorArray)
        setPublishableKey(_ => metaData->getString("payment_id", ""))
        setPaymentId(_ => metaData->getString("publishableKey", ""))
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

  React.useEffect(() => {
    if isReady && linkToken->String.length > 0 {
      let handler = Plaid.create({
        token: linkToken,
        onLoad: _ => {
          logger.setLogInfo(~value="Plaid SDK Loaded", ~eventName=PLAID_SDK_LOADED, ())
        },
        onSuccess: (publicToken, _) => {
          handlePostMessage([
            ("isPlaid", true->JSON.Encode.bool),
            ("publicToken", publicToken->JSON.Encode.string),
          ])
        },
        onExit: _ => {
          handlePostMessage([
            ("fullscreen", false->JSON.Encode.bool),
            ("isPlaid", true->JSON.Encode.bool),
            ("isExited", true->JSON.Encode.bool),
            ("publicToken", ""->JSON.Encode.string),
          ])
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
