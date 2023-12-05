@react.component
let default: (
  ~sessionObj: option<SessionsType.token>,
  ~list: PaymentMethodsRecord.list,
  ~thirdPartySessionObj: option<Js.Json.t>,
) => React.element
