let sendPromiseData = (promise, key) => {
  let executePromise = async () => {
    let response = try {
      await promise
    } catch {
    | _ => JSON.Encode.null
    }
    Utils.messageParentWindow([("response", response), ("data", key->JSON.Encode.string)])
  }
  executePromise()->ignore
}

let useMessageHandler = getPromisesAndHandler => {
  React.useEffect(_ => {
    let (promises, messageHandler) = getPromisesAndHandler()
    let setupMessageListener = _ => {
      Utils.messageParentWindow([("preMountLoaderIframeMountedCallback", true->JSON.Encode.bool)])
      Window.addEventListener("message", messageHandler)
    }

    let cleanupMessageListener = _ => {
      Utils.messageParentWindow([("preMountLoaderIframeUnMount", true->JSON.Encode.bool)])
      Window.removeEventListener("message", messageHandler)
    }

    setupMessageListener()

    let executeAllPromises = async () => {
      try {
        let _ = await Promise.all(promises)
      } catch {
      | error => Console.error2("Error in message handler:", error)
      }
      cleanupMessageListener()
    }
    executeAllPromises()->ignore

    Some(cleanupMessageListener)
  }, [])
}

module PreMountLoaderForElements = {
  @react.component
  let make = (
    ~logger,
    ~publishableKey,
    ~clientSecret,
    ~endpoint,
    ~merchantHostname,
    ~customPodUri,
  ) => {
    useMessageHandler(() => {
      let paymentMethodsPromise = PaymentHelpers.fetchPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
      )

      let customerPaymentMethodsPromise = PaymentHelpers.fetchCustomerPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~optLogger=Some(logger),
        ~customPodUri,
        ~endpoint,
      )

      let sessionTokensPromise = PaymentHelpers.fetchSessions(
        ~clientSecret,
        ~publishableKey,
        ~optLogger=Some(logger),
        ~customPodUri,
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
  let make = (~logger, ~endpoint, ~ephemeralKey, ~customPodUri, ~pmSessionId, ~pmClientSecret) => {
    useMessageHandler(() => {
      switch GlobalVars.sdkVersionEnum {
      | V2 => {
          let listPromise = PaymentHelpersV2.fetchPaymentManagementList(
            ~pmSessionId,
            ~pmClientSecret,
            ~optLogger=Some(logger),
            ~customPodUri,
            ~endpoint,
          )

          let messageHandler = (ev: Window.event) => {
            open Utils
            let dict = ev.data->safeParse->getDictFromJson
            if dict->isKeyPresentInDict("sendPaymentManagementListResponse") {
              listPromise->sendPromiseData("payment_management_list")
            }
          }

          let promises = [listPromise]
          (promises, messageHandler)
        }
      | V1 => {
          let savedPaymentMethodsPromise = PaymentHelpers.fetchSavedPaymentMethodList(
            ~ephemeralKey,
            ~optLogger=Some(logger),
            ~customPodUri,
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
        }
      }
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
  ~pmSessionId,
  ~pmClientSecret,
  ~hyperComponentName: Types.hyperComponentName,
  ~merchantHostname,
  ~customPodUri,
) => {
  let logger = HyperLogger.make(
    ~sessionId,
    ~source=Loader,
    ~merchantId=publishableKey,
    ~clientSecret,
  )

  switch hyperComponentName {
  | Elements =>
    <PreMountLoaderForElements
      logger publishableKey clientSecret endpoint merchantHostname customPodUri
    />
  | PaymentMethodsManagementElements =>
    <PreMountLoaderForPMMElements
      logger endpoint ephemeralKey customPodUri pmSessionId pmClientSecret
    />
  }
}
