open Utils

let forSdk = async (
  uri,
  ~event: SdkLogger.apiEvent,
  ~context=?,
  ~source=?,
  ~onSuccess,
  ~onFailure,
  ~bodyStr="",
  ~headers=?,
  ~method,
  ~customPodUri=None,
  ~publishableKey=None,
  ~onCatchCallback=None,
  ~sdkAuthorization=None,
  ~signal: option<Fetch.AbortSignal.t>=?,
) => {
  try {
    let body = switch method {
    | #GET => None
    | _ => Some(Fetch.Body.string(bodyStr))
    }
    let response = await SdkLogger.observeApi(
      ~event,
      ~context?,
      ~source?,
      ~url=uri,
      ~details=bodyStr->WebLoggerUtils.payloadDetails,
      ~request={
        method,
        ?body,
        ?signal,
        headers: getHeaders(
          ~headers=headers->Option.getOr(Dict.make()),
          ~uri,
          ~customPodUri,
          ~publishableKey,
          ~sdkAuthorization,
        ),
      },
    )
    let data = await response->Fetch.Response.json
    response->Fetch.Response.ok ? onSuccess(data) : onFailure(data)
  } catch {
  | err => {
      let exceptionMessage = err->formatException
      Console.error2(
        "Unexpected error while making request:",
        {
          "uri": uri,
          "error": exceptionMessage,
        },
      )
      switch onCatchCallback {
      | Some(fun) => fun(exceptionMessage)
      | None => onFailure(exceptionMessage)
      }
    }
  }
}

let forPmSession = async (
  uri,
  ~event: PaymentMethodSessionLogger.apiEvent,
  ~context=?,
  ~onSuccess,
  ~onFailure,
  ~bodyStr="",
  ~headers=?,
  ~method,
  ~customPodUri=None,
  ~publishableKey=None,
  ~onCatchCallback=None,
  ~sdkAuthorization=None,
  ~signal: option<Fetch.AbortSignal.t>=?,
) => {
  try {
    let body = switch method {
    | #GET => None
    | _ => Some(Fetch.Body.string(bodyStr))
    }
    let response = await PaymentMethodSessionLogger.observeApi(
      ~event,
      ~context?,
      ~url=uri,
      ~details=bodyStr->WebLoggerUtils.payloadDetails,
      ~request={
        method,
        ?body,
        ?signal,
        headers: getHeaders(
          ~headers=headers->Option.getOr(Dict.make()),
          ~uri,
          ~customPodUri,
          ~publishableKey,
          ~sdkAuthorization,
        ),
      },
    )
    let data = await response->Fetch.Response.json
    response->Fetch.Response.ok ? onSuccess(data) : onFailure(data)
  } catch {
  | err => {
      let exceptionMessage = err->formatException
      Console.error2(
        "Unexpected error while making request:",
        {"uri": uri, "error": exceptionMessage},
      )
      switch onCatchCallback {
      | Some(fun) => fun(exceptionMessage)
      | None => onFailure(exceptionMessage)
      }
    }
  }
}
