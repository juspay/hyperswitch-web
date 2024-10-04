let logApi = (
  ~eventName,
  ~statusCode="",
  ~data: JSON.t=Dict.make()->JSON.Encode.object,
  ~apiLogType: LogUtils.apiLogType,
  ~url="",
  ~paymentMethod="",
  ~result: JSON.t=Dict.make()->JSON.Encode.object,
  ~optLogger: option<OrcaLogger.loggerMake>,
  ~logType: OrcaLogger.logType=INFO,
  ~logCategory: OrcaLogger.logCategory=API,
  ~isPaymentSession: bool=false,
) => {
  let (value, internalMetadata) = LogUtils.getApiLogValues(apiLogType, url, statusCode, data)

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

let logInputChangeInfo = (text, logger: OrcaLogger.loggerMake) => {
  logger.setLogInfo(~value=text, ~eventName=INPUT_FIELD_CHANGED)
}

let handleLogging = (
  ~optLogger: option<OrcaLogger.loggerMake>,
  ~value,
  ~internalMetadata="",
  ~eventName,
  ~paymentMethod,
  ~logType: OrcaLogger.logType=INFO,
) => {
  switch optLogger {
  | Some(logger) =>
    logger.setLogInfo(~value, ~internalMetadata, ~eventName, ~paymentMethod, ~logType)
  | _ => ()
  }
}
