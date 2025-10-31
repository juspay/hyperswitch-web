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
  ~testMode=false,
) => {
  let (
    paymentMethodsPromise,
    customerPaymentMethodsPromise,
    sessionTokensPromise,
    blockedBinsPromise,
  ) = if testMode {
    let mockPaymentMethods =
      [
        (
          "payment_methods",
          [
            [
              ("payment_method", "card"->JSON.Encode.string),
              (
                "payment_method_types",
                [
                  [("payment_method_type", "credit"->JSON.Encode.string)],
                  [("payment_method_type", "debit"->JSON.Encode.string)],
                ]
                ->Array.map(Dict.fromArray)
                ->Array.map(JSON.Encode.object)
                ->JSON.Encode.array,
              ),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ]->JSON.Encode.array,
        ),
        ("is_tax_calculation_enabled", false->JSON.Encode.bool),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object

    let mockCustomerMethods = Dict.make()->JSON.Encode.object

    let mockSessionTokens = Dict.make()->JSON.Encode.object

    let mockBlockedBins = Dict.make()->JSON.Encode.object

    (
      Promise.resolve(mockPaymentMethods),
      Promise.resolve(mockCustomerMethods),
      Promise.resolve(mockSessionTokens),
      Promise.resolve(mockBlockedBins),
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
    ~testMode=false,
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
          ~testMode,
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
) => {
  let logger = HyperLogger.make(
    ~sessionId,
    ~source=Loader,
    ~merchantId=publishableKey,
    ~clientSecret,
  )

  // Detect test mode from URL parameters
  let url = RescriptReactRouter.useUrl()
  let testMode = url.search->CardUtils.getQueryParamsDictforKey("testMode") === "true"

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
      testMode
    />
  | PaymentMethodsManagementElements =>
    <PreMountLoaderForPMMElements
      logger endpoint ephemeralKey customPodUri pmSessionId pmClientSecret publishableKey profileId
    />
  }
}
