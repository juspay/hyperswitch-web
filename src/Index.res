%%raw(`require("tailwindcss/tailwind.css")`)

Sentry.initiateSentry(~dsn=GlobalVars.sentryDSN)

let app = switch ReactDOM.querySelector("#app") {
| Some(container) =>
  let root = ReactDOM.Client.createRoot(container)
  root->ReactDOM.Client.Root.render(
    <div className="h-auto flex flex-col ">
      <div className="h-auto flex flex-col">
        <Recoil.RecoilRoot>
          <ErrorBoundary level=ErrorBoundary.Top>
            <App />
          </ErrorBoundary>
        </Recoil.RecoilRoot>
      </div>
    </div>,
  )
| None => ()
}
app
