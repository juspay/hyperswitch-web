open LoggerTypes
include PaymentLoggerEvents

let logLifecycle = (
  ~event: lifecycleEvent,
  ~details=?,
  ~exn=?,
  ~failure=?,
  ~durationMs=?,
  ~paymentMethod=?,
  ~context=?,
  ~source=?,
  ~message=?,
) =>
  LoggerRuntime.emit(
    ~category=Lifecycle,
    ~spec=event->WebLoggerUtils.spec,
    ~severity=event->lifecycleSeverity,
    ~data=event->WebLoggerUtils.eventDetails,
    ~details?,
    ~exn?,
    ~failure?,
    ~durationMs?,
    ~paymentMethod?,
    ~context?,
    ~source?,
    ~message?,
  )
