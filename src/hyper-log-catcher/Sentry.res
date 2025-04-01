type integration
type scope
type instrumentation

type tag = {mutable tag: string}
type hint = {originalException: tag}
external toJson: Exn.t => tag = "%identity"
external toExn: tag => Exn.t = "%identity"
type event
type sentryInitArg = {
  dsn: string,
  integrations: array<integration>,
  tracesSampleRate: float,
  tracePropagationTargets: array<string>,
  replaysSessionSampleRate: float,
  replaysOnErrorSampleRate: float,
}

external exnToJsExn: exn => option<Exn.t> = "%identity"

@module("@sentry/react")
external initSentry: sentryInitArg => unit = "init"

@module("@sentry/react")
external newBrowserTracing: unit => integration = "browserTracingIntegration"

type reactRouterV6BrowserTracingIntegrationArg = {useEffect: (unit => option<unit => unit>) => unit}

@module("@sentry/react")
external reactRouterV6BrowserTracingIntegration: reactRouterV6BrowserTracingIntegrationArg => integration =
  "reactRouterV6BrowserTracingIntegration"

@module("@sentry/react")
external newSentryReplay: unit => integration = "replayIntegration"


@module("@sentry/react")
external capture: Exn.t => unit = "captureException"

module ErrorBoundary = {
  type fallbackArg = {
    error: Exn.t,
    componentStack: array<string>,
    resetError: unit => unit,
  }

  @module("@sentry/react") @react.component
  external make: (
    ~fallback: fallbackArg => React.element,
    ~children: React.element,
  ) => React.element = "ErrorBoundary"
}

let initiateSentry = (~dsn) => {
  try {
    initSentry({
      dsn,
      integrations: [
        newBrowserTracing(),
        reactRouterV6BrowserTracingIntegration({useEffect: React.useEffect0}),
        newSentryReplay(),
      ],
      tracesSampleRate: 0.1,
      tracePropagationTargets: [
        "localhost",
        "https://dev.hyperswitch.io",
        "https://beta.hyperswitch.io",
        "https://checkout.hyperswitch.io",
      ],
      replaysSessionSampleRate: 0.1,
      replaysOnErrorSampleRate: 1.0,
    })
  } catch {
  | err => Console.error(err)
  }
}

let initiateSentryJs = (~dsn) => {
  try {
    initSentry({
      dsn,
      integrations: [newBrowserTracing(), newSentryReplay()],
      tracesSampleRate: 1.0,
      tracePropagationTargets: ["localhost"],
      replaysSessionSampleRate: 0.1,
      replaysOnErrorSampleRate: 1.0,
    })
  } catch {
  | err => Console.error(err)
  }
}

let captureException = (err: exn) => {
  let error = err->exnToJsExn
  switch error {
  | Some(e) =>
    let z = e->toJson
    z.tag = "HyperTag"
    capture(toExn(z))
  | None => ()
  }
}

let sentryLogger = callback => {
  try {
    callback()
  } catch {
  | err => captureException(err)
  }
}
