open LoggerTypes

let emit = (
  ~category, ~spec, ~severity, ~data=?, ~details=?, ~verbatim=?, ~exn=?,
  ~failure=?, ~durationMs=?, ~paymentMethod=?, ~context=?, ~source=?,
  ~message=?, ~once=?,
) =>
  LoggerRuntime.emit(~category, ~spec, ~severity, ~data?, ~details?, ~verbatim?,
    ~exn?, ~failure?, ~durationMs?, ~paymentMethod?, ~context?, ~source?,
    ~message?, ~once=once->Option.getOr(false))

let resource = (
  ~spec, ~severity, ~url, ~resource, ~attributes=?, ~matchQuery=?, ~inBody=?,
  ~paymentMethod=?, ~context=?, ~source=?, ~abandoned=?, ~message=?,
  ~onLoad=?, ~onError=?,
) =>
  LoggerRuntime.observeResource(~spec, ~severity, ~url,
    ~resource=switch resource {
    | SharedLoggerRuntime.Script => ResourceLoader.Script
    | SharedLoggerRuntime.Stylesheet => ResourceLoader.Stylesheet
    },
    ~attributes?, ~matchQuery?, ~inBody?, ~paymentMethod?, ~context?, ~source?,
    ~abandoned?, ~message?, ~onLoad?, ~onError?)

let configure = () => {
  LoggerConfig.configure(
    ~enableLogging=GlobalVars.enableLogging,
    ~logEndpoint=GlobalVars.logEndpoint,
    (),
  )
  WebLoggerQueue.configure()
  SharedLoggerRuntime.configure({
    emit,
    resource,
    isEnabled: LoggerRuntime.isEnabled,
    shouldLogMerchantConfig: LoggerRuntime.shouldLogMerchantConfig,
    getContext: LoggerContext.current,
    setSession: (~sessionId=?, ~merchantId=?, ()) =>
      LoggerContext.setSessionData(~sessionId?, ~merchantId?, ()),
    summarizeExn: WebLoggerUtils.summarizeExn,
    summarizeUnknown: WebLoggerUtils.summarizeUnknown,
    rethrow: LoggerRuntime.rethrow,
    defaultTimeoutMs: LoggerConfig.defaultTimeoutMs,
  })
}
