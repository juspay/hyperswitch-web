// CoordinatorMount — the merchant-DOM contract for ONE hidden
// `cardFormCoordinator` iframe per CardForm group (MessageChannel Card
// Relay; docs/messagechannel-architecture-pitch.md).
//
// DOM contract (locked):
//   1. The coordinator iframe lives inside an SDK-appended container div
//      (`#orca-<elementIframeId>-iframeRef-<localSelectorString>`), and is
//      GEOMETRICALLY hidden via `Utils.makeHiddenIframe`; the inner document
//      renders nothing (see CardFormCoordinator.res → `React.null`).
//   2. A per-group fullscreen slot
//      (`#orca-fullscreen-iframeRef-<localSelectorString>`) sits in the SAME
//      container — the coordinator's three_ds_invoke fullscreen plumbing
//      lands THERE instead of the legacy `#orca-fullscreen` singleton, so
//      MULTIPLE CardForm groups on one page cannot clobber each other's
//      overlay.
//   3. `localSelectorString` IS the coordinator's `iframeId`: it rides the
//      mount-config and echoes on every outbound message.
//   4. Posts carrying a MessageChannel port MUST use
//      `Utils.iframePostMessageWithTransfer` — the payload stays stringified
//      (receivers `safeParse` `ev.data`); the port rides the transfer list.
//      Window.iframePostMessage stays untouched.
//
open Utils

type coordinatorMount = {
  iframe: Dom.element,
  container: Dom.element,
  fullscreenSlot: Dom.element,
}

// Queued port1 channel awaiting its coordinator iframe-mounted flush. Hoisted
// here so BOTH CardForm groups share one pendingPort shape and `teardown`
// can close the un-transferred/residual ones directly.
type pendingPort = {
  fieldName: string,
  epoch: int,
  port: MessageChannelBinding.port,
}

// Build the DOM: hidden-coordinator container + iframe + fullscreen slot,
// appended under `parentContainer` (the group's own outer container div in
// the merchant DOM). Returns handles so the group can post/transfer into the
// coordinator and route overlay responses.
let create = (
  ~parentContainer: Window.body,
  ~localSelectorString: string,
  ~elementIframeId: string,
  ~surfaceFamily: string,
  ~groupId: string,
  ~sdkDomain: string,
): coordinatorMount => {
  // SDK-appended container div (locked contract #1).
  let container = Window.createElement("div")
  container->Window.setAttribute("id", `orca-${elementIframeId}-iframeRef-${localSelectorString}`)
  parentContainer->Window.appendChild(container)

  // The hidden coordinator iframe: URL carries BOTH routing params
  // (`componentName=cardFormCoordinator`, surfaceFamily for the
  // PaymentSurfaceFamily admission gate, groupId for port-key scoping).
  let src =
    `${sdkDomain}/index.html?componentName=cardFormCoordinator` ++
    `&surfaceFamily=${surfaceFamily}` ++
    `&groupId=${groupId}`
  let iframe = Window.createElement("iframe")
  iframe->Window.setAttribute("id", `orca-coordinator-${localSelectorString}`)
  iframe->Window.setAttribute("src", src)
  iframe->Window.setAttribute("allow", "payment *")
  iframe->Window.setAttribute(
    "sandbox",
    "allow-scripts allow-popups allow-same-origin allow-forms",
  )
  // Geometry per `Utils.makeHiddenIframe`'s offscreen vocabulary, but 0×0 —
  // this iframe never paints (inner document renders React.null).
  iframe->Window.setAttribute(
    "style",
    "position: absolute; width: 0; height: 0; border: none; overflow: hidden; left: -9999px; top: -9999px;",
  )
  container->Window.appendChildElement(iframe)

  // Per-group fullscreen slot (locked contract #2).
  let fullscreenSlot = Window.createElement("div")
  fullscreenSlot->Window.setAttribute("id", `orca-fullscreen-iframeRef-${localSelectorString}`)
  container->Window.appendChildElement(fullscreenSlot)

  {iframe, container, fullscreenSlot}
}

// Embed the relay coordination into a field's mount-config BEFORE posting:
// `portKey` + `portEpoch` tell the receiving document (the field's
// LoaderController, or the coordinator's) where to registry-absorb the port.
let withPortMeta = (~mountConfig: JSON.t, ~portKey: string, ~portEpoch: int): JSON.t => {
  let dict = mountConfig->getDictFromJson
  dict->Dict.set("portKey", portKey->JSON.Encode.string)
  dict->Dict.set("portEpoch", portEpoch->Int.toFloat->JSON.Encode.float)
  dict->JSON.Encode.object
}

// Post a field's mount-config WITH its port2 in the transfer list — the
// field-side hinge of the P0.3 choreography (called at the same sites today's
// groups call `Window.iframePostMessage(config)` for a fresh field mount
// config).
let postFieldMountConfigWithPort = (
  ~fieldIframe: Nullable.t<Dom.element>,
  ~mountConfig: JSON.t,
  ~portKey: string,
  ~portEpoch: int,
  ~port: MessageChannelBinding.port,
  ~targetOrigin: string=GlobalVars.targetOrigin,
): unit => {
  fieldIframe->iframePostMessageWithTransfer(
    withPortMeta(~mountConfig, ~portKey, ~portEpoch)->JSON.stringify,
    ~targetOrigin,
    ~transfer=[port],
  )
}

// Forward the retained port1 into the coordinator iframe after its
// `iframeMounted` broadcast (step 2 of the choreography): pack a minimal
// `cardFieldPort` framing dict and transfer the port — the coordinator-side
// LoaderController absorbs `ev.ports` under THIS `portKey`.
let forwardPortToCoordinator = (
  ~coordinatorIframe: Nullable.t<Dom.element>,
  ~groupId: string,
  ~fieldName: string,
  ~portEpoch: int,
  ~port: MessageChannelBinding.port,
  ~targetOrigin: string=GlobalVars.targetOrigin,
): unit => {
  coordinatorIframe->iframePostMessageWithTransfer(
    [
      ("cardFieldPort", true->JSON.Encode.bool),
      ("portKey", CardFormCoordinator.portKey(~groupId, ~fieldName)->JSON.Encode.string),
      ("portEpoch", portEpoch->Int.toFloat->JSON.Encode.float),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object
    ->JSON.stringify,
    ~targetOrigin,
    ~transfer=[port],
  )
}

// Per-group answer-listener key: the group registers+removes the fullscreen
// answer-loop listener under this name (same deinit slot as the
// `on*CoordinatorFullscreen-*` router listener).
let fullscreenAnswerListenerName = (localSelectorString: string): string =>
  `onCoordinatorFullscreenAnswer-${localSelectorString}`

// Per-group fullscreen FLOW factories — mirrors the INSTRUMENTED lifecycle of
// `LoaderPaymentElement.res:442-514`, scoped to THIS group. Returns a tuple:
//   1. ROUTER  — mount (iframeId-scoped), teardown (UNGATED on bare
//      `{fullscreen:false}` frames), and the fullscreen-document UPLINK
//      forward (`confirmParams`/`poll_status`/`openurl_if_required`/
//      `submitSuccessful` → the coordinator iframe, so its confirm intent —
//      not Hyper.res:487's onSubmit — is the resolution path when the
//      merchant called group.confirm()).
//   2. ANSWERER — the metadata answer loop the overlay docs block on:
//      `iframeMountedCallback` → `{fullScreenIframeMounted, metadata,
//      options, appearance}` → fullscreen iframe (ThreeDSAuth.res:29-52);
//      `driverMounted` → `{fullScreenIframeMounted, metadata, options}` →
//      coordinator iframe + `{metadata}` → fullscreen iframe
//      (ThreeDSMethod.res:288, FullScreenDivDriver.res:4).
// Both callbacks share latched `metadata` (captured from the mount frame) +
// the fullscreen-active ref that scopes the uplink forward.
let makeFullscreenFlows = (
  ~mount: coordinatorMount,
  ~localSelectorString: string,
  ~sdkDomain: string,
  ~options: JSON.t,
  ~appearance: JSON.t,
): (Window.event => unit, Window.event => unit) => {
  let metadataRef: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)
  let fullscreenActiveRef = ref(false)

  let router = (ev: Window.event) => {
    let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
    let dict = json->getDictFromJson
    let iframeId = dict->getString("iframeId", "")
    if dict->getBool("fullscreen", false) && iframeId === localSelectorString {
      // MOUNT (scoped): latch the real metadata payload; the overlay mounts
      // into the per-group slot (locked contract #2).
      metadataRef := dict->getJsonObjectFromDict("metadata")
      fullscreenActiveRef := true
      mount.fullscreenSlot->Window.innerHTML("")
      let parmType = dict->getString("param", "")
      let overlaySrc =
        parmType !== ""
          ? `${sdkDomain}/fullscreenIndex.html?fullscreenType=${parmType}`
          : `${sdkDomain}/fullscreenIndex.html?fullscreenType=fullscreen`
      mount.fullscreenSlot->Utils.makeIframe(overlaySrc)->ignore
    } else if dict->Dict.get("fullscreen")->Option.isSome && !(dict->getBool("fullscreen", true)) {
      // TEARDOWN (ungated): bare `{fullscreen:false}` frames carry NO iframeId
      // (PaymentHelpers.res:282, GooglePayHelpers.res:128,
      // Utils.closePaymentLoaderIfAny:1847, ThreeDSAuth error path) — the
      // legacy singleton behaviour flushed globally; every group-scope router
      // flushing its own slot reproduces that exactly.
      mount.fullscreenSlot->Window.innerHTML("")
      fullscreenActiveRef := false
      mount.iframe->Nullable.make->Window.iframePostMessage(
        [("fullScreenIframeMounted", false->JSON.Encode.bool), ("options", options)]->Dict.fromArray,
      )
    } else if (
      fullscreenActiveRef.contents && (
        dict->Dict.get("confirmParams")->Option.isSome ||
        dict->Dict.get("poll_status")->Option.isSome ||
        dict->Dict.get("openurl_if_required")->Option.isSome ||
        dict->Dict.get("submitSuccessful")->Option.isSome
      )
    ) {
      // UPLINK: the overlay doc posts these to the MERCHANT window (its
      // parent); forward into the coordinator iframe so the in-flight
      // intent machinery sees them (ThreeDSAuth.res:24-26 vocabulary).
      mount.iframe->Nullable.make->Window.iframePostMessage(dict)
    } else {
      ()
    }
  }

  let answerer = (ev: Window.event) => {
    let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
    let dict = json->getDictFromJson
    // The fullscreen iframe is `makeIframe`-created id `orca-fullscreen`
    // (Utils.res:1594) — select it exactly like the legacy loop does.
    let fullScreenEle = Window.querySelector(`#orca-fullscreen`)
    // BOTH answers are gated on THIS group's overlay being active. On a
    // two-group page (#orca-fullscreen is not group-scoped) an idle group's
    // answerer would otherwise answer the ACTIVE group's overlay with EMPTY
    // latched metadata + the idle group's options and corrupt a live 3DS
    // challenge.
    if fullscreenActiveRef.contents && dict->Dict.get("iframeMountedCallback")->Option.isSome {
      fullScreenEle->Window.iframePostMessage(
        [
          ("fullScreenIframeMounted", true->JSON.Encode.bool),
          ("metadata", metadataRef.contents),
          ("options", options),
          ("appearance", appearance),
        ]->Dict.fromArray,
      )
    }
    if fullscreenActiveRef.contents && dict->Dict.get("driverMounted")->Option.isSome {
      mount.iframe->Nullable.make->Window.iframePostMessage(
        [
          ("fullScreenIframeMounted", true->JSON.Encode.bool),
          ("metadata", metadataRef.contents),
          ("options", options),
        ]->Dict.fromArray,
      )
      fullScreenEle->Window.iframePostMessage(
        [("metadata", metadataRef.contents)]->Dict.fromArray,
      )
    }
  }

  (router, answerer)
}

// TEARDOWN (deinit-before-flush discipline): the group calls this once on
// deinit to close the epoch's ports AND strip the container. Cleanup has to
// happen ORDER-INVERTED relative to mount: slots go first, then the
// container; the registry sweep (`closeAllPorts`) deliberately lives in the
// group's OWN epoch handle space (SadPortRegistry is per
// top-document and the group documents its key prefix).
let teardown = (~mount: coordinatorMount, ~pendingPorts: array<pendingPort>): unit => {
  // Review fix (field-destroy-without-remount retention): a queued port1 lives
  // forever otherwise — the field on the port2 side is gone; a fleet of idle
  // listeners has no owner. Closing a port that was ALREADY transferred is
  // tolerated with a try (detached ports neutralize on close; errors washed).
  pendingPorts->Array.forEach(({port}) =>
    try {
      port->MessageChannelBinding.portClose
    } catch {
    | _ => ()
    }
  )
  mount.fullscreenSlot->Window.remove
  mount.container->Window.remove
}
