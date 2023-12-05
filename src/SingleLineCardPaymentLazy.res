open LazyUtils

type props = {
  paymentType: CardThemeType.mode,
  cardProps: CardUtils.cardProps,
  expiryProps: CardUtils.expiryProps,
  cvcProps: CardUtils.cvcProps,
  zipProps: CardUtils.zipProps,
  handleElementFocus: bool => unit,
  isFocus: bool,
}

let make: props => React.element = reactLazy(.() => import_("./SingleLineCardPayment.bs.js"))
