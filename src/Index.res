%%raw(`require("tailwindcss/tailwind.css")`)

Sentry.initiateSentry(~dsn=GlobalVars.sentryDSN)

let app = switch ReactDOM.querySelector("#app") {
| Some(container) =>
  open ReactDOM.Experimental
  let root = createRoot(container)
  root->render(
    <div className="h-auto flex flex-col ">
      <div className="h-auto flex flex-col">
        <Recoil.RecoilRoot>
          <ErrorBoundary level=ErrorBoundary.Top> <App /> </ErrorBoundary>
        </Recoil.RecoilRoot>
      </div>
    </div>,
  )
| None => ()
}
app
