open Types
open Utils
open EventListenerManager
open Identity

@val @scope(("navigator", "clipboard"))
external writeText: string => promise<'a> = "writeText"

type callbacks = {
  release: unit => unit,
  isStaleAliasFor: (string, string) => bool,
  getFrame: unit => Nullable.t<Dom.element>,
  isTrusted: Types.event => bool,
  isTrustedWallet: Types.event => bool,
  isEventActive: Types.eventType => bool,
  oneClick: ref<option<unit => Promise.t<unit>>>,
  complete: ref<bool>,
}
let callbackOwners: Dict.t<callbacks> = Dict.make()
let hasCallback = (frame, predicate) =>
  callbackOwners
  ->Dict.valuesToArray
  ->Array.some(owner =>
    !(frame->Nullable.isNullable) && owner.getFrame() === frame && predicate(owner)
  )
let hasPaymentButtonHandler = frame =>
  hasCallback(frame, owner =>
    owner.isEventActive(PaymentButtonClick) && owner.oneClick.contents->Option.isSome
  )
let hasPaymentCompleteHandler = frame =>
  hasCallback(frame, owner => owner.isEventActive(PaymentComplete) && owner.complete.contents)
let hasPaymentButtonHandlerForEvent = event =>
  callbackOwners
  ->Dict.valuesToArray
  ->Array.some(owner =>
    owner.isTrustedWallet(event) && owner.isEventActive(PaymentButtonClick) &&
    owner.oneClick.contents->Option.isSome
  )

let walletOneClickEventHandler = (
  logger: HyperLoggerTypes.loggerMake,
  event: Types.event,
  handler,
) => {
  open Promise
  let json = try {
    event.data->anyTypeToJson
  } catch {
  | _ => JSON.Encode.null
  }

  let dict = json->getDictFromJson
  if dict->Dict.get("oneClickConfirmTriggered")->Option.isSome {
    let reply = accepted => {
      let msg =
        [
          ("walletClickEvent", accepted->JSON.Encode.bool),
          (
            "walletClickRequestId",
            dict->getJsonFromDict("walletClickRequestId", JSON.Encode.null),
          ),
        ]->Dict.fromArray
      event.source->Window.postMessage(msg->JSON.Encode.object->JSON.stringify, event.origin)
    }
    switch handler {
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
          reply(true)
          resolve()
        })
        ->catch(_ => {
          logger.setLogError(
            ~value=`Error in one click handler callback`,
            ~eventName=ONE_CLICK_HANDLER_CALLBACK,
            ~logType=ERROR,
          )
          reply(false)
          resolve()
        })
        ->ignore
      }

    // A vendor button can retain the old flag after the callback is removed.
    | None => reply(true)
    }
  }
}

let ensureWalletOneClickListener = logger => {
  addSmartEventListener(
    "message",
    event => {
      let owners = callbackOwners
        ->Dict.valuesToArray
        ->Array.filter(owner =>
          owner.isTrustedWallet(event) && owner.isEventActive(PaymentButtonClick)
        )
      // Prefer an active legacy callback over its paired mount's empty handler.
      owners
      ->Array.find(owner => owner.oneClick.contents->Option.isSome)
      ->Option.orElse(owners->Array.get(0))
      ->Option.forEach(owner => walletOneClickEventHandler(logger, event, owner.oneClick.contents))
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
// Older React wrappers register callbacks and mount through separate handles.
// Pair the handles themselves so callbacks follow a remount without taking
// ownership of the other handle's iframe.
type mountTarget = {
  creationId: int,
  mutable inheritedPair: bool,
  selector: ref<string>,
  frame: ref<Nullable.t<Dom.element>>,
  destroyed: ref<bool>,
  hasRegistration: ref<bool>,
  registeredEvents: array<Types.eventType>,
  mutable paired: bool,
  releaseCallback: ref<unit => unit>,
}
type callbackTarget = {selector: ref<string>, mount: ref<option<mountTarget>>, release: ref<unit => unit>}
let nextHandleId = ref(0)
let pendingMountsByType: Dict.t<array<mountTarget>> = Dict.make()
let pendingCallbacksByType: Dict.t<array<callbackTarget>> = Dict.make()

let isLiveMount = target =>
  !target.destroyed.contents &&
    target.frame.contents->Nullable.toOption->Option.mapOr(false, Window.Element.isConnected)

let make = (
  componentType,
  options,
  setIframeRef,
  mountPostMessage,
  ~appearance,
  ~isPaymentManagementElement=false,
  ~animateResize=true,
  ~redirectionFlags: JotaiAtomTypes.redirectionFlags,
  ~sdkDomainUrl=ApiEndpoint.sdkDomainUrl,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~confirmPayment: JSON.t => promise<JSON.t>,
  ~eventListenerTracker=LoggerUtils.defaultEventListenerTracker,
  ~onFullscreenCreated: (Dom.element, JSON.t) => unit=(_, _) => (),
  ~getClientSecret: unit => string=() => "",
  ~ownerId="",
  ~fieldName: option<string>=?,
  ~surfaceFamily: option<string>=?,
  ~groupId: option<string>=?,
) => {
  try {
    let logger = logger->Option.getOr(LoggerUtils.defaultLoggerConfig)
    let pairingKey = `${ownerId}:${groupId->Option.getOr("")}:${componentType}`
    let creationId = nextHandleId.contents
    nextHandleId := creationId + 1
    let hasMounted = ref(false)
    let hasRegistration = ref(false)
    let callbacksActive = ref(false)
    let destroyed = ref(false)
    let handleRef = ref(defaultPaymentElement)
    // Keep registrations on the handle so unmount can release window listeners
    // without losing callbacks when the same handle is mounted again.
    let listeners = ref([])
    let trackListener = (eventType, activity) => {
      eventListenerMap->Dict.get(activity)->Option.forEach(handler => {
        listeners := listeners.contents->Array.filter(((kind, name, _)) =>
          kind !== eventType || name !== activity
        )
        listeners.contents->Array.push((eventType, activity, handler))->ignore
      })
    }
    let addInstanceListener = (eventType, handler, activity) => {
      addSmartEventListener(eventType, handler, activity)
      trackListener(eventType, activity)
    }
    let eventHandlerFunc = (condition, handler, eventType, activity, ~isTrustedMessage) => {
      Utils.eventHandlerFunc(condition, handler, eventType, activity, ~isTrustedMessage)
      trackListener("message", activity)
    }
    let localSelectorRef = ref("")
    let eventListenerSelectorRef = localSelectorRef
    let mountedIframeRef = ref(Nullable.null)
    let fullscreenIframeRef = ref(Nullable.null)
    let mountedWrapperRef = ref(Nullable.null)
    let ownTarget: mountTarget = {
      creationId,
      inheritedPair: false,
      selector: localSelectorRef,
      frame: mountedIframeRef,
      destroyed,
      hasRegistration,
      registeredEvents: [],
      paired: false,
      releaseCallback: ref(() => ()),
    }
    let releaseCallback = ref(() => ())
    let callbackTarget: callbackTarget = {selector: localSelectorRef, mount: ref((None: option<mountTarget>)), release: releaseCallback}
    // Kept current across update() so the Change listener filters on the latest subscriptions.
    let currentOptions = ref(options)
    let subscriptionEventsRef = ref(options->getDictFromJson->getStrArray("subscriptionEvents"))
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

    let getMountedFrame = () => destroyed.contents ? Nullable.null : mountedIframeRef.contents
    let removePendingCallback = () => {
      let callbacks = pendingCallbacksByType->Dict.get(pairingKey)->Option.getOr([])
      pendingCallbacksByType->Dict.set(pairingKey, callbacks->Array.filter(target => target !== callbackTarget))
    }
    let resolveCallbackMount = () => {
      let current = callbackTarget.mount.contents
      current->Option.forEach(target => localSelectorRef := target.selector.contents)
      if current->Option.mapOr(false, isLiveMount) {
        removePendingCallback()
      } else {
        let mounts = pendingMountsByType->Dict.get(pairingKey)->Option.getOr([])
        let available = mounts->Array.filter(target =>
          isLiveMount(target) && !target.hasRegistration.contents &&
            (!target.paired || target.inheritedPair)
        )
        pendingMountsByType->Dict.set(pairingKey, available)
        let candidates = available->Array.filter(target =>
          (localSelectorRef.contents === "" || target.selector.contents === localSelectorRef.contents) &&
          (!target.paired || (current->Option.isNone && creationId < target.creationId))
        )
        let replacement = candidates->Array.find(target => !target.paired)
          ->Option.orElse(candidates->Array.get(0))
        switch replacement {
        | Some(target) =>
          if target.paired {
            // A legacy render creates its callback handle before the effect's
            // mount handle. Late registration can replace an inherited alias;
            // a newly created future widget cannot take an existing pairing.
            callbacksActive := false
            target.releaseCallback.contents()
            callbacksActive := true
          }
          current->Option.forEach(previous => {
            previous.paired = false
            previous.inheritedPair = false
            previous.releaseCallback := () => ()
          })
          target.paired = true
          target.inheritedPair = current->Option.isSome
          target.releaseCallback := releaseCallback.contents
          callbackTarget.mount := Some(target)
          localSelectorRef := target.selector.contents
          pendingMountsByType->Dict.set(pairingKey, available->Array.filter(mount =>
            mount !== target || target.inheritedPair
          ))
          removePendingCallback()
        | None =>
          // Retain the old pairing while unmounted: that same handle can still
          // remount elsewhere. A replacement may claim it only in this container.
          let callbacks = pendingCallbacksByType->Dict.get(pairingKey)->Option.getOr([])
          if !(callbacks->Array.includes(callbackTarget)) {
            callbacks->Array.push(callbackTarget)->ignore
            pendingCallbacksByType->Dict.set(pairingKey, callbacks)
          }
        }
      }
    }
    let getCallbackFrame = () => {
      if destroyed.contents {
        Nullable.null
      } else if hasMounted.contents {
        getMountedFrame()
      } else if callbacksActive.contents {
        resolveCallbackMount()
        callbackTarget.mount.contents
        ->Option.mapOr(Nullable.null, target =>
          isLiveMount(target) ? target.frame.contents : Nullable.null
        )
      } else {
        Nullable.null
      }
    }
    let isTrustedForFrame = (ev: Types.event, frame) =>
      isFromFrame(ev, frame, iframeOrigin) ||
      (ev.origin === fullscreenOrigin && WidgetRegistry.ownsOverlaySource(ev.source, frame))
    let isTrustedMessage = ev => isTrustedForFrame(ev, getCallbackFrame())
    let isTrustedMountMessage = ev => isTrustedForFrame(ev, getMountedFrame())
    // A mounted handle overrides only the events it registers. Keep the legacy
    // alias paired so its unrelated callbacks and remount behavior are preserved.
    let isEventActive = event =>
      hasMounted.contents || callbackTarget.mount.contents->Option.mapOr(true, target =>
        !(target.registeredEvents->Array.includes(event))
      )
    let publishCallbackOptionsTo = frame =>
      frame->Window.iframePostMessage(
        [
          ("isPaymentButtonHandlerProvided", hasPaymentButtonHandler(frame)->JSON.Encode.bool),
          ("isPaymentCompleteHandlerProvided", hasPaymentCompleteHandler(frame)->JSON.Encode.bool),
        ]->Dict.fromArray,
        ~targetOrigin=iframeOrigin,
      )
    let removePendingMount = () => {
      let mounts = pendingMountsByType->Dict.get(pairingKey)->Option.getOr([])
      pendingMountsByType->Dict.set(pairingKey, mounts->Array.filter(target => target !== ownTarget))
    }
    let detachCallback = (~publish=true, ()) => {
      callbackTarget.mount.contents->Option.forEach(target => {
        callbackTarget.mount := None
        target.paired = false
        target.inheritedPair = false
        target.releaseCallback := () => ()
        if !target.destroyed.contents && !target.hasRegistration.contents &&
          target.frame.contents->Nullable.toOption->Option.mapOr(false, frame => frame->Window.Element.isConnected) {
          let mounts = pendingMountsByType->Dict.get(pairingKey)->Option.getOr([])
          if !(mounts->Array.includes(target)) {
            mounts->Array.push(target)->ignore
            pendingMountsByType->Dict.set(pairingKey, mounts)
          }
        }
        if publish {
          publishCallbackOptionsTo(target.frame.contents)
        }
      })
    }
    let postToInstance = message =>
      getCallbackFrame()->Window.iframePostMessage(message, ~targetOrigin=iframeOrigin)

    // Unique per-instance ID to scope event listener names and prevent collisions.
    let elementInstanceId = generateRandomString(8)

    let setPaymentIframeRef = ref => {
      mountedIframeRef := ref
      setIframeRef(ref)
      ref
      ->Nullable.toOption
      ->Option.forEach(frame => {
        SdkMessageSources.register(~frame, ~origin=iframeOrigin)
        WidgetRegistry.registerFrame(frame, componentType, getClientSecret, handleRef.contents)
        publishCallbackOptionsTo(ref)
      })
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

    let isTrustedWalletMessage = event =>
      isTrustedMessage(event) ||
      (event.source === window &&
      event.origin === Window.Location.origin &&
      getCallbackFrame()
      ->Nullable.toOption
      ->Option.mapOr(false, frame =>
        frame->Window.Element.isConnected &&
          WidgetRegistry.walletRoutes
          ->WeakMap.get(frame)
          ->Option.mapOr(false, route =>
            event.data->anyTypeToJson->getDictFromJson->getString("walletRoutingId", "") === route
          )
      ))
    let callbackState: callbacks = {
      release: () => releaseCallback.contents(),
      isStaleAliasFor: (key, selector) =>
        pairingKey === key && !hasMounted.contents &&
        callbackTarget.mount.contents->Option.mapOr(false, target =>
          !isLiveMount(target) && target.selector.contents === selector
        ),
      getFrame: getCallbackFrame,
      isTrusted: isTrustedMessage,
      isTrustedWallet: isTrustedWalletMessage,
      isEventActive,
      oneClick: ref((None: option<unit => Promise.t<unit>>)),
      complete: ref(false),
    }
    let registerCallbacks = () => {
      callbacksActive := true
      callbackOwners->Dict.set(elementInstanceId, callbackState)
    }
    let publishCallbackOptions = () => publishCallbackOptionsTo(getCallbackFrame())
    let registerCallbackHandle = event => {
      hasRegistration := true
      if !(ownTarget.registeredEvents->Array.includes(event)) {
        ownTarget.registeredEvents->Array.push(event)->ignore
      }
      registerCallbacks()
      removePendingMount()
      publishCallbackOptions()
    }
    let onSDKHandleClick = eventHandler => {
      callbackState.oneClick := eventHandler
      registerCallbackHandle(PaymentButtonClick)
    }

    let on = (eventType, eventHandler) => {
      let event = eventType->eventTypeMapper
      // Publish the final handler state when taking over this event, without an
      // intermediate false flag while replacing a completion or wallet handler.
      switch event {
      | PaymentComplete => callbackState.complete := eventHandler->Option.isSome
      | PaymentButtonClick =>
        callbackState.oneClick := eventHandler->Option.map(eH => () =>
          Promise.resolve(eH((None: option<Types.eventData>)))
        )
      | _ => ()
      }
      registerCallbackHandle(event)
      let isTrustedMessage = ev => isTrustedMessage(ev) && isEventActive(event)
      eventListenerTracker.register(eventListenerSelectorRef)
      if eventHandler->Option.isSome {
        eventListenerTracker.logger.track(eventType)
      }
      let matchesInstance = (ev: Types.event) => {
        // Source ownership is checked first. Some existing emitters omit iframeId.
        let iframeId = ev.data->anyTypeToJson->getDictFromJson->getString("iframeId", "")
        let selector = callbackTarget.mount.contents
          ->Option.mapOr(localSelectorRef.contents, target => target.selector.contents)
        ev.data.elementType === componentType && (iframeId === "" || iframeId === selector)
      }

      // Subscription event helper: checks eventName in payload, then applies matchesInstance.
      let addSubscriptionEventListener = (subscriptionEventName, activity) => {
        addInstanceListener(
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
      switch event {
      | Escape =>
        addInstanceListener(
          "keypress",
          (ev: Types.event) => {
            if ev.key === "Escape" && isEventActive(Escape) {
              switch eventHandler {
              | Some(eH) => eH(Some(sanitizeEventData(ev.data)))
              | None => ()
              }
            }
          },
          `onEscape-${componentType}-${elementInstanceId}`,
        )
      | PaymentComplete =>
        let activity = `onPaymentComplete-${componentType}-${elementInstanceId}`
        removeSmartEventListener("message", activity)
        listeners := listeners.contents->Array.filter(((_, name, _)) => name !== activity)
        if eventHandler->Option.isSome {
          eventHandlerFunc(
            ev => ev.data.paymentComplete,
            eventHandler->Option.map(eH =>
              data => eH(data->Option.map(data => eventType->getPaymentCompleteEventData(data)))
            ),
            PaymentComplete,
            `onPaymentComplete-${componentType}-${elementInstanceId}`,
            ~isTrustedMessage,
          )
        }
      | Change =>
        // The fullscreen iframe cannot read subscriptionEvents, so it emits
        // paymentMethodFlowCancel unconditionally; drop it here unless subscribed.
        let isPaymentMethodFlowCancelSubscribed = () =>
          subscriptionEventsRef.contents->Array.includes("paymentMethodFlowCancel")
        let isUnsubscribedPaymentMethodFlowCancel = (ev: Types.event) =>
          !isPaymentMethodFlowCancelSubscribed() &&
          ev.data
          ->anyTypeToJson
          ->getOptionalJsonFromJson("eventName")
          ->getStringFromOptionalJson("") === "paymentMethodFlowCancel"
        eventHandlerFunc(
          ev =>
            !ev.data.focus &&
            !ev.data.blur &&
            !ev.data.ready &&
            !ev.data.resize &&
            !ev.data.confirmTriggered &&
            !ev.data.oneClickConfirmTriggered &&
            !isUnsubscribedPaymentMethodFlowCancel(ev) &&
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
        ()
      | SurchargeInfo =>
        addSubscriptionEventListener(
          "surchargeInfo",
          `onSurchargeInfo-${componentType}-${elementInstanceId}`,
        )
      | _ => ()
      }
    }
    let collapse = () => ()
    let blur = () => postToInstance([("doBlur", true->JSON.Encode.bool)]->Dict.fromArray)

    let focus = () => postToInstance([("doFocus", true->JSON.Encode.bool)]->Dict.fromArray)

    let clear = () => postToInstance([("doClearValues", true->JSON.Encode.bool)]->Dict.fromArray)

    let unmountInstance = (~publish=true, ()) => {
      callbacksActive := false
      callbackOwners->Dict.delete(elementInstanceId)
      removePendingMount()
      removePendingCallback()
      detachCallback(~publish, ())
      listeners.contents->Array.forEach(((kind, name, _)) => removeSmartEventListener(kind, name))
      listeners := listeners.contents->Array.filter(((_, name, _)) =>
        name !== `onMount-${componentType}-${elementInstanceId}` &&
        name !== `onFullScreenCallback-${elementInstanceId}`
      )
      mountedIframeRef.contents->Nullable.toOption->Option.forEach(WidgetRegistry.close)
      mountedIframeRef := Nullable.null
      fullscreenIframeRef := Nullable.null
      mountedWrapperRef.contents->Nullable.toOption->Option.forEach(wrapper => wrapper->remove)
      mountedWrapperRef := Nullable.null
    }

    let unmount = () => unmountInstance()
    // The caller publishes flags after installing the replacement owner. An
    // intermediate publication could let another pending alias claim the slot.
    releaseCallback := () => unmountInstance(~publish=false, ())

    let destroy = () => {
      unmount()
      destroyed := true
      listeners := []
      eventListenerTracker.destroy()
    }

    let update = newOptions => {
      switch newOptions->getDictFromJson->Dict.get("subscriptionEvents") {
      | Some(_) =>
        subscriptionEventsRef := newOptions->getDictFromJson->getStrArray("subscriptionEvents")
      | None => ()
      }
      let flatOption = currentOptions.contents->flattenObject(true)
      let newFlatOption = newOptions->flattenObject(true)

      let merged = mergeTwoFlattenedJsonDicts(flatOption, newFlatOption)
      // Arrays (including []) are replacement values, not indexed patches.
      newOptions
      ->getDictFromJson
      ->Dict.toArray
      ->Array.forEach(((key, value)) => {
        if value->JSON.Decode.array->Option.isSome || value === JSON.Encode.null {
          merged->Dict.set(key, value)
        }
      })
      currentOptions := merged->JSON.Encode.object
      postToInstance(
        [
          ("paymentElementsUpdate", true->JSON.Encode.bool),
          ("options", currentOptions.contents),
        ]->Dict.fromArray,
      )
    }

    let mount = selector => {
      if destroyed.contents {
        Console.warn(
          "INTEGRATION ERROR: Cannot mount a destroyed widget. Create a new widget and register its callbacks, or use unmount() when you intend to reuse a widget.",
        )
      } else {
        if !(mountedIframeRef.contents->Nullable.isNullable) {
          unmount()
        }
        // Publishing the old owner's flags must not reacquire this pairing.
        callbacksActive := false
        detachCallback()
        removePendingCallback()
        hasMounted := true
        ensureWalletOneClickListener(logger)
        registerCallbacks()
        listeners.contents->Array.forEach(((kind, name, handler)) =>
          addSmartEventListener(kind, handler, name)
        )

        let eventName: HyperLoggerTypes.eventName = ELEMENT_MOUNT_CALLED
        logger.setLogInfo(
          ~value=[
            ("componentType", componentType->JSON.Encode.string),
            ("surfaceFamily", surfaceFamily->Option.getOr("element")->JSON.Encode.string),
          ]
          ->Dict.fromArray
          ->JSON.Encode.object
          ->JSON.stringify,
          ~eventName,
        )
        let localSelectorArr = selector->String.split("#")
        let localSelectorString = localSelectorArr->Array.get(1)->Option.getOr("someString")
        localSelectorRef := localSelectorString

        // Replacing the container also ends the previous owner's mount lifetime.
        // Use its normal cleanup, keeping the handle reusable and legacy aliases
        // eligible to follow the replacement within their original collection.
        let previousFrame = Window.querySelector(
          `#orca-${elementIframeId}-iframeRef-${localSelectorString}`,
        )
        let previousOwners = callbackOwners->Dict.valuesToArray->Array.filter(owner =>
          (!(previousFrame->Nullable.isNullable) && owner.getFrame() === previousFrame) ||
          owner.isStaleAliasFor(pairingKey, localSelectorString)
        )
        previousFrame->Nullable.toOption
        ->Option.flatMap(frame => WidgetRegistry.frames->WeakMap.get(frame))
        ->Option.forEach(state => state.handle.unmount())

        if !hasRegistration.contents && !ownTarget.paired {
          let callbacks = pendingCallbacksByType->Dict.get(pairingKey)->Option.getOr([])
          let candidates = callbacks->Array.filter(callback =>
            !(callback.mount.contents->Option.mapOr(false, isLiveMount)) &&
              (callback.selector.contents === "" || callback.selector.contents === localSelectorString)
          )
          let pending = candidates->Array.find(callback => callback.mount.contents->Option.isNone)
            ->Option.orElse(candidates->Array.get(0))
          switch pending {
          | Some(callback) =>
            ownTarget.inheritedPair = callback.mount.contents->Option.isSome
            callback.mount.contents->Option.forEach(previous => {
              previous.paired = false
              previous.inheritedPair = false
              previous.releaseCallback := () => ()
            })
            ownTarget.paired = true
            ownTarget.releaseCallback := callback.release.contents
            callback.mount := Some(ownTarget)
            callback.selector := localSelectorString
            pendingCallbacksByType->Dict.set(pairingKey, callbacks->Array.filter(target => target !== callback))
            if ownTarget.inheritedPair {
              let mounts = pendingMountsByType->Dict.get(pairingKey)->Option.getOr([])
              mounts->Array.push(ownTarget)->ignore
              pendingMountsByType->Dict.set(pairingKey, mounts)
            }
          | None =>
            let mounts = pendingMountsByType->Dict.get(pairingKey)->Option.getOr([])
            mounts->Array.push(ownTarget)->ignore
            pendingMountsByType->Dict.set(pairingKey, mounts)
          }
        }
        eventListenerTracker.onMount(eventListenerSelectorRef.contents)
        let iframeHeightRef = ref(25.0)
        let currentClass = ref("base")
        let fullscreen = ref(false)
        let fullscreenParam = ref("")
        let fullscreenMetadata = ref(Dict.make()->JSON.Encode.object)
        let mountedWindow = ref((Nullable.null: Nullable.t<Dom.element>))
        let optionsDict = currentOptions.contents->getDictFromJson
        let handle = (ev: Types.event) => {
          let eventDataObject = ev.data->anyTypeToJson
          if eventDataObject->getDictFromJson->getBool("ready", false) {
            mountedIframeRef.contents->Nullable.toOption->Option.forEach(WidgetRegistry.markReady)
          }

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
              let iframeURL = ApiEndpoint.getFullscreenIframeUrl(
                ~fullscreenType=fullscreenParam.contents,
              )
              fullscreen.contents
                ? {
                    if iframeID == localSelectorString {
                      let handleFullScreenCallback = (ev: Types.event) => {
                        if isTrustedMountMessage(ev) {
                          let json = ev.data->anyTypeToJson
                          let dict = json->Utils.getDictFromJson
                          if dict->Dict.get("iframeMountedCallback")->Option.isSome {
                            let fullScreenEle = fullscreenIframeRef.contents
                            fullScreenEle->Window.iframePostMessage(
                              [
                                ("fullScreenIframeMounted", true->JSON.Encode.bool),
                                ("metadata", fullscreenMetadata.contents),
                                ("options", currentOptions.contents),
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
                                ("options", currentOptions.contents),
                              ]->Dict.fromArray,
                              ~targetOrigin=iframeOrigin,
                            )
                            let fullScreenEle = fullscreenIframeRef.contents
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
                      addInstanceListener(
                        "message",
                        handleFullScreenCallback,
                        `onFullScreenCallback-${elementInstanceId}`,
                      )
                      let colorScheme =
                        appearance
                        ->CardTheme.getColorSchemeFromAppearance
                        ->CardTheme.getColorSchemeValue
                      ele
                      ->makeIframe(iframeURL, ~colorScheme, ~onCreate=iframe => {
                        if (
                          Window.querySelector("#orca-fullscreen")->Nullable.toOption !==
                            Some(iframe)
                        ) {
                          iframe->Window.setAttribute("id", `orca-fullscreen-${elementInstanceId}`)
                        }
                        fullscreenIframeRef := Nullable.make(iframe)
                        SdkMessageSources.register(~frame=iframe, ~origin=fullscreenOrigin)
                        mountedIframeRef.contents
                        ->Nullable.toOption
                        ->Option.forEach(owner => WidgetRegistry.registerOverlay(iframe, owner))
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
                        ("options", currentOptions.contents),
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
            mountPostMessage(mountedIframe, localSelectorString, sdkHandleOneClickConfirmPayment, currentOptions.contents)
          }
        }
        // Multi-instance elements need unique listener names per instance.
        let eventListenerActivityName = `onMount-${componentType}-${elementInstanceId}`
        let handleIfTrusted = (ev: Types.event) => {
          if (
            isTrustedMountMessage(ev) ||
            (!(getMountedFrame()->Nullable.isNullable) && ev.source === window &&
            ev.origin === Window.Location.origin &&
            ev.data.iframeId === localSelectorRef.contents)
          ) {
            handle(ev)
          }
        }
        addInstanceListener("message", handleIfTrusted, eventListenerActivityName)

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
            mountedWrapperRef := Window.querySelector(`#orca-${elementIframeWrapperDivId}-${localSelectorString}`)
            setPaymentIframeRef(Window.querySelector(`#${iframeElementId}`))
            // A legacy alias may follow this replacement. Retire only owners
            // superseded by a new alias or by the new mount's own registrations.
            previousOwners->Array.forEach(owner => {
              if owner.getFrame() !== mountedIframeRef.contents {
                owner.release()
              }
            })

            let elem = Window.querySelector(`#${iframeElementId}`)
            switch elem->Nullable.toOption {
            | Some(ele) =>
              mountedWindow := ele->Window.contentWindow->Nullable.make
              ele
              ->Window.style
              ->Window.setTransition(
                animateResize ? "height 0.35s ease 0s, opacity 0.4s ease 0.1s" : "none",
              )

              let eventName: HyperLoggerTypes.eventName = ELEMENT_MOUNTED
              logger.setLogInfo(
                ~value=[
                  ("componentType", componentType->JSON.Encode.string),
                  ("surfaceFamily", surfaceFamily->Option.getOr("element")->JSON.Encode.string),
                  ("iframeId", iframeElementId->JSON.Encode.string),
                ]
                ->Dict.fromArray
                ->JSON.Encode.object
                ->JSON.stringify,
                ~eventName,
              )
            | None => ()
            }
          }

        | None => ()
        }
      }
    }

    let handle = {
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
      confirmPayment: payload => {
        let dict = payload->getDictFromJson->Dict.copy
        dict->Dict.set("element", handleRef.contents->anyTypeToJson)
        confirmPayment(dict->JSON.Encode.object)
      },
    }
    handleRef := handle
    WidgetRegistry.registerHandle(handle, () =>
      getCallbackFrame()->Nullable.toOption->Option.mapOr([], frame => [frame])
    )
    handle
  } catch {
  | e => {
      Sentry.captureException(e)
      defaultPaymentElement
    }
  }
}
