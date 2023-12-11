open LazyUtils

type props = {
  sessionObj: option<SessionsType.token>,
  list: PaymentMethodsRecord.list,
  thirdPartySessionObj: option<Js.Json.t>,
  paymentType: CardThemeType.mode,
  walletOptions: array<string>,
}

let make: props => React.element = reactLazy(.() => import_("./GPay.bs.js"))
