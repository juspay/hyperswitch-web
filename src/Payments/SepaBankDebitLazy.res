open LazyUtils

type props = {paymentType: CardThemeType.mode}

let make: props => React.element = reactLazy(() => import_("./SepaBankDebit.bs.js"))
