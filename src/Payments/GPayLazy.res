open LazyUtils

type props = {
  sessionObj: option<SessionsType.token>,
  list: PaymentMethodsRecord.list,
  thirdPartySessionObj: option<JSON.t>,
  paymentType: CardThemeType.mode,
  walletOptions: array<string>,
}

let make: props => React.element = reactLazy(.() => import_("./GPay.bs.js"))
