open LazyUtils

type props = {
  paymentType: CardThemeType.mode,
  list: PaymentMethodsRecord.list,
  countryProps: (string, Js.Array2.t<string>),
}

let make: props => React.element = reactLazy(.() => import_("./KlarnaPayment.bs.js"))
