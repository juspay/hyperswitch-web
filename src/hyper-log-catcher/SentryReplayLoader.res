/*
 Schedules Session Replay's download for after the iframe has painted. Deliberately not part of
 Sentry.res: HyperLoader.js has Sentry.res in its module graph, and an `import()` there would
 put an async-chunk request into the merchant-page bundle, which could not fetch one when
 `output.publicPath` was root-relative. Only Index.res, the iframe entry, imports this file.
 */
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
    /* `load` is the "after first paint" trigger; the timer is a second one, because a session
       that never loads Replay has no on-error buffer at all (replaysOnErrorSampleRate: 1.0) */
    addWindowEventListener("load", load)
    setTimeout(load, 3000)->ignore
  }
}
