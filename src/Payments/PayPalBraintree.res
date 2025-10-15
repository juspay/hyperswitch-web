open BraintreeTypes
open BraintreeHelpers
open Utils

@react.component
let make = (~sessionObj: option<SessionsType.token>) => {
  let sessionToken = sessionObj->Option.getOr(SessionsType.defaultToken)
  let paypalSDKUrl = generatePayPalSDKUrl(sessionToken.token)
  let updateSession = Recoil.useRecoilValueFromAtom(RecoilAtoms.updateSession)
  let {readyAll} = ScriptsHandler.useScripts([braintreeClientUrl, braintreePayPalUrl, paypalSDKUrl])
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let (connectors, _) = paymentMethodListValue->PaymentUtils.getConnectors(Wallets(Paypal(SDK)))
  let transactionInfo = sessionToken.transaction_info->getDictFromJson
  let createPaymentConfig = {
    flow: transactionInfo->getString("flow", ""),
    amount: transactionInfo->getFloat("total_price", 0.0),
    currency: transactionInfo->getString("currency_code", ""),
  }

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Paypal)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let paypalCheckoutInstanceRef = React.useRef(Nullable.null)

  let handlePayPalPayment = data => {
    switch paypalCheckoutInstanceRef.current->Nullable.toOption {
    | Some(paypalCheckoutInstance) =>
      paypalCheckoutInstance.tokenizePayment(data, (_err, payload) => {
        let body = PaymentBody.paypalSdkBody(~token=payload.nonce, ~connectors)
        intent(
          ~bodyArr=body,
          ~confirmParam={
            return_url: options.wallets.walletReturnUrl,
            publishableKey,
          },
        )
      })
    | None => Console.error("PayPal checkout instance is not initialized.")
    }
  }

  React.useEffect(() => {
    if readyAll {
      braintreeClientCreate({authorization: sessionToken.client_token}, (err, clientInstance) => {
        if !err {
          braintreePayPalCheckoutCreate(
            {
              client: clientInstance,
            },
            (paypalCheckoutErr, paypalCheckoutInstance) => {
              switch paypalCheckoutErr->Nullable.toOption {
              | Some(val) => Console.warn(`INTEGRATION ERROR: ${val.message}`)
              | None =>
                let element = Window.window->Window.document->Window.getElementById("paypal-button")
                switch element->Nullable.toOption {
                | Some(_) => {
                    paypalCheckoutInstanceRef.current = Nullable.make(paypalCheckoutInstance)
                    paypalCheckoutInstance.loadPayPalSDK(
                      {
                        currency: createPaymentConfig.currency,
                        intent: "authorize",
                      },
                      () => {
                        paypalSDK["Buttons"]({
                          style: paypalButtonStyle,
                          fundingSource: paypalSDK["FUNDING"]["PAYPAL"],
                          createOrder: () => {
                            switch paypalCheckoutInstanceRef.current->Nullable.toOption {
                            | Some(instance) =>
                              messageParentWindow([
                                ("fullscreen", true->JSON.Encode.bool),
                                ("param", "paymentloader"->JSON.Encode.string),
                                ("iframeId", iframeId->JSON.Encode.string),
                              ])
                              createPaymentConfig->instance.createPayment
                            | None => Console.error("PayPal checkout instance not found")
                            }
                          },
                          onApprove: (data, _) => handlePayPalPayment(data),
                          onCancel: _ =>
                            messageParentWindow([("fullscreen", false->JSON.Encode.bool)]),
                          onError: _ =>
                            messageParentWindow([("fullscreen", false->JSON.Encode.bool)]),
                        }).render("#paypal-button")
                      },
                    )
                  }
                | None => Console.error("Button container not found")
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
  }, [readyAll])

  <div className="w-full">
    <div
      id="paypal-button"
      style={pointerEvents: updateSession ? "none" : "auto", opacity: updateSession ? "0.5" : "1.0"}
    />
  </div>
}

let default = make
