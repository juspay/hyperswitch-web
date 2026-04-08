// Common utilities shared between Elements.res and PaymentSession.res updateIntent flows.
// This file extracts the shared logic so both flows stay DRY.

open Utils
open Identity
open EventListenerManager

// --- Iframe messaging helpers ---

let postMessageToIframes = (iframes: array<Nullable.t<Dom.element>>, message) => {
  iframes->Array.forEach(ifR => ifR->Window.iframePostMessage(message))
}

let postResponseToIframes = (iframes, key, response) => {
  postMessageToIframes(iframes, [(key, response)]->Dict.fromArray)
}

let setOverlayLoading = (iframes, isLoading) => {
  postResponseToIframes(iframes, "updateIntentLoading", isLoading->JSON.Encode.bool)
}

// --- Ready signal listener ---

let waitForReady = () => {
  Promise.make((resolve, _) => {
    let onMessage = (event: Types.event) => {
      let dict = event.data->anyTypeToJson->getDictFromJson
      if dict->getBool("ready", false) {
        resolve()
      }
    }
    addSmartEventListener("message", onMessage, "updateIntent.ready")
  })
}

// --- Credential parsing ---

let getNewCredentials = async (~callback, ~currentClientSecret) => {
  let newSdkAuthorization = await callback()
  let sdkAuthorizationData = newSdkAuthorization->getSdkAuthorizationData
  let newClientSecret = switch sdkAuthorizationData.clientSecret->getNonEmptyOption {
  | Some(cs) => cs
  | None => currentClientSecret
  }
  (newSdkAuthorization, newClientSecret)
}

// --- Send credentials update to iframes ---

let sendElementsUpdateToIframes = (iframes, ~newSdkAuthorization, ~newClientSecret) => {
  Console.log2("SeNDING UPDATED SDKAUTH TO IFRAME", newSdkAuthorization)
  postMessageToIframes(
    iframes,
    [
      ("ElementsUpdate", true->JSON.Encode.bool),
      ("sdkAuthorization", newSdkAuthorization->JSON.Encode.string),
      ("clientSecret", newClientSecret->JSON.Encode.string),
      ("options", Dict.make()->JSON.Encode.object),
    ]->Dict.fromArray,
  )
}

// --- Shared error response helpers ---

// Error response when updateIntent is already in progress (used as early return guard).
let updateIntentInProgressResponse = () =>
  getFailedSubmitResponse(
    ~message="An updateIntent operation is already in progress.",
    ~errorType="update_intent_error",
  )

// Error response when confirm is blocked because updateIntent is in progress.
// Uses getFailedSubmitResponse (same format as Elements/Hyper).
let confirmBlockedResponse = () =>
  getFailedSubmitResponse(
    ~message="Cannot confirm payment while updateIntent is in progress.",
    ~errorType="update_intent_error",
  )

// Same as confirmBlockedResponse but uses handleFailureResponse (used in PaymentSessionMethods).
let confirmBlockedResponseForSession = () =>
  handleFailureResponse(
    ~message="Cannot confirm payment while updateIntent is in progress.",
    ~errorType="update_intent_error",
  )

// --- Forward a data promise to iframes ---

// Checks if an API response JSON indicates an error.
// Returns true for null responses or responses containing an "error" key.
let isErrorResponse = (json: JSON.t) => {
  switch json->JSON.Classify.classify {
  | Null => true
  | Object(dict) => dict->Dict.get("error")->Option.isSome
  | _ => false
  }
}

// When a data promise resolves, posts the result to all iframes under the given key.
let forwardPromiseToIframes = (iframes, promise, key) => {
  promise->Promise.then(json => {
    postResponseToIframes(iframes, key, json)
    Promise.resolve(json)
  })
}

// --- PreMountLoader iframe management ---

// Mounts a hidden preMountLoader iframe that makes API calls, returns the iframe element.
// Removes any existing preMountLoader with the same selectorString before creating a new one.
let mountPreMountLoaderIframe = (
  ~publishableKey,
  ~profileId,
  ~sdkSessionId,
  ~endpoint,
  ~customPodUri,
  ~isTestMode,
  ~isSdkParamsEnabled,
  ~selectorString,
  ~currentClientSecret,
  ~currentSdkAuthorization,
) => {
  // Remove any existing preMountLoader iframe + its wrapper div before creating a new one
  let existingIframe = Window.querySelector(`#orca-payment-element-iframeRef-${selectorString}`)
  switch existingIframe->Nullable.toOption {
  | Some(iframe) => {
      let wrapperDiv = Window.querySelector(`#orca-element-${selectorString}`)
      switch wrapperDiv->Nullable.toOption {
      | Some(wrapper) => wrapper->remove
      | None => iframe->remove
      }
    }
  | None => ()
  }

  let componentType = "preMountLoader"
  let merchantHostname = Window.Location.hostname
  let isTestModeValue = isTestMode->getStringFromBool
  let isSdkParamsEnabledValue = isSdkParamsEnabled->getStringFromBool
  let iframeDivHtml = `<div id="orca-element-${selectorString}" style= "height: 0px; width: 0px; display: none;"  class="${componentType}">
      <div id="orca-fullscreen-iframeRef-${selectorString}"></div>
        <iframe
          id="orca-payment-element-iframeRef-${selectorString}"
          name="orca-payment-element-iframeRef-${selectorString}"
          title="Orca Payment Element Frame"
          src="${ApiEndpoint.sdkDomainUrl}/index.html?fullscreenType=${componentType}&publishableKey=${publishableKey}&clientSecret=${currentClientSecret}&profileId=${profileId}&sessionId=${sdkSessionId}&endpoint=${endpoint}&merchantHostname=${merchantHostname}&customPodUri=${customPodUri}&isTestMode=${isTestModeValue}&isSdkParamsEnabled=${isSdkParamsEnabledValue}&sdkAuthorization=${currentSdkAuthorization}"
          allow="*"
          name="orca-payment"
          style="outline: none;"
        ></iframe>
      </div>`
  let iframeDiv = Window.createElement("div")
  iframeDiv->Window.innerHTML(iframeDivHtml)
  Window.body->Window.appendChild(iframeDiv)

  let elem = Window.querySelector(`#orca-payment-element-iframeRef-${selectorString}`)
  elem
}

// Removes the preMountLoader iframe and its wrapper div from the DOM.
let unMountPreMountLoaderIframe = (selectorString: string) => {
  let wrapperDiv = Window.querySelector(`#orca-element-${selectorString}`)
  switch wrapperDiv->Nullable.toOption {
  | Some(wrapper) => wrapper->remove
  | None => ()
  }
}

// Sets up the preMountLoader iframe and creates promises for all 4 API responses.
// Returns a tuple of (paymentMethodsData, customerPaymentMethodsData, sessionTokensData).
// Can be called during init and during updateIntent.
let setupPreMountLoaderPromises = (
  ~publishableKey,
  ~profileId,
  ~sdkSessionId,
  ~endpoint,
  ~customPodUri,
  ~isTestMode,
  ~isSdkParamsEnabled,
  ~selectorString,
  ~currentClientSecret,
  ~currentSdkAuthorization,
) => {
  let preMountLoaderIframeDiv = mountPreMountLoaderIframe(
    ~publishableKey,
    ~profileId,
    ~sdkSessionId,
    ~endpoint,
    ~customPodUri,
    ~isTestMode,
    ~isSdkParamsEnabled,
    ~selectorString,
    ~currentClientSecret,
    ~currentSdkAuthorization,
  )

  let preMountLoaderMountedPromise = Promise.make((resolve, _reject) => {
    let preMountLoaderIframeCallback = (ev: Types.event) => {
      let json = ev.data->anyTypeToJson
      let dict = json->getDictFromJson
      if dict->Dict.get("preMountLoaderIframeMountedCallback")->Option.isSome {
        resolve(true->JSON.Encode.bool)
      } else if dict->Dict.get("preMountLoaderIframeUnMount")->Option.isSome {
        unMountPreMountLoaderIframe(selectorString)
      }
    }
    addSmartEventListener("message", preMountLoaderIframeCallback, "onPreMountLoaderIframeCallback")
  })

  // Creates a promise that resolves when the preMountLoader sends back data for a given key.
  // Waits for the iframe to mount first, then posts a request and listens for the response.
  let createDataPromise = (~dataKey, ~listenerName, ~sendKey) => {
    preMountLoaderMountedPromise->Promise.then(_ => {
      Promise.make((resolve, _) => {
        let handleData = (event: Types.event) => {
          let json = event.data->anyTypeToJson
          let dict = json->getDictFromJson
          if dict->getString("data", "") === dataKey {
            resolve(dict->getJsonFromDict("response", JSON.Encode.null))
          }
        }
        addSmartEventListener("message", handleData, listenerName)
        let msg = [(sendKey, true->JSON.Encode.bool)]->Dict.fromArray
        preMountLoaderIframeDiv->Window.iframePostMessage(msg)
      })
    })
  }

  let paymentMethodsData = createDataPromise(
    ~dataKey="payment_methods",
    ~listenerName="onPaymentMethodsData-shared",
    ~sendKey="sendPaymentMethodsResponse",
  )
  let customerPaymentMethodsData = createDataPromise(
    ~dataKey="customer_payment_methods",
    ~listenerName="onCustomerPaymentMethodsData-shared",
    ~sendKey="sendCustomerPaymentMethodsResponse",
  )

  let sessionTokensData = createDataPromise(
    ~dataKey="session_tokens",
    ~listenerName="onSessionTokensData-shared",
    ~sendKey="sendSessionTokensResponse",
  )

  let requestMsg =
    [("requestPreMountLoaderMountedCallback", true->JSON.Encode.bool)]->Dict.fromArray
  preMountLoaderIframeDiv->Window.iframePostMessage(requestMsg)

  // Clean up preMountLoader iframe after all promises resolve
  Promise.all([paymentMethodsData, customerPaymentMethodsData, sessionTokensData])
  ->Promise.then(_ => {
    let msg = [("cleanUpPreMountLoaderIframe", true->JSON.Encode.bool)]->Dict.fromArray
    preMountLoaderIframeDiv->Window.iframePostMessage(msg)
    Promise.resolve()
  })
  ->Promise.catch(_ => Promise.resolve())
  ->ignore

  (paymentMethodsData, customerPaymentMethodsData, sessionTokensData)
}

// --- Core performUpdateIntent ---

// The core updateIntent implementation. Both Elements and PaymentSession call this.
// Returns JSON.t directly — success JSON on success, error JSON on failure.
// Handles concurrency guard internally.
// If any API call fails, refs are NOT updated (old data preserved) and error is returned.
let performUpdateIntent = async (
  ~isUpdateIntentInProgress: ref<bool>,
  ~clientSecretRef: ref<string>,
  ~sdkAuthorizationRef: ref<string>,
  ~paymentMethodsDataPromise: ref<promise<JSON.t>>,
  ~customerPaymentMethodsDataPromise: ref<promise<JSON.t>>,
  ~sessionTokensDataPromise: ref<promise<JSON.t>>,
  ~iframes: array<Nullable.t<Dom.element>>,
  ~callback: unit => promise<string>,
  ~publishableKey,
  ~profileId,
  ~sdkSessionId,
  ~endpoint,
  ~customPodUri,
  ~isTestMode,
  ~isSdkParamsEnabled,
  ~selectorString,
  ~shouldWaitForReady,
) => {
  if isUpdateIntentInProgress.contents {
    updateIntentInProgressResponse()
  } else {
    isUpdateIntentInProgress.contents = true

    let response = try {
      // Get new credentials from merchant callback
      let (newSdkAuthorization, newClientSecret) = await getNewCredentials(
        ~callback,
        ~currentClientSecret=clientSecretRef.contents,
      )

      // Mount new preMountLoader with new credentials (refs NOT updated yet —
      // we validate all API responses before committing any state changes)
      let (
        newPaymentMethodsPromise,
        newCustomerPaymentMethodsPromise,
        newSessionTokensPromise,
      ) = setupPreMountLoaderPromises(
        ~publishableKey,
        ~profileId,
        ~sdkSessionId,
        ~endpoint,
        ~customPodUri,
        ~isTestMode,
        ~isSdkParamsEnabled,
        ~selectorString,
        ~currentClientSecret=newClientSecret,
        ~currentSdkAuthorization=newSdkAuthorization,
      )

      // Wait for ALL API responses before updating anything
      let results = await Promise.all([
        newPaymentMethodsPromise,
        newCustomerPaymentMethodsPromise,
        newSessionTokensPromise,
      ])

      // Check if any API response indicates an error
      let firstError = results->Array.find(isErrorResponse)

      switch firstError {
      | Some(errorJson) =>
        // API call failed — don't update refs, clean up new preMountLoader, return error
        unMountPreMountLoaderIframe(selectorString)
        let errorMessage =
          errorJson
          ->getDictFromJson
          ->getDictFromDict("error")
          ->getString("message", "An API call failed during updateIntent.")
        getFailedSubmitResponse(~message=errorMessage, ~errorType="update_intent_error")

      | None =>
        // All API calls succeeded — now commit state changes
        clientSecretRef.contents = newClientSecret
        sdkAuthorizationRef.contents = newSdkAuthorization

        paymentMethodsDataPromise.contents = newPaymentMethodsPromise
        customerPaymentMethodsDataPromise.contents = newCustomerPaymentMethodsPromise
        sessionTokensDataPromise.contents = newSessionTokensPromise

        // Send ElementsUpdate to all inner iframes with new credentials
        sendElementsUpdateToIframes(iframes, ~newSdkAuthorization, ~newClientSecret)

        // Wait for the payment element to signal ready (only if a payment element is mounted)
        let readyPromise = if shouldWaitForReady {
          Some(waitForReady())
        } else {
          None
        }

        // Forward fresh data to all mounted iframes
        let _ = await Promise.all([
          forwardPromiseToIframes(iframes, newPaymentMethodsPromise, "paymentMethodList"),
          forwardPromiseToIframes(
            iframes,
            newCustomerPaymentMethodsPromise,
            "customerPaymentMethods",
          ),
          forwardPromiseToIframes(iframes, newSessionTokensPromise, "sessions"),
        ])

        switch readyPromise {
        | Some(p) => await p
        | None => ()
        }

        [("status", "succeeded"->JSON.Encode.string)]->getJsonFromArrayOfJson
      }
    } catch {
    | Exn.Error(e) =>
      getFailedSubmitResponse(
        ~message=Exn.message(e)->Option.getOr("Something went wrong during updateIntent!"),
        ~errorType="update_intent_error",
      )
    | _ =>
      getFailedSubmitResponse(
        ~message="An unexpected error occurred during updateIntent.",
        ~errorType="update_intent_error",
      )
    }
    isUpdateIntentInProgress.contents = false
    response
  }
}
