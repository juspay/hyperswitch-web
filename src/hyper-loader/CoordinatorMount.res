/* CoordinatorMount — the merchant-DOM contract for ONE hidden `cardFormCoordinator` iframe
   per CardForm group.
   `localSelectorString` IS the coordinator's `iframeId`: it rides the mount-config and
   echoes on every outbound message. The per-group fullscreen slot keeps two CardForm groups
   on one page from clobbering each other's 3DS overlay.
   Posts carrying a MessageChannel port MUST use `Utils.iframePostMessageWithTransfer` — the
   payload stays stringified and the port rides the transfer list. */

open Utils

type coordinatorMount = {
  iframe: Dom.element,
  container: Dom.element,
  fullscreenSlot: Dom.element,
}

type pendingPort = {
  fieldName: string,
  epoch: int,
  port: MessageChannelBinding.port,
}

let create = (
  ~parentContainer: Window.body,
  ~localSelectorString: string,
  ~elementIframeId: string,
  ~surfaceFamily: string,
  ~groupId: string,
  ~sdkDomain: string,
): coordinatorMount => {
  let container = Window.createElement("div")
  container->Window.setAttribute("id", `orca-${elementIframeId}-iframeRef-${localSelectorString}`)
  parentContainer->Window.appendChild(container)

  /* URL carries both routing params: `componentName=cardFormCoordinator` plus surfaceFamily
     for the admission gate and groupId for port-key scoping. */
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
  iframe->Window.setAttribute(
    "style",
    "position: absolute; width: 0; height: 0; border: none; overflow: hidden; left: -9999px; top: -9999px;",
  )
  container->Window.appendChildElement(iframe)

  let fullscreenSlot = Window.createElement("div")
  fullscreenSlot->Window.setAttribute("id", `orca-fullscreen-iframeRef-${localSelectorString}`)
  container->Window.appendChildElement(fullscreenSlot)

  {iframe, container, fullscreenSlot}
}

/* `portKey` and `portEpoch` tell the receiving document where to registry-absorb the port;
   they must be embedded BEFORE the mount-config is posted. */
let withPortMeta = (~mountConfig: JSON.t, ~portKey: string, ~portEpoch: int): JSON.t => {
  let dict = mountConfig->getDictFromJson
  dict->Dict.set("portKey", portKey->JSON.Encode.string)
  dict->Dict.set("portEpoch", portEpoch->Int.toFloat->JSON.Encode.float)
  dict->JSON.Encode.object
}

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

/* step 2 of the choreography: after the coordinator's `iframeMounted`, transfer port1 in a
   minimal `cardFieldPort` frame — its LoaderController absorbs `ev.ports` under this key. */
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

let fullscreenAnswerListenerName = (localSelectorString: string): string =>
  `onCoordinatorFullscreenAnswer-${localSelectorString}`

/* per-group fullscreen flow factories. The ROUTER mounts iframeId-scoped, tears down
   UNGATED, and forwards the overlay's uplink into the coordinator iframe so ITS confirm
   intent is the resolution path when the merchant called group.confirm(). The ANSWERER
   satisfies the metadata answer loop the overlay docs block on. */
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
      metadataRef := dict->getJsonObjectFromDict("metadata")
      fullscreenActiveRef := true
      mount.fullscreenSlot->Window.innerHTML("")
      let paramType = dict->getString("param", "")
      let overlaySrc =
        paramType !== ""
          ? `${sdkDomain}/fullscreenIndex.html?fullscreenType=${paramType}`
          : `${sdkDomain}/fullscreenIndex.html?fullscreenType=fullscreen`
      mount.fullscreenSlot->Utils.makeIframe(overlaySrc)->ignore
    } else if dict->Dict.get("fullscreen")->Option.isSome && !(dict->getBool("fullscreen", true)) {
      /* teardown is UNGATED: bare `{fullscreen:false}` frames carry NO iframeId, so each
         group-scoped router flushing its own slot reproduces the legacy global flush. */
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
      /* the overlay posts these to the MERCHANT window; forward them into the coordinator iframe
         so the in-flight intent machinery sees them. */
      mount.iframe->Nullable.make->Window.iframePostMessage(dict)
    } else {
      ()
    }
  }

  let answerer = (ev: Window.event) => {
    let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
    let dict = json->getDictFromJson
    let fullScreenEle = Window.querySelector(`#orca-fullscreen`)
    /* both answers are gated on THIS group's overlay being active: `#orca-fullscreen` is not
       group-scoped, so on a two-group page an idle group's answerer would otherwise answer the
       ACTIVE group's overlay with empty metadata and corrupt a live 3DS challenge. */
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

/* teardown closes the epoch's ports and strips the container, order-inverted relative to
   mount: slots first, then the container. The registry sweep lives in the group's own epoch
   handle space because SadPortRegistry is per top-document. */
let teardown = (~mount: coordinatorMount, ~pendingPorts: array<pendingPort>): unit => {
  /* a queued port1 would live forever otherwise — its port2 field is gone. Closing an
     already-transferred port is tolerated: detached ports neutralize on close. */
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
