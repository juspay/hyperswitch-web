@react.component
let default: (
  ~sessionObj: option<SessionsType.token>,
  ~list: PaymentMethodsRecord.list,
  ~thirdPartySessionObj: option<Js.Json.t>,
  ~paymentType: option<CardThemeType.mode>,
  ~walletOptions: array<string>,
) => React.element
