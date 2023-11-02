open LazyUtils

@obj
external makeProps: (
  ~paymentType: CardThemeType.mode,
  ~list: PaymentMethodsRecord.list,
  ~countryProps: ('a, Js.Array2.t<string>),
  unit,
) => componentProps = ""

let make = reactLazy(.() => import_("./KlarnaPayment.bs.js"))
