open LoggerTypes
include HyperLoaderLoggerEvents

let observeMerchantCall = (
  ~event: merchantCallEvent,
  ~details=?,
  ~timeoutMs=?,
  ~failureOf=WebLoggerUtils.summarizeErrorResponse,
  ~detailsOf=?,
  ~source=?,
  ~context=?,
  ~message=?,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category=Merchant,
    ~spec=event->WebLoggerUtils.spec(~action=Call),
    ~severity=event->merchantCallSeverity,
    ~data=event->WebLoggerUtils.eventDetails,
    ~details?,
    ~timeoutMs?,
    ~failureOf,
    ~detailsOf?,
    ~source?,
    ~context?,
    ~message?,
    ~call,
  )

let observeMerchantCallback = (
  ~event: merchantCallbackEvent,
  ~context=?,
  ~source=?,
  ~timeoutMs=?,
  ~message=?,
  ~callback,
) =>
  LoggerRuntime.observeCallback(
    ~category=Merchant,
    ~spec=event->WebLoggerUtils.spec(~action=Callback),
    ~context?,
    ~source?,
    ~severity=event->merchantCallbackSeverity,
    ~data=event->WebLoggerUtils.eventDetails,
    ~timeoutMs?,
    ~failureOf=WebLoggerUtils.summarizeErrorResponse,
    ~message?,
    ~callback,
  )

let logMerchantCall = (~event: merchantCallEvent, ~details=?, ~message=?) =>
  LoggerRuntime.emit(
    ~category=Merchant,
    ~spec=event->WebLoggerUtils.spec(~action=Call, ~outcome=Returned),
    ~severity=(event->merchantCallSeverity).success,
    ~data=event->WebLoggerUtils.eventDetails,
    ~details?,
    ~message?,
  )

let logMerchantProps = (
  ~event: merchantPropEvent,
  ~details=?,
  ~config: option<JSON.t>=?,
  ~isSensitive=WebLoggerUtils.maskAll,
  ~message=?,
) =>
  if !LoggerRuntime.isNestedElement() && event->merchantPropSeverity->LoggerRuntime.isEnabled {
    LoggerRuntime.emit(
      ~category=Merchant,
      ~spec=event->WebLoggerUtils.spec(~action=Prop),
      ~severity=event->merchantPropSeverity,
      ~data=event->WebLoggerUtils.eventDetails,
      ~details?,
      ~verbatim=?config->Option.map(config => config->WebLoggerUtils.configSnapshot(~isSensitive)),
      ~message?,
      ~once=true,
    )
  }

let logMerchantIssue = (~issue: merchantIssue, ~details=?, ~context=?, ~message=?) =>
  if !LoggerRuntime.isNestedElement() {
    LoggerRuntime.emit(
      ~category=Merchant,
      ~spec=issue->WebLoggerUtils.spec(~action=IntegrationIssue),
      ~context?,
      ~severity=issue->merchantIssueSeverity,
      ~data=issue->WebLoggerUtils.eventDetails,
      ~details?,
      ~message?,
      ~once=true,
    )
  }

let startSession = (~sessionId=?, ~merchantId=?) => {
  LoggerContext.setSessionData(~sessionId?, ~merchantId?, ())
}
