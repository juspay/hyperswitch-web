open LoggerTypes
include HyperLoaderLoggerEvents

let observeMerchantCall = (
  ~event: merchantCallEvent,
  ~details=[],
  ~timeoutMs=?,
  ~failureOf=LoggerUtils.summarizeErrorResponse,
  ~detailsOf=?,
  ~source=?,
  ~message=?,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category=Merchant,
    ~spec=event->LoggerUtils.spec(~action=Call),
    ~severity=event->merchantCallSeverity,
    ~data=event->LoggerUtils.eventDetails,
    ~details,
    ~timeoutMs?,
    ~failureOf,
    ~detailsOf?,
    ~source?,
    ~message?,
    ~call,
  )

let observeMerchantCallback = (
  ~event: merchantCallbackEvent,
  ~timeoutMs=?,
  ~message=?,
  ~callback,
) =>
  LoggerRuntime.observeCallback(
    ~category=Merchant,
    ~spec=event->LoggerUtils.spec(~action=Callback),
    ~severity=event->merchantCallbackSeverity,
    ~data=event->LoggerUtils.eventDetails,
    ~timeoutMs?,
    ~failureOf=LoggerUtils.summarizeErrorResponse,
    ~message?,
    ~callback,
  )

let logMerchantCall = (~event: merchantCallEvent, ~details=[], ~message=?) =>
  LoggerRuntime.emit(
    ~category=Merchant,
    ~spec=event->LoggerUtils.spec(~action=Call, ~outcome=Returned),
    ~severity=(event->merchantCallSeverity).success,
    ~data=event->LoggerUtils.eventDetails,
    ~details,
    ~message?,
  )

let logMerchantProps = (~event: merchantPropEvent, ~details=[], ~message=?) =>
  if !LoggerRuntime.isNestedElement() {
    LoggerRuntime.emit(
      ~category=Merchant,
      ~spec=event->LoggerUtils.spec(~action=Prop),
      ~severity=event->merchantPropSeverity,
      ~data=event->LoggerUtils.eventDetails,
      ~details,
      ~message?,
      ~once=true,
    )
  }

let logMerchantIssue = (~issue: merchantIssue, ~details=[], ~message=?) =>
  if !LoggerRuntime.isNestedElement() {
    LoggerRuntime.emit(
      ~category=Merchant,
      ~spec=issue->LoggerUtils.spec(~action=IntegrationIssue),
      ~severity=issue->merchantIssueSeverity,
      ~data=issue->LoggerUtils.eventDetails,
      ~details,
      ~message?,
      ~once=true,
    )
  }

let startSession = (~sessionId=?, ~merchantId=?) => {
  LoggerRuntime.configure(~source=HyperLoader)
  LoggerContext.setSessionData(~sessionId?, ~merchantId?, ())
}
