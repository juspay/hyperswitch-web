open LazyUtils

@obj
external makeProps: (
  ~sessionObj: option<SessionsType.token>,
  ~list: PaymentMethodsRecord.list,
  ~thirdPartySessionObj: option<Js.Json.t>,
  unit,
) => componentProps = ""

let make = reactLazy(.() => import_("./GPay.bs.js"))
