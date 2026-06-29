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

let getNewCredentials = async (~callback: unit => promise<JSON.t>, ~currentClientSecret) => {
  let callbackResult = await callback()
  let newSdkAuthorization = callbackResult->getDictFromJson->getString("sdkAuthorization", "")
  // Note: under the new SDK auth contract, client_secret is no longer embedded in the token.
  // We unconditionally return currentClientSecret so that callers continue using the original secret.
  (newSdkAuthorization, currentClientSecret)
}

// --- Send credentials update to iframes ---

let sendElementsUpdateToIframes = (iframes, ~newSdkAuthorization, ~newClientSecret) => {
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
          title="Hyperswitch payment setup frame"
          src="${ApiEndpoint.sdkDomainUrl}/index.html?fullscreenType=${componentType}&publishableKey=${publishableKey}&clientSecret=${currentClientSecret}&sessionId=${sdkSessionId}&endpoint=${endpoint}&merchantHostname=${merchantHostname}&customPodUri=${customPodUri}&isTestMode=${isTestModeValue}&isSdkParamsEnabled=${isSdkParamsEnabledValue}&sdkAuthorization=${currentSdkAuthorization}"
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

// Sets up the preMountLoader iframe and creates promises for all API responses.
// Returns a tuple of (sessionTokensData, sdkConfigsData, clientListData).
// clientListData is the single source for both payment_methods and
// customer_payment_methods data (replaces the old paymentMethodsData/
// customerPaymentMethodsData pair).
// Can be called during init and during updateIntent.
let setupPreMountLoaderPromises = (
  ~publishableKey,
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

  let sessionTokensData = createDataPromise(
    ~dataKey="session_tokens",
    ~listenerName="onSessionTokensData-shared",
    ~sendKey="sendSessionTokensResponse",
  )

  let sdkConfigsData = createDataPromise(
    ~dataKey="sdk_configs",
    ~listenerName="onSdkConfigsData-shared",
    ~sendKey="sendSdkConfigsResponse",
  )

  let clientListData = createDataPromise(
    ~dataKey="client_list",
    ~listenerName="onClientListData-shared",
    ~sendKey="sendClientListResponse",
  )

  let requestMsg =
    [("requestPreMountLoaderMountedCallback", true->JSON.Encode.bool)]->Dict.fromArray
  preMountLoaderIframeDiv->Window.iframePostMessage(requestMsg)

  Promise.all([sessionTokensData, sdkConfigsData, clientListData])
  ->Promise.then(_ => {
    let msg = [("cleanUpPreMountLoaderIframe", true->JSON.Encode.bool)]->Dict.fromArray
    preMountLoaderIframeDiv->Window.iframePostMessage(msg)
    Promise.resolve()
  })
  ->Promise.catch(_ => Promise.resolve())
  ->ignore

  (sessionTokensData, sdkConfigsData, clientListData)
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
  ~sessionTokensDataPromise: ref<promise<JSON.t>>,
  ~sdkConfigsDataPromise: ref<promise<JSON.t>>,
  ~clientListDataPromise: ref<promise<JSON.t>>,
  ~iframes: array<Nullable.t<Dom.element>>,
  ~callback: unit => promise<JSON.t>,
  ~publishableKey,
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
      let callbackResult = await callback()
      let newSdkAuthorization = callbackResult->getDictFromJson->getString("sdkAuthorization", "")

      // Mount new preMountLoader with new credentials (refs NOT updated yet —
      // we validate all API responses before committing any state changes).
      let (
        newSessionTokensPromise,
        newSdkConfigsDataPromise,
        newClientListDataPromise,
      ) = setupPreMountLoaderPromises(
        ~publishableKey,
        ~sdkSessionId,
        ~endpoint,
        ~customPodUri,
        ~isTestMode,
        ~isSdkParamsEnabled,
        ~selectorString,
        ~currentClientSecret=clientSecretRef.contents,
        ~currentSdkAuthorization=newSdkAuthorization,
      )

      // Wait for ALL API responses before updating anything.
      let results = await Promise.all([
        newSessionTokensPromise,
        newSdkConfigsDataPromise,
        newClientListDataPromise,
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

        sdkAuthorizationRef.contents = newSdkAuthorization

        sessionTokensDataPromise.contents = newSessionTokensPromise
        sdkConfigsDataPromise.contents = newSdkConfigsDataPromise
        clientListDataPromise.contents = newClientListDataPromise

        // Send ElementsUpdate to all inner iframes with new credentials
        sendElementsUpdateToIframes(
          iframes,
          ~newSdkAuthorization,
          ~newClientSecret=clientSecretRef.contents,
        )

        // Wait for the payment element to signal ready (only if a payment element is mounted)
        let readyPromise = if shouldWaitForReady {
          Some(waitForReady())
        } else {
          None
        }

        // Forward fresh data to all mounted iframes. clientList is the single
        // source for both payment_methods and customer_payment_methods data,
        // forwarded once under the "clientList" key (retired the separate
        // "paymentMethodList"/"customerPaymentMethods" keys).
        let _ = await Promise.all([
          forwardPromiseToIframes(iframes, newSessionTokensPromise, "sessions"),
          forwardPromiseToIframes(iframes, newSdkConfigsDataPromise, "sdkConfigs"),
          forwardPromiseToIframes(iframes, newClientListDataPromise, "clientList"),
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
