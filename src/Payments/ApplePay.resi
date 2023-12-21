@react.component
let default: (
  ~sessionObj: option<Js.Json.t>,
  ~list: PaymentMethodsRecord.list,
  ~paymentType: option<CardThemeType.mode>,
  ~walletOptions: array<string>,
) => React.element
