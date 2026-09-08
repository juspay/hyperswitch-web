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
      mount.iframe->Nullable.make->Window.iframePostMessage(dict)
    } else {
      ()
    }
  }

  let answerer = (ev: Window.event) => {
    let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
    let dict = json->getDictFromJson
    let fullScreenEle = Window.querySelector(`#orca-fullscreen`)
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

let teardown = (~mount: coordinatorMount, ~pendingPorts: array<pendingPort>): unit => {
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
