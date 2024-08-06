@react.component
let make = (
  ~sessionId,
  ~publishableKey,
  ~clientSecret,
  ~endpoint,
  ~ephemeralKey,
  ~hyperComponentName: Types.hyperComponentName,
  ~merchantHostname,
) => {
  open Utils
  let (paymentMethodsResponseSent, setPaymentMethodsResponseSent) = React.useState(_ => false)
  let (
    customerPaymentMethodsResponseSent,
    setCustomerPaymentMethodsResponseSent,
  ) = React.useState(_ => false)
  let (savedPaymentMethodsResponseSent, setSavedPaymentMethodsResponseSent) = React.useState(_ =>
    false
  )
  let (sessionTokensResponseSent, setSessionTokensResponseSent) = React.useState(_ => false)
  let logger = OrcaLogger.make(
    ~sessionId,
    ~source=Loader,
    ~merchantId=publishableKey,
    ~clientSecret,
  )

  let (
    paymentMethodsResponse,
    customerPaymentMethodsResponse,
    sessionTokensResponse,
    savedPaymentMethodsResponse,
  ) = React.useMemo0(() => {
    let paymentMethodsResponse = switch hyperComponentName {
    | Elements =>
      PaymentHelpers.fetchPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~switchToCustomPod=false,
        ~endpoint,
      )
    | _ => JSON.Encode.null->Promise.resolve
    }

    let customerPaymentMethodsResponse = switch hyperComponentName {
    | Elements =>
      PaymentHelpers.fetchCustomerPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~optLogger=Some(logger),
        ~switchToCustomPod=false,
        ~endpoint,
      )
    | _ => JSON.Encode.null->Promise.resolve
    }

    let sessionTokensResponse = switch hyperComponentName {
    | Elements =>
      PaymentHelpers.fetchSessions(
        ~clientSecret,
        ~publishableKey,
        ~optLogger=Some(logger),
        ~switchToCustomPod=false,
        ~endpoint,
        ~merchantHostname,
      )
    | _ => JSON.Encode.null->Promise.resolve
    }

    let savedPaymentMethodsResponse = switch hyperComponentName {
    | PaymentMethodsManagementElements =>
      PaymentHelpers.fetchSavedPaymentMethodList(
        ~ephemeralKey,
        ~optLogger=Some(logger),
        ~switchToCustomPod=false,
        ~endpoint,
      )
    | _ => JSON.Encode.null->Promise.resolve
    }

    (
      paymentMethodsResponse,
      customerPaymentMethodsResponse,
      sessionTokensResponse,
      savedPaymentMethodsResponse,
    )
  })

  let sendPromiseData = (promise, key) => {
    open Promise
    promise
    ->then(res => {
      handlePostMessage([("response", res), ("data", key->JSON.Encode.string)])
      switch key {
      | "payment_methods" => setPaymentMethodsResponseSent(_ => true)
      | "session_tokens" => setSessionTokensResponseSent(_ => true)
      | "customer_payment_methods" => setCustomerPaymentMethodsResponseSent(_ => true)
      | "saved_payment_methods" => setSavedPaymentMethodsResponseSent(_ => true)
      | _ => ()
      }
      resolve()
    })
    ->catch(_err => {
      handlePostMessage([("response", JSON.Encode.null), ("data", key->JSON.Encode.string)])
      resolve()
    })
    ->ignore
  }

  let handle = (ev: Window.event) => {
    let json = ev.data->safeParse
    let dict = json->Utils.getDictFromJson
    if dict->Dict.get("sendPaymentMethodsResponse")->Option.isSome {
      paymentMethodsResponse->sendPromiseData("payment_methods")
    } else if dict->Dict.get("sendCustomerPaymentMethodsResponse")->Option.isSome {
      customerPaymentMethodsResponse->sendPromiseData("customer_payment_methods")
    } else if dict->Dict.get("sendSessionTokensResponse")->Option.isSome {
      sessionTokensResponse->sendPromiseData("session_tokens")
    } else if dict->Dict.get("sendSavedPaymentMethodsResponse")->Belt.Option.isSome {
      savedPaymentMethodsResponse->sendPromiseData("saved_payment_methods")
    }
  }

  React.useEffect0(() => {
    Window.addEventListener("message", handle)
    handlePostMessage([("preMountLoaderIframeMountedCallback", true->JSON.Encode.bool)])
    Some(
      () => {
        Window.removeEventListener("message", handle)
      },
    )
  })

  React.useEffect4(() => {
    let handleUnmount = () => {
      handlePostMessage([("preMountLoaderIframeUnMount", true->JSON.Encode.bool)])
      Window.removeEventListener("message", handle)
    }

    switch hyperComponentName {
    | Elements =>
      if (
        paymentMethodsResponseSent &&
        customerPaymentMethodsResponseSent &&
        sessionTokensResponseSent
      ) {
        handleUnmount()
      }
    | PaymentMethodsManagementElements =>
      if savedPaymentMethodsResponseSent {
        handleUnmount()
      }
    }

    None
  }, (
    paymentMethodsResponseSent,
    customerPaymentMethodsResponseSent,
    sessionTokensResponseSent,
    savedPaymentMethodsResponseSent,
  ))

  React.null
}
