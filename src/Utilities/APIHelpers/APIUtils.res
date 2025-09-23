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

type apiCallV2 = FetchSessionsV2 | FetchIntent

type commonApiParams = {
  publishableKey: option<string>,
  customBackendBaseUrl: option<string>,
}

type apiParamsV2 = {...commonApiParams, paymentIdV2: option<string>}

type apiParamsV1 = {
  ...commonApiParams,
  clientSecret: option<string>,
  paymentMethodId: option<string>,
  forceSync: option<string>,
  pollId: option<string>,
  payoutId: option<string>,
}

module CommonUtils = {
  let buildQueryParams = params =>
    switch params {
    | list{} => ""
    | _ =>
      params
      ->List.map(((key, value)) => `${key}=${value}`)
      ->List.reduce("", (acc, param) => acc === "" ? `?${param}` : `${acc}&${param}`)
    }
}

let generateApiUrlV1 = (~params: apiParamsV1, ~apiCallType: apiCallV1) => {
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

  let isRetrieveIntent = switch apiCallType {
  | RetrievePaymentIntent => true
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
  | ConfirmPayout => `payouts/${payoutIdVal}/confirm`
  }

  `${baseUrl}/${path}${CommonUtils.buildQueryParams(queryParams)}`
}

let generateApiUrlV2 = (~params: apiParamsV2, ~apiCallType: apiCallV2) => {
  let {publishableKey, customBackendBaseUrl, paymentIdV2} = params

  let publishableKeyVal = publishableKey->Option.getOr("")
  let paymentIdVal = paymentIdV2->Option.getOr("")

  let baseUrl =
    customBackendBaseUrl->Option.getOr(
      ApiEndpoint.getApiEndPoint(~publishableKey=publishableKeyVal),
    )

  let queryParams = switch apiCallType {
  | _ => list{}
  }

  let path = switch apiCallType {
  | FetchSessionsV2 => `v2/payments/${paymentIdVal}/create-external-sdk-tokens`
  | FetchIntent => `v2/payments/${paymentIdVal}/get-intent`
  }

  `${baseUrl}/${path}${CommonUtils.buildQueryParams(queryParams)}`
}
