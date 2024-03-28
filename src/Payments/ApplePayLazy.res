open LazyUtils

type props = {
  sessionObj: option<JSON.t>,
  list: PaymentMethodsRecord.list,
}

let make: props => React.element = reactLazy(() => import_("./ApplePay.bs.js"))
