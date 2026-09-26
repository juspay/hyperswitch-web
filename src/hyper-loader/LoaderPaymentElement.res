open Types
open Utils
open EventListenerManager
open Identity

@val @scope(("navigator", "clipboard"))
external writeText: string => promise<'a> = "writeText"

let isPaymentButtonHandlerProvided = ref(false)

let currentOneClickHandler = ref((None: option<unit => Promise.t<unit>>))

let walletOneClickEventHandler = (event: Types.event) => {
  open Promise
  let json = try {
    event.data->anyTypeToJson
  } catch {
  | _ => JSON.Encode.null
  }

  let dict = json->getDictFromJson
  if dict->Dict.get("oneClickConfirmTriggered")->Option.isSome {
    switch currentOneClickHandler.contents {
    | Some(eH) =>
      eH()
      ->then(_ => {
        let msg = [("walletClickEvent", true->JSON.Encode.bool)]->Dict.fromArray
        event.source->Window.sendPostMessage(msg)
        resolve()
      })
      ->catch(_ => {
        let msg = [("walletClickEvent", false->JSON.Encode.bool)]->Dict.fromArray
        event.source->Window.sendPostMessage(msg)
        resolve()
      })
      ->ignore

    | None => ()
    }
  }
}

let ensureWalletOneClickListener = () => {
  addSmartEventListener("message", walletOneClickEventHandler, "walletOneClickHandler")
}

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

let pendingMountSelectorsByType: Dict.t<array<string>> = Dict.make()

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
  ~confirmPayment: JSON.t => promise<JSON.t>,
  ~fieldName: option<string>=?,
  ~surfaceFamily: option<string>=?,
  ~groupId: option<string>=?,
) => {
  try {
    let surfaceData: HyperLoaderLogger.surfaceData = {
      surface: fieldName->Option.isSome ? CardField : PaymentElement,
    }
    let surfaceDetails = switch fieldName {
    | Some(field) => [("field", field->JSON.Encode.string)]
    | None => [("component_type", componentType->JSON.Encode.string)]
    }
    let mountId = ref("")
    let localSelectorRef = ref("")

    let elementInstanceId = generateRandomString(8)

    let setPaymentIframeRef = ref => {
      setIframeRef(ref)
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

    ensureWalletOneClickListener()

    let onSDKHandleClick = eventHandler =>
      switch eventHandler {
      | Some(handler) =>
        currentOneClickHandler :=
          Some(
            HyperLoaderLogger.observeMerchantCallback(
              ~event=OnSdkHandleClick({surface: PaymentElement}),
              ~timeoutMs=LoggerRuntime.userGatedTimeoutMs,
              ~callback=handler,
            ),
          )
        isPaymentButtonHandlerProvided := true
      | None => ()
      }

    let registerEventHandler = (eventType, eventHandler) => {
      if componentType->Utils.canHaveMultipleInstances && localSelectorRef.contents === "" {
        let mounts = pendingMountSelectorsByType->Dict.get(componentType)->Option.getOr([])
        if mounts->Array.length > 0 {
          let selector = mounts->Array.getUnsafe(0)
          let remaining = mounts->Array.sliceToEnd(~start=1)
          pendingMountSelectorsByType->Dict.set(componentType, remaining)
          localSelectorRef := selector
        } else {
          let refs = pendingOnRefsByType->Dict.get(componentType)->Option.getOr([])

          if !(refs->Array.some(r => r === localSelectorRef)) {
            refs->Array.push(localSelectorRef)->ignore
            pendingOnRefsByType->Dict.set(componentType, refs)
          }
        }
      }
      let matchesInstance = (ev: Types.event) => {
        if componentType->Utils.canHaveMultipleInstances {
          ev.data.elementType === componentType && ev.data.iframeId === localSelectorRef.contents
        } else {
          ev.data.elementType === componentType
        }
      }

      let addSubscriptionEventListener = (subscriptionEventName, activity) => {
        addSmartEventListener(
          "message",
          (ev: Types.event) => {
            let json = ev.data->anyTypeToJson
            let name = json->getOptionalJsonFromJson("eventName")->getStringFromOptionalJson("")
            if name === subscriptionEventName && matchesInstance(ev) {
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
      | CompleteDoThis =>
        if eventHandler->Option.isSome {
          eventHandlerFunc(
            ev => ev.data.completeDoThis,
            eventHandler,
            CompleteDoThis,
            `onCompleteDoThis-${componentType}-${elementInstanceId}`,
          )
        }
      | Change =>
        eventHandlerFunc(
          ev =>
            !ev.data.focus &&
            !ev.data.blur &&
            !ev.data.ready &&
            !ev.data.confirmTriggered &&
            !ev.data.oneClickConfirmTriggered &&
            matchesInstance(ev),
          eventHandler,
          Change,
          `onChange-${componentType}-${elementInstanceId}`,
        )
      | Click =>
        eventHandlerFunc(
          ev => ev.data.clickTriggered,
          eventHandler,
          Click,
          `onClick-${componentType}-${elementInstanceId}`,
        )
      | Ready =>
        eventHandlerFunc(
          ev => ev.data.ready && matchesInstance(ev),
          eventHandler,
          Ready,
          `onReady-${componentType}-${elementInstanceId}`,
        )
      | Focus =>
        eventHandlerFunc(
          ev => ev.data.focus && matchesInstance(ev),
          eventHandler,
          Focus,
          `onFocus-${componentType}-${elementInstanceId}`,
        )
      | Blur =>
        eventHandlerFunc(
          ev => ev.data.blur && matchesInstance(ev),
          eventHandler,
          Blur,
          `onBlur-${componentType}-${elementInstanceId}`,
        )
      | ConfirmPayment =>
        eventHandlerFunc(
          ev => ev.data.confirmTriggered,
          eventHandler,
          ConfirmPayment,
          `onHelpConfirmPayment-${componentType}-${elementInstanceId}`,
        )
      | OneClickConfirmPayment =>
        eventHandlerFunc(
          ev => ev.data.oneClickConfirmTriggered,
          eventHandler,
          OneClickConfirmPayment,
          `onHelpOneClickConfirmPayment-${componentType}-${elementInstanceId}`,
        )
      | SurchargeInfo =>
        addSubscriptionEventListener(
          "surchargeInfo",
          `onSurchargeInfo-${componentType}-${elementInstanceId}`,
        )
      | _ =>
        HyperLoaderLogger.logMerchantIssue(
          ~issue=UnknownOptionKey,
          ~details=[("event", eventType->JSON.Encode.string)],
        )
      }
    }
    let collapse = () => ()
    let blur = () =>
      iframeRef->Array.forEach(iframe => {
        let message = [("doBlur", true->JSON.Encode.bool)]->Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })

    let focus = () =>
      iframeRef->Array.forEach(iframe => {
        let message = [("doFocus", true->JSON.Encode.bool)]->Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })

    let clear = () =>
      iframeRef->Array.forEach(iframe => {
        let message = [("doClearValues", true->JSON.Encode.bool)]->Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })

    let clearMountedContainer = () =>
      switch Window.querySelector(mountId.contents)->Nullable.toOption {
      | Some(elem) => elem->Window.innerHTML("")
      | None => ()
      }

    let containerPresentDetail = () => [
      (
        "container_present",
        Window.querySelector(mountId.contents)->Nullable.toOption->Option.isSome->JSON.Encode.bool,
      ),
    ]

    let unmount = () =>
      HyperLoaderLogger.observeMerchantCall(
        ~event=Unmount(surfaceData),
        ~details=surfaceDetails->Array.concat(containerPresentDetail()),
        ~call=clearMountedContainer,
      )

    let destroy = () =>
      HyperLoaderLogger.observeMerchantCall(
        ~event=Destroy(surfaceData),
        ~details=surfaceDetails->Array.concat(containerPresentDetail()),
        ~call=() => {
          clearMountedContainer()
          mountId := ""
        },
      )

    let updateElementOptions = newOptions => {
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
        iframe->Window.iframePostMessage(message)
      })
    }

    let update = newOptions =>
      HyperLoaderLogger.observeMerchantCall(
        ~event=HyperLoaderLogger.Update({surface: PaymentElement}),
        ~details=[("component_type", componentType->JSON.Encode.string)],
        ~call=() => updateElementOptions(newOptions),
      )

    let mountElement = selector => {
      mountId := selector
      let localSelectorArr = selector->String.split("#")
      let localSelectorString = localSelectorArr->Array.get(1)->Option.getOr("someString")
      localSelectorRef := localSelectorString

      if componentType->Utils.canHaveMultipleInstances {
        let refs = pendingOnRefsByType->Dict.get(componentType)->Option.getOr([])
        let emptyIdx = refs->Array.findIndex(r => r.contents === "")
        if emptyIdx >= 0 {
          let siblingRef = refs->Array.getUnsafe(emptyIdx)
          siblingRef := localSelectorString
          let remaining = refs->Array.filterWithIndex((_, i) => i !== emptyIdx)
          pendingOnRefsByType->Dict.set(componentType, remaining)
        } else {
          let mounts = pendingMountSelectorsByType->Dict.get(componentType)->Option.getOr([])
          mounts->Array.push(localSelectorString)->ignore
          pendingMountSelectorsByType->Dict.set(componentType, mounts)
        }
      }
      let iframeHeightRef = ref(25.0)
      let currentClass = ref("base")
      let fullscreen = ref(false)
      let fullscreenParam = ref("")
      let fullscreenMetadata = ref(Dict.make()->JSON.Encode.object)
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
                            LoggerContext.sharedContext(),
                          ]->Dict.fromArray,
                        )
                      }
                      if dict->Dict.get("driverMounted")->Option.isSome {
                        mainElement->Window.iframePostMessage(
                          [
                            ("fullScreenIframeMounted", true->JSON.Encode.bool),
                            ("metadata", fullscreenMetadata.contents),
                            ("options", options),
                          ]->Dict.fromArray,
                        )
                        let fullScreenEle = Window.querySelector(`#orca-fullscreen`)
                        fullScreenEle->Window.iframePostMessage(
                          [
                            ("metadata", fullscreenMetadata.contents),
                            LoggerContext.sharedContext(),
                          ]->Dict.fromArray,
                        )
                      }
                    }
                    addSmartEventListener(
                      "message",
                      handleFullScreenCallback,
                      "onFullScreenCallback",
                    )
                    ele->makeIframe(iframeURL)->ignore
                  }
                }
              : {
                  ele->Window.innerHTML("")
                  mainElement->Window.iframePostMessage(
                    [
                      ("fullScreenIframeMounted", false->JSON.Encode.bool),
                      ("options", options),
                    ]->Dict.fromArray,
                  )
                }
          | None => ()
          }
        }

        if iframeMounted->Option.isSome {
          mountPostMessage(
            Window.querySelector(`#orca-${elementIframeId}-iframeRef-${localSelectorString}`),
            localSelectorString,
            sdkHandleOneClickConfirmPayment,
          )
        }
      }

      let eventListenerActivityName = if componentType->Utils.canHaveMultipleInstances {
        `onMount-${componentType}-${localSelectorString}`
      } else {
        `onMount-${componentType}`
      }
      addSmartEventListener("message", handle, eventListenerActivityName)

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
            ele
            ->Window.style
            ->Window.setTransition(
              animateResize ? "height 0.35s ease 0s, opacity 0.4s ease 0.1s" : "none",
            )
          | None => ()
          }
        }

      | None =>
        HyperLoaderLogger.logMerchantIssue(
          ~issue=MissingParameter,
          ~details=[("selector", selector->JSON.Encode.string)],
        )
      }
    }

    let mount = selector =>
      HyperLoaderLogger.observeMerchantCall(
        ~event=Mount(surfaceData),
        ~details=surfaceDetails,
        ~call=() => mountElement(selector),
      )

    let on = (eventType, callback) => registerEventHandler(eventType, callback)

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
      onSDKHandleClick,
      confirmPayment,
    }
  } catch {
  | e => {
      Sentry.captureException(e)

      SdkLogger.logCrash(
        ~origin=ElementConstructor,
        ~details=[("component_type", componentType->JSON.Encode.string)],
        ~exn=e,
      )
      defaultPaymentElement
    }
  }
}
