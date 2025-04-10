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

let useMessageHandler = getMessageHandler => {
  React.useEffect(_ => {
    let messageHandler = getMessageHandler()

    let setupMessageListener = _ => {
      Window.addEventListener("message", messageHandler)
      Utils.messageParentWindow([("preMountLoaderIframeMountedCallback", true->JSON.Encode.bool)])
    }

    let cleanupMessageListener = _ => {
      Window.removeEventListener("message", messageHandler)
      Utils.messageParentWindow([("preMountLoaderIframeUnMount", true->JSON.Encode.bool)])
    }

    let handleCleanUpEventListener = (ev: Window.event) => {
      open Utils
      let dict = ev.data->safeParse->getDictFromJson
      if dict->Dict.get("cleanUpPreMountLoaderIframe")->Option.isSome {
        cleanupMessageListener()
      }
    }

    Window.addEventListener("message", handleCleanUpEventListener)

    setupMessageListener()

    Some(
      () => {
        cleanupMessageListener()
        Window.removeEventListener("message", handleCleanUpEventListener)
      },
    )
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

      messageHandler
    })

    React.null
  }
}

module PreMountLoaderForPMMElements = {
  @react.component
  let make = (
    ~logger,
    ~endpoint,
    ~ephemeralKey,
    ~customPodUri,
    ~pmSessionId,
    ~pmClientSecret,
    ~publishableKey,
    ~profileId,
  ) => {
    useMessageHandler(() => {
      switch GlobalVars.sdkVersion {
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

          messageHandler
        }
      | V2 => {
          let listPromise = PaymentHelpersV2.fetchPaymentManagementList(
            ~pmSessionId,
            ~pmClientSecret,
            ~publishableKey,
            ~profileId,
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

          messageHandler
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
  ~profileId,
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
      logger endpoint ephemeralKey customPodUri pmSessionId pmClientSecret publishableKey profileId
    />
  }
}
