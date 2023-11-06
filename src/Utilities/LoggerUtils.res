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
  ~data: Js.Json.t=Js.Dict.empty()->Js.Json.object_,
  ~type_,
  ~url="",
  ~paymentMethod="",
  ~result: Js.Json.t=Js.Dict.empty()->Js.Json.object_,
  ~optLogger: option<OrcaLogger.loggerMake>,
  ~logType: OrcaLogger.logType=INFO,
  ~logCategory: OrcaLogger.logCategory=API,
  (),
) => {
  let logtype = getLogtype(type_)
  let (value, internalMetadata) = switch logtype {
  | Request => ([("url", url->Js.Json.string)], [])
  | Response => (
      [("url", url->Js.Json.string), ("statusCode", statusCode->Js.Json.string)],
      [("response", data)],
    )
  | NoResponse => (
      [("url", url->Js.Json.string), ("statusCode", "504"->Js.Json.string), ("response", data)],
      [("response", data)],
    )
  | Err => (
      [
        ("url", url->Js.Json.string),
        ("statusCode", statusCode->Js.Json.string),
        ("response", data),
      ],
      [("response", data)],
    )
  | Method => ([("method", paymentMethod->Js.Json.string)], [("result", result)])
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
    ~value=[("inputChange", text->Js.Json.string)]
    ->Js.Dict.fromArray
    ->Js.Json.object_
    ->Js.Json.stringify,
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
