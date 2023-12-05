open LazyUtils

type props = {
  sessionObj: SessionsType.token,
  list: PaymentMethodsRecord.list,
}

let make: props => React.element = reactLazy(.() => import_("./PaypalSDK.bs.js"))
