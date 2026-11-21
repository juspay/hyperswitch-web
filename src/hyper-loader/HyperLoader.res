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
    if (
      dict->Utils.getBool("disableBeforeUnloadEventListener", false) &&
        (PaymentMessageSecurity.isExpectedSender(
          ~source=Utils.window,
          ~origin=Window.Location.origin,
          ~eventSource=ev.source,
          ~eventOrigin=ev.origin,
        ) ||
        // A same-origin merchant wrapper can call Hyper.confirmPayment and
        // redirect the top window. It shares the top document's principal.
        PaymentMessageSecurity.isSameOriginDescendant(
          ~window=Utils.window,
          ~origin=Window.Location.origin,
          ~eventSource=ev.source,
          ~eventOrigin=ev.origin,
        ) ||
        SdkMessageSources.isRegisteredSender(ev))
    ) {
      try {
        handlers->Array.forEach(handler => Window.removeEventListener("beforeunload", handler))
      } catch {
      | err => Console.error2("Incorrect usage of removeBeforeUnloadEventListeners hook", err)
      }
    }
  }

  // Subscribe to postMessage event
  Window.addEventListener("message", iframeMessageHandler)
}

Types.window["Hyper"] = Hyper.make
Types.window["Hyper"]["init"] = Hyper.make
Types.window["removeBeforeUnloadEventListeners"] = removeBeforeUnloadEventListeners

let isWordpress = Types.window["wp"] !== JSON.Encode.null
if !isWordpress {
  Types.window["Stripe"] = Hyper.make
}
