open Utils

// Posts a dict message to all mounted iframes.
let postMessageToIframes = (iframes: array<Nullable.t<Dom.element>>, message) => {
  iframes->Array.forEach(ifR => ifR->Window.iframePostMessage(message))
}

// Posts a single key-value response to all mounted iframes.
let postResponseToIframes = (iframes, key, response) => {
  postMessageToIframes(iframes, [(key, response)]->Dict.fromArray)
}

// Sends updateIntentLoading flag to inner iframe to show/hide the overlay.
let setOverlayLoading = (iframes, isLoading) => {
  postResponseToIframes(iframes, "updateIntentLoading", isLoading->JSON.Encode.bool)
}

// Waits for the "ready" event from the inner iframe.
// Uses addSmartEventListener so repeated updateIntent calls auto-cleanup the previous listener.
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

    // Execute merchant callback to get new sdkAuthorization
    let newSdkAuthorization = await callback()

    // Extract clientSecret from the new sdkAuthorization
    let sdkAuthorizationData = newSdkAuthorization->getSdkAuthorizationData
    let newClientSecret = switch sdkAuthorizationData.clientSecret->getNonEmptyOption {
    | Some(cs) => cs
    | None => clientSecret
    }

    // Re-execute all 4 API calls in parallel
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

    // Post updated credentials to inner iframe so confirm calls use the new token
    postMessageToIframes(
      iframes,
      [
        ("ElementsUpdate", true->JSON.Encode.bool),
        ("sdkAuthorization", newSdkAuthorization->JSON.Encode.string),
        ("clientSecret", newClientSecret->JSON.Encode.string),
        ("options", Dict.make()->JSON.Encode.object),
      ]->Dict.fromArray,
    )

    // Post API responses and wait for iframe to re-render
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
