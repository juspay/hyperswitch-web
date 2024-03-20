open LazyUtils

type props = {
  sessionObj: option<JSON.t>,
  list: PaymentMethodsRecord.list,
  paymentType: CardThemeType.mode,
  walletOptions: array<string>,
}

let make: props => React.element = reactLazy(() => import_("./ApplePay.bs.js"))
