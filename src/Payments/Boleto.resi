let cleanSocialSecurityNumber: Js.String2.t => Js.String2.t
let formatSocialSecurityNumber: Js.String2.t => Js.String2.t
@react.component
let make: (
  ~paymentType: OrcaPaymentPage.CardThemeType.mode,
  ~list: OrcaPaymentPage.PaymentMethodsRecord.list,
) => React.element
let default: props<
  OrcaPaymentPage.CardThemeType.mode,
  OrcaPaymentPage.PaymentMethodsRecord.list,
> => React.element
