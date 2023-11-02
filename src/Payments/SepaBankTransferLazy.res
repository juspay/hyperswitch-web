open LazyUtils

@obj
external makeProps: (
  ~paymentType: CardThemeType.mode,
  ~list: PaymentMethodsRecord.list,
  ~countryProps: (string, array<string>),
  unit,
) => componentProps = ""

let make = reactLazy(.() => import_("./SepaBankTransfer.bs.js"))
