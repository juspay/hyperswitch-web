open Types
open Utils
open EventListenerManager
open Identity

@val @scope(("navigator", "clipboard"))
external writeText: string => promise<'a> = "writeText"

let onCompleteDoThisUsed = ref(false)
let isPaymentButtonHandlerProvided = ref(false)
let make = (
  componentType,
  options,
  setIframeRef,
  iframeRef,
  mountPostMessage,
  ~isPaymentManagementElement=false,
  ~redirectionFlags: RecoilAtomTypes.redirectionFlags,
) => {
  try {
    let mountId = ref("")
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

    Window.addEventListener("message", walletOneClickEventHandler)

    let onSDKHandleClick = (eventHandler: option<unit => Promise.t<'a>>) => {
      currEventHandler := eventHandler
      if eventHandler->Option.isSome {
        isPaymentButtonHandlerProvided := true
      }
    }

    let on = (eventType, eventHandler) => {
      switch eventType->eventTypeMapper {
      | Escape =>
        addSmartEventListener(
          "keypress",
          (ev: Types.event) => {
            if ev.key === "Escape" {
              switch eventHandler {
              | Some(eH) => eH(Some(ev.data))
              | None => ()
              }
            }
          },
          "onEscape",
        )
      | CompleteDoThis =>
        if eventHandler->Option.isSome {
          eventHandlerFunc(
            ev => ev.data.completeDoThis,
            eventHandler,
            CompleteDoThis,
            "onCompleteDoThis",
          )
        }
      | Change =>
        eventHandlerFunc(
          ev => ev.data.elementType === componentType,
          eventHandler,
          Change,
          "onChange",
        )
      | Click => eventHandlerFunc(ev => ev.data.clickTriggered, eventHandler, Click, "onClick")
      | Ready => eventHandlerFunc(ev => ev.data.ready, eventHandler, Ready, "onReady")
      | Focus => eventHandlerFunc(ev => ev.data.focus, eventHandler, Focus, "onFocus")
      | Blur => eventHandlerFunc(ev => ev.data.blur, eventHandler, Blur, "onBlur")
      | ConfirmPayment =>
        eventHandlerFunc(
          ev => ev.data.confirmTriggered,
          eventHandler,
          ConfirmPayment,
          "onHelpConfirmPayment",
        )
      | OneClickConfirmPayment =>
        eventHandlerFunc(
          ev => ev.data.oneClickConfirmTriggered,
          eventHandler,
          OneClickConfirmPayment,
          "onHelpOneClickConfirmPayment",
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
        Console.warn(
          "INTEGRATION ERROR: Div does not seem to exist on which payment element is to mount/unmount",
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
      addSmartEventListener("message", handle, `onMount-${componentType}`)

      let oElement = Window.querySelector(selector)
      let classesBase = optionsDict->getClasses("base")
      let additionalIframeStyle =
        componentType->Utils.isOtherElements ? "height: 2rem;" : "height: 0;"
      switch oElement->Nullable.toOption {
      | Some(elem) => {
          let iframeDiv = `<div id="orca-${elementIframeWrapperDivId}-${localSelectorString}" style="height: auto; font-size: 0;" class="${componentType} ${currentClass.contents} ${classesBase}">
          <div id="orca-fullscreen-iframeRef-${localSelectorString}"></div>
           <iframe
           id ="orca-${elementIframeId}-iframeRef-${localSelectorString}"
           name="orca-${elementIframeId}-iframeRef-${localSelectorString}"
          src="${ApiEndpoint.sdkDomainUrl}/index.html?componentName=${componentType}"
          allow="payment *"
          title="Orca Payment Element Frame"
          sandbox="allow-scripts allow-popups allow-same-origin allow-forms"
          name="orca-payment"
          style="border: 0px; ${additionalIframeStyle} outline: none;"
          width="100%"
        ></iframe>
        </div>`
          elem->Window.innerHTML(iframeDiv)
          setPaymentIframeRef(
            Window.querySelector(`#orca-${elementIframeId}-iframeRef-${localSelectorString}`),
          )

          let elem = Window.querySelector(
            `#orca-${elementIframeId}-iframeRef-${localSelectorString}`,
          )
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
