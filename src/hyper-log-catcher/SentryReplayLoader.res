external toReplayClient: Sentry.client => SentryReplay.client = "%identity"

@val @scope("document") external documentReadyState: string = "readyState"
@val @scope("window")
external addWindowEventListener: (string, unit => unit) => unit = "addEventListener"

let loadAfterPaint = (browserClient: Sentry.client) => {
  let hasLoaded = ref(false)
  let load = () =>
    if !hasLoaded.contents {
      hasLoaded := true
      import(SentryReplay.addTo)
      ->Promise.thenResolve(addTo => addTo(browserClient->toReplayClient))
      ->Promise.catch(err => {
        Console.error(err)
        Promise.resolve()
      })
      ->ignore
    }

  if documentReadyState === "complete" {
    load()
  } else {
    addWindowEventListener("load", load)
    setTimeout(load, 3000)->ignore
  }
}
