open HyperLoggerTypes
open LoggerUtils

type responseStatus = Success | Error | Exception | Request

let logApiResponse = (
  ~logger,
  ~uri,
  ~eventName,
  ~status,
  ~statusCode=?,
  ~data=?,
  ~isPaymentSession=?,
) => {
  switch eventName {
  | Some(actualEventName) =>
    let (apiLogType, logType) = switch status {
    | Success => (Response, INFO)
    | Error => (Err, ERROR)
    | Exception => (NoResponse, ERROR)
    | Request => (Request, INFO)
    }
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType,
      ~eventName=actualEventName,
      ~logType,
      ~logCategory=API,
      ~statusCode?,
      ~data?,
      ~isPaymentSession?,
    )

  | None => ()
  }
}
