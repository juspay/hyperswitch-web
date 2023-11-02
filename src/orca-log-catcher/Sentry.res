type integration
type scope
type instrumentation

type tag = {mutable tag: string}
type hint = {originalException: tag}
external toJson: Js.Exn.t => tag = "%identity"
external toExn: tag => Js.Exn.t = "%identity"
type event
type sentryInitArg = {
  dsn: string,
  integrations: array<integration>,
  tracesSampleRate: float,
  tracePropagationTargets: array<string>,
  replaysSessionSampleRate: float,
  replaysOnErrorSampleRate: float,
  beforeSend: (event, hint) => option<event>,
}

external exnToJsExn: exn => option<Js.Exn.t> = "%identity"

@module("react")
external useEffect: (. unit => option<unit => unit>) => unit = "useEffect"
type sentry
@val @scope("window")
external isSentryPresent: Js.Nullable.t<sentry> = "Sentry"

@module("@sentry/react")
external initSentry: sentryInitArg => unit = "init"

type newBrowserTracingArg = {routingInstrumentation: instrumentation}
@new @module("@sentry/react")
external newBrowserTracing: newBrowserTracingArg => integration = "BrowserTracing"

@module("@sentry/react")
external reactRouterV6Instrumentation: (
  (. unit => option<unit => unit>) => unit
) => instrumentation = "reactRouterV6Instrumentation"

@new @module("@sentry/react")
external newSentryReplay: unit => integration = "Replay"

@val @scope("Sentry")
external initSentryJs: sentryInitArg => unit = "init"

@val @scope("Sentry")
external capture: (. Js.Exn.t) => unit = "captureException"

@new
external newSentryReplayJs: unit => integration = "Sentry.Replay"

@new
external newBrowserTracingJs: unit => integration = "Sentry.BrowserTracing"

module ErrorBoundary = {
  type fallbackArg = {
    error: Js.Exn.t,
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
      dsn: dsn,
      integrations: [
        newBrowserTracing({
          routingInstrumentation: reactRouterV6Instrumentation(useEffect),
        }),
        newSentryReplay(),
      ],
      tracesSampleRate: 1.0,
      tracePropagationTargets: [
        "localhost",
        "https://dev.hyperswitch.io",
        "https://beta.hyperswitch.io",
        "https://checkout.hyperswitch.io",
      ],
      replaysSessionSampleRate: 0.1,
      replaysOnErrorSampleRate: 1.0,
      beforeSend: (event, hint) => {
        hint.originalException.tag == "HyperTag" ? Some(event) : None
      },
    })
  } catch {
  | err => Js.log(err)
  }
}

let initiateSentryJs = (~dsn) => {
  try {
    initSentryJs({
      dsn: dsn,
      integrations: [newBrowserTracingJs(), newSentryReplayJs()],
      tracesSampleRate: 1.0,
      tracePropagationTargets: ["localhost"],
      replaysSessionSampleRate: 0.1,
      replaysOnErrorSampleRate: 1.0,
      beforeSend: (event, hint) => {
        hint.originalException.tag == "HyperTag" ? Some(event) : None
      },
    })
  } catch {
  | err => Js.log(err)
  }
}

let captureException = (err: exn) => {
  switch isSentryPresent->Js.Nullable.toOption {
  | Some(_val) =>
    let error = err->exnToJsExn
    switch error {
    | Some(e) =>
      let z = e->toJson
      z.tag = "HyperTag"
      capture(. toExn(z))
    | None => ()
    }
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
