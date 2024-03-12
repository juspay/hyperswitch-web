@react.component
let make = (~sessionId, ~publishableKey, ~clientSecret, ~endpoint) => {
  open Utils
  let (paymentMethodsResponseSent, setPaymentMethodsResponseSent) = React.useState(_ => false)
  let (
    customerPaymentMethodsResponseSent,
    setCustomerPaymentMethodsResponseSent,
  ) = React.useState(_ => false)
  let (sessionTokensResponseSent, setSessionTokensResponseSent) = React.useState(_ => false)
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
        ~endpoint,
      ),
      PaymentHelpers.useCustomerDetails(
        ~clientSecret,
        ~publishableKey,
        ~optLogger=Some(logger),
        ~switchToCustomPod=false,
        ~endpoint,
      ),
      PaymentHelpers.useSessions(
        ~clientSecret,
        ~publishableKey,
        ~optLogger=Some(logger),
        ~switchToCustomPod=false,
        ~endpoint,
        (),
      ),
    )
  })

  let sendPromiseData = (promise, key) => {
    open Promise
    promise
    ->then(res => {
      handlePostMessage([("response", res), ("data", key->Js.Json.string)])
      switch key {
      | "payment_methods" => setPaymentMethodsResponseSent(_ => true)
      | "session_tokens" => setSessionTokensResponseSent(_ => true)
      | "customer_payment_methods" => setCustomerPaymentMethodsResponseSent(_ => true)
      | _ => ()
      }
      resolve()
    })
    ->catch(_err => {
      handlePostMessage([("response", Js.Json.null), ("data", key->Js.Json.string)])
      resolve()
    })
    ->ignore
  }

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

  React.useEffect0(() => {
    Window.addEventListener("message", handle)
    handlePostMessage([("preMountLoaderIframeMountedCallback", true->Js.Json.boolean)])
    Some(
      () => {
        Window.removeEventListener("message", handle)
      },
    )
  })

  React.useEffect3(() => {
    if (
      paymentMethodsResponseSent && customerPaymentMethodsResponseSent && sessionTokensResponseSent
    ) {
      handlePostMessage([("preMountLoaderIframeUnMount", true->Js.Json.boolean)])
      Window.removeEventListener("message", handle)
    }
    None
  }, (paymentMethodsResponseSent, customerPaymentMethodsResponseSent, sessionTokensResponseSent))

  React.null
}
