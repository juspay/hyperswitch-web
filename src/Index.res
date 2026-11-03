%%raw(`require("tailwindcss/tailwind.css")`)
%%raw("import './index.css'")

Sentry.initiateSentry(~dsn=GlobalVars.sentryDSN)

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
