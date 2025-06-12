open Promise
open Types
open Utils

let startAuthenticationSession = (
  ~clientSecret,
  ~publishableKey,
  ~endpoint,
  ~logger,
  ~customPodUri,
  ~redirectionFlags,
  ~iframeId,
) => {
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]

  PaymentHelpers.retrievePaymentIntent(
    clientSecret,
    headers,
    ~optLogger=Some(logger),
    ~customPodUri,
    ~isForceSync=false,
    ~isAuthenticationSession=true,
  )->then(json => {
    let intent = PaymentConfirmTypes.itemToObjMapper(json->getDictFromJson)
    let url = URLModule.makeUrl(intent.returnUrl)
    url.searchParams.set("payment_intent_client_secret", clientSecret)
    url.searchParams.set("payment_id", clientSecret)
    url.searchParams.set("status", intent.status)

    PaymentHelpers.handleNextAction(
      ~intent,
      ~optLogger=Some(logger),
      ~paymentMethod="CARD",
      ~headers,
      ~clientSecret,
      ~iframeId,
      ~url,
      ~publishableKey,
    )
    resolve(JSON.Encode.null)
  })
}
