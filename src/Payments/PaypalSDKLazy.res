open LazyUtils

type props = {sessionObj: SessionsType.token}

let make: props => React.element = reactLazy(() => import_("./PaypalSDK.bs.js"))
