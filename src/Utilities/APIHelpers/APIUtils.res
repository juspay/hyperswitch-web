type apiCallV1 =
  | FetchSessions
  | FetchThreeDsAuth
  | CalculateTax
  | CreatePaymentMethod
  | RetrievePaymentIntent
  | CallAuthLink
  | CallAuthExchange
  | RetrieveStatus
  | ConfirmPayout
  | FetchEnabledAuthnMethodsToken
  | FetchEligibilityCheck
  | FetchAuthenticationSync
  | FetchPaymentMethodEligibility
  | FetchSdkConfigs
  | FetchClientList

type commonApiParams = {
  publishableKey: option<string>,
  customBackendBaseUrl: option<string>,
}

type apiParamsV1 = {
  ...commonApiParams,
  clientSecret: option<string>,
  forceSync: option<string>,
  pollId: option<string>,
  payoutId: option<string>,
  sdkAuthorization: option<string>,
  authenticationId?: string,
  merchantId?: string,
}

module CommonUtils = {
  let buildQueryParams = params =>
    switch params {
    | list{} => ""
    | _ =>
      params
      ->List.map(((key, value)) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
      ->List.reduce("", (acc, param) => acc === "" ? `?${param}` : `${acc}&${param}`)
    }
}

let encodePathSegment = segment => {
  if segment === "." || segment === ".." {
    Js.Exn.raiseError("Invalid API path segment")
  } else {
    encodeURIComponent(segment)
  }
}

let generateApiUrlV1 = (~params: apiParamsV1, ~apiCallType: apiCallV1) => {
  let {
    clientSecret,
    publishableKey,
    customBackendBaseUrl,
    forceSync,
    pollId,
    payoutId,
    sdkAuthorization,
  } = params

  let clientSecretVal = clientSecret->Option.getOr("")
  let publishableKeyVal = publishableKey->Option.getOr("")
  let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
    ~clientSecret=clientSecretVal,
    ~sdkAuthorization=sdkAuthorization->Utils.getNonEmptyOption,
  )
  let pollIdVal = pollId->Option.getOr("")
  let payoutIdVal = payoutId->Option.getOr("")

  let authenticationIdVal = params.authenticationId->Option.getOr("")
  let merchantId = params.merchantId->Option.getOr("")

  let baseUrl =
    customBackendBaseUrl->Option.getOr(
      ApiEndpoint.getApiEndPoint(~publishableKey=publishableKeyVal),
    )
  let baseUrl = ApiEndpoint.isAllowedEndpoint(baseUrl)
    ? baseUrl
    : ApiEndpoint.getApiEndPoint(~publishableKey=publishableKeyVal)

  let isRetrieveIntent = switch apiCallType {
  | RetrievePaymentIntent => true
  | _ => false
  }

  let defaultParams = list{
    switch (sdkAuthorization->Utils.getNonEmptyOption, clientSecret) {
    | (None, Some(cs)) => Some(("client_secret", cs))
    | _ => None
    },
    switch forceSync {
    | Some(fs) if isRetrieveIntent => Some(("force_sync", fs))
    | _ => None
    },
  }->List.filterMap(x => x)

  let queryParams = switch apiCallType {
  | RetrievePaymentIntent
  | FetchSdkConfigs
  | FetchClientList => defaultParams
  | FetchSessions
  | FetchThreeDsAuth
  | CalculateTax
  | CreatePaymentMethod
  | CallAuthLink
  | CallAuthExchange
  | RetrieveStatus
  | ConfirmPayout
  | FetchEnabledAuthnMethodsToken
  | FetchEligibilityCheck
  | FetchAuthenticationSync
  | FetchPaymentMethodEligibility =>
    list{}
  }

  let path = switch apiCallType {
  | FetchSessions => "payments/session_tokens"
  | FetchThreeDsAuth => `payments/${encodePathSegment(paymentIntentId)}/3ds/authentication`
  | CalculateTax => `payments/${encodePathSegment(paymentIntentId)}/calculate_tax`
  | CreatePaymentMethod => "payment_methods"
  | RetrievePaymentIntent => `payments/${encodePathSegment(paymentIntentId)}`
  | CallAuthLink => "payment_methods/auth/link"
  | CallAuthExchange => "payment_methods/auth/exchange"
  | RetrieveStatus => `poll/status/${encodePathSegment(pollIdVal)}`
  | ConfirmPayout => `payouts/${encodePathSegment(payoutIdVal)}/confirm`
  | FetchEnabledAuthnMethodsToken =>
    `authentication/${encodePathSegment(authenticationIdVal)}/enabled_authn_methods_token`
  | FetchEligibilityCheck =>
    `authentication/${encodePathSegment(authenticationIdVal)}/eligibility-check`
  | FetchAuthenticationSync =>
    `authentication/${encodePathSegment(merchantId)}/${encodePathSegment(authenticationIdVal)}/sync`
  | FetchPaymentMethodEligibility => `payments/${encodePathSegment(paymentIntentId)}/eligibility`
  | FetchSdkConfigs => "v1/sdk/configs/web/sdk_config.json"
  | FetchClientList => `payments/${encodePathSegment(paymentIntentId)}/client`
  }

  `${baseUrl}/${path}${CommonUtils.buildQueryParams(queryParams)}`
}
