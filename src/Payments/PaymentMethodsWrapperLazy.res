open LazyUtils

@obj
external makeProps: (
  ~paymentType: CardThemeType.mode,
  ~list: PaymentMethodsRecord.list,
  ~paymentMethodName: string,
  unit,
) => componentProps = ""

let make = reactLazy(.() => import_("./PaymentMethodsWrapper.bs.js"))
