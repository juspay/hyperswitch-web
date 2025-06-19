// TODO - This is the expected structure of the APIUtils module. Giving one example of how to structure the API calls.

// type apiCall =
//   // * Payments
//   | RetrievePaymentIntent
//   | PostSessionTokens
//   | PaymentsConfirm

//   // * 3DS
//   | ThreeDsAuth
//   | PollStatus

//   // * Sessions
//   | FetchSessions

//   // * Payouts
//   | ConfirmPayout

//   // * Payment Methods
//   | CreatePaymentMethod
//   | DeletePaymentMethod
//   | FetchPaymentMethodList
//   | FetchCustomerPaymentMethodList
//   | FetchSavedPaymentMethodList

//   // * Authentication
//   | CallAuthLink
//   | CallAuthExchange

//   // * Tax Calculation
//   | CalculateTax

// let generateApiUrl = (
//   apiCallType: apiCall,
//   ~clientSecret=?,
//   ~publishableKey=?,
//   ~pollID=?,
//   ~paymentId=?,
// ) => {
//   let clientSecretVal = clientSecret->Option.getOr("")
//   let publishableKeyVal = publishableKey->Option.getOr("")
//   let pollIDVal = pollID->Option.getOr("")
//   let paymentIdVal = paymentId->Option.getOr("")

//   let baseUrl = ApiEndpoint.getApiEndPoint(~publishableKey=publishableKeyVal)

//   let extractPaymentIntentID = () => String.split(clientSecretVal, "_secret_")[0]->Option.getOr("")

//   let path = switch apiCallType {
//   | RetrievePaymentIntent =>
//     let paymentIntentID = Utils.getPaymentId(clientSecretVal)
//     `payments/${paymentIntentID}?client_secret=${clientSecretVal}`

//   | ThreeDsAuth =>
//     let paymentIntentID = extractPaymentIntentID()
//     `payments/${paymentIntentID}/3ds/authentication`

//   | PollStatus => `poll/status/${pollIDVal}`

//   | FetchSessions => `payments/session_tokens`

//   | ConfirmPayout => `payouts/${paymentIdVal}/confirm`

//   | CreatePaymentMethod => `payment_methods`

//   | FetchPaymentMethodList => `account/payment_methods?client_secret=${clientSecretVal}`

//   | FetchCustomerPaymentMethodList => `customers/payment_methods?client_secret=${clientSecretVal}`

//   | PaymentsConfirm =>
//     let paymentIntentID = extractPaymentIntentID()
//     `payments/${paymentIntentID}/confirm`

//   | CallAuthLink => `payment_methods/auth/link`

//   | CallAuthExchange => `payment_methods/auth/exchange`

//   | FetchSavedPaymentMethodList => `customers/payment_methods`

//   | DeletePaymentMethod => `payment_methods`

//   | CalculateTax => `payments/${paymentIdVal}/calculate_tax`

//   | PostSessionTokens =>
//     let paymentIntentID = Utils.getPaymentId(clientSecretVal)
//     `payments/${paymentIntentID}/post_session_tokens`
//   }

//   `${baseUrl}/${path}`
// }

type apiCall = FetchPaymentMethodList | FetchCustomerPaymentMethodList | FetchSessions

let generateApiUrl = (
  apiCallType: apiCall,
  ~clientSecret=?,
  ~publishableKey=?,
  ~customBackendBaseUrl=?,
) => {
  let clientSecretVal = clientSecret->Option.getOr("")
  let publishableKeyVal = publishableKey->Option.getOr("")

  let baseUrl = switch customBackendBaseUrl {
  | Some(url) => url
  | None => ApiEndpoint.getApiEndPoint(~publishableKey=publishableKeyVal)
  }

  let path = switch apiCallType {
  | FetchPaymentMethodList => `account/payment_methods?client_secret=${clientSecretVal}`
  | FetchCustomerPaymentMethodList => `customers/payment_methods?client_secret=${clientSecretVal}`
  | FetchSessions => `payments/session_tokens`
  }

  `${baseUrl}/${path}`
}
