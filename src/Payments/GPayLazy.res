open LazyUtils

type props = {
  sessionObj: option<SessionsType.token>,
  thirdPartySessionObj: option<JSON.t>,
  paymentType: CardThemeType.mode,
  walletOptions: array<string>,
}

let make: props => React.element = reactLazy(() => import_("./GPay.bs.js"))
