open LazyUtils

@obj
external makeProps: (
  ~sessionObj: SessionsType.token,
  ~list: PaymentMethodsRecord.list,
  unit,
) => componentProps = ""

let make = reactLazy(.() => import_("./PaypalSDK.bs.js"))
