open Utils

let postMessageToIframes = (iframes: array<Nullable.t<Dom.element>>, message) => {
  iframes->Array.forEach(ifR => ifR->Window.iframePostMessage(message))
}

let postResponseToIframes = (iframes, key, response) => {
  postMessageToIframes(iframes, [(key, response)]->Dict.fromArray)
}

let setOverlayLoading = (iframes, isLoading) => {
  postResponseToIframes(iframes, "updateIntentLoading", isLoading->JSON.Encode.bool)
}

let waitForReady = () => {
  Promise.make((resolve, _) => {
    let onMessage = (event: Types.event) => {
      let dict = event.data->Identity.anyTypeToJson->getDictFromJson
      if dict->getBool("ready", false) {
        resolve()
      }
    }
    EventListenerManager.addSmartEventListener("message", onMessage, "updateIntent.ready")
  })
}

let updateIntent = async (
  ~iframes: array<Nullable.t<Dom.element>>,
  ~clientSecret,
  ~publishableKey,
  ~logger: HyperLoggerTypes.loggerMake,
  ~customPodUri,
  ~endpoint,
  ~callback: unit => promise<string>,
) => {
  try {
    setOverlayLoading(iframes, true)

    let newSdkAuthorization = await callback()

    let sdkAuthorizationData = newSdkAuthorization->getSdkAuthorizationData
    let newClientSecret = switch sdkAuthorizationData.clientSecret->getNonEmptyOption {
    | Some(cs) => cs
    | None => clientSecret
    }

    let (
      paymentMethodListResponse,
      customerPaymentMethodsResponse,
      sessionsResponse,
      blockedBinsResponse,
    ) = await Promise.all4((
      PaymentHelpers.fetchPaymentMethodList(
        ~clientSecret=newClientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~sdkAuthorization=Some(newSdkAuthorization),
      ),
      PaymentHelpers.fetchCustomerPaymentMethodList(
        ~clientSecret=newClientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~sdkAuthorization=Some(newSdkAuthorization),
      ),
      PaymentHelpers.fetchSessions(
        ~clientSecret=newClientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~sdkAuthorization=Some(newSdkAuthorization),
      ),
      PaymentHelpers.fetchBlockedBins(
        ~clientSecret=newClientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~sdkAuthorization=Some(newSdkAuthorization),
      ),
    ))

    postMessageToIframes(
      iframes,
      [
        ("ElementsUpdate", true->JSON.Encode.bool),
        ("sdkAuthorization", newSdkAuthorization->JSON.Encode.string),
        ("clientSecret", newClientSecret->JSON.Encode.string),
        ("options", Dict.make()->JSON.Encode.object),
      ]->Dict.fromArray,
    )

    let readyPromise = waitForReady()
    postResponseToIframes(iframes, "paymentMethodList", paymentMethodListResponse)
    postResponseToIframes(iframes, "customerPaymentMethods", customerPaymentMethodsResponse)
    postResponseToIframes(iframes, "sessions", sessionsResponse)
    postResponseToIframes(iframes, "blockedBins", blockedBinsResponse)

    await readyPromise
    setOverlayLoading(iframes, false)

    [("status", "succeeded"->JSON.Encode.string)]->getJsonFromArrayOfJson
  } catch {
  | Exn.Error(e) => {
      setOverlayLoading(iframes, false)
      let errorMsg = Exn.message(e)->Option.getOr("Something went wrong during updateIntent!")
      getFailedSubmitResponse(~message=errorMsg, ~errorType="update_intent_error")
    }
  | _ => {
      setOverlayLoading(iframes, false)
      getFailedSubmitResponse(
        ~message="An unexpected error occurred during updateIntent.",
        ~errorType="update_intent_error",
      )
    }
  }
}
