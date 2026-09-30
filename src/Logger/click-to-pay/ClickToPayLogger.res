open LoggerTypes
include ClickToPayLoggerEvents

let paymentMethod = LoggerPaymentMethod.Card

let source = () =>
  LoggerRuntime.isMerchantWindow() ? Some(LoggerRuntime.AuthenticationSession) : None

let logLifecycle = (~event: lifecycleEvent, ~details=?, ~exn=?, ~message=?) =>
  LoggerRuntime.emit(
    ~category=Lifecycle,
    ~spec=event->LoggerUtils.spec,
    ~severity=event->lifecycleSeverity,
    ~data=event->LoggerUtils.eventDetails,
    ~details?,
    ~exn?,
    ~paymentMethod,
    ~source=?source(),
    ~message?,
  )

let observe = (
  ~category,
  ~spec,
  ~severity,
  ~data,
  ~details=?,
  ~failureOf,
  ~detailsOf=?,
  ~message=?,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category,
    ~spec,
    ~severity,
    ~data,
    ~details?,
    ~failureOf,
    ~detailsOf?,
    ~paymentMethod,
    ~source=?source(),
    ~message?,
    ~call,
  )

let observeFunction = (~event: functionEvent, ~detailsOf=?, ~message=?, ~call) =>
  observe(
    ~category=Function,
    ~spec=event->LoggerUtils.spec(~action=Call),
    ~severity=event->functionSeverity,
    ~data=event->LoggerUtils.eventDetails,
    ~failureOf=LoggerUtils.summarizeErrorResponse,
    ~detailsOf?,
    ~message?,
    ~call,
  )

let observeMerchantCall = (~method: merchantMethod, ~details=?, ~detailsOf=?, ~message=?, ~call) =>
  observe(
    ~category=Merchant,
    ~spec=method->LoggerUtils.spec(~action=Call),
    ~severity=method->merchantCallSeverity,
    ~data=[("surface", "AUTHENTICATION_SESSION"->JSON.Encode.string)],
    ~details?,
    ~failureOf=LoggerUtils.summarizeErrorResponse,
    ~detailsOf?,
    ~message?,
    ~call,
  )

let observeApi = (~event: apiEvent, ~url, ~message=?, ~call) =>
  observe(
    ~category=Api,
    ~spec=event->LoggerUtils.spec(~action=Request),
    ~severity=event->apiSeverity,
    ~data=event->LoggerUtils.eventDetails->Array.concat([("url", url->JSON.Encode.string)]),
    ~failureOf=LoggerUtils.httpFailure,
    ~detailsOf=LoggerUtils.httpDetails,
    ~message?,
    ~call,
  )

let observeResource = (
  ~event: resourceEvent,
  ~url,
  ~attributes=?,
  ~matchQuery=?,
  ~message=?,
  ~onLoad=?,
  ~onError=?,
) =>
  LoggerRuntime.observeResource(
    ~spec=event->LoggerUtils.spec(~action=Load),
    ~severity=event->resourceSeverity,
    ~url,
    ~resource=event->resourceKind,
    ~attributes?,
    ~matchQuery?,
    ~paymentMethod,
    ~source=?source(),
    ~message?,
    ~onLoad?,
    ~onError?,
  )
