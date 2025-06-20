type apiCall =
  | FetchPaymentMethodList
  | FetchCustomerPaymentMethodList
  | FetchSessions
  | FetchThreeDsAuth
  | FetchSavedPaymentMethodList

let generateApiUrl = (
  apiCallType: apiCall,
  ~clientSecret=?,
  ~publishableKey=?,
  ~customBackendBaseUrl=?,
) => {
  let clientSecretVal = clientSecret->Option.getOr("")
  let publishableKeyVal = publishableKey->Option.getOr("")
  let paymentIntentID = Utils.getPaymentId(clientSecretVal)

  let baseUrl = switch customBackendBaseUrl {
  | Some(url) => url
  | None => ApiEndpoint.getApiEndPoint(~publishableKey=publishableKeyVal)
  }

  let path = switch apiCallType {
  | FetchPaymentMethodList => `account/payment_methods?client_secret=${clientSecretVal}`
  | FetchCustomerPaymentMethodList => `customers/payment_methods?client_secret=${clientSecretVal}`
  | FetchSessions => `payments/session_tokens`
  | FetchThreeDsAuth => `payments/${paymentIntentID}/3ds/authentication`
  | FetchSavedPaymentMethodList => `customers/payment_methods`
  }

  `${baseUrl}/${path}`
}
