/*
 Synchronous facade over AuthenticationSession.

 `hyper.initAuthenticationSession(...)` is synchronous on the public API but both record fields
 already return promises, so no call queue is needed - each method chains onto the chunk
 download. On chunk failure both members resolve with
 `Types.defaultInitAuthenticationSession`'s values rather than rejecting, so nothing leaks an
 unhandled rejection into the merchant's page.
 */
let sessionChunk = LazyChunk.make(~label="AuthenticationSession")
let methodsChunk = LazyChunk.make(~label="ClickToPayAuthenticationSession")

/*
 `window.ClickToPayAuthenticationSession` was set the moment HyperLoader.js finished executing
 (module-level side effect of AuthenticationSessionMethods). Deferring that module narrowed the
 guarantee: the global would only appear after initAuthenticationSession() plus chunk resolve.
 This forwarder restores the old timing - a real function during initial script evaluation
 (this module is in HyperLoader's eager graph via Hyper.res) that pulls the chunk in on first
 call. The standalone ClickToPayAuthenticationSession.js entry still assigns the real one.
 Because the forwarder can itself fail at load time, it resolves the
 `Types.defaultInitAuthenticationSession.initClickToPaySession` value rather than rejecting.
 */
let initClickToPaySession = (
  ~clientSecret,
  ~publishableKey,
  ~logger: HyperLoggerTypes.loggerMake,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
  ~initClickToPaySessionInput: Types.initClickToPaySessionInput,
  ~shouldLoadScripts=true,
) =>
  methodsChunk
  ->LazyChunk.load(() => import(AuthenticationSessionMethods.initClickToPaySession))
  ->Promise.then(maybeInitClickToPaySession =>
    switch maybeInitClickToPaySession {
    | Some(initClickToPaySession) =>
      initClickToPaySession(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~profileId,
        ~authenticationId,
        ~merchantId,
        ~initClickToPaySessionInput,
        ~shouldLoadScripts,
      )
    | None =>
      try logger.setLogError(
        ~value="ClickToPay authentication session chunk unavailable",
        ~eventName=SDK_CRASH,
      ) catch {
      | _ => ()
      }
      Types.defaultInitAuthenticationSession.initClickToPaySession(initClickToPaySessionInput)
    }
  )

Types.window["ClickToPayAuthenticationSession"] = initClickToPaySession

let make = (
  options,
  ~clientSecret,
  ~publishableKey,
  ~logger: option<HyperLoggerTypes.loggerMake>,
): Types.initAuthenticationSession => {
  let noteFailure = value =>
    try logger->Option.forEach(logger => logger.setLogError(~value, ~eventName=SDK_CRASH)) catch {
    | _ => ()
    }

  let reportFailure = err =>
    try {
      Console.error2("[AuthenticationSession] session unavailable", err)
      Sentry.captureException(err)
      noteFailure("AuthenticationSession construction failed")
    } catch {
    | _ => ()
    }

  let cached: ref<option<promise<option<Types.initAuthenticationSession>>>> = ref(None)

  let load = () =>
    switch cached.contents {
    | Some(sessionPromise) => sessionPromise
    | None =>
      let sessionPromise =
        sessionChunk
        ->LazyChunk.load(() => import(AuthenticationSession.make))
        ->Promise.thenResolve(maybeMake =>
          switch maybeMake {
          | None =>
            /* Do not cache: the next call goes back through LazyChunk so the held object can
               recover, not just a freshly created one */
            cached := None
            noteFailure("AuthenticationSession chunk unavailable - calls took their fallback")
            None
          | Some(make) =>
            try Some(make(options, ~clientSecret, ~publishableKey, ~logger)) catch {
            | err =>
              cached := None
              reportFailure(err)
              None
            }
          }
        )
      cached := Some(sessionPromise)
      sessionPromise
    }

  {
    initClickToPaySession: initClickToPaySessionInput =>
      load()->Promise.then(session =>
        switch session {
        | Some(session) => session.initClickToPaySession(initClickToPaySessionInput)
        | None =>
          Types.defaultInitAuthenticationSession.initClickToPaySession(initClickToPaySessionInput)
        }
      ),
    getActiveClickToPaySession: () =>
      load()->Promise.then(session =>
        switch session {
        | Some(session) => session.getActiveClickToPaySession()
        | None => Types.defaultInitAuthenticationSession.getActiveClickToPaySession()
        }
      ),
  }
}
