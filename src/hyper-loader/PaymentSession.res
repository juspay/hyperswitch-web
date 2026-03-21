open Types
open Utils

let make = (
  options,
  ~clientSecret,
  ~publishableKey,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~redirectionFlags: RecoilAtomTypes.redirectionFlags,
  ~iframeRef: ref<array<nullable<Dom.element>>>,
) => {
  let logger = logger->Option.getOr(LoggerUtils.defaultLoggerConfig)
  let customPodUri =
    options
    ->JSON.Decode.object
    ->Option.flatMap(x => x->Dict.get("customPodUri"))
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("")
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

  let noTimeout: option<timeoutId> = None
  let updateIntentTimeoutId = ref(noTimeout)

  let noResolve: option<JSON.t => unit> = None
  let pendingInitResolve = ref(noResolve)

  let clearUpdateIntentTimeout = () => {
    updateIntentTimeoutId.contents->Option.forEach(id => clearTimeout(id))
    updateIntentTimeoutId := noTimeout
  }

  let resetUpdateIntentState = () => {
    iframeRef.contents->Array.forEach(ifR =>
      ifR->Window.iframePostMessage(
        [("updateIntentInProgress", false->JSON.Encode.bool)]->Dict.fromArray,
      )
    )
  }

  let resolvePendingInit = (result: JSON.t) => {
    switch pendingInitResolve.contents {
    | Some(resolve) =>
      resolve(result)
      pendingInitResolve := noResolve
    | _ => ()
    }
  }

  let initUpdateIntent = () => {
    // Clear any prior pending timeout (idempotent)
    clearUpdateIntentTimeout()

    // Re-entrancy guard: if a previous initUpdateIntent promise is still pending,
    // resolve it with a cancellation error before replacing
    resolvePendingInit(
      handleFailureResponse(
        ~message="initUpdateIntent was called again before completeUpdateIntent finished. The previous call has been cancelled.",
        ~errorType="update_intent_cancelled",
      ),
    )

    // Guard: no iframes actually mounted (filter out null entries that may exist pre-mount)
    let mountedIframes = iframeRef.contents->Array.filterMap(Nullable.toOption)
    if mountedIframes->Array.length === 0 {
      Promise.resolve(
        handleFailureResponse(
          ~message="No payment elements are mounted. Call initUpdateIntent after elements are ready.",
          ~errorType="invalid_request",
        ),
      )
    } else {
      // Signal iframes: show overlay, block confirm
      iframeRef.contents->Array.forEach(ifR =>
        ifR->Window.iframePostMessage(
          [("updateIntentInProgress", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      )

      // Return a promise that stays pending until completeUpdateIntent resolves it
      // or the timeout fires
      Promise.make((resolve, _) => {
        pendingInitResolve := Some(resolve)

        let timeoutId = setTimeout(() => {
          logger.setLogError(
            ~value="paymentSession.initUpdateIntent() timed out — completeUpdateIntent was not called in time",
            ~eventName=UPDATE_INTENT_TIMEOUT,
          )
          resetUpdateIntentState()
          updateIntentTimeoutId := noTimeout
          // Resolve the pending promise with error
          resolvePendingInit(
            handleFailureResponse(
              ~message="paymentSession.completeUpdateIntent() was not called within the allowed time. Please restart the payment flow.",
              ~errorType="update_intent_timeout",
            ),
          )
        }, GlobalVars.updateIntentTimeoutMs)
        updateIntentTimeoutId := Some(timeoutId)
      })
    }
  }

  let completeUpdateIntent = async (params: JSON.t) => {
    // Cancel timeout — merchant called this in time
    clearUpdateIntentTimeout()

    let paramsDict = params->JSON.Decode.object->Option.getOr(Dict.make())
    let newSdkAuthorization = paramsDict->getString("sdkAuthorization", "")

    if newSdkAuthorization === "" {
      resetUpdateIntentState()
      let errorResult = handleFailureResponse(
        ~message="sdkAuthorization is required in completeUpdateIntent params.",
        ~errorType="invalid_request",
      )
      resolvePendingInit(errorResult)
      errorResult
    } else {
      // Update sdkAuthorization in Elements.res localOptions via postMessage
      iframeRef.contents->Array.forEach(ifR =>
        ifR->Window.iframePostMessage(
          [("sdkAuthorization", newSdkAuthorization->JSON.Encode.string)]->Dict.fromArray,
        )
      )

      try {
        // Fetch all three in parallel — NO blockedBins per requirements
        let (paymentMethods, customerPaymentMethods, sessions) = await Promise.all3((
          PaymentHelpers.fetchPaymentMethodList(
            ~clientSecret,
            ~publishableKey,
            ~logger,
            ~customPodUri,
            ~endpoint,
            ~sdkAuthorization=Some(newSdkAuthorization),
          ),
          PaymentHelpers.fetchCustomerPaymentMethodList(
            ~clientSecret,
            ~publishableKey,
            ~logger,
            ~customPodUri,
            ~endpoint,
            ~sdkAuthorization=Some(newSdkAuthorization),
          ),
          PaymentHelpers.fetchSessions(
            ~clientSecret,
            ~publishableKey,
            ~logger,
            ~endpoint,
            ~sdkAuthorization=Some(newSdkAuthorization),
          ),
        ))

        // Post refreshed data — LoaderController.res already handles these keys
        iframeRef.contents->Array.forEach(ifR => {
          ifR->Window.iframePostMessage([("paymentMethodList", paymentMethods)]->Dict.fromArray)
          ifR->Window.iframePostMessage(
            [("customerPaymentMethods", customerPaymentMethods)]->Dict.fromArray,
          )
          ifR->Window.iframePostMessage([("sessions", sessions)]->Dict.fromArray)
        })

        // Remove overlay + unblock confirm
        resetUpdateIntentState()

        let successResult = [("updateCompleted", true->JSON.Encode.bool)]->getJsonFromArrayOfJson
        resolvePendingInit(successResult)
        successResult
      } catch {
      | Exn.Error(e) =>
        let errorMsg = Exn.message(e)->Option.getOr("Something went wrong!")
        // Always unblock, even on failure — don't leave SDK frozen
        resetUpdateIntentState()
        let errorResult = handleFailureResponse(
          ~message=errorMsg,
          ~errorType="update_intent_failed",
        )
        resolvePendingInit(errorResult)
        errorResult
      | _ =>
        // Catch-all for non-Error exceptions — ensure SDK never stays frozen
        resetUpdateIntentState()
        let errorResult = handleFailureResponse(
          ~message="An unexpected error occurred during completeUpdateIntent.",
          ~errorType="update_intent_failed",
        )
        resolvePendingInit(errorResult)
        errorResult
      }
    }
  }

  let defaultInitPaymentSession: initPaymentSession = {
    getCustomerSavedPaymentMethods: _ =>
      PaymentSessionMethods.getCustomerSavedPaymentMethods(
        ~clientSecret,
        ~publishableKey,
        ~endpoint,
        ~logger,
        ~customPodUri,
        ~redirectionFlags,
      ),
    initUpdateIntent,
    completeUpdateIntent,
  }

  defaultInitPaymentSession
}
