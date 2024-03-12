let loadHyper = (str, option) => {
  Promise.resolve(Hyper.make(str, option))
}

let loadStripe = (str, option) => {
  ErrorUtils.manageErrorWarning(DEPRECATED_LOADSTRIPE, (), ~logger=OrcaLogger.defaultLoggerConfig)
  loadHyper(str, option)
}

@val external window: {..} = "window"
window["Hyper"] = Hyper.make
window["Hyper"]["init"] = Hyper.make

let isWordpress = window["wp"] !== JSON.Encode.null
if !isWordpress {
  window["Stripe"] = Hyper.make
}
