open Utils

type completion =
  | PollStatus(JSON.t)
  | OpenUrlIfRequired(string)
  | Submitted(JSON.t)
  | SubmitFailed(JSON.t)
  | OpenUrl(string)

type t = {
  present: (~param: string, ~metadata: JSON.t) => promise<completion>,
  showLoader: unit => unit,
  dispose: unit => unit,
}

@val @scope(("navigator", "clipboard"))
external writeText: string => promise<'a> = "writeText"

@get external parentWindow: Dom.element => Nullable.t<Dom.element> = "parent"

let fullscreenElementId = "orca-fullscreen"

let isFromFrame = (~source: Dom.element, ~frameWindow: Dom.element) => {
  let rec climb = (current: Dom.element, depth) =>
    if current === frameWindow {
      true
    } else if depth === 0 {
      false
    } else {
      switch current->parentWindow->Nullable.toOption {
      | Some(parent) if parent !== current => climb(parent, depth - 1)
      | _ => false
      }
    }
  try {
    climb(source, 5)
  } catch {
  | _ => false
  }
}

let toCompletion = dict =>
  switch (
    dict->Dict.get("poll_status"),
    dict->Dict.get("openurl_if_required"),
    dict->Dict.get("submitSuccessful"),
    dict->Dict.get("openurl"),
  ) {
  | (Some(pollStatus), _, _, _) => Some(PollStatus(pollStatus))
  | (_, Some(url), _, _) => Some(OpenUrlIfRequired(url->JSON.Decode.string->Option.getOr("")))
  | (_, _, Some(submitSuccessful), _) =>
    switch submitSuccessful->JSON.Decode.bool {
    | Some(true) => Some(Submitted(dict->Dict.get("data")->Option.getOr(JSON.Encode.null)))
    | _ =>
      Some(
        SubmitFailed(
          [
            ("error", dict->Dict.get("error")->Option.getOr(JSON.Encode.null)),
          ]->getJsonFromArrayOfJson,
        ),
      )
    }
  | (_, _, _, Some(url)) => Some(OpenUrl(url->JSON.Decode.string->Option.getOr("")))
  | _ => None
  }

let make = (~id: string) => {
  let listenerKey = `onHeadlessFullscreen-${id}`
  let slotRef: ref<option<Dom.element>> = ref(None)
  let frameRef: ref<option<Dom.element>> = ref(None)
  let knownWindowsRef: ref<array<Dom.element>> = ref([])
  let metadataRef = ref(JSON.Encode.null)
  let resolverRef: ref<option<completion => unit>> = ref(None)

  let getSlot = () =>
    switch slotRef.contents {
    | Some(slot) => slot
    | None =>
      let slot = Window.createElement("div")
      slot->Window.setAttribute("id", `orca-fullscreen-iframeRef-${id}`)
      Window.body->Window.appendChild(slot)
      slotRef := Some(slot)
      slot
    }

  let clearFrame = () => {
    slotRef.contents->Option.forEach(slot => slot->Window.innerHTML(""))
    frameRef := None
  }

  let mount = (~param, ~metadata) => {
    let metadataDict = metadata->getDictFromJson->Dict.copy
    if metadataDict->Dict.keysToArray->Array.length > 0 {
      metadataDict->Dict.set("iframeId", id->JSON.Encode.string)
    }
    metadataRef := metadataDict->JSON.Encode.object
    let slot = getSlot()
    slot->Window.innerHTML("")
    let src = `${ApiEndpoint.sdkDomainUrl}/fullscreenIndex.html?fullscreenType=${param}`
    slot->makeIframe(src)->ignore
    let frame = slot->Window.Element.firstElementChild->Nullable.toOption
    frameRef := frame
    frame
    ->Option.flatMap(frame => frame->Window.Element.nullableContentWindow->Nullable.toOption)
    ->Option.forEach(frameWindow =>
      knownWindowsRef := knownWindowsRef.contents->Array.concat([frameWindow])
    )
  }

  let handleMessage = (ev: Types.event) => {
    let isOurs =
      knownWindowsRef.contents->Array.some(frameWindow =>
        isFromFrame(~source=ev.source, ~frameWindow)
      )
    if isOurs {
      let dict = ev.data->Identity.anyTypeToJson->getDictFromJson
      let fullscreen = dict->Dict.get("fullscreen")->Option.flatMap(JSON.Decode.bool)
      let iframeId = dict->getString("iframeId", "")
      if dict->Dict.get("iframeMountedCallback")->Option.isSome {
        frameRef.contents
        ->Nullable.fromOption
        ->Window.iframePostMessage(
          [
            ("fullScreenIframeMounted", true->JSON.Encode.bool),
            ("metadata", metadataRef.contents),
            ("options", Dict.make()->JSON.Encode.object),
            ("appearance", Dict.make()->JSON.Encode.object),
          ]->Dict.fromArray,
        )
      } else if fullscreen === Some(true) && iframeId === id {
        mount(
          ~param=dict->getString("param", ""),
          ~metadata=dict->Dict.get("metadata")->Option.getOr(JSON.Encode.null),
        )
      } else if fullscreen === Some(false) && dict->Dict.get("param")->Option.isNone {
        clearFrame()
      } else if dict->getBool("copy", false) {
        writeText(dict->getString("copyDetails", ""))->Promise.catch(_ => Promise.resolve())->ignore
      } else {
        switch (dict->toCompletion, resolverRef.contents) {
        | (Some(completion), Some(resolver)) =>
          resolverRef := None
          EventListenerManager.removeSmartEventListener("message", listenerKey)
          resolver(completion)
        | _ => ()
        }
      }
    }
  }

  let present = (~param, ~metadata) =>
    Promise.make((resolve, _) => {
      resolverRef := Some(resolve)
      EventListenerManager.addSmartEventListener("message", handleMessage, listenerKey)
      mount(~param, ~metadata)
    })

  let showLoader = () => mount(~param="paymentloader", ~metadata=JSON.Encode.null)

  let dispose = () => {
    resolverRef := None
    EventListenerManager.removeSmartEventListener("message", listenerKey)
    slotRef.contents->Option.forEach(Window.remove)
    slotRef := None
    frameRef := None
    knownWindowsRef := []
  }

  {present, showLoader, dispose}
}
