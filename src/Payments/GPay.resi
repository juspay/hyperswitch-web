@react.component
let default: (
  ~sessionObj: option<SessionsType.token>,
  ~thirdPartySessionObj: option<JSON.t>,
) => React.element
