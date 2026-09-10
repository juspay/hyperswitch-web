%%raw(`require("tailwindcss/tailwind.css")`)
%%raw("import './index.css'")

Sentry.initiateSentry(~dsn=GlobalVars.sentryDSN)

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
    ~message="Uncaught error in SDK iframe",
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
    ~message="Unhandled promise rejection in SDK iframe",
    ~details=[("error_message", reason->describeCrashValue->describeCrashText)],
  )
})

let app = switch ReactDOM.querySelector("#app") {
| Some(container) =>
  let root = ReactDOM.Client.createRoot(container)
  root->ReactDOM.Client.Root.render(
    <div className="h-auto flex flex-col ">
      <div className="h-auto flex flex-col">
        <Jotai.Provider>
          <ErrorBoundary level=ErrorBoundary.Top componentName="App">
            <App />
          </ErrorBoundary>
        </Jotai.Provider>
      </div>
    </div>,
  )
| None => ()
}
app
