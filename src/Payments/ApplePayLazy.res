open LazyUtils

@obj
external makeProps: (
  ~sessionObj: option<Js.Json.t>,
  ~list: PaymentMethodsRecord.list,
  unit,
) => componentProps = ""

let make = reactLazy(.() => import_("./ApplePay.bs.js"))
