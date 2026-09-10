let describeCrashText = text =>
  text->LoggerCommonHelpers.truncateDiagnosticText(~maxLength=256)->JSON.Encode.string

let describeCrashValue = value =>
  switch value->JSON.Decode.string {
  | Some(text) => text
  | None =>
    switch value->Utils.getDictFromJson->Utils.getOptionString("message") {
    | Some(text) => text
    | None => "UNKNOWN"
    }
  }

let isLoggingGlobalCrash = ref(false)

let logGlobalCrash = (~message, ~details) =>
  if !isLoggingGlobalCrash.contents {
    isLoggingGlobalCrash := true
    LoggerCommonHelpers.safeRun(() => SdkRuntimeLogger.logCrash(~message, ~details))
    isLoggingGlobalCrash := false
  }

Window.addEventListener("error", (event: JSON.t) => {
  let eventDict = event->Utils.getDictFromJson
  logGlobalCrash(
    ~message="Uncaught error in hyper loader",
    ~details=[
      ("error_message", eventDict->Utils.getString("message", "UNKNOWN")->describeCrashText),
      (
        "error_source",
        eventDict
        ->Utils.getString("filename", "")
        ->LoggerCommonHelpers.sanitizedUrl
        ->describeCrashText,
      ),
    ],
  )
})

Window.addEventListener("unhandledrejection", (event: JSON.t) => {
  let reason = event->Utils.getDictFromJson->Utils.getJsonObjectFromDict("reason")
  logGlobalCrash(
    ~message="Unhandled promise rejection in hyper loader",
    ~details=[("error_message", reason->describeCrashValue->describeCrashText)],
  )
})

let loadHyper = (str, option) => {
  Promise.resolve(Hyper.make(str, option, None))
}

let loadStripe = (str, option) => {
  ErrorUtils.manageErrorWarning(DeprecatedLoadStripe)
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

Types.window["Hyper"] = Hyper.make
Types.window["Hyper"]["init"] = Hyper.make
Types.window["removeBeforeUnloadEventListeners"] = removeBeforeUnloadEventListeners

let isWordpress = Types.window["wp"] !== JSON.Encode.null
if !isWordpress {
  Types.window["Stripe"] = Hyper.make
}
