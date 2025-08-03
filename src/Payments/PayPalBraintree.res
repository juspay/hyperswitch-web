open BraintreeTypes
open BraintreeHelpers

@react.component
let make = (~sessionObj: option<SessionsType.token>) => {
  Console.log2("PayPal SDK component loaded with sessionObj:", sessionObj)
  let sessionToken = sessionObj->Option.getOr(SessionsType.defaultToken)
  let braintreeClientLoadStatus = CommonHooks.useScript(braintreeClientUrl)
  let braintreePayPalScriptLoadStatus = CommonHooks.useScript(braintreePayPalUrl)
  let paypalSDKUrl = generatePayPalSDKUrl(sessionToken.token)
  let paypalSDKLoadStatus = CommonHooks.useScript(paypalSDKUrl)

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Paypal)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let paypalCheckoutInstanceRef = React.useRef(Nullable.null)

  let handlePayPalPayment = data => {
    switch paypalCheckoutInstanceRef.current->Nullable.toOption {
    | Some(paypalCheckoutInstance) =>
      paypalCheckoutInstance.tokenizePayment(data, (_err, payload) => {
        let connectors = ["braintree"]
        let body = PaymentBody.paypalSdkBody(~token=payload.nonce, ~connectors)

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
      })
    | None => Console.error("PayPal checkout instance is not initialized.")
    }
  }

  React.useEffect(() => {
    let areRequiredScriptsLoaded =
      braintreeClientLoadStatus == "ready" &&
      braintreePayPalScriptLoadStatus == "ready" &&
      paypalSDKLoadStatus == "ready"

    Console.log3(braintreeClientLoadStatus, braintreePayPalScriptLoadStatus, paypalSDKLoadStatus)

    if areRequiredScriptsLoaded {
      braintreeClientCreate({authorization: braintreeToken}, (err, clientInstance) => {
        if !err {
          braintreePayPalCheckoutCreate(
            createPayPalCheckoutConfig(clientInstance),
            (paypalCheckoutErr, paypalCheckoutInstance) => {
              switch paypalCheckoutErr->Nullable.toOption {
              | Some(val) => Console.warn(`INTEGRATION ERROR: ${val.message}`)
              | None => {
                  paypalCheckoutInstanceRef.current = Nullable.make(paypalCheckoutInstance)

                  paypalCheckoutInstance.loadPayPalSDK(
                    {
                      currency: "USD",
                      intent: "authorize",
                    },
                    () => {
                      paypalSDK["Buttons"]({
                        style: {
                          layout: "vertical",
                          color: "blue",
                          shape: "rect",
                          label: "paypal",
                          height: 40,
                        },
                        fundingSource: paypalSDK["FUNDING"]["PAYPAL"],
                        createOrder: () => {
                          switch paypalCheckoutInstanceRef.current->Nullable.toOption {
                          | Some(instance) =>
                            Utils.messageParentWindow([
                              ("fullscreen", true->JSON.Encode.bool),
                              ("param", "paymentloader"->JSON.Encode.string),
                              ("iframeId", iframeId->JSON.Encode.string),
                            ])
                            instance.createPayment({
                              flow: "checkout",
                              amount: 1500.00,
                              currency: "USD",
                            })
                          | None =>
                            Console.error("PayPal checkout instance not found")
                            ""
                          }
                        },
                        onApprove: (data, _actions) => {
                          handlePayPalPayment(data)
                        },
                        onCancel: _data => {
                          Utils.messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
                        },
                        onError: _err => {
                          Utils.messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
                        },
                      }).render("#paypal-button")
                    },
                  )
                }
              }
            },
          )
        } else {
          Console.error("Failed to create Braintree client instance.")
        }
      })
    }
    None
  }, (braintreeClientLoadStatus, braintreePayPalScriptLoadStatus, paypalSDKLoadStatus))

  <div className="w-full">
    <div id="paypal-button" />
  </div>
}

let default = make
