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

    let handleResendMountedCallback = (ev: Window.event) => {
      open Utils
      let dict = ev.data->safeParse->getDictFromJson
      if dict->Dict.get("requestPreMountLoaderMountedCallback")->Option.isSome {
        messageParentWindow([("preMountLoaderIframeMountedCallback", true->JSON.Encode.bool)])
      }
    }

    Window.addEventListener("message", handleCleanUpEventListener)
    Window.addEventListener("message", handleResendMountedCallback)

    setupMessageListener()

    Some(
      () => {
        cleanupMessageListener()
        Window.removeEventListener("message", handleCleanUpEventListener)
        Window.removeEventListener("message", handleResendMountedCallback)
      },
    )
  }, [])
}

let getMessageHandlerV1Elements = (
  ~sdkAuthorization,
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~merchantHostname,
  ~isTestMode=false,
  ~isSdkParamsEnabled=false,
) => {
  let (
    paymentMethodsPromise,
    customerPaymentMethodsPromise,
    sessionTokensPromise,
    blockedBinsPromise,
  ) = if isTestMode || isSdkParamsEnabled {
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
        ~sdkAuthorization=Some(sdkAuthorization),
      ),
      PaymentHelpers.fetchCustomerPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~sdkAuthorization=Some(sdkAuthorization),
      ),
      PaymentHelpers.fetchSessions(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~merchantHostname,
        ~sdkAuthorization=Some(sdkAuthorization),
      ),
      PaymentHelpers.fetchBlockedBins(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~sdkAuthorization=Some(sdkAuthorization),
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

let getMessageHandlerV2PMM = (
  ~pmSessionId,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~sdkAuthorization,
) => {
  let listPromise = PaymentHelpersV2.fetchPaymentManagementList(
    ~pmSessionId,
    ~optLogger=Some(logger),
    ~customPodUri,
    ~endpoint,
    ~sdkAuthorization,
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
    ~sdkAuthorization,
    ~clientSecret,
    ~endpoint,
    ~merchantHostname,
    ~customPodUri,
    ~isTestMode=false,
    ~isSdkParamsEnabled=false,
  ) => {
    useMessageHandler(() =>
      getMessageHandlerV1Elements(
        ~sdkAuthorization,
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~merchantHostname,
        ~isTestMode,
        ~isSdkParamsEnabled,
      )
    )

    React.null
  }
}

module PreMountLoaderForPMMElements = {
  @react.component
  let make = (~logger, ~endpoint, ~customPodUri, ~pmSessionId, ~sdkAuthorization) => {
    useMessageHandler(() =>
      getMessageHandlerV2PMM(~pmSessionId, ~sdkAuthorization, ~logger, ~customPodUri, ~endpoint)
    )

    React.null
  }
}

@react.component
let make = (
  ~sessionId,
  ~publishableKey,
  ~sdkAuthorization,
  ~clientSecret,
  ~endpoint,
  ~pmSessionId,
  ~hyperComponentName: Types.hyperComponentName,
  ~merchantHostname,
  ~customPodUri,
  ~isTestMode=false,
  ~isSdkParamsEnabled=false,
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
      sdkAuthorization
      clientSecret
      endpoint
      merchantHostname
      customPodUri
      isTestMode
      isSdkParamsEnabled
    />
  | PaymentMethodsManagementElements =>
    <PreMountLoaderForPMMElements logger endpoint customPodUri pmSessionId sdkAuthorization />
  }
}
