type props = {
  paymentType: CardThemeType.mode,
  list: PaymentMethodsRecord.list,
  countryProps: (string, array<string>),
}

let default: props => React.element
