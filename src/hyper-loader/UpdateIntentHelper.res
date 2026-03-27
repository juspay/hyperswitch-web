open Utils

let overlayIdPrefix = "orca-updateIntent-overlay"
let spinnerStylesId = "orca-updateIntent-spinner-styles"

let overlayStyle = "position: absolute; top: 0; left: 0; width: 100%; height: 100%; backdrop-filter: blur(4px); -webkit-backdrop-filter: blur(4px); background: rgba(255, 255, 255, 0.4); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; z-index: 999; border-radius: inherit;"

let spinnerStyle = "width: 24px; height: 24px; border: 3px solid rgba(0, 0, 0, 0.1); border-top-color: rgba(0, 0, 0, 0.6); border-radius: 50%; animation: orca-spin 0.6s linear infinite;"

let labelStyle = "font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size: 13px; color: rgba(0, 0, 0, 0.55); letter-spacing: 0.2px;"

let wrapperStyle = "height: auto; font-size: 0; position: relative;"

let spinnerKeyframes = `@keyframes orca-spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}`

// Extracts the selector string from an iframe element's id (e.g. "orca-payment-element-iframeRef-foo" -> "foo").
let getSelectorString = iframeElement => {
  iframeElement
  ->Window.getAttribute("id")
  ->Nullable.toOption
  ->Option.getOr("")
  ->String.split("-iframeRef-")
  ->Array.get(1)
  ->Option.getOr("")
}

// Posts a dict message to all mounted iframes.
let postMessageToIframes = (iframes: array<Nullable.t<Dom.element>>, message) => {
  iframes->Array.forEach(ifR => ifR->Window.iframePostMessage(message))
}

// Posts a single key-value response to all mounted iframes.
let postResponseToIframes = (iframes, key, response) => {
  postMessageToIframes(iframes, [(key, response)]->Dict.fromArray)
}

// Injects spinner keyframes into document.body (idempotent).
let ensureSpinnerStyles = () => {
  if Window.querySelector(`#${spinnerStylesId}`)->Nullable.toOption->Option.isNone {
    let styleEl = Window.createElement("style")
    Window.id(styleEl, spinnerStylesId)
    Window.innerHTML(styleEl, spinnerKeyframes)
    Window.body->Window.appendChild(styleEl)
  }
}

// Creates the overlay element with a blur backdrop, spinner, and "Refreshing..." label.
let createOverlay = overlayId => {
  ensureSpinnerStyles()

  let overlay = Window.createElement("div")
  Window.id(overlay, overlayId)
  Window.setAttribute(overlay, "style", overlayStyle)

  let spinner = Window.createElement("div")
  Window.setAttribute(spinner, "style", spinnerStyle)

  let label = Window.createElement("div")
  Window.setAttribute(label, "style", labelStyle)
  Window.innerHTML(label, "Refreshing...")

  overlay->Window.appendChildToElement(spinner)
  overlay->Window.appendChildToElement(label)
  overlay
}

// Shows a lightweight overlay on each mounted iframe's wrapper div.
let showOverlay = (iframes: array<Nullable.t<Dom.element>>) => {
  iframes->Array.forEach(ifR => {
    ifR
    ->Nullable.toOption
    ->Option.forEach(iframeElement => {
      let selectorString = getSelectorString(iframeElement)
      if selectorString !== "" {
        iframeElement
        ->Window.parentElement
        ->Nullable.toOption
        ->Option.forEach(
          wrapperDiv => {
            Window.setAttribute(wrapperDiv, "style", wrapperStyle)
            let overlay = createOverlay(`${overlayIdPrefix}-${selectorString}`)
            wrapperDiv->Window.appendChildToElement(overlay)
          },
        )
      }
    })
  })
}

// Removes the overlay from each mounted iframe's wrapper div.
let hideOverlay = (iframes: array<Nullable.t<Dom.element>>) => {
  iframes->Array.forEach(ifR => {
    ifR
    ->Nullable.toOption
    ->Option.forEach(iframeElement => {
      let selectorString = getSelectorString(iframeElement)
      if selectorString !== "" {
        Window.querySelector(`#${overlayIdPrefix}-${selectorString}`)
        ->Nullable.toOption
        ->Option.forEach(el => el->Window.remove)
      }
    })
  })
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
    showOverlay(iframes)

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
    hideOverlay(iframes)

    [("status", "succeeded"->JSON.Encode.string)]->getJsonFromArrayOfJson
  } catch {
  | Exn.Error(e) => {
      hideOverlay(iframes)
      let errorMsg = Exn.message(e)->Option.getOr("Something went wrong during updateIntent!")
      getFailedSubmitResponse(~message=errorMsg, ~errorType="update_intent_error")
    }
  | _ => {
      hideOverlay(iframes)
      getFailedSubmitResponse(
        ~message="An unexpected error occurred during updateIntent.",
        ~errorType="update_intent_error",
      )
    }
  }
}
