open LazyUtils

type props = {sessionObj: SessionsType.token, paymentType: CardThemeType.mode}

let make: props => React.element = reactLazy(() => import_("./PaypalSDK.bs.js"))
