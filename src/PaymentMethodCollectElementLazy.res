open LazyUtils

type props = {
  enabledPaymentMethods: array<PaymentMethodCollectUtils.paymentMethodType>,
  integrateError: bool,
  logger: OrcaLogger.loggerMake,
}

let make: props => React.element = reactLazy(() => import_("./PaymentMethodCollectElement.bs.js"))
