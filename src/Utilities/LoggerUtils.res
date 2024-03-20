type logType = Request | Response | NoResponse | Method | Err
let getLogtype = val => {
  switch val {
  | "request" => Request
  | "response" => Response
  | "no_response" => NoResponse
  | "method" => Method
  | "err" => Err
  | _ => Err
  }
}
let logApi = (
  ~eventName,
  ~statusCode="",
  ~data: JSON.t=Dict.make()->JSON.Encode.object,
  ~type_,
  ~url="",
  ~paymentMethod="",
  ~result: JSON.t=Dict.make()->JSON.Encode.object,
  ~optLogger: option<OrcaLogger.loggerMake>,
  ~logType: OrcaLogger.logType=INFO,
  ~logCategory: OrcaLogger.logCategory=API,
  (),
) => {
  let logtype = getLogtype(type_)
  let (value, internalMetadata) = switch logtype {
  | Request => ([("url", url->JSON.Encode.string)], [])
  | Response => (
      [("url", url->JSON.Encode.string), ("statusCode", statusCode->JSON.Encode.string)],
      [("response", data)],
    )
  | NoResponse => (
      [
        ("url", url->JSON.Encode.string),
        ("statusCode", "504"->JSON.Encode.string),
        ("response", data),
      ],
      [("response", data)],
    )
  | Err => (
      [
        ("url", url->JSON.Encode.string),
        ("statusCode", statusCode->JSON.Encode.string),
        ("response", data),
      ],
      [("response", data)],
    )
  | Method => ([("method", paymentMethod->JSON.Encode.string)], [("result", result)])
  }
  switch optLogger {
  | Some(logger) =>
    logger.setLogApi(
      ~eventName,
      ~value=ArrayType(value),
      ~internalMetadata=ArrayType(internalMetadata),
      ~logType,
      ~logCategory,
      ~type_,
      (),
    )
  | None => ()
  }
}

let logInputChangeInfo = (text, logger: OrcaLogger.loggerMake) => {
  logger.setLogInfo(
    ~value=[("inputChange", text->JSON.Encode.string)]
    ->Dict.fromArray
    ->JSON.Encode.object
    ->JSON.stringify,
    ~eventName=INPUT_FIELD_CHANGED,
    (),
  )
}

let handleLogging = (
  ~optLogger: option<OrcaLogger.loggerMake>,
  ~value,
  ~internalMetadata="",
  ~eventName,
  ~paymentMethod,
  ~logType: OrcaLogger.logType=INFO,
  (),
) => {
  switch optLogger {
  | Some(logger) =>
    logger.setLogInfo(~value, ~internalMetadata, ~eventName, ~paymentMethod, ~logType, ())
  | _ => ()
  }
}
