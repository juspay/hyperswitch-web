open LazyUtils

type props = {list: PaymentMethodsRecord.list}

let make: props => React.element = reactLazy(() => import_("./PayPal.bs.js"))
