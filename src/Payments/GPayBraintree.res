open BraintreeTypes
open BraintreeHelpers

@react.component
let make = (~sessionObj: option<SessionsType.token>) => {
  let sessionToken = sessionObj->Option.getOr(SessionsType.defaultToken)
  let braintreeClientLoadStatus = CommonHooks.useScript(braintreeClientUrl)
  let braintreeGPayScriptLoadStatus = CommonHooks.useScript(braintreeGPayUrl)
  let gPayScriptLoadStatus = CommonHooks.useScript(googlePayUrl)

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Gpay)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let gPayInstanceRef = React.useRef(Nullable.null)
  let paymentClientRef = React.useRef(Nullable.null)

  let handleGPayButtonClick = async () => {
    switch gPayInstanceRef.current->Nullable.toOption {
    | Some(gPayInstance) => {
        let request = gPayInstance.createPaymentDataRequest(createGpayTransactionInfo(sessionToken))
        switch paymentClientRef.current->Nullable.toOption {
        | Some(paymentClient) =>
          try {
            Utils.messageParentWindow([
              ("fullscreen", true->JSON.Encode.bool),
              ("param", "paymentloader"->JSON.Encode.string),
              ("iframeId", iframeId->JSON.Encode.string),
            ])
            let paymentData = await paymentClient.loadPaymentData(request)
            let payload = await gPayInstance.parseResponse(paymentData)
            let payloadDict = payload->Utils.getDictFromJson
            let payObj = createPayObj(payloadDict)
            let connectors = ["braintree"]
            let body = PaymentBody.gpayBody(~payObj, ~connectors)
            intent(
              ~bodyArr=body,
              ~confirmParam={
                return_url: options.wallets.walletReturnUrl,
                publishableKey,
              },
              ~handleUserError=true,
              ~isThirdPartyFlow=true,
              ~manualRetry=isManualRetryEnabled,
            )
          } catch {
          | _ => Utils.messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
          }
        | None => Console.error("Payment client is not initialized.")
        }
      }
    | None => Console.error("Google Pay instance is not initialized.")
    }
  }

  React.useEffect(() => {
    let areRequiredScriptsLoaded =
      braintreeClientLoadStatus == "ready" &&
      braintreeGPayScriptLoadStatus == "ready" &&
      gPayScriptLoadStatus == "ready"

    Console.log3(braintreeClientLoadStatus, braintreeGPayScriptLoadStatus, gPayScriptLoadStatus)

    if areRequiredScriptsLoaded {
      braintreeClientCreate({authorization: braintreeToken}, (err, clientInstance) => {
        if !err {
          braintreeGPayPaymentCreate(
            clientInstance->createGooglePayConfig,
            (err, gPayInstance) => {
              if !err {
                gPayInstanceRef.current = Nullable.make(gPayInstance)
                paymentClientRef.current = Nullable.make(
                  newGPayPaymentClient({environment: environment}),
                )

                switch paymentClientRef.current->Nullable.toOption {
                | Some(client) => {
                    let button = client.createButton({
                      onClick: handleGPayButtonClick,
                      buttonSizeMode,
                      // buttonType,
                    })
                    let buttonMountPoint =
                      Window.window->Window.document->Window.getElementById("google-pay-button")

                    switch buttonMountPoint->Nullable.toOption {
                    | Some(mountPoint) => mountPoint->appendChildElement(button)
                    | None => Console.error("Mount point for Google Pay button not found.")
                    }
                  }
                | None => Console.error("Payment client is not initialized.")
                }
              } else {
                Console.error("Failed to create Google Pay instance.")
              }
            },
          )
        } else {
          Console.error("Failed to create Braintree client instance.")
        }
      })
    }
    None
  }, (braintreeClientLoadStatus, braintreeGPayScriptLoadStatus, gPayScriptLoadStatus))

  <div className="w-full">
    <div id="google-pay-button" />
  </div>
}

let default = make
