/*
 Synchronous facade over Elements - the loader's largest API surface.

 `window.Hyper(pk)` -> `.elements({...})` -> `elements.create("card", {})` -> `card.mount(...)`
 all stay synchronous: `make` returns a real `Types.element` immediately and records the calls
 made before the chunk lands.

 One `LazyCallQueue` per `elements()` carries every deferred call made in the tree it roots, so
 replay follows merchant call order - see LazyCallQueue.res for why a derived-promise chain
 cannot. The chunk download starts when `elements()` is called.

 `getElement` cannot wait, so the facade keys the handles it hands out by component type,
 mirroring Elements.res `savedPaymentElement`, and answers from that map - on the failure path
 too. That is a deliberate divergence from `Types.defaultElement.getElement` (which answers
 `None`): `elements.getElement("card").mount(...)` would throw on `None`, while the inert
 handle returned here keeps a chunk failure silent instead of a TypeError in the merchant's
 frame. The cost: `if (elements.getElement("card"))` takes the truthy branch after a failed
 chunk.

 When the chunk never arrives, promise-returning members resolve with their `Types.default*`
 value rather than rejecting - merchant code is written as
 `const r = await form.confirmPayment(); if (r.error) {...}`, and a rejection would throw
 instead of taking the error branch. These are the values Elements.res:1622-1623 already returns
 from its own catch.

 The import() lives here rather than in Hyper.res because a dynamic import taxes every entry
 whose graph contains the module holding it; only HyperLoader reaches this file.
 */
module Q = LazyCallQueue

/* Reporting a replay failure must not itself throw - it runs inside promise handlers that
   would otherwise turn one failure into an unhandled rejection on the merchant's page */
let report = (message, err) =>
  try {
    Console.error2(message, err)
    Sentry.captureException(err)
  } catch {
  | _ => ()
  }

/* Module-level: one download shared by every elements() call on the page; resolves `None` when
   the chunk is not available */
let chunk = LazyChunk.make(~label="Elements")

let load = () => chunk->LazyChunk.load(() => import(Elements.make))

let make = (
  options,
  setIframeRef,
  ~sdkSessionId,
  ~publishableKey,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~analyticsMetadata,
  ~customBackendUrl,
  ~redirectionFlags: JotaiAtomTypes.redirectionFlags,
  ~isTestMode=false,
  ~preloadSDKWithParams=Dict.make(),
  ~isUpdateIntentInProgress: ref<bool>,
  ~clientSecretRef: ref<string>,
  ~sdkAuthorizationRef: ref<string>,
  ~sessionTokensDataPromise: ref<promise<JSON.t>>,
  ~sdkConfigsDataPromise: ref<promise<JSON.t>>,
  ~clientListDataPromise: ref<promise<JSON.t>>,
  ~confirmPayment: JSON.t => promise<JSON.t>,
): Types.element => {
  let cardFormFields: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)

  let noteFailure = value =>
    try logger->Option.forEach(logger => logger.setLogError(~value, ~eventName=SDK_CRASH)) catch {
    | _ => ()
    }

  let reportFailure = err => {
    report("[Elements] deferred call failed", err)
    noteFailure("Elements deferred call failed")
  }

  let queue = Q.make(~onError=reportFailure)
  let enqueue = step => queue->Q.push(step)

  let elementsRef: ref<option<Types.element>> = ref(None)

  load()
  ->Promise.thenResolve(maybeMake =>
    switch maybeMake {
    | None => noteFailure("Elements chunk unavailable - deferred calls took their fallback")
    | Some(make) =>
      try elementsRef :=
        Some(
          make(
            options,
            setIframeRef,
            ~sdkSessionId,
            ~publishableKey,
            ~logger,
            ~analyticsMetadata,
            ~customBackendUrl,
            ~redirectionFlags,
            ~isTestMode,
            ~preloadSDKWithParams,
            ~isUpdateIntentInProgress,
            ~clientSecretRef,
            ~sdkAuthorizationRef,
            ~sessionTokensDataPromise,
            ~sdkConfigsDataPromise,
            ~clientListDataPromise,
            ~confirmPayment,
            ~cardFormFields,
          ),
        ) catch {
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

  /* Mirrors Elements.res `savedPaymentElement` so getElement can answer synchronously */
  let createdElements: Dict.t<Types.paymentElement> = Dict.make()

  let create = (
    componentTypeOrOptions: JSON.t,
    legacyOptions: Nullable.t<JSON.t>,
  ): Types.paymentElement => {
    let elementRef: ref<option<Types.paymentElement>> = ref(None)
    enqueue(() =>
      elementsRef.contents->Option.forEach(elements =>
        elementRef := Some(elements.create(componentTypeOrOptions, legacyOptions))
      )
    )

    let handle: Types.paymentElement = {
      on: (event, handler) =>
        queue->Q.pushCall(elementRef, element => element.on(event, handler)),
      collapse: () => queue->Q.pushCall(elementRef, element => element.collapse()),
      blur: () => queue->Q.pushCall(elementRef, element => element.blur()),
      update: newOptions =>
        queue->Q.pushCall(elementRef, element => element.update(newOptions)),
      destroy: () => queue->Q.pushCall(elementRef, element => element.destroy()),
      unmount: () => queue->Q.pushCall(elementRef, element => element.unmount()),
      mount: selector => queue->Q.pushCall(elementRef, element => element.mount(selector)),
      focus: () => queue->Q.pushCall(elementRef, element => element.focus()),
      clear: () => queue->Q.pushCall(elementRef, element => element.clear()),
      onSDKHandleClick: callback =>
        queue->Q.pushCall(elementRef, element => element.onSDKHandleClick(callback)),
      confirmPayment: payload =>
        queue->Q.pushPromiseCall(
          elementRef,
          element => element.confirmPayment(payload),
          ~orElse=() => Types.defaultPaymentElement.confirmPayment(payload),
        ),
    }

    let (componentType, _options) = Utils.parseComponentTypeAndOptions(
      ~componentTypeOrOptions,
      ~legacyOptions,
      ~defaultComponentType="payment",
    )
    createdElements->Dict.set(componentType, handle)
    handle
  }

  let getElement = componentName => createdElements->Dict.get(componentName)

  /* Elements.res memoises the card form, so the facade must too - merchants compare identity */
  let cardFormRef: ref<option<Types.cardForm>> = ref(None)

  let createCardForm = (): Types.cardForm =>
    switch cardFormRef.contents {
    | Some(cardForm) => cardForm
    | None =>
      let realFormRef: ref<option<Types.cardForm>> = ref(None)
      enqueue(() =>
        elementsRef.contents->Option.forEach(elements =>
          realFormRef := Some(elements.createCardForm())
        )
      )

      let createField = (fieldType: string, fieldOptions: JSON.t): Types.fieldHandle => {
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
          update: newOptions =>
            queue->Q.pushCall(fieldRef, handle => handle.update(newOptions)),
          focus: () => queue->Q.pushCall(fieldRef, handle => handle.focus()),
          blur: () => queue->Q.pushCall(fieldRef, handle => handle.blur()),
          clear: () => queue->Q.pushCall(fieldRef, handle => handle.clear()),
          on: (event, callback) =>
            queue->Q.pushCall(fieldRef, handle => handle.on(event, callback)),
        }
      }

      let cardForm: Types.cardForm = {
        create: createField,
        on: (event, callback) =>
          queue->Q.pushCall(realFormRef, form => form.on(event, callback)),
        confirmPayment: () =>
          queue->Q.pushPromiseCall(
            realFormRef,
            form => form.confirmPayment(),
            ~orElse=() => Types.defaultCardForm.confirmPayment(),
          ),
        deinit: () => queue->Q.pushCall(realFormRef, form => form.deinit()),
        update: newOptions =>
          queue->Q.pushCall(realFormRef, form => form.update(newOptions)),
        fields: cardFormFields,
      }
      cardFormRef := Some(cardForm)
      cardForm
    }

  {
    getElement,
    update: newOptions =>
      queue->Q.pushCall(elementsRef, elements => elements.update(newOptions)),
    fetchUpdates: () =>
      queue->Q.pushPromiseCall(
        elementsRef,
        elements => elements.fetchUpdates(),
        ~orElse=() => Types.defaultElement.fetchUpdates(),
      ),
    create,
    updateIntent: callback =>
      queue->Q.pushPromiseCall(
        elementsRef,
        elements => elements.updateIntent(callback),
        ~orElse=() => Types.defaultElement.updateIntent(callback),
      ),
    createCardForm,
  }
}
