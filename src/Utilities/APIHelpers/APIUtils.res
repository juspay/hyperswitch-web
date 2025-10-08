type apiCallV1 =
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
  | FetchBlockedBins

type apiCallV2 = FetchSessionsV2

type apiCall =
  | V1(apiCallV1)
  | V2(apiCallV2)

type apiParams = {
  clientSecret: option<string>,
  publishableKey: option<string>,
  customBackendBaseUrl: option<string>,
  paymentMethodId: option<string>,
  forceSync: option<string>,
  pollId: option<string>,
  payoutId: option<string>,
}

let generateApiUrl = (apiCallType: apiCall, ~params: apiParams) => {
  let {
    clientSecret,
    publishableKey,
    customBackendBaseUrl,
    paymentMethodId,
    forceSync,
    pollId,
    payoutId,
  } = params

  let clientSecretVal = clientSecret->Option.getOr("")
  let publishableKeyVal = publishableKey->Option.getOr("")
  let paymentIntentID = Utils.getPaymentId(clientSecretVal)
  let paymentMethodIdVal = paymentMethodId->Option.getOr("")
  let pollIdVal = pollId->Option.getOr("")
  let payoutIdVal = payoutId->Option.getOr("")

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

  let isRetrieveIntent = switch apiCallType {
  | V1(RetrievePaymentIntent) => true
  | _ => false
  }

  let defaultParams = list{
    switch clientSecret {
    | Some(cs) => Some(("client_secret", cs))
    | None => None
    },
    switch forceSync {
    | Some(fs) if isRetrieveIntent => Some(("force_sync", fs))
    | _ => None
    },
  }->List.filterMap(x => x)

  let queryParams = switch apiCallType {
  | V1(inner) =>
    switch inner {
    | FetchPaymentMethodList
    | FetchCustomerPaymentMethodList
    | RetrievePaymentIntent => defaultParams
    | FetchBlockedBins => list{("data_kind", "card_bin"), ...defaultParams}
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
  | V2(_) => list{}
  }

  let path = switch apiCallType {
  | V1(inner) =>
    switch inner {
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
    | ConfirmPayout => `payouts/${payoutIdVal}/confirm`
    | FetchBlockedBins => "blocklist"
    }
  | V2(inner) =>
    switch inner {
    | FetchSessionsV2 => `v2/payments/${paymentIntentID}/create-external-sdk-tokens`
    }
  }

  `${baseUrl}/${path}${buildQueryParams(queryParams)}`
}
