open Types

let make = (options, ~clientSecret, ~publishableKey, ~logger: option<OrcaLogger.loggerMake>) => {
  let logger = logger->Belt.Option.getWithDefault(OrcaLogger.defaultLoggerConfig)
  let switchToCustomPod =
    GlobalVars.isInteg &&
    options
    ->Js.Json.decodeObject
    ->Belt.Option.flatMap(x => x->Js.Dict.get("switchToCustomPod"))
    ->Belt.Option.flatMap(Js.Json.decodeBoolean)
    ->Belt.Option.getWithDefault(false)
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey, ())

  let defaultInitPaymentSession = {
    getCustomerSavedPaymentMethods: _ =>
      PaymentSessionMethods.getCustomerSavedPaymentMethods(
        ~clientSecret,
        ~publishableKey,
        ~endpoint,
        ~logger,
        ~switchToCustomPod,
      ),
  }

  defaultInitPaymentSession
}
