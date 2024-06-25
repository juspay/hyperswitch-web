open LazyUtils

type props = {
  integrateError: bool,
  logger: OrcaLogger.loggerMake,
}

let make: props => React.element = reactLazy(() => import_("./PaymentMethodCollectElement.bs.js"))
