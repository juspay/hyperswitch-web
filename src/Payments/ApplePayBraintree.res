open BraintreeTypes
open BraintreeHelpers

@react.component
let make = (~sessionObj: JSON.t) => {
  let braintreeClientLoadStatus = CommonHooks.useScript(braintreeClientUrl)
  let braintreeApplePayScriptLoadStatus = CommonHooks.useScript(braintreeApplePayUrl)

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Gpay)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let applePayInstanceRef = React.useRef(Nullable.null)

  let handleApplePayButtonClick = _ =>
    if (
      !(applePayInstanceRef.current->Nullable.isNullable) &&
      !(braintreeApplePaySession->Nullable.isNullable)
    ) {
      switch applePayInstanceRef.current->Nullable.toOption {
      | Some(applePayInstance) =>
        let paymentRequest =
          sessionObj->createApplePayTransactionInfo->applePayInstance.createPaymentRequest
        let sessions = newApplePaySession(3, paymentRequest)
        sessions.onvalidatemerchant = event => {
          applePayInstance.performValidation(
            {
              validationURL: event.validationURL,
              displayName: "My Store",
            },
            (err, merchantSession) => {
              if !err {
                sessions.completeMerchantValidation(merchantSession)
              } else {
                Console.log("Failed to validate merchant session.")
                sessions.abort()
              }
            },
          )
        }
        sessions.onpaymentauthorized = event => {
          applePayInstance.tokenize(
            {
              token: event.payment.token,
            },
            (err, payload) => {
              if !err {
                sessions.completePayment(applePaySession.\"STATUS_SUCCESS")
                let nonce = payload.nonce
                Console.log2("Apple Pay nonce received:", nonce)
                //
                //
                //
                // INTENT CALL
                //
                //
                //
              } else {
                sessions.completePayment(applePaySession.\"STATUS_FAILURE")
              }
            },
          )
        }
        sessions.oncancel = _ => {
          Console.log("Apple Pay payment was cancelled.")
        }
        sessions.begin()
      | None => Console.error("Apple Pay instance is not available")
      }
    } else {
      Console.log("apple pay not working")
    }

  React.useEffect(() => {
    let areRequiredScriptsLoaded =
      braintreeClientLoadStatus == "ready" && braintreeApplePayScriptLoadStatus == "ready"

    Console.log2(braintreeClientLoadStatus, braintreeApplePayScriptLoadStatus)

    if areRequiredScriptsLoaded {
      braintreeClientCreate({authorization: braintreeToken}, (err, clientInstance) => {
        if !err {
          braintreeApplePayPaymentCreate(
            clientInstance->createApplePayConfig,
            (err, applePayInstance) => {
              if !err {
                applePayInstanceRef.current = Nullable.make(applePayInstance)
                Console.log("Apple Pay instance created successfully.")
              } else {
                Console.error("Failed to create Apple Pay instance.")
              }
            },
          )
        } else {
          Console.error("Failed to create Braintree client instance.")
        }
      })
    }
    None
  }, (braintreeClientLoadStatus, braintreeApplePayScriptLoadStatus))

  <div className="w-full">
    <button
      id="apple-pay-button"
      className="w-full p-2 flex justify-center items-center border-2 border-black"
      onClick=handleApplePayButtonClick>
      {"Apple Pay"->React.string}
    </button>
  </div>
}

let default = make
