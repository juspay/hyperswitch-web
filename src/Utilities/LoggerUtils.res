let logApi = (
  ~eventName,
  ~statusCode="",
  ~data: JSON.t=Dict.make()->JSON.Encode.object,
  ~apiLogType: HyperLogger.apiLogType,
  ~url="",
  ~paymentMethod="",
  ~result: JSON.t=Dict.make()->JSON.Encode.object,
  ~optLogger: option<HyperLogger.loggerMake>,
  ~logType: HyperLogger.logType=INFO,
  ~logCategory: HyperLogger.logCategory=API,
  ~isPaymentSession: bool=false,
) => {
  let (value, internalMetadata) = switch apiLogType {
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
      ~apiLogType,
      ~isPaymentSession,
    )
  | None => ()
  }
}

let logInputChangeInfo = (text, logger: HyperLogger.loggerMake) => {
  logger.setLogInfo(~value=text, ~eventName=INPUT_FIELD_CHANGED)
}

let handleLogging = (
  ~optLogger: option<HyperLogger.loggerMake>,
  ~value,
  ~internalMetadata="",
  ~eventName,
  ~paymentMethod,
  ~logType: HyperLogger.logType=INFO,
) => {
  switch optLogger {
  | Some(logger) =>
    logger.setLogInfo(~value, ~internalMetadata, ~eventName, ~paymentMethod, ~logType)
  | _ => ()
  }
}
