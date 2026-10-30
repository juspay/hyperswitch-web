open Utils

type coordinatorMount = {
  iframe: Dom.element,
  container: Dom.element,
  fullscreenSlot: Dom.element,
  origin: string,
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
  SdkMessageSources.register(~frame=iframe, ~origin=URLModule.makeUrl(sdkDomain).origin)

  let fullscreenSlot = Window.createElement("div")
  fullscreenSlot->Window.setAttribute("id", `orca-fullscreen-iframeRef-${localSelectorString}`)
  container->Window.appendChildElement(fullscreenSlot)

  {iframe, container, fullscreenSlot, origin: URLModule.makeUrl(sdkDomain).origin}
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
  let overlayTypeRef = ref("")
  let methodTransitionPending = ref(false)
  // Keep the window identity for terminal events queued just before overlay removal.
  let overlayRef: ref<option<(Dom.element, Dom.element)>> = ref(None)
  let origin = URLModule.makeUrl(sdkDomain).origin
  let fromCoordinator = (ev: Window.event) =>
    mount.iframe->Window.Element.isConnected &&
      PaymentMessageSecurity.isExpectedSender(
        ~source=mount.iframe->Window.contentWindow,
        ~origin,
        ~eventSource=ev.source,
        ~eventOrigin=ev.origin,
      )
  let fromOverlay = (ev: Window.event, ~allowRedirect=false) => {
    let redirectOrigin =
      metadataRef.contents
      ->getDictFromJson
      ->getDictFromDict("threeDSData")
      ->getString("three_ds_authorize_url", "")
      ->PaymentMessageSecurity.originOf
    overlayRef.contents
    ->Option.map(((_, source)) =>
      ev.source === source &&
        (ev.origin === origin || (allowRedirect && redirectOrigin === Some(ev.origin)))
    )
    ->Option.getOr(false)
  }
  let postToCoordinator = fields =>
    mount.iframe->Nullable.make->Window.iframePostMessage(fields, ~targetOrigin=origin)

  let router = (ev: Window.event) => {
    let dict = ev.data->Identity.anyTypeToJson->getDictFromJson
    let iframeId = dict->getString("iframeId", "")
    let paramType = dict->getString("param", "")
    let fromMethod =
      overlayTypeRef.contents === "3ds" &&
      paramType === "3dsAuth" &&
      (fullscreenActiveRef.contents || methodTransitionPending.contents) &&
      fromOverlay(ev)
    if (
      (fromCoordinator(ev) || fromMethod) &&
      dict->getBool("fullscreen", false) &&
      iframeId === localSelectorString
    ) {
      if fromMethod {
        // The method overlay may report its result, but cannot replace the
        // coordinator's credentials or authentication destination.
        let methodResult = dict->getDictFromDict("metadata")->getString("3dsMethodComp", "N")
        let metadata = metadataRef.contents->getDictFromJson->Dict.copy
        metadata->Dict.set("3dsMethodComp", (methodResult === "Y" ? "Y" : "N")->JSON.Encode.string)
        metadataRef := metadata->JSON.Encode.object
      } else {
        metadataRef := dict->getJsonObjectFromDict("metadata")
      }
      overlayTypeRef := paramType
      methodTransitionPending := false
      fullscreenActiveRef := true
      mount.fullscreenSlot->Window.innerHTML("")
      overlayRef := None
      let overlaySrc = ApiEndpoint.getFullscreenIframeUrl(
        ~sdkDomain,
        ~fullscreenType=paramType,
      )
      let colorScheme =
        appearance->CardTheme.getColorSchemeFromAppearance->CardTheme.getColorSchemeValue
      mount.fullscreenSlot
      ->Utils.makeIframe(overlaySrc, ~colorScheme, ~onCreate=iframe => {
        overlayRef := Some((iframe, iframe->Window.contentWindow))
        SdkMessageSources.register(~frame=iframe, ~origin)
      })
      ->ignore
    } else if (
      (fromCoordinator(ev) || fromOverlay(ev, ~allowRedirect=true)) &&
      dict->Dict.get("fullscreen")->Option.isSome &&
      !(dict->getBool("fullscreen", true))
    ) {
      // ThreeDSMethod queues close and open messages consecutively. Retain
      // that exact source for the one allowed transition after removal.
      methodTransitionPending :=
        overlayTypeRef.contents === "3ds" && fromOverlay(ev) && iframeId === localSelectorString
      mount.fullscreenSlot->Window.innerHTML("")
      fullscreenActiveRef := false
      postToCoordinator(
        [
          ("fullScreenIframeMounted", false->JSON.Encode.bool),
          ("options", options),
        ]->Dict.fromArray,
      )
    } else if fullscreenActiveRef.contents && fromOverlay(ev, ~allowRedirect=true) {
      // Overlay completion cannot add coordinator commands or arbitrary options.
      let fields =
        dict
        ->Dict.toArray
        ->Array.filter(((key, _)) =>
          [
            "confirmParams",
            "poll_status",
            "openurl_if_required",
            "submitSuccessful",
          ]->Array.includes(key)
        )
      if fields->Array.length > 0 {
        postToCoordinator(fields->Dict.fromArray)
      }
    }
  }

  let answerer = (ev: Window.event) => {
    if fullscreenActiveRef.contents && fromOverlay(ev) {
      let dict = ev.data->Identity.anyTypeToJson->getDictFromJson
      switch overlayRef.contents {
      | Some((iframe, _)) =>
        if dict->Dict.get("iframeMountedCallback")->Option.isSome {
          iframe
          ->Nullable.make
          ->Window.iframePostMessage(
            [
              ("fullScreenIframeMounted", true->JSON.Encode.bool),
              ("metadata", metadataRef.contents),
              ("options", options),
              ("appearance", appearance),
            ]->Dict.fromArray,
            ~targetOrigin=origin,
          )
        }
        if dict->Dict.get("driverMounted")->Option.isSome {
          postToCoordinator(
            [
              ("fullScreenIframeMounted", true->JSON.Encode.bool),
              ("metadata", metadataRef.contents),
              ("options", options),
            ]->Dict.fromArray,
          )
          iframe
          ->Nullable.make
          ->Window.iframePostMessage(
            [
              ("fullScreenIframeMounted", true->JSON.Encode.bool),
              ("metadata", metadataRef.contents),
            ]->Dict.fromArray,
            ~targetOrigin=origin,
          )
        }
      | None => ()
      }
    }
  }

  (router, answerer)
}

let teardown = (~mount: coordinatorMount): unit => {
  mount.fullscreenSlot->Window.remove
  mount.container->Window.remove
}
