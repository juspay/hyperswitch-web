open LazyUtils

type props = {
  paymentType: CardThemeType.mode,
  cardProps: CardUtils.cardProps,
  expiryProps: CardUtils.expiryProps,
  cvcProps: CardUtils.cvcProps,
  countryProps: (string, Js.Array2.t<string>),
}

let make: props => React.element = reactLazy(.() => import_("./PaymentElementRenderer.bs.js"))
