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
  ~isPreLoadedDataAvailable,
) => {
  let makeResolvedPromise = data => Promise.resolve(data)
  let fakePromise = makeResolvedPromise(JSON.Encode.null)

  let paymentMethodsPromise = isPreLoadedDataAvailable
    ? fakePromise
    : PaymentHelpers.fetchPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
      )

  let customerPaymentMethodsPromise = isPreLoadedDataAvailable
    ? fakePromise
    : PaymentHelpers.fetchCustomerPaymentMethodList(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
      )

  let sessionTokensPromise = isPreLoadedDataAvailable
    ? fakePromise
    : PaymentHelpers.fetchSessions(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~merchantHostname,
      )

  let blockedBinsPromise = isPreLoadedDataAvailable
    ? fakePromise
    : PaymentHelpers.fetchBlockedBins(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
      )

  let preLoadedParams = ref(JSON.Encode.null)

  let getPreLoadedParamsPromise = val =>
    preLoadedParams.contents
    ->Utils.getDictFromJson
    ->Dict.get(val)
    ->Option.getOr(JSON.Encode.null)
    ->makeResolvedPromise

  ev => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if !isPreLoadedDataAvailable {
      if dict->isKeyPresentInDict("sendPaymentMethodsResponse") {
        paymentMethodsPromise->sendPromiseData("payment_methods")
      } else if dict->isKeyPresentInDict("sendCustomerPaymentMethodsResponse") {
        customerPaymentMethodsPromise->sendPromiseData("customer_payment_methods")
      } else if dict->isKeyPresentInDict("sendSessionTokensResponse") {
        sessionTokensPromise->sendPromiseData("session_tokens")
      } else if dict->isKeyPresentInDict("sendBlockedBinsResponse") {
        blockedBinsPromise->sendPromiseData("blocked_bins")
      }
    } else if dict->isKeyPresentInDict("preLoadedParams") {
      preLoadedParams := dict->Dict.get("preLoadedParams")->Option.getOr(JSON.Encode.null)
    } else if dict->isKeyPresentInDict("sendPaymentMethodsResponse") {
      getPreLoadedParamsPromise("payment_method_list")->sendPromiseData("payment_methods")
    } else if dict->isKeyPresentInDict("sendCustomerPaymentMethodsResponse") {
      getPreLoadedParamsPromise("customer_methods_list")->sendPromiseData(
        "customer_payment_methods",
      )
    } else if dict->isKeyPresentInDict("sendSessionTokensResponse") {
      getPreLoadedParamsPromise("session_tokens")->sendPromiseData("session_tokens")
    } else if dict->isKeyPresentInDict("sendBlockedBinsResponse") {
      getPreLoadedParamsPromise("blocked_bins")->sendPromiseData("blocked_bins")
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
  ~isPreLoadedDataAvailable as _,
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

  ev => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendPaymentMethodsListV2Response") {
      paymentMethodsListPromise->sendPromiseData("payment_methods_list_v2")
    } else if dict->isKeyPresentInDict("sendSessionTokensResponse") {
      sessionTokensPromise->sendPromiseData("session_tokens")
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
    ~isPreLoadedDataAvailable,
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
          ~isPreLoadedDataAvailable,
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
          ~isPreLoadedDataAvailable,
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
    ~isPreLoadedDataAvailable as _,
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
  ~isPreLoadedDataAvailable=false,
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
      isPreLoadedDataAvailable
    />
  | PaymentMethodsManagementElements =>
    <PreMountLoaderForPMMElements
      logger
      endpoint
      ephemeralKey
      customPodUri
      pmSessionId
      pmClientSecret
      publishableKey
      profileId
      isPreLoadedDataAvailable
    />
  }
}
