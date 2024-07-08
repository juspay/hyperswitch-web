open LazyUtils

type props = {}
let make: props => React.element = reactLazy(() => import_("./PaymentManagement.bs.js"))
