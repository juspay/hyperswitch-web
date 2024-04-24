@react.component
let default: (
  ~sessionObj: option<SessionsType.token>,
  ~thirdPartySessionObj: option<JSON.t>,
  ~paymentType: option<CardThemeType.mode>,
  ~walletOptions: array<string>,
) => React.element
