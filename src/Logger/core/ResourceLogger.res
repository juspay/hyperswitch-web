type resourceEvent =
  | Sdk(SdkLogger.resourceEvent)
  | ClickToPay(ClickToPayLogger.resourceEvent)
  | AuthenticationSession(AuthenticationSessionLogger.resourceEvent)
  | PaymentMethodSession(PaymentMethodSessionLogger.resourceEvent)

let observeResource = (
  ~event: resourceEvent,
  ~url,
  ~attributes=?,
  ~matchQuery=?,
  ~inBody=?,
  ~paymentMethod=?,
  ~context=?,
  ~source=?,
  ~abandoned=?,
  ~message=?,
  ~onLoad=?,
  ~onError=?,
) => {
  let (spec, severity, resource) = switch event {
  | Sdk(event) => (
      event->SharedLoggerEvent.spec(~action=Load),
      event->SdkLogger.resourceSeverity,
      event->SdkLogger.isStylesheet ? ResourceLoader.Stylesheet : ResourceLoader.Script,
    )
  | ClickToPay(event) | AuthenticationSession(event) => (
      event->SharedLoggerEvent.spec(~action=Load),
      event->ClickToPayLogger.resourceSeverity,
      event->ClickToPayLogger.isStylesheet ? ResourceLoader.Stylesheet : ResourceLoader.Script,
    )
  | PaymentMethodSession(event) => (
      event->SharedLoggerEvent.spec(~action=Load),
      event->PaymentMethodSessionLogger.resourceSeverity,
      ResourceLoader.Script,
    )
  }
  let (paymentMethod, context, source) = switch event {
  | AuthenticationSession(_) => (
      Some(ClickToPayLogger.paymentMethod),
      Some(context->AuthenticationSessionLogger.authenticationContext),
      Some(SharedLoggerRuntime.AuthenticationSession),
    )
  | ClickToPay(_) => (Some(ClickToPayLogger.paymentMethod), context, source)
  | Sdk(_) | PaymentMethodSession(_) => (paymentMethod, context, source)
  }
  LoggerRuntime.observeResource(
    ~spec,
    ~severity,
    ~url,
    ~resource,
    ~attributes?,
    ~matchQuery?,
    ~inBody?,
    ~paymentMethod?,
    ~context?,
    ~source?,
    ~abandoned?,
    ~message?,
    ~onLoad?,
    ~onError?,
  )
}
