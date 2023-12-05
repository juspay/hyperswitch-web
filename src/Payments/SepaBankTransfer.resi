@react.component
let default: (
  ~paymentType: CardThemeType.mode,
  ~list: PaymentMethodsRecord.list,
  ~countryProps: (string, array<string>),
) => React.element
