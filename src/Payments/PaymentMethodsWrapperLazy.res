open LazyUtils

type props = {
  paymentType: CardThemeType.mode,
  paymentMethodName: string,
}

let make: props => React.element = reactLazy(() => import_("./PaymentMethodsWrapper.bs.js"))
