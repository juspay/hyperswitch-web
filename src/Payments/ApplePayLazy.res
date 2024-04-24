open LazyUtils

type props = {
  sessionObj: option<JSON.t>,
  paymentType: CardThemeType.mode,
  walletOptions: array<string>,
}

let make: props => React.element = reactLazy(() => import_("./ApplePay.bs.js"))
