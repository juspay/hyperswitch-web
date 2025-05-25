open HyperLoggerTypes
open LoggerUtils

type responseStatus = Success | Error | Exception | Request

let logApiResponse = (~logger, ~uri, ~eventName, ~status, ~statusCode=?, ~data=?) => {
  let (apiLogType, logType, actualEventName) = switch status {
  | Success => (Response, INFO, eventName)
  | Error => (Err, ERROR, eventName)
  | Exception => (NoResponse, ERROR, eventName)
  | Request => (Request, INFO, eventName)
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
  )
}
