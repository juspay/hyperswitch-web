open Types

let make = (
  options,
  ~publishableKey,
  ~sdkSessionId,
  ~redirectionFlags: JotaiAtomTypes.redirectionFlags,
  ~iframeRef: ref<array<Nullable.t<Dom.element>>>,
  ~isTestMode=false,
  ~isUpdateIntentInProgress: ref<bool>,
  ~clientSecretRef: ref<string>,
  ~sdkAuthorizationRef: ref<string>,
  ~sessionTokensDataPromise: ref<promise<JSON.t>>,
  ~sdkConfigsDataPromise: ref<promise<JSON.t>>,
  ~clientListDataPromise: ref<promise<JSON.t>>,
) => {
  let customPodUri =
    options
    ->JSON.Decode.object
    ->Option.flatMap(x => x->Dict.get("customPodUri"))
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("")
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

  let localSelectorString = "hyper-preMountLoader-session-iframe"

  let updateIntent = (callback: unit => promise<JSON.t>) => {
    UpdateIntentHelpersNew.performUpdateIntent(
      ~isUpdateIntentInProgress,
      ~clientSecretRef,
      ~sdkAuthorizationRef,
      ~sessionTokensDataPromise,
      ~sdkConfigsDataPromise,
      ~clientListDataPromise,
      ~iframes=iframeRef.contents,
      ~callback,
      ~publishableKey,
      ~sdkSessionId,
      ~endpoint,
      ~customPodUri,
      ~isTestMode,
      ~isSdkParamsEnabled=false,
      ~selectorString=localSelectorString,
      ~shouldWaitForReady=false,
    )
  }

  let defaultInitPaymentSession = {
    getCustomerSavedPaymentMethods: options =>
      PaymentSessionMethods.getCustomerSavedPaymentMethods(
        ~options,
        ~clientSecretRef,
        ~publishableKey,
        ~endpoint,
        ~customPodUri,
        ~sdkAuthorizationRef,
        ~redirectionFlags,
        ~iframeRef,
        ~isUpdateIntentInProgress,
      ),
    updateIntent,
  }

  defaultInitPaymentSession
}
