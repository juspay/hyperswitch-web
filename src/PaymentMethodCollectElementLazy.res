open LazyUtils

type props = {
  enabled_payment_methods: array<PaymentMethodCollectUtils.paymentMethodType>,
  integrateError: bool,
  logger: OrcaLogger.loggerMake,
}

let make: props => React.element = reactLazy(() => import_("./PaymentMethodCollectElement.bs.js"))
