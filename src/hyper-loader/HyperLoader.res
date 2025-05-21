let loadHyper = (str, option) => {
  Promise.resolve(Hyper.make(str, option, None))
}

let loadStripe = (str, option) => {
  ErrorUtils.manageErrorWarning(DEPRECATED_LOADSTRIPE, ~logger=LoggerUtils.defaultLoggerConfig)
  loadHyper(str, option)
}

let removeBeforeUnloadEventListeners: array<'ev => unit> => unit = handlers => {
  let iframeMessageHandler = (ev: Types.event) => {
    let dict = ev.data->Identity.anyTypeToJson->Utils.getDictFromJson
    dict
    ->Dict.get("disableBeforeUnloadEventListener")
    ->Option.map(shouldRemove => {
      if shouldRemove->JSON.Decode.bool->Option.getOr(false) {
        try {
          handlers
          ->Array.map(handler => {
            Window.removeEventListener("beforeunload", handler)
          })
          ->ignore
        } catch {
        | err => Js.Console.error2("Incorrect usage of removeBeforeUnloadEventListeners hook", err)
        }
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
window["removeBeforeUnloadEventListeners"] = removeBeforeUnloadEventListeners

let isWordpress = window["wp"] !== JSON.Encode.null
if !isWordpress {
  window["Stripe"] = Hyper.make
}
