let loadHyper = (str, option) => {
  Promise.resolve(Hyper.make(str, option, None))
}

let loadStripe = (str, option) => {
  ErrorUtils.manageErrorWarning(DEPRECATED_LOADSTRIPE, ~logger=HyperLogger.defaultLoggerConfig)
  loadHyper(str, option)
}

let removeBeforeUnloadEventListener: ('ev => unit) => unit = handler => {
  let iframeMessageHandler = (ev: Types.event) => {
    let dict = ev.data->Identity.anyTypeToJson->Utils.getDictFromJson
    dict
    ->Dict.get("disableBeforeUnloadEventListener")
    ->Option.map(shouldRemove => {
      if shouldRemove->JSON.Decode.bool->Option.getOr(false) {
        Window.removeEventListener("beforeunload", handler)
      }
    })
    ->ignore
  }

  // Subscribe to postMessage event
  Window.addEventListener("message", iframeMessageHandler)
}

@val external window: {..} = "window"
window["Hyper"] = Hyper.make
window["Hyper"]["init"] = Hyper.make
window["removeBeforeUnloadEventListener"] = removeBeforeUnloadEventListener

let isWordpress = window["wp"] !== JSON.Encode.null
if !isWordpress {
  window["Stripe"] = Hyper.make
}
