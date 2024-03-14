open LazyUtils

type props = {
  paymentType: CardThemeType.mode,
  list: PaymentMethodsRecord.list,
  countryProps: (string, array<string>),
}

let make: props => React.element = reactLazy(() => import_("./KlarnaPayment.bs.js"))
