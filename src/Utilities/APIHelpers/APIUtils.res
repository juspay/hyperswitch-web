type apiCall =
  | FetchPaymentMethodList
  | FetchCustomerPaymentMethodList
  | FetchSessions
  | FetchThreeDsAuth
  | FetchSavedPaymentMethodList
  | DeletePaymentMethod

type apiParams = {
  clientSecret: option<string>,
  publishableKey: option<string>,
  customBackendBaseUrl: option<string>,
  paymentMethodId: option<string>,
}

let generateApiUrl = (apiCallType: apiCall, ~params: apiParams) => {
  let {clientSecret, publishableKey, customBackendBaseUrl, paymentMethodId} = params

  let clientSecretVal = clientSecret->Option.getOr("")
  let publishableKeyVal = publishableKey->Option.getOr("")
  let paymentIntentID = Utils.getPaymentId(clientSecretVal)
  let paymentMethodIdVal = paymentMethodId->Option.getOr("")

  let baseUrl =
    customBackendBaseUrl->Option.getOr(
      ApiEndpoint.getApiEndPoint(~publishableKey=publishableKeyVal),
    )

  let buildQueryParams = (params: list<(string, string)>) => {
    switch params {
    | list{} => ""
    | _ =>
      params
      ->List.map(((key, value)) => `${key}=${value}`)
      ->List.reduce("", (acc, param) => acc === "" ? `?${param}` : `${acc}&${param}`)
    }
  }

  let queryParams = switch apiCallType {
  | FetchPaymentMethodList => list{("client_secret", clientSecretVal)}
  | FetchCustomerPaymentMethodList => list{("client_secret", clientSecretVal)}
  | FetchSessions
  | FetchThreeDsAuth
  | FetchSavedPaymentMethodList
  | DeletePaymentMethod =>
    list{}
  }

  let path = switch apiCallType {
  | FetchPaymentMethodList => "account/payment_methods"
  | FetchSessions => "payments/session_tokens"
  | FetchThreeDsAuth => `payments/${paymentIntentID}/3ds/authentication`
  | FetchCustomerPaymentMethodList
  | FetchSavedPaymentMethodList => "customers/payment_methods"
  | DeletePaymentMethod => `payment_methods/${paymentMethodIdVal}`
  }

  `${baseUrl}/${path}${buildQueryParams(queryParams)}`
}
