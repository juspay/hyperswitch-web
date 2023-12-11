type props = {
  sessionObj: option<SessionsType.token>,
  list: PaymentMethodsRecord.list,
  thirdPartySessionObj: option<Js.Json.t>,
  paymentType: option<CardThemeType.mode>,
  walletOptions: array<string>,
}

let default: props => React.element
