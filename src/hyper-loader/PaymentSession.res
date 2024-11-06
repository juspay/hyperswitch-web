open Types

let make = (
  options,
  ~clientSecret,
  ~publishableKey,
  ~logger: option<HyperLogger.loggerMake>,
  ~ephemeralKey,
) => {
  let logger = logger->Option.getOr(HyperLogger.defaultLoggerConfig)
  let customPodUri =
    options
    ->JSON.Decode.object
    ->Option.flatMap(x => x->Dict.get("customPodUri"))
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("")
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

  let defaultInitPaymentSession = {
    getCustomerSavedPaymentMethods: _ =>
      PaymentSessionMethods.getCustomerSavedPaymentMethods(
        ~clientSecret,
        ~publishableKey,
        ~endpoint,
        ~logger,
        ~customPodUri,
      ),
    getPaymentManagementMethods: _ =>
      PaymentSessionMethods.getPaymentManagementMethods(
        ~ephemeralKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
      ),
  }

  defaultInitPaymentSession
}
