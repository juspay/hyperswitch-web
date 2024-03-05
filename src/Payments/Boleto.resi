let cleanSocialSecurityNumber: Js.String2.t => Js.String2.t
let formatSocialSecurityNumber: Js.String2.t => Js.String2.t
@react.component
let make: (~paymentType: CardThemeType.mode, ~list: PaymentMethodsRecord.list) => React.element
let default: props<CardThemeType.mode, PaymentMethodsRecord.list> => React.element
