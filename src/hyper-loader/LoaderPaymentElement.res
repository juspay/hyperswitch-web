open Types
open Utils
open EventListenerManager
open Identity

@val @scope(("navigator", "clipboard"))
external writeText: string => promise<'a> = "writeText"

let isPaymentCompleteHandlerProvided = ref(false)
let isPaymentButtonHandlerProvided = ref(false)

let currentOneClickHandler = ref((None: option<unit => Promise.t<unit>>))
let oneClickSources: Dict.t<Types.event => bool> = Dict.make()

let walletOneClickEventHandler = (logger: HyperLoggerTypes.loggerMake, event: Types.event) => {
  open Promise
  let json = try {
    event.data->anyTypeToJson
  } catch {
  | _ => JSON.Encode.null
  }

  let dict = json->getDictFromJson
  if dict->Dict.get("oneClickConfirmTriggered")->Option.isSome {
    switch currentOneClickHandler.contents {
    | Some(eH) => {
        logger.setLogInfo(
          ~value=`One click handler callback execution initiated`,
          ~eventName=ONE_CLICK_HANDLER_CALLBACK,
          ~logType=INFO,
        )
        resolve()
        ->then(() => eH())
        ->then(_ => {
          logger.setLogInfo(
            ~value=`One click handler callback executed successfully`,
            ~eventName=ONE_CLICK_HANDLER_CALLBACK,
            ~logType=INFO,
          )
          let msg =
            [
              ("walletClickEvent", true->JSON.Encode.bool),
              (
                "walletClickRequestId",
                dict->getJsonFromDict("walletClickRequestId", JSON.Encode.null),
              ),
            ]->Dict.fromArray
          event.source->Window.postMessage(msg->JSON.Encode.object->JSON.stringify, event.origin)
          resolve()
        })
        ->catch(_ => {
          logger.setLogError(
            ~value=`Error in one click handler callback`,
            ~eventName=ONE_CLICK_HANDLER_CALLBACK,
            ~logType=ERROR,
          )
          let msg =
            [
              ("walletClickEvent", false->JSON.Encode.bool),
              (
                "walletClickRequestId",
                dict->getJsonFromDict("walletClickRequestId", JSON.Encode.null),
              ),
            ]->Dict.fromArray
          event.source->Window.postMessage(msg->JSON.Encode.object->JSON.stringify, event.origin)
          resolve()
        })
        ->ignore
      }

    | None => ()
    }
  }
}

let ensureWalletOneClickListener = (logger, ~ownerId, ~isTrustedMessage) => {
  oneClickSources->Dict.set(ownerId, isTrustedMessage)
  addSmartEventListener(
    "message",
    event => {
      // The merchant callback is intentionally global. Retain each SDK
      // owner's live sender check, and invoke the callback only once.
      if oneClickSources->Dict.valuesToArray->Array.some(check => check(event)) {
        walletOneClickEventHandler(logger, event)
      }
    },
    "walletOneClickHandler",
  )
}

// ─── Shared iframe HTML builder ────────────────────────────────────────────────
// Produces the raw <iframe> HTML fragment used by the `mount` function.
let buildIframeHtmlString = (~iframeId: string, ~iframeSrc: string, ~additionalStyle: string) =>
  `<iframe
   id="${iframeId}"
   name="${iframeId}"
   src="${iframeSrc}"
   allow="payment *"
   title="Orca Payment Element Frame"
   sandbox="allow-scripts allow-popups allow-same-origin allow-forms"
   style="border: 0px; ${additionalStyle} outline: none;"
   width="100%"
></iframe>`
// Multi-instance support: rendezvous queues that pair handler-only instances
// (C, created at React render time, calls on()) with mounting instances
// (O, created in useEffect, calls mount()).
//
// React.StrictMode renders components twice and runs effects twice (cleanup +
// re-run), so we CANNOT register at make() time (duplicates accumulate).
// Instead we register lazily: mount() queues the selector, on() claims it.
// Whichever arrives first enqueues; the second dequeues and completes the pair.

// Selectors from mount() calls waiting for a matching on() call.
let pendingMountSelectorsByType: Dict.t<array<string>> = Dict.make()
// Refs from on() calls waiting for a matching mount() selector.
let pendingOnRefsByType: Dict.t<array<ref<string>>> = Dict.make()

let make = (
  componentType,
  options,
  setIframeRef,
  iframeRef,
  mountPostMessage,
  ~appearance,
  ~isPaymentManagementElement=false,
  ~animateResize=true,
  ~redirectionFlags: JotaiAtomTypes.redirectionFlags,
  ~sdkDomainUrl=ApiEndpoint.sdkDomainUrl,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~confirmPayment: JSON.t => promise<JSON.t>,
  ~eventListenerTracker=LoggerUtils.defaultEventListenerTracker,
  ~isTrustedPaymentMessage: option<Types.event => bool>=?,
  ~onFullscreenCreated: (Dom.element, JSON.t) => unit=(_, _) => (),
  ~fieldName: option<string>=?,
  ~surfaceFamily: option<string>=?,
  ~groupId: option<string>=?,
) => {
  try {
    let logger = logger->Option.getOr(LoggerUtils.defaultLoggerConfig)
    let mountId = ref("")
    let localSelectorRef = ref("")
    let eventListenerSelectorRef =
      componentType->Utils.canHaveMultipleInstances ? localSelectorRef : ref(componentType)
    let mountedIframeRef = ref(Nullable.null)
    let fullscreenIframeRef = ref(Nullable.null)
    let iframeOrigin = URLModule.makeUrl(sdkDomainUrl).origin
    let fullscreenOrigin = URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin

    let isFromFrame = (ev: Types.event, iframe, origin) =>
      iframe
      ->Nullable.toOption
      ->Option.map(iframe =>
        iframe->Window.Element.isConnected &&
        ev.source === iframe->Window.contentWindow &&
        ev.origin === origin
      )
      ->Option.getOr(false)

    let isTrustedMessage = (ev: Types.event) => {
      let trusted = switch isTrustedPaymentMessage {
      | Some(check) => check(ev)
      | None =>
        isFromFrame(ev, mountedIframeRef.contents, iframeOrigin) ||
        isFromFrame(ev, fullscreenIframeRef.contents, fullscreenOrigin)
      }
      trusted || (ev.source === window && ev.origin === Window.Location.origin)
    }

    // Unique per-instance ID to scope event listener names and prevent collisions.
    let elementInstanceId = generateRandomString(8)

    let setPaymentIframeRef = ref => {
      mountedIframeRef := ref
      setIframeRef(ref)
      ref->Nullable.toOption->Option.forEach(frame =>
        SdkMessageSources.register(~frame, ~origin=iframeOrigin)
      )
    }

    let (elementIframeWrapperDivId, elementIframeId) = if isPaymentManagementElement {
      ("management-element", "payment-methods-management-element")
    } else {
      ("element", "payment-element")
    }

    let sdkHandleOneClickConfirmPayment =
      options->getDecodedBoolFromJson(
        callbackFuncForExtractingValFromDict("sdkHandleOneClickConfirmPayment"),
        true,
      )

    let onSDKHandleClick = eventHandler => {
      if eventHandler->Option.isSome {
        currentOneClickHandler := eventHandler
        isPaymentButtonHandlerProvided := true
      }
    }

    let on = (eventType, eventHandler) => {
      // Multi-instance: if this C instance has no selector yet, try to claim
      // a pending mount selector.  If none is available, register self in the
      // pendingOnRefs queue so the next mount() can adopt us.
      // Guard on "" prevents re-registration on StrictMode effect re-runs.
      if componentType->Utils.canHaveMultipleInstances && localSelectorRef.contents === "" {
        let mounts = pendingMountSelectorsByType->Dict.get(componentType)->Option.getOr([])
        if mounts->Array.length > 0 {
          let selector = mounts->Array.getUnsafe(0)
          let remaining = mounts->Array.sliceToEnd(~start=1)
          pendingMountSelectorsByType->Dict.set(componentType, remaining)
          localSelectorRef := selector
        } else {
          // No mount yet — register ref for adoption when mount() comes.
          let refs = pendingOnRefsByType->Dict.get(componentType)->Option.getOr([])

          // Avoid duplicate registration (e.g. on() called twice on same instance).
          if !(refs->Array.some(r => r === localSelectorRef)) {
            refs->Array.push(localSelectorRef)->ignore
            pendingOnRefsByType->Dict.set(componentType, refs)
          }
        }
      }
      eventListenerTracker.register(eventListenerSelectorRef)
      if eventHandler->Option.isSome {
        eventListenerTracker.logger.track(eventType)
      }
      let matchesInstance = (ev: Types.event) => {
        // Multi-instance: match by elementType + iframeId so events route to the correct instance.
        if componentType->Utils.canHaveMultipleInstances {
          ev.data.elementType === componentType && ev.data.iframeId === localSelectorRef.contents
        } else {
          ev.data.elementType === componentType
        }
      }

      // Subscription event helper: checks eventName in payload, then applies matchesInstance.
      let addSubscriptionEventListener = (subscriptionEventName, activity) => {
        addSmartEventListener(
          "message",
          (ev: Types.event) => {
            let json = ev.data->anyTypeToJson
            let name = json->getOptionalJsonFromJson("eventName")->getStringFromOptionalJson("")
            if isTrustedMessage(ev) && name === subscriptionEventName && matchesInstance(ev) {
              switch eventHandler {
              | Some(eH) => eH(Some(sanitizeEventData(ev.data)))
              | None => ()
              }
            }
          },
          activity,
        )
      }
      switch eventType->eventTypeMapper {
      | Escape =>
        addSmartEventListener(
          "keypress",
          (ev: Types.event) => {
            if ev.key === "Escape" {
              switch eventHandler {
              | Some(eH) => eH(Some(sanitizeEventData(ev.data)))
              | None => ()
              }
            }
          },
          `onEscape-${componentType}-${elementInstanceId}`,
        )
      | PaymentComplete =>
        if eventHandler->Option.isSome {
          isPaymentCompleteHandlerProvided := true
          eventHandlerFunc(
            ev => ev.data.paymentComplete,
            eventHandler->Option.map(eH => _ => eH(Some(eventType->getPaymentCompleteEventData))),
            PaymentComplete,
            `onPaymentComplete-${componentType}-${elementInstanceId}`,
            ~isTrustedMessage,
          )
        }
      | Change =>
        eventHandlerFunc(
          ev =>
            !ev.data.focus &&
            !ev.data.blur &&
            !ev.data.ready &&
            !ev.data.resize &&
            !ev.data.confirmTriggered &&
            !ev.data.oneClickConfirmTriggered &&
            matchesInstance(ev),
          eventHandler,
          Change,
          `onChange-${componentType}-${elementInstanceId}`,
          ~isTrustedMessage,
        )
      | Click =>
        eventHandlerFunc(
          ev => ev.data.clickTriggered,
          eventHandler,
          Click,
          `onClick-${componentType}-${elementInstanceId}`,
          ~isTrustedMessage,
        )
      | Ready =>
        eventHandlerFunc(
          ev => ev.data.ready && matchesInstance(ev),
          eventHandler,
          Ready,
          `onReady-${componentType}-${elementInstanceId}`,
          ~isTrustedMessage,
        )
      | Resize =>
        eventHandlerFunc(
          ev => ev.data.resize && matchesInstance(ev),
          eventHandler,
          Resize,
          `onResize-${componentType}-${elementInstanceId}`,
          ~isTrustedMessage,
        )
      | Focus =>
        eventHandlerFunc(
          ev => ev.data.focus && matchesInstance(ev),
          eventHandler,
          Focus,
          `onFocus-${componentType}-${elementInstanceId}`,
          ~isTrustedMessage,
        )
      | Blur =>
        eventHandlerFunc(
          ev => ev.data.blur && matchesInstance(ev),
          eventHandler,
          Blur,
          `onBlur-${componentType}-${elementInstanceId}`,
          ~isTrustedMessage,
        )
      | ConfirmPayment =>
        eventHandlerFunc(
          ev => ev.data.confirmTriggered,
          eventHandler,
          ConfirmPayment,
          `onHelpConfirmPayment-${componentType}-${elementInstanceId}`,
          ~isTrustedMessage,
        )
      | OneClickConfirmPayment =>
        eventHandlerFunc(
          ev => ev.data.oneClickConfirmTriggered,
          eventHandler,
          OneClickConfirmPayment,
          `onHelpOneClickConfirmPayment-${componentType}-${elementInstanceId}`,
          ~isTrustedMessage,
        )
      | PaymentButtonClick =>
        onSDKHandleClick(eventHandler->Option.map(eH => () => Promise.resolve(eH(None))))
      | SurchargeInfo =>
        addSubscriptionEventListener(
          "surchargeInfo",
          `onSurchargeInfo-${componentType}-${elementInstanceId}`,
        )
      | _ => ()
      }
    }
    let collapse = () => ()
    let blur = () => {
      iframeRef->Array.forEach(iframe => {
        let message = [("doBlur", true->JSON.Encode.bool)]->Dict.fromArray
        iframe->Window.iframePostMessage(message, ~targetOrigin=iframeOrigin)
      })
    }

    let focus = () => {
      iframeRef->Array.forEach(iframe => {
        let message = [("doFocus", true->JSON.Encode.bool)]->Dict.fromArray
        iframe->Window.iframePostMessage(message, ~targetOrigin=iframeOrigin)
      })
    }

    let clear = () => {
      iframeRef->Array.forEach(iframe => {
        let message = [("doClearValues", true->JSON.Encode.bool)]->Dict.fromArray
        iframe->Window.iframePostMessage(message, ~targetOrigin=iframeOrigin)
      })
    }

    let unmount = () => {
      oneClickSources->Dict.delete(elementInstanceId)
      let id = mountId.contents
      mountedIframeRef := Nullable.null
      fullscreenIframeRef := Nullable.null

      let oElement = Window.querySelector(id)
      switch oElement->Nullable.toOption {
      | Some(elem) => elem->Window.innerHTML("")
      | None =>
        Console.warn(
          "INTEGRATION ERROR: Div does not seem to exist on which payment element is to mount/unmount",
        )
      }
    }

    let destroy = () => {
      eventListenerTracker.destroy()
      unmount()
      mountId := ""
    }

    let update = newOptions => {
      let flatOption = options->flattenObject(true)
      let newFlatOption = newOptions->flattenObject(true)

      let keys = flatOption->Dict.keysToArray
      keys->Array.forEach(key => {
        switch newFlatOption->Dict.get(key) {
        | Some(op) => flatOption->Dict.set(key, op)
        | None => ()
        }
      })

      let newEntries = newFlatOption->Dict.toArray
      newEntries->Array.forEach(entries => {
        let (key, value) = entries
        if flatOption->Dict.get(key)->Option.isNone {
          flatOption->Dict.set(key, value)
        }
      })

      iframeRef->Array.forEach(iframe => {
        let message =
          [
            ("paymentElementsUpdate", true->JSON.Encode.bool),
            ("options", flatOption->JSON.Encode.object->unflattenObject->JSON.Encode.object),
          ]->Dict.fromArray
        iframe->Window.iframePostMessage(message, ~targetOrigin=iframeOrigin)
      })
    }

    let mount = selector => {
      ensureWalletOneClickListener(logger, ~ownerId=elementInstanceId, ~isTrustedMessage)
      mountId := selector
      let localSelectorArr = selector->String.split("#")
      let localSelectorString = localSelectorArr->Array.get(1)->Option.getOr("someString")
      localSelectorRef := localSelectorString

      // Multi-instance rendezvous: pair this mount with a waiting on() ref, or
      // enqueue the selector so a future on() call can claim it.
      if componentType->Utils.canHaveMultipleInstances {
        let refs = pendingOnRefsByType->Dict.get(componentType)->Option.getOr([])
        let emptyIdx = refs->Array.findIndex(r => r.contents === "")
        if emptyIdx >= 0 {
          // A C instance is already waiting — hand it the selector.
          let siblingRef = refs->Array.getUnsafe(emptyIdx)
          siblingRef := localSelectorString
          let remaining = refs->Array.filterWithIndex((_, i) => i !== emptyIdx)
          pendingOnRefsByType->Dict.set(componentType, remaining)
        } else {
          // No C instance waiting yet — enqueue for a future on() call.
          let mounts = pendingMountSelectorsByType->Dict.get(componentType)->Option.getOr([])
          mounts->Array.push(localSelectorString)->ignore
          pendingMountSelectorsByType->Dict.set(componentType, mounts)
        }
      }
      eventListenerTracker.onMount(eventListenerSelectorRef.contents)
      let iframeHeightRef = ref(25.0)
      let currentClass = ref("base")
      let fullscreen = ref(false)
      let fullscreenParam = ref("")
      let fullscreenMetadata = ref(Dict.make()->JSON.Encode.object)
      let mountedWindow = ref((Nullable.null: Nullable.t<Dom.element>))
      let optionsDict = options->getDictFromJson
      let handle = (ev: Types.event) => {
        let eventDataObject = ev.data->anyTypeToJson

        let iframeHeight = eventDataObject->getOptionalJsonFromJson("iframeHeight")
        if iframeHeight->Option.isSome {
          let iframeId =
            eventDataObject
            ->getOptionalJsonFromJson("iframeId")
            ->getStringFromOptionalJson("no-element")
          iframeHeightRef :=
            iframeHeight->Option.getOr(JSON.Encode.null)->Utils.getFloatFromJson(200.0)
          if iframeId === localSelectorString {
            let elem = Window.querySelector(
              `#orca-${elementIframeId}-iframeRef-${localSelectorString}`,
            )
            switch elem->Nullable.toOption {
            | Some(ele) =>
              switch iframeId {
              | "payout-link" | "payment-method-collect" =>
                ele
                ->Window.style
                ->Window.setHeight("100vh")
              | _ =>
                ele
                ->Window.style
                ->Window.setHeight(`${iframeHeightRef.contents->Float.toString}px`)
              }
            | None => ()
            }
          }
        }

        switch eventDataObject->getOptionalJsonFromJson("openurl") {
        | Some(val) => {
            let url = val->getStringFromJson("")
            Utils.replaceRootHref(url, redirectionFlags)
          }
        | None => ()
        }

        let isCopy =
          eventDataObject->getOptionalJsonFromJson("copy")->getBoolFromOptionalJson(false)
        let text =
          eventDataObject->getOptionalJsonFromJson("copyDetails")->getStringFromOptionalJson("")
        if isCopy {
          open Promise
          writeText(text)->then(_ => resolve())->catch(_ => resolve())->ignore
        }

        let combinedHyperClasses = eventDataObject->getOptionalJsonFromJson("concatedString")
        if combinedHyperClasses->Option.isSome {
          let id = eventDataObject->getOptionalJsonFromJson("id")->getStringFromOptionalJson("")

          let decodeStringTest = combinedHyperClasses->Option.flatMap(JSON.Decode.string)
          switch decodeStringTest {
          | Some(val) => currentClass := val
          | None => ()
          }
          if id == localSelectorString {
            let elem = Window.querySelector(
              `#orca-${elementIframeWrapperDivId}-${localSelectorString}`,
            )
            switch elem->Nullable.toOption {
            | Some(ele) => ele->Window.className(currentClass.contents)
            | None => ()
            }
          }
        }

        let iframeMounted = eventDataObject->getOptionalJsonFromJson("iframeMounted")
        let fullscreenIframe = eventDataObject->getOptionalJsonFromJson("fullscreen")
        let param = eventDataObject->getOptionalJsonFromJson("param")
        let metadata = eventDataObject->getOptionalJsonFromJson("metadata")
        let iframeID =
          eventDataObject->getOptionalJsonFromJson("iframeId")->getStringFromOptionalJson("")

        if fullscreenIframe->Option.isSome {
          fullscreen := fullscreenIframe->getBoolFromOptionalJson(false)
          fullscreenParam := param->getStringFromOptionalJson("")
          fullscreenMetadata :=
            metadata
            ->Option.flatMap(JSON.Decode.object)
            ->Option.getOr(Dict.make())
            ->JSON.Encode.object
          let fullscreenElem = Window.querySelector(
            `#orca-fullscreen-iframeRef-${localSelectorString}`,
          )

          switch fullscreenElem->Nullable.toOption {
          | Some(ele) =>
            fullscreenIframeRef := Nullable.null
            ele->Window.innerHTML("")
            let mainElement = Window.querySelector(
              `#orca-${elementIframeId}-iframeRef-${localSelectorString}`,
            )
            let iframeURL =
              fullscreenParam.contents != ""
                ? `${ApiEndpoint.sdkDomainUrl}/fullscreenIndex.html?fullscreenType=${fullscreenParam.contents}`
                : `${ApiEndpoint.sdkDomainUrl}/fullscreenIndex.html?fullscreenType=fullscreen`
            fullscreen.contents
              ? {
                  if iframeID == localSelectorString {
                    let handleFullScreenCallback = (ev: Types.event) => {
                      if isTrustedMessage(ev) {
                        let json = ev.data->anyTypeToJson
                        let dict = json->Utils.getDictFromJson
                        if dict->Dict.get("iframeMountedCallback")->Option.isSome {
                          let fullScreenEle = Window.querySelector(`#orca-fullscreen`)
                          fullScreenEle->Window.iframePostMessage(
                            [
                              ("fullScreenIframeMounted", true->JSON.Encode.bool),
                              ("metadata", fullscreenMetadata.contents),
                              ("options", options),
                              ("appearance", appearance),
                            ]->Dict.fromArray,
                            ~targetOrigin=fullscreenOrigin,
                          )
                        }
                        if dict->Dict.get("driverMounted")->Option.isSome {
                          mainElement->Window.iframePostMessage(
                            [
                              ("fullScreenIframeMounted", true->JSON.Encode.bool),
                              ("metadata", fullscreenMetadata.contents),
                              ("options", options),
                            ]->Dict.fromArray,
                            ~targetOrigin=iframeOrigin,
                          )
                          let fullScreenEle = Window.querySelector(`#orca-fullscreen`)
                          fullScreenEle->Window.iframePostMessage(
                            [
                              ("fullScreenIframeMounted", true->JSON.Encode.bool),
                              ("metadata", fullscreenMetadata.contents),
                            ]->Dict.fromArray,
                            ~targetOrigin=fullscreenOrigin,
                          )
                        }
                      }
                    }
                    addSmartEventListener(
                      "message",
                      handleFullScreenCallback,
                      "onFullScreenCallback",
                    )
                    let colorScheme =
                      appearance
                      ->CardTheme.getColorSchemeFromAppearance
                      ->CardTheme.getColorSchemeValue
                    ele
                    ->makeIframe(iframeURL, ~colorScheme, ~onCreate=iframe => {
                      fullscreenIframeRef := Nullable.make(iframe)
                      SdkMessageSources.register(~frame=iframe, ~origin=fullscreenOrigin)
                      onFullscreenCreated(iframe, fullscreenMetadata.contents)
                    })
                    ->ignore
                  }
                }
              : {
                  ele->Window.innerHTML("")
                  mainElement->Window.iframePostMessage(
                    [
                      ("fullScreenIframeMounted", false->JSON.Encode.bool),
                      ("options", options),
                    ]->Dict.fromArray,
                    ~targetOrigin=iframeOrigin,
                  )
                }
          | None => ()
          }
        }

        if iframeMounted->Option.isSome {
          let mountedIframe = Window.querySelector(
            `#orca-${elementIframeId}-iframeRef-${localSelectorString}`,
          )

          if (
            !(mountedWindow.contents->Nullable.isNullable) &&
            ev.source === mountedWindow.contents->Nullable.getUnsafe
          ) {
            eventListenerTracker.logger.logOnMount()
          }
          mountPostMessage(mountedIframe, localSelectorString, sdkHandleOneClickConfirmPayment)
        }
      }
      // Multi-instance elements need unique listener names per instance.
      let eventListenerActivityName = if componentType->Utils.canHaveMultipleInstances {
        `onMount-${componentType}-${localSelectorString}`
      } else {
        `onMount-${componentType}`
      }
      let handleIfTrusted = (ev: Types.event) => {
        if isTrustedMessage(ev) {
          handle(ev)
        }
      }
      addSmartEventListener("message", handleIfTrusted, eventListenerActivityName)

      let oElement = Window.querySelector(selector)
      let classesBase = optionsDict->getClasses("base")
      let additionalIframeStyle = switch (fieldName, componentType->Utils.isOtherElements) {
      | (Some(_), _) =>
        let inputFieldHeight =
          optionsDict
          ->getDictFromDict("appearance")
          ->getDictFromDict("variables")
          ->getString("inputFieldHeight", "48px")
        `height: ${inputFieldHeight};`
      | (None, true) => "height: 3rem;"
      | (None, false) => "height: 0;"
      }
      switch oElement->Nullable.toOption {
      | Some(elem) => {
          let iframeElementId = `orca-${elementIframeId}-iframeRef-${localSelectorString}`
          let appendParam = (url, key, value) =>
            switch value {
            | Some(v) => `${url}&${key}=${encodeURIComponent(v)}`
            | None => url
            }
          let iframeSrc =
            `${sdkDomainUrl}/index.html?componentName=${componentType}`
            ->appendParam("fieldName", fieldName)
            ->appendParam("surfaceFamily", surfaceFamily)
            ->appendParam("groupId", groupId)
          let iframeDiv = `<div id="orca-${elementIframeWrapperDivId}-${localSelectorString}" style="height: auto; font-size: 0;" class="${componentType} ${currentClass.contents} ${classesBase}">
          <div id="orca-fullscreen-iframeRef-${localSelectorString}"></div>
          ${buildIframeHtmlString(
              ~iframeId=iframeElementId,
              ~iframeSrc,
              ~additionalStyle=additionalIframeStyle,
            )}
          </div>`
          elem->Window.innerHTML(iframeDiv)
          setPaymentIframeRef(Window.querySelector(`#${iframeElementId}`))

          let elem = Window.querySelector(`#${iframeElementId}`)
          switch elem->Nullable.toOption {
          | Some(ele) =>
            mountedWindow := ele->Window.contentWindow->Nullable.make
            ele
            ->Window.style
            ->Window.setTransition(
              animateResize ? "height 0.35s ease 0s, opacity 0.4s ease 0.1s" : "none",
            )
          | None => ()
          }
        }

      | None => ()
      }
    }

    {
      on,
      collapse,
      blur,
      focus,
      clear,
      unmount,
      destroy,
      update,
      mount,
      onSDKHandleClick: eventHandler => {
        eventListenerTracker.register(eventListenerSelectorRef)
        if eventHandler->Option.isSome {
          eventListenerTracker.logger.track("onSDKHandleClick")
        }
        onSDKHandleClick(eventHandler)
      },
      confirmPayment,
    }
  } catch {
  | e => {
      Sentry.captureException(e)
      defaultPaymentElement
    }
  }
}
