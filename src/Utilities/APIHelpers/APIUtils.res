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

type apiParams = {
  clientSecret: option<string>,
  publishableKey: option<string>,
  customBackendBaseUrl: option<string>,
  paymentMethodId: option<string>,
  falseSync: option<string>,
}

let generateApiUrl = (apiCallType: apiCall, ~params: apiParams) => {
  let {clientSecret, publishableKey, customBackendBaseUrl, paymentMethodId, falseSync} = params

  let clientSecretVal = clientSecret->Option.getOr("")
  let publishableKeyVal = publishableKey->Option.getOr("")
  let paymentIntentID = Utils.getPaymentId(clientSecretVal)
  let paymentMethodIdVal = paymentMethodId->Option.getOr("")
  let falseSync = falseSync->Option.getOr("")

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
  | RetrievePaymentIntent => list{("client_secret", clientSecretVal), ("false_sync", falseSync)}
  | FetchSessions
  | FetchThreeDsAuth
  | FetchSavedPaymentMethodList
  | DeletePaymentMethod
  | CalculateTax
  | CreatePaymentMethod =>
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
  }

  `${baseUrl}/${path}${buildQueryParams(queryParams)}`
}
