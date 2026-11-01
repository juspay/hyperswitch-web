open LoggerTypes
include PaymentMethodSessionLoggerEvents

let logState = (~event: stateEvent, ~context=?, ~durationMs=?) =>
  LoggerRuntime.emit(
    ~category=State,
    ~spec=event->WebLoggerUtils.spec,
    ~severity=event->stateSeverity,
    ~data=event->WebLoggerUtils.eventDetails,
    ~context?,
    ~durationMs?,
  )

let logLifecycle = (
  ~event: lifecycleEvent,
  ~context=?,
  ~details=?,
  ~exn=?,
  ~paymentMethod=LoggerPaymentMethod.Card,
  ~message=?,
) =>
  LoggerRuntime.emit(
    ~category=Lifecycle,
    ~spec=event->WebLoggerUtils.spec,
    ~severity=event->lifecycleSeverity,
    ~data=event->WebLoggerUtils.eventDetails,
    ~context?,
    ~details?,
    ~exn?,
    ~paymentMethod,
    ~message?,
  )

let logFunction = (
  ~event: functionEvent,
  ~outcome,
  ~context=?,
  ~startedAt=?,
  ~exn=?,
  ~paymentMethod=LoggerPaymentMethod.Card,
  ~message=?,
) =>
  LoggerRuntime.emitPhase(
    ~category=Function,
    ~spec=event->WebLoggerUtils.spec(~action=Call),
    ~severity=event->functionSeverity,
    ~outcome,
    ~data=event->WebLoggerUtils.eventDetails,
    ~context?,
    ~startedAt?,
    ~exn?,
    ~paymentMethod,
    ~message?,
  )

let logApi = (
  ~event: apiEvent,
  ~outcome,
  ~context=?,
  ~details=?,
  ~startedAt=?,
  ~exn=?,
  ~paymentMethod=LoggerPaymentMethod.Card,
) =>
  LoggerRuntime.emitPhase(
    ~category=Api,
    ~spec=event->WebLoggerUtils.spec(~action=Request),
    ~severity=event->apiSeverity,
    ~outcome,
    ~data=event->WebLoggerUtils.eventDetails,
    ~context?,
    ~details?,
    ~startedAt?,
    ~exn?,
    ~paymentMethod,
  )

let observeResource = (
  ~event: resourceEvent,
  ~url,
  ~attributes=?,
  ~context=?,
  ~onLoad=?,
  ~onError=?,
) =>
  LoggerRuntime.observeResource(
    ~spec=event->WebLoggerUtils.spec(~action=Load),
    ~severity=event->resourceSeverity,
    ~url,
    ~resource=ResourceLoader.Script,
    ~attributes?,
    ~context?,
    ~onLoad?,
    ~onError?,
  )
