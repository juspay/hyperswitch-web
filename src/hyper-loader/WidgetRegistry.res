// Handles are opaque identities. DOM selectors and caller-supplied IDs are never
// used to establish ownership of a confirmation target.
type frameState = {
  componentType: string,
  handle: Types.paymentElement,
  ready: promise<float>,
  markReady: unit => unit,
  onClose: ref<unit => unit>,
  close: unit => unit,
  getClientSecret: unit => string,
  mutable confirming: bool,
  mutable closed: bool,
  mutable messageListeners: array<string>,
}

let handles: WeakMap.t<JSON.t, unit => array<Dom.element>> = WeakMap.make()
let frames: WeakMap.t<Dom.element, frameState> = WeakMap.make()
let overlayOwners: WeakMap.t<Dom.element, Dom.element> = WeakMap.make()
let overlaySources: WeakMap.t<Dom.element, Dom.element> = WeakMap.make()
let walletRoutes: WeakMap.t<Dom.element, string> = WeakMap.make()

let registerHandle = (handle, getFrames) => {
  let json = Identity.anyTypeToJson(handle)
  handles->WeakMap.set(json, getFrames)->ignore
  // React context copies the collection while retaining its bound create function.
  json
  ->Utils.getDictFromJson
  ->Dict.get("create")
  ->Option.forEach(create => {
    if create->typeof === #function {
      handles->WeakMap.set(create, getFrames)->ignore
    }
  })
}

let getFrames = handle => {
  let getFrames = switch handles->WeakMap.get(handle) {
  | Some(getFrames) => Some(getFrames)
  | None =>
    handle
    ->Utils.getDictFromJson
    ->Dict.get("create")
    ->Option.flatMap(create => handles->WeakMap.get(create))
  }
  getFrames->Option.map(getFrames => getFrames()->Array.filter(Window.Element.isConnected))
}

// Lookup must prefer a live owner over an unmounted handle created by a render.
let getMountedElement = (iframeRefs, componentType) =>
  iframeRefs->Array.reduce(None, (previous, iframe) =>
    iframe
    ->Nullable.toOption
    ->Option.flatMap(frame => {
      if frame->Window.Element.isConnected {
        frames->WeakMap.get(frame)->Option.flatMap(state =>
          state.componentType === componentType && !state.closed ? Some(state.handle) : None
        )
      } else {
        None
      }
    })
    ->Option.orElse(previous)
  )

let registerFrame = (frame, componentType, getClientSecret, handle) => {
  let resolveReady = ref((_timestamp: float) => ())
  let ready = Promise.make((resolve, _) => resolveReady := resolve)
  let onClose = ref(() => ())
  frames
  ->WeakMap.set(
    frame,
    {
      componentType,
      handle,
      ready,
      markReady: () => resolveReady.contents(Date.now()),
      onClose,
      close: () => {
        resolveReady.contents(Date.now())
        onClose.contents()
      },
      getClientSecret,
      confirming: false,
      closed: false,
      messageListeners: [],
    },
  )
  ->ignore
}

let markReady = frame => frames->WeakMap.get(frame)->Option.forEach(state => state.markReady())

let registerOverlay = (overlay, owner) => {
  overlayOwners->WeakMap.set(overlay, owner)->ignore
  overlaySources->WeakMap.set(overlay->Window.contentWindow, owner)->ignore
}
let ownsOverlaySource = (source, frame) =>
  overlaySources
  ->WeakMap.get(source)
  ->Option.mapOr(false, owner => owner->Window.Element.isConnected && Some(owner) === frame->Nullable.toOption)

let ownsOverlay = (overlay, targets) =>
  overlayOwners->WeakMap.get(overlay)->Option.mapOr(false, owner => targets->Array.includes(owner))

let addMessageListener = (frame, handler, activity) =>
  frames->WeakMap.get(frame)->Option.forEach(state => {
    // Async prefetch/SDK callbacks can finish after unmount. They must not
    // reinstall listeners owned by a closed frame.
    if !state.closed && frame->Window.Element.isConnected {
      if !(state.messageListeners->Array.includes(activity)) {
        state.messageListeners->Array.push(activity)->ignore
      }
      EventListenerManager.addSmartEventListener("message", handler, activity)
    }
  })

let close = frame => frames->WeakMap.get(frame)->Option.forEach(state => {
  if !state.closed {
    state.closed = true
    state.messageListeners->Array.forEach(activity =>
      EventListenerManager.removeSmartEventListener("message", activity)
    )
    state.messageListeners = []
    state.close()
  }
})
