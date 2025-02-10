open Utils
open Identity
open PaymentHelpersTypes
open LoggerUtils
open URLModule

let fetchPaymentManagementList = (
  ~pmSessionId,
  ~pmClientSecret,
  ~endpoint,
  ~optLogger,
  ~customPodUri,
  ~isPaymentSession=false,
) => {
  open Promise
  let publishableKey = "pk_"
  let headers = [
    ("Content-Type", "application/json"),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/v2/payment-methods-session/${pmSessionId}/list-payment-methods`
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=SAVED_PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
          ~isPaymentSession,
        )
        Console.log("Mock response")
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
        ~isPaymentSession,
      )
      res->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
      ~isPaymentSession,
    )
    JSON.Encode.null->resolve
  })
}

let deletePaymentMethodV2 = (
  ~pmSessionId,
  ~pmClientSecret,
  ~paymentMethodId,
  ~logger,
  ~customPodUri,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let publishableKey = "pk_"
  let headers = [
    ("Content-Type", "application/json"),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/payment_methods/${paymentMethodId}`
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=DELETE_PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(uri, ~method=#DELETE, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=DELETE_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=DELETE_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=DELETE_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}
