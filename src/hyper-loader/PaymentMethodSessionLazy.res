/*
 Synchronous facade over PaymentMethodSession.

 `hyper.initPaymentMethodSession(...)`, `session.createCardForm()`, `form.create(...)` and every
 handle method on the result are synchronous on the public API, so this module returns real
 objects immediately and records the calls made before the chunk lands. One `LazyCallQueue` per
 session carries every deferred call in the tree it roots - see LazyCallQueue.res for why a
 derived-promise chain cannot preserve merchant order.

 `fields` is created here and threaded into PaymentMethodSession.make so the ref the merchant
 holds is the one the real session writes to.

 `tokenize` resolves with `Types.vaultSDKNotLoadedError` when the chunk never arrives rather
 than rejecting: merchant code is `const r = await form.tokenize(); if (r.error) {...}`, and a
 rejection would throw instead of taking the error branch.
 */
module Q = LazyCallQueue

let chunk = LazyChunk.make(~label="PaymentMethodSession")

let make = (
  options: JSON.t,
  ~logger: HyperLoggerTypes.loggerMake,
): Types.initPaymentMethodSession => {
  let fields: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)

  let noteFailure = value =>
    try logger.setLogError(~value, ~eventName=SDK_CRASH) catch {
    | _ => ()
    }

  let reportFailure = err =>
    try {
      Console.error2("[PaymentMethodSession] deferred call failed", err)
      Sentry.captureException(err)
      noteFailure("PaymentMethodSession deferred call failed")
    } catch {
    | _ => ()
    }

  let queue = Q.make(~onError=reportFailure)
  let enqueue = step => queue->Q.push(step)

  let sessionRef: ref<option<Types.initPaymentMethodSession>> = ref(None)

  /* Starting the download now rather than on the first method call - calling
     initPaymentMethodSession is itself the commitment to a vault session */
  chunk
  ->LazyChunk.load(() => import(PaymentMethodSession.make))
  ->Promise.thenResolve(maybeMake =>
    switch maybeMake {
    | None =>
      noteFailure("PaymentMethodSession chunk unavailable - deferred calls took their fallback")
    | Some(make) =>
      try sessionRef := Some(make(options, ~logger, ~fields)) catch {
      | err => reportFailure(err)
      }
    }
  )
  ->Promise.catch(err => {
    reportFailure(err)
    Promise.resolve()
  })
  /* Draining after the catch, not inside the success branch, is what lets every queued call
     take its fallback branch when the chunk never arrives instead of waiting forever */
  ->Promise.thenResolve(() => queue->Q.drain)
  ->Promise.catch(err => {
    reportFailure(err)
    Promise.resolve()
  })
  ->ignore

  let createCardForm = (): Types.vaultCardForm => {
    let realFormRef: ref<option<Types.vaultCardForm>> = ref(None)
    enqueue(() =>
      sessionRef.contents->Option.forEach(session => realFormRef := Some(session.createCardForm()))
    )

    let create = (fieldType: string, fieldOptions: JSON.t): Types.fieldHandle => {
      let fieldRef: ref<option<Types.fieldHandle>> = ref(None)
      enqueue(() =>
        realFormRef.contents->Option.forEach(form =>
          fieldRef := Some(form.create(fieldType, fieldOptions))
        )
      )
      {
        mount: selector => queue->Q.pushCall(fieldRef, handle => handle.mount(selector)),
        unmount: () => queue->Q.pushCall(fieldRef, handle => handle.unmount()),
        destroy: () => queue->Q.pushCall(fieldRef, handle => handle.destroy()),
        update: newOptions => queue->Q.pushCall(fieldRef, handle => handle.update(newOptions)),
        focus: () => queue->Q.pushCall(fieldRef, handle => handle.focus()),
        blur: () => queue->Q.pushCall(fieldRef, handle => handle.blur()),
        clear: () => queue->Q.pushCall(fieldRef, handle => handle.clear()),
        on: (event, callback) => queue->Q.pushCall(fieldRef, handle => handle.on(event, callback)),
      }
    }

    {
      create,
      on: (event, callback) => queue->Q.pushCall(realFormRef, form => form.on(event, callback)),
      tokenize: () =>
        queue->Q.pushPromiseCall(
          realFormRef,
          form => form.tokenize(),
          ~orElse=() => Types.defaultVaultCardForm.tokenize(),
        ),
      deinit: () => queue->Q.pushCall(realFormRef, form => form.deinit()),
      update: newOptions => queue->Q.pushCall(realFormRef, form => form.update(newOptions)),
      fields,
    }
  }

  {
    createCardForm,
    update: newOptions => queue->Q.pushCall(sessionRef, session => session.update(newOptions)),
    on: (event, callback) => queue->Q.pushCall(sessionRef, session => session.on(event, callback)),
    deinit: () => queue->Q.pushCall(sessionRef, session => session.deinit()),
    fields,
  }
}
