let sendPromiseData = (promise, key) => {
  open Promise
  promise
  ->then(res => resolve(res))
  ->catch(_ => resolve(JSON.Encode.null))
  ->thenResolve(response => {
    Utils.messageParentWindow([("response", response), ("data", key->JSON.Encode.string)])
  })
  ->ignore
}

let useMessageHandler = getPromisesAndMessageHandler => {
  React.useEffect0(() => {
    let (promises, messageHandler) = getPromisesAndMessageHandler()

    open Promise
    Promise.all(promises)
    ->thenResolve(_ => {
      Utils.messageParentWindow([("preMountLoaderIframeUnMount", true->JSON.Encode.bool)])
      Window.removeEventListener("message", messageHandler)
    })
    ->ignore

    Utils.messageParentWindow([("preMountLoaderIframeMountedCallback", true->JSON.Encode.bool)])
    Window.addEventListener("message", messageHandler)
    Some(() => Window.removeEventListener("message", messageHandler))
  })
}

module PreMountLoaderForElements = {
  @react.component
  let make = (~logger, ~publishableKey, ~clientSecret, ~endpoint, ~merchantHostname) => {
    useMessageHandler(() => {
      let paymentMethodsPromise = PaymentHelpers.fetchPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~switchToCustomPod=false,
        ~endpoint,
      )

      let customerPaymentMethodsPromise = PaymentHelpers.fetchCustomerPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~optLogger=Some(logger),
        ~switchToCustomPod=false,
        ~endpoint,
      )

      let sessionTokensPromise = PaymentHelpers.fetchSessions(
        ~clientSecret,
        ~publishableKey,
        ~optLogger=Some(logger),
        ~switchToCustomPod=false,
        ~endpoint,
        ~merchantHostname,
      )

      let messageHandler = (ev: Window.event) => {
        open Utils
        let dict = ev.data->safeParse->getDictFromJson
        if dict->isKeyPresentInDict("sendPaymentMethodsResponse") {
          paymentMethodsPromise->sendPromiseData("payment_methods")
        } else if dict->isKeyPresentInDict("sendCustomerPaymentMethodsResponse") {
          customerPaymentMethodsPromise->sendPromiseData("customer_payment_methods")
        } else if dict->isKeyPresentInDict("sendSessionTokensResponse") {
          sessionTokensPromise->sendPromiseData("session_tokens")
        }
      }

      let promises = [paymentMethodsPromise, customerPaymentMethodsPromise, sessionTokensPromise]
      (promises, messageHandler)
    })

    React.null
  }
}

module PreMountLoaderForPMMElements = {
  @react.component
  let make = (~logger, ~endpoint, ~ephemeralKey) => {
    useMessageHandler(() => {
      let savedPaymentMethodsPromise = PaymentHelpers.fetchSavedPaymentMethodList(
        ~ephemeralKey,
        ~optLogger=Some(logger),
        ~switchToCustomPod=false,
        ~endpoint,
      )

      let messageHandler = (ev: Window.event) => {
        open Utils
        let dict = ev.data->safeParse->getDictFromJson
        if dict->isKeyPresentInDict("sendSavedPaymentMethodsResponse") {
          savedPaymentMethodsPromise->sendPromiseData("saved_payment_methods")
        }
      }

      let promises = [savedPaymentMethodsPromise]
      (promises, messageHandler)
    })

    React.null
  }
}

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
  let logger = OrcaLogger.make(
    ~sessionId,
    ~source=Loader,
    ~merchantId=publishableKey,
    ~clientSecret,
  )

  switch hyperComponentName {
  | Elements =>
    <PreMountLoaderForElements logger publishableKey clientSecret endpoint merchantHostname />
  | PaymentMethodsManagementElements =>
    <PreMountLoaderForPMMElements logger endpoint ephemeralKey />
  }
}
