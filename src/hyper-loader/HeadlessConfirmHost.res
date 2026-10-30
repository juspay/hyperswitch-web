open Promise
open Utils
open HeadlessConfirmTypes

@val @scope(("navigator", "clipboard"))
external writeText: string => promise<'a> = "writeText"

@get external parentWindow: Dom.element => Dom.element = "parent"
@get external contentWindowOf: Dom.element => Dom.element = "contentWindow"
@val external ownWindow: Dom.element = "window"

type context = {
  publishableKey: string,
  clientSecret: string,
  sdkAuthorization: option<string>,
  customPodUri: string,
  logger: HyperLoggerTypes.loggerMake,
  redirectionFlags: JotaiAtomTypes.redirectionFlags,
}

type t = {
  prepare: unit => unit,
  confirm: (~request: request, ~ctx: context) => promise<JSON.t>,
}

let isFromWindow = (~source: Dom.element, ~target: Dom.element) => {
  let rec climb = (current: Dom.element, depth) =>
    if current === target {
      true
    } else if depth === 0 {
      false
    } else {
      let parent = current->parentWindow
      parent !== current && climb(parent, depth - 1)
    }
  try {
    climb(source, 4)
  } catch {
  | _ => false
  }
}

let serverError = message => handleFailureResponse(~message, ~errorType="server_error")

let frameReadyTimeoutMs = 15000

let getRedirectUrl = (~ctx, ~returnUrl, ~status) => {
  let url = URLModule.makeUrl(returnUrl)
  if ctx.sdkAuthorization->Option.isNone {
    url.searchParams.set("payment_intent_client_secret", ctx.clientSecret)
  }
  url.searchParams.set(
    "payment_id",
    getPaymentIdOrExtractFromSdkAuth(
      ~clientSecret=ctx.clientSecret,
      ~sdkAuthorization=ctx.sdkAuthorization,
    ),
  )
  url.searchParams.set("status", status)
  url.href
}

let finishWithIntent = (intent, ~ctx, ~request) =>
  switch intent->JSON.Decode.object {
  | Some(dict) if dict->Dict.get("error")->Option.isSome => intent
  | Some(dict) =>
    if request.redirect === "always" {
      replaceRootHref(
        getRedirectUrl(~ctx, ~returnUrl=request.returnUrl, ~status=dict->getString("status", "")),
        ctx.redirectionFlags,
      )
    }
    intent
  | None => serverError("Failed to retrieve the payment status.")
  }

let retrieveForceSync = ctx =>
  PaymentHelpers.retrievePaymentIntent(
    ctx.clientSecret,
    ~publishableKey=ctx.publishableKey,
    ~logger=ctx.logger,
    ~customPodUri=ctx.customPodUri,
    ~isForceSync=true,
    ~sdkAuthorization=ctx.sdkAuthorization,
  )

let pollThenRetrieve = (pollStatus, ~ctx) => {
  let dict = pollStatus->getDictFromJson
  PaymentHelpers.pollStatus(
    ~publishableKey=ctx.publishableKey,
    ~customPodUri=ctx.customPodUri,
    ~pollId=dict->getString("poll_id", ""),
    ~interval=dict->getString("delay_in_secs", "")->Int.fromString->Option.getOr(1) * 1000,
    ~count=dict->getString("frequency", "")->Int.fromString->Option.getOr(5),
    ~returnUrl=dict->getString("return_url_with_query_params", ""),
    ~logger=ctx.logger,
    ~sdkAuthorization=ctx.sdkAuthorization,
  )->then(_ => retrieveForceSync(ctx))
}

let make = (~id) => {
  let containerRef: ref<option<Dom.element>> = ref(None)
  let frameRef: ref<option<Dom.element>> = ref(None)
  let fullscreenSlotRef: ref<option<Dom.element>> = ref(None)
  let fullscreenMetadataRef = ref(JSON.Encode.null)
  let readyRef: ref<option<promise<result<unit, string>>>> = ref(None)
  let pendingRef: ref<option<JSON.t => unit>> = ref(None)
  let ctxRef: ref<option<(context, request)>> = ref(None)
  let isPollingRef = ref(false)
  let fullscreenWindowsRef: ref<array<Dom.element>> = ref([])
  let listenerKey = `onHeadlessConfirmHost-${id}`
  let readyListenerKey = `${listenerKey}-ready`
  let readyTimerRef = ref(None)
  let cancelReadyRef: ref<option<unit => unit>> = ref(None)
  let generationRef = ref(0)

  let clearReadyTimer = () => {
    readyTimerRef.contents->Option.forEach(clearTimeout)
    readyTimerRef := None
  }

  let resetHost = () => {
    generationRef := generationRef.contents + 1
    clearReadyTimer()
    EventListenerManager.removeSmartEventListener("message", readyListenerKey)
    EventListenerManager.removeSmartEventListener("message", listenerKey)
    frameRef.contents->Option.forEach(frame => frame->Window.elementOnerror(_ => ()))
    containerRef.contents->Option.forEach(Window.remove)
    containerRef := None
    frameRef := None
    fullscreenSlotRef := None
    fullscreenMetadataRef := JSON.Encode.null
    fullscreenWindowsRef := []
    readyRef := None
    isPollingRef := false
  }

  let getFullscreenFrame = () =>
    fullscreenSlotRef.contents->Option.flatMap(slot =>
      slot->Window.Element.firstElementChild->Nullable.toOption
    )

  let isFrom = (source, frame) =>
    switch frame {
    | Some(frame) => isFromWindow(~source, ~target=frame->contentWindowOf)
    | None => false
    }

  let postToFrame = (frame, message) =>
    frame->Option.forEach(frame =>
      frame
      ->contentWindowOf
      ->Window.postMessage(
        message->JSON.stringify,
        URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin,
      )
    )

  let clearFullscreen = () =>
    fullscreenSlotRef.contents->Option.forEach(slot => slot->Window.innerHTML(""))

  let showFullscreen = (~param, ~metadata) =>
    fullscreenSlotRef.contents->Option.forEach(slot => {
      fullscreenMetadataRef := metadata
      slot->Window.innerHTML("")
      let src = `${ApiEndpoint.sdkDomainUrl}/fullscreenIndex.html?fullscreenType=${param === ""
          ? "fullscreen"
          : param}`
      slot->makeIframe(src, ~colorScheme="light")->ignore
      getFullscreenFrame()->Option.forEach(frame =>
        fullscreenWindowsRef :=
          fullscreenWindowsRef.contents->Array.concat([frame->contentWindowOf])
      )
    })

  let settle = result =>
    switch pendingRef.contents {
    | Some(resolve) =>
      pendingRef := None
      ctxRef := None
      // A fresh browsing context isolates all legacy (untagged) messages on retry.
      resetHost()
      resolve(result)
    | None => ()
    }

  let settleWith = (promise, ~ctx, ~request) => {
    let generation = generationRef.contents
    promise
    ->then(result => {
      if generation === generationRef.contents {
        settle(result->finishWithIntent(~ctx, ~request))
      }
      Promise.resolve()
    })
    ->catch(err => {
      if generation === generationRef.contents {
        settle(serverError(err->formatException->JSON.stringify))
      }
      Promise.resolve()
    })
    ->ignore
  }

  let showLoader = () => showFullscreen(~param="paymentloader", ~metadata=JSON.Encode.null)

  let handleOutcome = dict =>
    switch ctxRef.contents {
    | None => ()
    | Some((ctx, request)) =>
      switch (
        dict->Dict.get("poll_status"),
        dict->Dict.get("openurl_if_required"),
        dict->Dict.get("submitSuccessful"),
        dict->Dict.get("openurl"),
      ) {
      | (Some(pollStatus), _, _, _) =>
        if !isPollingRef.contents {
          showLoader()
          isPollingRef := true
          pollThenRetrieve(pollStatus, ~ctx)->settleWith(~ctx, ~request)
        }
      | (_, Some(_), _, _) =>
        if !isPollingRef.contents {
          showLoader()
          isPollingRef := true
          retrieveForceSync(ctx)->settleWith(~ctx, ~request)
        }
      | (_, _, Some(submitSuccessful), _) =>
        if submitSuccessful->JSON.Decode.bool->Option.getOr(false) {
          dict
          ->Dict.get("data")
          ->Option.getOr(JSON.Encode.null)
          ->finishWithIntent(~ctx, ~request)
          ->settle
        } else {
          [("error", dict->Dict.get("error")->Option.getOr(JSON.Encode.null))]
          ->getJsonFromArrayOfJson
          ->settle
        }
      | (_, _, _, Some(url)) =>
        replaceRootHref(url->JSON.Decode.string->Option.getOr(""), ctx.redirectionFlags)
      | _ => ()
      }
    }

  let handleMessage = (ev: Types.event) => {
    let ownWindowOpenUrl = if isPollingRef.contents && ev.source === ownWindow {
      ev.data->Identity.anyTypeToJson->getDictFromJson->Dict.get("openurl")
    } else {
      None
    }
    ownWindowOpenUrl->Option.forEach(url =>
      ctxRef.contents->Option.forEach(((ctx, _)) =>
        replaceRootHref(url->JSON.Decode.string->Option.getOr(""), ctx.redirectionFlags)
      )
    )
    let fromConfirmFrame = ev.source->isFrom(frameRef.contents)
    let fromFullscreen =
      fullscreenWindowsRef.contents->Array.some(target => isFromWindow(~source=ev.source, ~target))
    if fromConfirmFrame || fromFullscreen {
      let dict = ev.data->Identity.anyTypeToJson->getDictFromJson
      let fullscreen = dict->Dict.get("fullscreen")->Option.flatMap(JSON.Decode.bool)
      if dict->Dict.get("iframeMountedCallback")->Option.isSome {
        getFullscreenFrame()->postToFrame(
          [
            ("fullScreenIframeMounted", true->JSON.Encode.bool),
            ("metadata", fullscreenMetadataRef.contents),
            ("options", Dict.make()->JSON.Encode.object),
            ("appearance", Dict.make()->JSON.Encode.object),
          ]->getJsonFromArrayOfJson,
        )
      } else if fullscreen === Some(true) && dict->getString("iframeId", "") === id {
        showFullscreen(
          ~param=dict->getString("param", ""),
          ~metadata=dict->Dict.get("metadata")->Option.getOr(JSON.Encode.null),
        )
      } else if fullscreen === Some(false) && dict->Dict.get("param")->Option.isNone {
        clearFullscreen()
      } else if dict->getBool("copy", false) {
        writeText(dict->getString("copyDetails", ""))->catch(_ => Promise.resolve())->ignore
      } else if fromConfirmFrame && dict->Dict.get(resultKey)->Option.isSome {
        let result = dict->Dict.get(resultKey)->Option.getOr(JSON.Encode.null)
        let isFallback = dict->getBool("fallback", false)
        let hasNoNextStep =
          fullscreenSlotRef.contents->Option.mapOr(true, slot =>
            slot->Window.Element.firstElementChild->Nullable.toOption->Option.isNone
          )
        if !isFallback || hasNoNextStep {
          switch ctxRef.contents {
          | Some((ctx, request)) => settle(result->finishWithIntent(~ctx, ~request))
          | None => ()
          }
        }
      } else {
        handleOutcome(dict)
      }
    }
  }

  let mount = () => {
    let container = Window.createElement("div")
    container->Window.setAttribute("id", `orca-headless-confirm-${id}`)
    let frame = Window.createElement("iframe")
    frame->Window.setAttribute("name", `orca-headless-confirm-frame-${id}`)
    frame->Window.setAttribute("title", "Hyperswitch headless confirm")
    frame->Window.setAttribute("aria-hidden", "true")
    frame->Window.setAttribute(
      "src",
      `${ApiEndpoint.sdkDomainUrl}/fullscreenIndex.html?fullscreenType=${fullscreenType}`,
    )
    frame->Window.setAttribute(
      "sandbox",
      "allow-scripts allow-popups allow-same-origin allow-forms",
    )
    frame->Window.setAttribute(
      "style",
      "position: absolute; width: 0; height: 0; border: none; overflow: hidden; left: -9999px; top: -9999px;",
    )
    let slot = Window.createElement("div")
    slot->Window.setAttribute("id", `orca-fullscreen-iframeRef-${id}`)
    container->Window.appendChildElement(frame)
    container->Window.appendChildElement(slot)
    containerRef := Some(container)
    frameRef := Some(frame)
    fullscreenSlotRef := Some(slot)

    let ready = Promise.make((resolve, _) => {
      let completed = ref(false)
      let finishReady = result => {
        if !completed.contents {
          completed := true
          cancelReadyRef := None
          clearReadyTimer()
          EventListenerManager.removeSmartEventListener("message", readyListenerKey)
          frame->Window.elementOnerror(_ => ())
          switch result {
          | Error(_) => resetHost()
          | Ok() => ()
          }
          resolve(result)
        }
      }
      cancelReadyRef :=
        Some(
          () => {
            finishReady(Error("The payment confirmation frame was removed. Please retry."))
          },
        )
      readyTimerRef := Some(setTimeout(() => {
            finishReady(Error("Timed out loading the payment confirmation frame. Please retry."))
          }, frameReadyTimeoutMs))
      frame->Window.elementOnerror(_ => {
        finishReady(Error("Failed to load the payment confirmation frame. Please retry."))
      })
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) =>
          if (
            ev.source->isFrom(Some(frame)) &&
              ev.data->Identity.anyTypeToJson->getDictFromJson->Dict.get(readyKey)->Option.isSome
          ) {
            finishReady(Ok())
          },
        readyListenerKey,
      )
    })
    EventListenerManager.addSmartEventListener("message", handleMessage, listenerKey)
    Window.body->Window.appendChild(container)
    ready
  }

  let getReady = () =>
    switch readyRef.contents {
    | Some(ready) if containerRef.contents->Option.mapOr(false, Window.Element.isConnected) => ready
    | _ =>
      cancelReadyRef.contents->Option.forEach(cancel => cancel())
      resetHost()
      let ready = mount()
      readyRef := Some(ready)
      ready
    }

  let confirm = (~request, ~ctx) =>
    getReady()->then(ready =>
      switch ready {
      | Error(message) => serverError(message)->Promise.resolve
      | Ok() =>
        Promise.make((resolve, _) => {
          pendingRef := Some(resolve)
          ctxRef := Some((ctx, request))
          frameRef.contents->postToFrame(
            [
              (requestKey, request->requestToJson),
              ("hostId", id->JSON.Encode.string),
            ]->getJsonFromArrayOfJson,
          )
        })
      }
    )

  let prepare = () => getReady()->ignore

  {prepare, confirm}
}
