type integration
type scope
type instrumentation
type transport
type stackParser
type client

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

@module("@sentry/react")
external capture: Exn.t => unit = "captureException"

@module("@sentry/browser")
external makeFetchTransport: transport = "makeFetchTransport"

@module("@sentry/browser")
external defaultStackParser: stackParser = "defaultStackParser"

@module("@sentry/browser")
external getCurrentScope: unit => scope = "getCurrentScope"

type browserClientArg = {
  dsn: string,
  environment: string,
  transport: transport,
  stackParser: stackParser,
  integrations: array<integration>,
  tracesSampleRate: float,
  tracePropagationTargets: array<string>,
  replaysSessionSampleRate: float,
  replaysOnErrorSampleRate: float,
}

// External for BrowserClient class
@module("@sentry/browser") @new
external createBrowserClient: browserClientArg => client = "BrowserClient"

@send external init: (client, unit) => unit = "init"
@send external setClient: (scope, client) => unit = "setClient"

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
    let browserClient = createBrowserClient({
      dsn,
      environment: GlobalVars.isProd ? "production" : "development",
      transport: makeFetchTransport,
      stackParser: defaultStackParser,
      integrations: [newBrowserTracing()],
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
    getCurrentScope()->setClient(browserClient)
    browserClient->init()
    /* Session Replay is deliberately absent: SentryReplayLoader adds it after first paint, so
       rrweb never competes with the bytes the payment form needs to render */
    Some(browserClient)
  } catch {
  | err =>
    Console.error(err)
    None
  }
}

let initiateSentryJs = (~dsn) => {
  try {
    let browserClient = createBrowserClient({
      dsn,
      environment: GlobalVars.isProd ? "production" : "development",
      transport: makeFetchTransport,
      stackParser: defaultStackParser,
      /* Error capture only: this client runs on the *merchant's* page - its Replay recorded a
         third party's DOM, and its tracing produced pageload spans about a third party's site
         at 100% sampling, propagating to nobody. The sample rates below are inert with no
         tracing or replay integration registered. */
      integrations: [],
      tracesSampleRate: 1.0,
      tracePropagationTargets: ["localhost"],
      replaysSessionSampleRate: 0.1,
      replaysOnErrorSampleRate: 1.0,
    })
    getCurrentScope()->setClient(browserClient)
    browserClient->init()
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
