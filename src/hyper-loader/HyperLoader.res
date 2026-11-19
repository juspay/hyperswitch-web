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

/* Checkpoint 1: the script was delivered, parsed and evaluated on the merchant
   page. Emitted with a one-shot beacon rather than a logger instance, so a page
   that loads the script and never calls Hyper.init pays for no timer and no
   beforeunload listener. The gap between this count and APP_INITIATED is the
   client-side read on WAF/CSP script-delivery problems. */
HyperLogger.sendSingleLog(
  ~eventName=SDK_SCRIPT_LOADED,
  ~sessionId=SdkLoadSession.sessionId,
  ~value=[("version", GlobalVars.repoVersion->JSON.Encode.string)]
  ->Dict.fromArray
  ->JSON.Encode.object
  ->JSON.stringify,
)

Types.window["Hyper"] = Hyper.make
Types.window["Hyper"]["init"] = Hyper.make
Types.window["removeBeforeUnloadEventListeners"] = removeBeforeUnloadEventListeners

let isWordpress = Types.window["wp"] !== JSON.Encode.null
if !isWordpress {
  Types.window["Stripe"] = Hyper.make
}
