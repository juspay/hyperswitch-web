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

let getMessageHandlerV1Elements = (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~merchantHostname,
  ~isTestMode=false,
) => {
  let (
    paymentMethodsPromise,
    customerPaymentMethodsPromise,
    sessionTokensPromise,
    blockedBinsPromise,
  ) = if isTestMode {
    let mockResponse = Dict.make()->JSON.Encode.object

    (
      Promise.resolve(mockResponse),
      Promise.resolve(mockResponse),
      Promise.resolve(mockResponse),
      Promise.resolve(mockResponse),
    )
  } else {
    (
      PaymentHelpers.fetchPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
      ),
      PaymentHelpers.fetchCustomerPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
      ),
      PaymentHelpers.fetchSessions(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~merchantHostname,
      ),
      PaymentHelpers.fetchBlockedBins(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
      ),
    )
  }

  ev => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendPaymentMethodsResponse") {
      paymentMethodsPromise->sendPromiseData("payment_methods")
    } else if dict->isKeyPresentInDict("sendCustomerPaymentMethodsResponse") {
      customerPaymentMethodsPromise->sendPromiseData("customer_payment_methods")
    } else if dict->isKeyPresentInDict("sendSessionTokensResponse") {
      sessionTokensPromise->sendPromiseData("session_tokens")
    } else if dict->isKeyPresentInDict("sendBlockedBinsResponse") {
      blockedBinsPromise->sendPromiseData("blocked_bins")
    }
  }
}

let getMessageHandlerV2Elements = (
  ~clientSecret,
  ~paymentId,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~profileId,
) => {
  let paymentMethodsListPromise = PaymentHelpersV2.fetchPaymentMethodList(
    ~clientSecret,
    ~paymentId,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
    ~profileId,
  )

  let sessionTokensPromise = PaymentHelpersV2.fetchSessions(
    ~clientSecret,
    ~paymentId,
    ~profileId,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
  )

  let getIntentPromise = PaymentHelpersV2.fetchIntent(
    ~clientSecret,
    ~paymentId,
    ~profileId,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
  )

  ev => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendPaymentMethodsListV2Response") {
      paymentMethodsListPromise->sendPromiseData("payment_methods_list_v2")
    } else if dict->isKeyPresentInDict("sendSessionTokensResponse") {
      sessionTokensPromise->sendPromiseData("session_tokens")
    } else if dict->isKeyPresentInDict("sendGetIntentResponse") {
      getIntentPromise->sendPromiseData("get_intent_v2")
    }
  }
}

let getMessageHandlerV1PMM = (~ephemeralKey, ~logger, ~customPodUri, ~endpoint) => {
  let savedPaymentMethodsPromise = PaymentHelpers.fetchSavedPaymentMethodList(
    ~ephemeralKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
  )

  ev => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendSavedPaymentMethodsResponse") {
      savedPaymentMethodsPromise->sendPromiseData("saved_payment_methods")
    }
  }
}

let getMessageHandlerV2PMM = (
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  ~profileId,
  ~logger,
  ~customPodUri,
  ~endpoint,
) => {
  let listPromise = PaymentHelpersV2.fetchPaymentManagementList(
    ~pmSessionId,
    ~pmClientSecret,
    ~publishableKey,
    ~profileId,
    ~optLogger=Some(logger),
    ~customPodUri,
    ~endpoint,
  )

  ev => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendPaymentManagementListResponse") {
      listPromise->sendPromiseData("payment_management_list")
    }
  }
}

module PreMountLoaderForElements = {
  @react.component
  let make = (
    ~logger,
    ~publishableKey,
    ~clientSecret,
    ~paymentId,
    ~endpoint,
    ~merchantHostname,
    ~customPodUri,
    ~profileId,
    ~isTestMode=false,
  ) => {
    useMessageHandler(() =>
      switch GlobalVars.sdkVersion {
      | V1 =>
        getMessageHandlerV1Elements(
          ~clientSecret,
          ~publishableKey,
          ~logger,
          ~customPodUri,
          ~endpoint,
          ~merchantHostname,
          ~isTestMode,
        )
      | V2 =>
        getMessageHandlerV2Elements(
          ~clientSecret,
          ~paymentId,
          ~publishableKey,
          ~logger,
          ~customPodUri,
          ~endpoint,
          ~profileId,
        )
      }
    )

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
    useMessageHandler(() =>
      switch GlobalVars.sdkVersion {
      | V1 => getMessageHandlerV1PMM(~ephemeralKey, ~logger, ~customPodUri, ~endpoint)
      | V2 =>
        getMessageHandlerV2PMM(
          ~pmSessionId,
          ~pmClientSecret,
          ~publishableKey,
          ~profileId,
          ~logger,
          ~customPodUri,
          ~endpoint,
        )
      }
    )

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
  ~paymentId,
  ~ephemeralKey,
  ~pmSessionId,
  ~pmClientSecret,
  ~hyperComponentName: Types.hyperComponentName,
  ~merchantHostname,
  ~customPodUri,
  ~isTestMode=false,
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
      logger
      publishableKey
      clientSecret
      endpoint
      merchantHostname
      customPodUri
      profileId
      paymentId
      isTestMode
    />
  | PaymentMethodsManagementElements =>
    <PreMountLoaderForPMMElements
      logger endpoint ephemeralKey customPodUri pmSessionId pmClientSecret publishableKey profileId
    />
  }
}
