@react.component
let default: (
  ~sessionObj: option<JSON.t>,
  ~list: PaymentMethodsRecord.list,
  ~paymentType: option<CardThemeType.mode>,
  ~walletOptions: array<string>,
) => React.element
