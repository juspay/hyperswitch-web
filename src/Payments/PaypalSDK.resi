@react.component
let make: (
  ~sessionObj: OrcaPaymentPage.SessionsType.token,
  ~list: OrcaPaymentPage.PaymentMethodsRecord.list,
) => React.element
let default: props<
  OrcaPaymentPage.SessionsType.token,
  OrcaPaymentPage.PaymentMethodsRecord.list,
> => React.element
