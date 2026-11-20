open LoggerTypes

let emit = (
  ~category, ~spec, ~severity, ~data=?, ~details=?, ~verbatim=?, ~exn=?,
  ~failure=?, ~durationMs=?, ~paymentMethod=?, ~context=?, ~source=?,
  ~message=?, ~once=?,
) =>
  LoggerRuntime.emit(~category, ~spec, ~severity, ~data?, ~details?, ~verbatim?,
    ~exn?, ~failure?, ~durationMs?, ~paymentMethod?, ~context?, ~source?,
    ~message?, ~once=once->Option.getOr(false))

let configure = () => {
  LoggerConfig.configure(
    ~enableLogging=GlobalVars.enableLogging,
    ~logEndpoint=GlobalVars.logEndpoint,
    (),
  )
  WebLoggerQueue.configure()
  SharedLoggerRuntime.configure({
    emit,
    isEnabled: LoggerRuntime.isEnabled,
    shouldLogMerchantConfig: LoggerRuntime.shouldLogMerchantConfig,
    getContext: LoggerContext.current,
    setSession: (~sessionId=?, ~merchantId=?, ()) =>
      LoggerContext.setSessionData(~sessionId?, ~merchantId?, ()),
    summarizeExn: WebLoggerUtils.summarizeExn,
    summarizeUnknown: WebLoggerUtils.summarizeUnknown,
    defaultTimeoutMs: LoggerConfig.defaultTimeoutMs,
  })
}
