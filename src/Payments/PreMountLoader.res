let sendPromiseData = (promise, key, ~targetOrigin) => {
  let executePromise = async () => {
    let response = try {
      await promise
    } catch {
    | _ => JSON.Encode.null
    }
    Utils.messageParentWindow(
      [("response", response), ("data", key->JSON.Encode.string)],
      ~targetOrigin,
    )
  }
  executePromise()->ignore
}

let useMessageHandler = getMessageHandler => {
  React.useEffect(_ => {
    let processMessage = getMessageHandler()
    let parentOrigin = ref(None)
    let isFromParent = (ev: Window.event) => {
      if ev.source !== Utils.iframeParent || !PaymentMessageSecurity.isConcreteOrigin(ev.origin) {
        false
      } else {
        switch parentOrigin.contents {
        | Some(expected) => ev.origin === expected
        | None =>
          parentOrigin := Some(ev.origin)
          true
        }
      }
    }
    let messageHandler = (ev: Window.event) => {
      if isFromParent(ev) {
        processMessage(ev)
      }
    }
    let sendLifecycleMessage = message => {
      Utils.messageParentWindow(message, ~targetOrigin=parentOrigin.contents->Option.getOr("*"))
    }

    let setupMessageListener = _ => {
      Window.addEventListener("message", messageHandler)
      sendLifecycleMessage([("preMountLoaderIframeMountedCallback", true->JSON.Encode.bool)])
    }

    let cleanupMessageListener = _ => {
      Window.removeEventListener("message", messageHandler)
      sendLifecycleMessage([("preMountLoaderIframeUnMount", true->JSON.Encode.bool)])
    }

    let handleCleanUpEventListener = (ev: Window.event) => {
      open Utils
      let dict = ev.data->safeParse->getDictFromJson
      if isFromParent(ev) && dict->Dict.get("cleanUpPreMountLoaderIframe")->Option.isSome {
        cleanupMessageListener()
      }
    }

    let handleResendMountedCallback = (ev: Window.event) => {
      open Utils
      let dict = ev.data->safeParse->getDictFromJson
      if isFromParent(ev) && dict->Dict.get("requestPreMountLoaderMountedCallback")->Option.isSome {
        sendLifecycleMessage([("preMountLoaderIframeMountedCallback", true->JSON.Encode.bool)])
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
  ~customPodUri,
  ~endpoint,
  ~merchantHostname,
  ~isTestMode=false,
  ~isSdkParamsEnabled=false,
) => {
  let (sessionTokensPromise, sdkConfigsPromise, clientListPromise) = if (
    isTestMode || isSdkParamsEnabled
  ) {
    let mockResponse = Dict.make()->JSON.Encode.object

    (Promise.resolve(mockResponse), Promise.resolve(mockResponse), Promise.resolve(mockResponse))
  } else {
    (
      PaymentHelpers.fetchSessions(
        ~clientSecret,
        ~publishableKey,
        ~customPodUri,
        ~endpoint,
        ~merchantHostname,
        ~sdkAuthorization=Some(sdkAuthorization),
      ),
      PaymentHelpers.fetchSdkConfigs(
        ~clientSecret,
        ~publishableKey,
        ~customPodUri,
        ~endpoint,
        ~sdkAuthorization=Some(sdkAuthorization),
      ),
      PaymentHelpers.fetchClientList(
        ~clientSecret,
        ~publishableKey,
        ~customPodUri,
        ~endpoint,
        ~sdkAuthorization=Some(sdkAuthorization),
      ),
    )
  }

  (ev: Window.event) => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendSessionTokensResponse") {
      sessionTokensPromise->sendPromiseData("session_tokens", ~targetOrigin=ev.origin)
    } else if dict->isKeyPresentInDict("sendSdkConfigsResponse") {
      sdkConfigsPromise->sendPromiseData("sdk_configs", ~targetOrigin=ev.origin)
    } else if dict->isKeyPresentInDict("sendClientListResponse") {
      clientListPromise->sendPromiseData("client_list", ~targetOrigin=ev.origin)
    }
  }
}

let getMessageHandlerV2PMM = (~pmSessionId, ~customPodUri, ~endpoint, ~sdkAuthorization) => {
  let listPromise = PaymentHelpersV2.fetchPaymentManagementList(
    ~pmSessionId,
    ~customPodUri,
    ~endpoint,
    ~sdkAuthorization,
  )

  (ev: Window.event) => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendPaymentManagementListResponse") {
      listPromise->sendPromiseData("payment_management_list", ~targetOrigin=ev.origin)
    }
  }
}

module PreMountLoaderForElements = {
  @react.component
  let make = (
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
  let make = (~endpoint, ~customPodUri, ~pmSessionId, ~sdkAuthorization) => {
    useMessageHandler(() =>
      getMessageHandlerV2PMM(~pmSessionId, ~sdkAuthorization, ~customPodUri, ~endpoint)
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
  LoggerContext.setSessionData(~sessionId, ~merchantId=publishableKey, ())

  switch hyperComponentName {
  | Elements =>
    <PreMountLoaderForElements
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
    <PreMountLoaderForPMMElements endpoint customPodUri pmSessionId sdkAuthorization />
  }
}
