@react.component
let make = () => {
  open Utils

  let (linkToken, setLinkToken) = React.useState(_ => "")
  let (isReady, setIsReady) = React.useState(_ => false)
  let (pmAuthConnectorsArr, setPmAuthConnectorsArr) = React.useState(_ => [])
  let (publishableKey, setPublishableKey) = React.useState(_ => "")
  let (clientSecret, setClientSecret) = React.useState(_ => "")
  let (sdkAuthorization, setSdkAuthorization) = React.useState(_ => "")
  let (isForceSync, setIsForceSync) = React.useState(_ => false)

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
        setSdkAuthorization(_ => metaData->getString("sdkAuthorization", ""))
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
    )
    None
  }, [pmAuthConnectorsArr])

  let callbackOnSuccessOfPlaidPaymentsFlow = async () => {
    try {
      let json = await PaymentHelpers.retrievePaymentIntent(
        clientSecret,
        ~publishableKey,
        ~customPodUri="",
        ~isForceSync=true,
        ~sdkAuthorization=Some(sdkAuthorization),
      )
      let dict = json->getDictFromJson
      let status = dict->getString("status", "")
      let return_url = dict->getString("return_url", "")

      let failureMessage = switch status {
      | "failed" => "Payment failed. Try again!"
      | _ => "Payment is processing. Try again later!"
      }
      switch status {
      | "succeeded" | "requires_customer_action" | "processing" => ()
      | _ =>
        SdkLogger.logLifecycle(
          ~event=BankAuthSyncFailed({status: status}),
          ~paymentMethod=OpenBanking(Plaid),
          ~message=failureMessage,
        )
      }
      switch status {
      | "succeeded" | "requires_customer_action" | "processing" =>
        postSubmitResponse(~jsonData=json, ~url=return_url)
      | "failed" =>
        postFailedSubmitResponse(~errortype="confirm_payment_failed", ~message=failureMessage)
      | _ => postFailedSubmitResponse(~errortype="sync_payment_failed", ~message=failureMessage)
      }
      messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
    } catch {
    | exn =>
      SdkLogger.logLifecycle(
        ~event=BankAuthSyncFailed({status: "sync_exception"}),
        ~paymentMethod=OpenBanking(Plaid),
        ~exn,
      )
    }
  }

  let initializePlaid = () => {
    let startedAt = Date.now()
    SdkLogger.logFunction(~event=PlaidCreate, ~outcome=Started, ~paymentMethod=OpenBanking(Plaid))
    Plaid.create({
      token: linkToken,
      onLoad: SdkLogger.observeFunctionCallback(
        ~event=OnLoad,
        ~paymentMethod=OpenBanking(Plaid),
        ~callback=() =>
          SdkLogger.logFunction(
            ~event=PlaidCreate,
            ~outcome=Done,
            ~startedAt,
            ~paymentMethod=OpenBanking(Plaid),
          ),
      ),
      onSuccess: SdkLogger.observeFunctionCallback(
        ~event=OnSuccess,
        ~paymentMethod=OpenBanking(Plaid),
        ~callback=(publicToken, _) => {
          messageParentWindow([
            ("isPlaid", true->JSON.Encode.bool),
            ("publicToken", publicToken->JSON.Encode.string),
          ])
          if isForceSync {
            callbackOnSuccessOfPlaidPaymentsFlow()->ignore
          }
        },
      ),
      onExit: SdkLogger.observeFunctionCallback(
        ~event=OnExit,
        ~paymentMethod=OpenBanking(Plaid),
        ~callback=_ =>
          if isForceSync {
            callbackOnSuccessOfPlaidPaymentsFlow()->ignore
          } else {
            messageParentWindow([
              ("fullscreen", false->JSON.Encode.bool),
              ("isPlaid", true->JSON.Encode.bool),
              ("isExited", true->JSON.Encode.bool),
              ("publicToken", ""->JSON.Encode.string),
            ])
          },
      ),
    }).open_()
  }

  React.useEffect(() => {
    if isReady && linkToken->String.length > 0 {
      initializePlaid()
    }

    None
  }, (isReady, linkToken))

  <div
    className="PlaidIframe h-screen w-screen bg-black/40 backdrop-blur-sm m-auto"
    style={
      transition: "opacity .35s ease .1s,background-color 600ms linear",
      opacity: "100",
    }
  />
}
