@react.component
let default: (
  ~sessionObj: option<JSON.t>,
  ~paymentType: option<CardThemeType.mode>,
  ~walletOptions: array<string>,
) => React.element
