type apiCall =
  | FetchPaymentMethodList
  | FetchCustomerPaymentMethodList
  | FetchSessions
  | FetchThreeDsAuth
  | FetchSavedPaymentMethodList
  | DeletePaymentMethod
  | CalculateTax
  | CreatePaymentMethod
  | RetrievePaymentIntent
  | CallAuthLink
  | CallAuthExchange
  | RetrieveStatus
  | ConfirmPayout

type apiParams = {
  clientSecret: option<string>,
  publishableKey: option<string>,
  customBackendBaseUrl: option<string>,
  paymentMethodId: option<string>,
  forceSync: option<string>,
  pollId: option<string>,
}

let generateApiUrl = (apiCallType: apiCall, ~params: apiParams) => {
  let {
    clientSecret,
    publishableKey,
    customBackendBaseUrl,
    paymentMethodId,
    forceSync,
    pollId,
  } = params

  let clientSecretVal = clientSecret->Option.getOr("")
  let publishableKeyVal = publishableKey->Option.getOr("")
  let paymentIntentID = Utils.getPaymentId(clientSecretVal)
  let paymentMethodIdVal = paymentMethodId->Option.getOr("")
  let pollIdVal = pollId->Option.getOr("")

  let baseUrl =
    customBackendBaseUrl->Option.getOr(
      ApiEndpoint.getApiEndPoint(~publishableKey=publishableKeyVal),
    )

  let buildQueryParams = params =>
    switch params {
    | list{} => ""
    | _ =>
      params
      ->List.map(((key, value)) => `${key}=${value}`)
      ->List.reduce("", (acc, param) => acc === "" ? `?${param}` : `${acc}&${param}`)
    }

  let defaultParams = list{
    switch clientSecret {
    | Some(cs) => Some(("client_secret", cs))
    | None => None
    },
    switch forceSync {
    | Some(fs) if apiCallType === RetrievePaymentIntent => Some(("false_sync", fs))
    | _ => None
    },
  }->List.filterMap(x => x)

  let queryParams = switch apiCallType {
  | FetchPaymentMethodList
  | FetchCustomerPaymentMethodList
  | RetrievePaymentIntent => defaultParams
  | FetchSessions
  | FetchThreeDsAuth
  | FetchSavedPaymentMethodList
  | DeletePaymentMethod
  | CalculateTax
  | CreatePaymentMethod
  | CallAuthLink
  | CallAuthExchange
  | RetrieveStatus
  | ConfirmPayout =>
    list{}
  }

  let path = switch apiCallType {
  | FetchPaymentMethodList => "account/payment_methods"
  | FetchSessions => "payments/session_tokens"
  | FetchThreeDsAuth => `payments/${paymentIntentID}/3ds/authentication`
  | FetchCustomerPaymentMethodList
  | FetchSavedPaymentMethodList => "customers/payment_methods"
  | DeletePaymentMethod => `payment_methods/${paymentMethodIdVal}`
  | CalculateTax => `payments/${paymentIntentID}/calculate_tax`
  | CreatePaymentMethod => "payment_methods"
  | RetrievePaymentIntent => `payments/${paymentIntentID}`
  | CallAuthLink => "payment_methods/auth/link"
  | CallAuthExchange => "payment_methods/auth/exchange"
  | RetrieveStatus => `poll/status/${pollIdVal}`
  | ConfirmPayout => `payouts/${paymentIntentID}/confirm`
  }

  `${baseUrl}/${path}${buildQueryParams(queryParams)}`
}
