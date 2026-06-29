open Types
open Utils
open EventListenerManager
open Identity

@val @scope(("navigator", "clipboard"))
external writeText: string => promise<'a> = "writeText"

let onCompleteDoThisUsed = ref(false)
let isPaymentButtonHandlerProvided = ref(false)

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
// Multi-instance support: tracks unmounted element refs so sibling mount() calls can
// adopt handler-only instances (e.g. React wrapper) that never mount themselves.
let unclaimedSelectorRefsByType: Dict.t<array<ref<string>>> = Dict.make()

let make = (
  componentType,
  options,
  setIframeRef,
  iframeRef,
  mountPostMessage,
  ~appearance,
  ~isPaymentManagementElement=false,
  ~redirectionFlags: RecoilAtomTypes.redirectionFlags,
  ~sdkDomainUrl=ApiEndpoint.sdkDomainUrl,
  ~logger: option<HyperLoggerTypes.loggerMake>,
) => {
  try {
    let logger = logger->Option.getOr(LoggerUtils.defaultLoggerConfig)
    let mountId = ref("")
    let localSelectorRef = ref("")
    // Unique per-instance ID to scope event listener names and prevent collisions.
    let elementInstanceId = generateRandomString(8)

    // Register for sibling adoption — see unclaimedSelectorRefsByType.
    if componentType->Utils.canHaveMultipleInstances {
      let refs = unclaimedSelectorRefsByType->Dict.get(componentType)->Option.getOr([])
      refs->Array.push(localSelectorRef)->ignore
      unclaimedSelectorRefsByType->Dict.set(componentType, refs)
    }
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

    let currEventHandler = ref(Some(() => Promise.make((_, _) => {()})))
    let walletOneClickEventHandler = (event: Types.event) => {
      open Promise
      let json = try {
        event.data->anyTypeToJson
      } catch {
      | _ => JSON.Encode.null
      }

      let dict = json->getDictFromJson
      if dict->Dict.get("oneClickConfirmTriggered")->Option.isSome {
        switch currEventHandler.contents {
        | Some(eH) => {
            logger.setLogInfo(
              ~value=`One click handler callback execution initiated`,
              ~eventName=ONE_CLICK_HANDLER_CALLBACK,
              ~logType=INFO,
            )
            eH()
            ->then(_ => {
              logger.setLogInfo(
                ~value=`One click handler callback executed successfully`,
                ~eventName=ONE_CLICK_HANDLER_CALLBACK,
                ~logType=INFO,
              )
              let msg = [("walletClickEvent", true->JSON.Encode.bool)]->Dict.fromArray
              event.source->Window.sendPostMessage(msg)
              resolve()
            })
            ->catch(_ => {
              logger.setLogError(
                ~value=`Error in one click handler callback`,
                ~eventName=ONE_CLICK_HANDLER_CALLBACK,
                ~logType=ERROR,
              )
              let msg = [("walletClickEvent", false->JSON.Encode.bool)]->Dict.fromArray
              event.source->Window.sendPostMessage(msg)
              resolve()
            })
            ->ignore
          }

        | None => ()
        }
      }
    }

    Window.addEventListener("message", walletOneClickEventHandler)

    let onSDKHandleClick = (eventHandler: option<unit => Promise.t<'a>>) => {
      currEventHandler := eventHandler
      if eventHandler->Option.isSome {
        isPaymentButtonHandlerProvided := true
      }
    }

    let on = (eventType, eventHandler) => {
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
      | CvcStatus =>
        addSubscriptionEventListener(
          "CVC_STATUS",
          `onCVC_STATUS-${componentType}-${elementInstanceId}`,
        )
      | FormStatus =>
        addSubscriptionEventListener(
          "FORM_STATUS",
          `onFORM_STATUS-${componentType}-${elementInstanceId}`,
        )
      | PaymentMethodInfoCard =>
        addSubscriptionEventListener(
          "PAYMENT_METHOD_INFO_CARD",
          `onPAYMENT_METHOD_INFO_CARD-${componentType}-${elementInstanceId}`,
        )
      | PaymentMethodStatus =>
        addSubscriptionEventListener(
          "PAYMENT_METHOD_STATUS",
          `onPAYMENT_METHOD_STATUS-${componentType}-${elementInstanceId}`,
        )
      | BillingAddress =>
        addSubscriptionEventListener(
          "PAYMENT_METHOD_INFO_BILLING_ADDRESS",
          `onPAYMENT_METHOD_INFO_BILLING_ADDRESS-${componentType}-${elementInstanceId}`,
        )
      | Surcharge =>
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
        iframe->Window.iframePostMessage(message)
      })
    }

    let focus = () => {
      iframeRef->Array.forEach(iframe => {
        let message = [("doFocus", true->JSON.Encode.bool)]->Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })
    }

    let clear = () => {
      iframeRef->Array.forEach(iframe => {
        let message = [("doClearValues", true->JSON.Encode.bool)]->Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })
    }

    let unmount = () => {
      let id = mountId.contents

      let oElement = Window.querySelector(id)
      switch oElement->Nullable.toOption {
      | Some(elem) => elem->Window.innerHTML("")
      | None =>
        logger.setLogError(
          ~value="INTEGRATION ERROR: Div does not seem to exist on which payment element is to mount/unmount",
          ~eventName=SDK_CONNECTOR_WARNING,
          ~logType=WARNING,
          ~logCategory=MERCHANT_EVENT,
        )
      }
    }

    let destroy = () => {
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
        iframe->Window.iframePostMessage(message)
      })
    }

    let mount = selector => {
      mountId := selector
      let localSelectorArr = selector->String.split("#")
      let localSelectorString = localSelectorArr->Array.get(1)->Option.getOr("someString")
      localSelectorRef := localSelectorString

      // Adopt oldest unmounted sibling so its .on() handlers can resolve this iframeId.
      if componentType->Utils.canHaveMultipleInstances {
        let refs = unclaimedSelectorRefsByType->Dict.get(componentType)->Option.getOr([])
        switch refs->Array.find(r => r.contents === "") {
        | Some(siblingRef) => siblingRef := localSelectorString
        | None => ()
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
                          [("metadata", fullscreenMetadata.contents)]->Dict.fromArray,
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
      // Multi-instance elements need unique listener names per instance.
      let eventListenerActivityName = if componentType->Utils.canHaveMultipleInstances {
        `onMount-${componentType}-${localSelectorString}`
      } else {
        `onMount-${componentType}`
      }
      addSmartEventListener("message", handle, eventListenerActivityName)

      let oElement = Window.querySelector(selector)
      let classesBase = optionsDict->getClasses("base")
      let additionalIframeStyle =
        componentType->Utils.isOtherElements ? "height: 3rem;" : "height: 0;"
      switch oElement->Nullable.toOption {
      | Some(elem) => {
          let iframeElementId = `orca-${elementIframeId}-iframeRef-${localSelectorString}`
          let iframeDiv = `<div id="orca-${elementIframeWrapperDivId}-${localSelectorString}" style="height: auto; font-size: 0;" class="${componentType} ${currentClass.contents} ${classesBase}">
          <div id="orca-fullscreen-iframeRef-${localSelectorString}"></div>
          ${buildIframeHtmlString(
              ~iframeId=iframeElementId,
              ~iframeSrc=`${sdkDomainUrl}/index.html?componentName=${componentType}`,
              ~additionalStyle=additionalIframeStyle,
            )}
          </div>`
          elem->Window.innerHTML(iframeDiv)
          setPaymentIframeRef(Window.querySelector(`#${iframeElementId}`))

          let elem = Window.querySelector(`#${iframeElementId}`)
          switch elem->Nullable.toOption {
          | Some(ele) =>
            ele->Window.style->Window.setTransition("height 0.35s ease 0s, opacity 0.4s ease 0.1s")
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
      onSDKHandleClick,
    }
  } catch {
  | e => {
      Sentry.captureException(e)
      defaultPaymentElement
    }
  }
}
