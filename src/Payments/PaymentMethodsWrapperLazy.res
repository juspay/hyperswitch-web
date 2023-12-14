open LazyUtils

type props = {
  paymentType: CardThemeType.mode,
  list: PaymentMethodsRecord.list,
  paymentMethodName: string,
}

let make: props => React.element = reactLazy(.() => import_("./PaymentMethodsWrapper.bs.js"))
