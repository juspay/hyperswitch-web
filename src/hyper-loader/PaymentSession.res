open Types
open Utils

let make = (
  options,
  ~publishableKey,
  ~profileId,
  ~sdkSessionId,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~redirectionFlags: RecoilAtomTypes.redirectionFlags,
  ~iframeRef: ref<array<Nullable.t<Dom.element>>>,
  ~isTestMode=false,
  ~isUpdateIntentInProgress: ref<bool>,
  ~clientSecretRef: ref<string>,
  ~sdkAuthorizationRef: ref<string>,
  ~paymentMethodsDataPromise: ref<promise<JSON.t>>,
  ~customerPaymentMethodsDataPromise: ref<promise<JSON.t>>,
  ~sessionTokensDataPromise: ref<promise<JSON.t>>,
) => {
  let logger = logger->Option.getOr(LoggerUtils.defaultLoggerConfig)
  let customPodUri =
    options
    ->JSON.Decode.object
    ->Option.flatMap(x => x->Dict.get("customPodUri"))
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("")
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

  let localSelectorString = "hyper-preMountLoader-session-iframe"

  let updateIntent = (callback: unit => promise<string>) => {
    UpdateIntentHelpersNew.performUpdateIntent(
      ~isUpdateIntentInProgress,
      ~clientSecretRef,
      ~sdkAuthorizationRef,
      ~paymentMethodsDataPromise,
      ~customerPaymentMethodsDataPromise,
      ~sessionTokensDataPromise,
      ~iframes=iframeRef.contents,
      ~callback,
      ~publishableKey,
      ~profileId,
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
    getCustomerSavedPaymentMethods: _ =>
      PaymentSessionMethods.getCustomerSavedPaymentMethods(
        ~clientSecretRef,
        ~publishableKey,
        ~endpoint,
        ~logger,
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
