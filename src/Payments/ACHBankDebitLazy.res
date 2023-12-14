open LazyUtils

type props = {
  paymentType: CardThemeType.mode,
  list: PaymentMethodsRecord.list,
}

let make: props => React.element = reactLazy(.() => import_("./ACHBankDebit.bs.js"))
