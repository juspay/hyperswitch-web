open LazyUtils

type props = {
  paymentType: CardThemeType.mode,
  list: PaymentMethodsRecord.list,
}

let make: props => React.element = reactLazy(() => import_("./KlarnaPayment.bs.js"))
