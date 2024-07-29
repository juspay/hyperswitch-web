@react.component
let default: (
  ~sessionObj: option<JSON.t>,
  ~walletOptions: array<string>,
  ~paymentType: CardThemeType.mode,
) => React.element
