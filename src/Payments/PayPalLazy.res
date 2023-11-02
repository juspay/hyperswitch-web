open LazyUtils

@obj
external makeProps: (~list: PaymentMethodsRecord.list, unit) => componentProps = ""

let make = reactLazy(.() => import_("./PayPal.bs.js"))
