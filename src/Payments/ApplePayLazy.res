open LazyUtils

type props = {
  sessionObj: option<JSON.t>
}

let make: props => React.element = reactLazy(() => import_("./ApplePay.bs.js"))
