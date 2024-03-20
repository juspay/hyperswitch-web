@react.component
let make = (~sessionId as _, ~publishableKey as _, ~clientSecret as _, ~endpoint as _) => {
  // open Utils
  // let logger = OrcaLogger.make(
  //   ~sessionId,
  //   ~source=Loader,
  //   ~merchantId=publishableKey,
  //   ~clientSecret,
  //   (),
  // )

  // // let (
  // //   paymentMethodsResponse,
  // //   customerPaymentMethodsResponse,
  // //   sessionTokensResponse,
  // // ) = React.useMemo0(() => {
  // //   (
  // //     PaymentHelpers.fetchPaymentMethodList(
  // //       ~clientSecret,
  // //       ~publishableKey,
  // //       ~logger,
  // //       ~switchToCustomPod=false,
  // //       ~endpoint,
  // //     ),
  // //     PaymentHelpers.fetchCustomerDetails(
  // //       ~clientSecret,
  // //       ~publishableKey,
  // //       ~optLogger=Some(logger),
  // //       ~switchToCustomPod=false,
  // //       ~endpoint,
  // //     ),
  // //     PaymentHelpers.fetchSessions(
  // //       ~clientSecret,
  // //       ~publishableKey,
  // //       ~optLogger=Some(logger),
  // //       ~switchToCustomPod=false,
  // //       ~endpoint,
  // //       (),
  // //     ),
  // //   )
  // // })

  // // let sendPromiseData = (promise, key) => {
  // //   open Promise
  // //   promise
  // //   ->then(res => {
  // //     handlePostMessage([("response", res), ("data", key->JSON.Encode.string)])
  // //     resolve()
  // //   })
  // //   ->catch(_err => {
  // //     handlePostMessage([("response", JSON.Encode.null), ("data", key->JSON.Encode.string)])
  // //     resolve()
  // //   })
  // //   ->ignore
  // // }

  // // React.useEffect0(() => {
  // //   let handle = (ev: Window.event) => {
  // //     let json = try {
  // //       ev.data->JSON.parseExn
  // //     } catch {
  // //     | _ => JSON.Encode.null
  // //     }
  // //     let dict = json->Utils.getDictFromJson
  // //     if dict->Dict.get("sendPaymentMethodsResponse")->Option.isSome {
  // //       paymentMethodsResponse->sendPromiseData("payment_methods")
  // //     } else if dict->Dict.get("sendCustomerPaymentMethodsResponse")->Option.isSome {
  // //       customerPaymentMethodsResponse->sendPromiseData("customer_payment_methods")
  // //     } else if dict->Dict.get("sendSessionTokensResponse")->Option.isSome {
  // //       sessionTokensResponse->sendPromiseData("session_tokens")
  // //     }
  // //   }
  // //   Window.addEventListener("message", handle)
  // //   handlePostMessage([("preMountLoaderInitCallback", true->JSON.Encode.bool)])
  // //   Some(
  // //     () => {
  // //       Window.removeEventListener("message", handle)
  // //     },
  // //   )
  // // })

  React.null
}
