@react.component
let default: (
  ~sessionObj: option<SessionsType.token>,
  ~thirdPartySessionObj: option<JSON.t>,
  ~walletOptions: array<string>,
) => React.element
