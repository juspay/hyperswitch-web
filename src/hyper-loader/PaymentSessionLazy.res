/*
 Synchronous facade over PaymentSession.

 `hyper.initPaymentSession(...)` is synchronous on the public API, but every field of the record
 it returns already hands back a promise, so each method chains onto the chunk download - no
 call queue is needed.

 Every ref forwarded here is created once in Hyper.make and shared with Elements, so passing
 them across the async boundary preserves identity.

 On chunk failure `getCustomerSavedPaymentMethods` / `updateIntent` resolve with
 `Types.defaultInitPaymentSession`'s values rather than rejecting: merchant code on that path
 is `const r = await session.updateIntent(cb); if (!r) {...}`, and a rejection would throw.
 */
let chunk = LazyChunk.make(~label="PaymentSession")

let make = (
  options,
  ~publishableKey,
  ~sdkSessionId,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~redirectionFlags: JotaiAtomTypes.redirectionFlags,
  ~iframeRef: ref<array<Nullable.t<Dom.element>>>,
  ~isTestMode=false,
  ~isUpdateIntentInProgress: ref<bool>,
  ~clientSecretRef: ref<string>,
  ~sdkAuthorizationRef: ref<string>,
  ~sessionTokensDataPromise: ref<promise<JSON.t>>,
  ~sdkConfigsDataPromise: ref<promise<JSON.t>>,
  ~clientListDataPromise: ref<promise<JSON.t>>,
): Types.initPaymentSession => {
  let noteFailure = value =>
    try logger->Option.forEach(logger => logger.setLogError(~value, ~eventName=SDK_CRASH)) catch {
    | _ => ()
    }

  let reportFailure = err =>
    try {
      Console.error2("[PaymentSession] session unavailable", err)
      Sentry.captureException(err)
      noteFailure("PaymentSession construction failed")
    } catch {
    | _ => ()
    }

  let cached: ref<option<promise<option<Types.initPaymentSession>>>> = ref(None)

  let load = () =>
    switch cached.contents {
    | Some(sessionPromise) => sessionPromise
    | None =>
      let sessionPromise =
        chunk
        ->LazyChunk.load(() => import(PaymentSession.make))
        ->Promise.thenResolve(maybeMake =>
          switch maybeMake {
          | None =>
            /* Do not cache: the next call goes back through LazyChunk so the object the
               merchant is already holding can recover, not just a freshly created one */
            cached := None
            noteFailure("PaymentSession chunk unavailable - calls took their fallback")
            None
          | Some(make) =>
            try Some(
              make(
                options,
                ~publishableKey,
                ~sdkSessionId,
                ~logger,
                ~redirectionFlags,
                ~iframeRef,
                ~isTestMode,
                ~isUpdateIntentInProgress,
                ~clientSecretRef,
                ~sdkAuthorizationRef,
                ~sessionTokensDataPromise,
                ~sdkConfigsDataPromise,
                ~clientListDataPromise,
              ),
            ) catch {
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
    getCustomerSavedPaymentMethods: savedMethodsOptions =>
      load()->Promise.then(session =>
        switch session {
        | Some(session) => session.getCustomerSavedPaymentMethods(savedMethodsOptions)
        | None =>
          Types.defaultInitPaymentSession.getCustomerSavedPaymentMethods(savedMethodsOptions)
        }
      ),
    updateIntent: callback =>
      load()->Promise.then(session =>
        switch session {
        | Some(session) => session.updateIntent(callback)
        | None => Types.defaultInitPaymentSession.updateIntent(callback)
        }
      ),
  }
}
