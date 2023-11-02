@react.component
let make = (~sessionId, ~publishableKey, ~clientSecret) => {
  open Utils
  let logger = OrcaLogger.make(
    ~sessionId,
    ~source=Loader,
    ~merchantId=publishableKey,
    ~clientSecret,
    (),
  )

  let (
    paymentMethodsResponse,
    customerPaymentMethodsResponse,
    sessionTokensResponse,
  ) = React.useMemo0(() => {
    (
      PaymentHelpers.usePaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~switchToCustomPod=false,
        ~endpoint=ApiEndpoint.getApiEndPoint(~publishableKey, ()),
      ),
      PaymentHelpers.useCustomerDetails(
        ~clientSecret,
        ~publishableKey,
        ~optLogger=Some(logger),
        ~switchToCustomPod=false,
        ~endpoint=ApiEndpoint.getApiEndPoint(~publishableKey, ()),
      ),
      PaymentHelpers.useSessions(
        ~clientSecret,
        ~publishableKey,
        ~optLogger=Some(logger),
        ~switchToCustomPod=false,
        ~endpoint=ApiEndpoint.getApiEndPoint(~publishableKey, ()),
        (),
      ),
    )
  })

  let sendPromiseData = (promise, key) => {
    open Promise
    promise
    ->then(res => {
      handlePostMessage([("response", res), ("data", key->Js.Json.string)])
      resolve()
    })
    ->catch(_err => {
      handlePostMessage([("response", Js.Json.null), ("data", key->Js.Json.string)])
      resolve()
    })
    ->ignore
  }

  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      let json = try {
        ev.data->Js.Json.parseExn
      } catch {
      | _ => Js.Json.null
      }
      let dict = json->Utils.getDictFromJson
      if dict->Js.Dict.get("sendPaymentMethodsResponse")->Belt.Option.isSome {
        paymentMethodsResponse->sendPromiseData("payment_methods")
      } else if dict->Js.Dict.get("sendCustomerPaymentMethodsResponse")->Belt.Option.isSome {
        customerPaymentMethodsResponse->sendPromiseData("customer_payment_methods")
      } else if dict->Js.Dict.get("sendSessionTokensResponse")->Belt.Option.isSome {
        sessionTokensResponse->sendPromiseData("session_tokens")
      }
    }
    Window.addEventListener("message", handle)
    handlePostMessage([("preMountLoaderInitCallback", true->Js.Json.boolean)])
    Some(
      () => {
        Window.removeEventListener("message", handle)
      },
    )
  })

  React.null
}
