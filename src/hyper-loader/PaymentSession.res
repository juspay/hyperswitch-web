open Types

let make = (
  options,
  ~clientSecret,
  ~publishableKey,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~ephemeralKey,
  ~redirectionFlags: RecoilAtomTypes.redirectionFlags,
) => {
  let logger = logger->Option.getOr(LoggerUtils.defaultLoggerConfig)
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
        ~redirectionFlags,
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
