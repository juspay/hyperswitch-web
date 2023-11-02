let loadHyper = (str, option) => {
  Js.Promise.resolve(Hyper.make(str, option))
}

let loadStripe = (str, option) => {
  ErrorUtils.manageErrorWarning(DEPRECATED_LOADSTRIPE, (), ~logger=OrcaLogger.defaultLoggerConfig)
  loadHyper(str, option)
}

@val external window: {..} = "window"
window["Hyper"] = Hyper.make

let isWordpress = window["wp"] !== Js.Json.null
if !isWordpress {
  window["Stripe"] = Hyper.make
}
