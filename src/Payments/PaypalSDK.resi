@react.component
let make: (~sessionObj: SessionsType.token, ~list: PaymentMethodsRecord.list) => React.element
let default: props<SessionsType.token, PaymentMethodsRecord.list> => React.element
