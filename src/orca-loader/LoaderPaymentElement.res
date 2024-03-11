open Types
open Utils
open EventListenerManager

open OrcaUtils

external eventToJson: Types.eventData => Js.Json.t = "%identity"

type location = {replace: (. string) => unit}
@val @scope("window") external location: location = "location"

@val @scope(("navigator", "clipboard"))
external writeText: string => Js.Promise.t<'a> = "writeText"

let make = (componentType, options, setIframeRef, iframeRef, mountPostMessage) => {
  try {
    let mountId = ref("")
    let setPaymentIframeRef = ref => {
      setIframeRef(ref)
    }

    let sdkHandleConfirmPayment =
      options->getDecodedBoolFromJson(
        callbackFuncForExtractingValFromDict("sdkHandleConfirmPayment"),
        false,
      )

    let sdkHandleOneClickConfirmPayment =
      options->getDecodedBoolFromJson(
        callbackFuncForExtractingValFromDict("sdkHandleOneClickConfirmPayment"),
        true,
      )

    let displaySavedPaymentMethods =
      options->getDecodedBoolFromJson(
        callbackFuncForExtractingValFromDict("displaySavedPaymentMethods"),
        true,
      )

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
      iframeRef->Js.Array2.forEach(iframe => {
        let message = [("doBlur", true->Js.Json.boolean)]->Js.Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })
    }

    let focus = () => {
      iframeRef->Js.Array2.forEach(iframe => {
        let message = [("doFocus", true->Js.Json.boolean)]->Js.Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })
    }

    let clear = () => {
      iframeRef->Js.Array2.forEach(iframe => {
        let message = [("doClearValues", true->Js.Json.boolean)]->Js.Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })
    }

    let unmount = () => {
      let id = mountId.contents

      let oElement = Window.querySelector(id)
      switch oElement->Js.Nullable.toOption {
      | Some(elem) => elem->Window.innerHTML("")
      | None =>
        Js.Console.warn(
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

      let keys = flatOption->Js.Dict.keys
      keys->Js.Array2.forEach(key => {
        switch newFlatOption->Js.Dict.get(key) {
        | Some(op) => flatOption->Js.Dict.set(key, op)
        | None => ()
        }
      })

      let newEntries = newFlatOption->Js.Dict.entries
      newEntries->Js.Array2.forEach(entries => {
        let (key, value) = entries
        if flatOption->Js.Dict.get(key)->Belt.Option.isNone {
          flatOption->Js.Dict.set(key, value)
        }
      })

      iframeRef->Js.Array2.forEach(iframe => {
        let message =
          [
            ("paymentElementsUpdate", true->Js.Json.boolean),
            ("options", flatOption->Js.Json.object_->unflattenObject->Js.Json.object_),
          ]->Js.Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })
    }

    let mount = selector => {
      mountId := selector
      let localSelectorArr = selector->Js.String2.split("#")
      let localSelectorString =
        localSelectorArr->Belt.Array.get(1)->Belt.Option.getWithDefault("someString")
      let iframeHeightRef = ref(25.0)
      let currentClass = ref("base")
      let fullscreen = ref(false)
      let fullscreenParam = ref("")
      let fullscreenMetadata = ref(Js.Dict.empty()->Js.Json.object_)
      let optionsDict = options->getDictFromJson
      let handle = (ev: Types.event) => {
        let eventDataObject = ev.data->eventToJson

        let iframeHeight = eventDataObject->getOptionalJsonFromJson("iframeHeight")
        if iframeHeight->Belt.Option.isSome {
          let iframeId =
            eventDataObject
            ->getOptionalJsonFromJson("iframeId")
            ->getStringfromOptionaljson("no-element")
          iframeHeightRef := iframeHeight->getFloatfromjson(200.0)
          if iframeId === localSelectorString {
            let elem = Window.querySelector(
              `#orca-payment-element-iframeRef-${localSelectorString}`,
            )
            switch elem->Js.Nullable.toOption {
            | Some(ele) =>
              ele
              ->Window.style
              ->Window.setHeight(
                `${iframeHeightRef.contents !== 0.0
                    ? iframeHeightRef.contents->Belt.Float.toString
                    : "200"}px`,
              )
            | None => ()
            }
          }
        }
        //<...>//

        switch eventDataObject->getOptionalJsonFromJson("openurl") {
        | Some(val) => {
            let url = val->getStringfromjson("")
            location.replace(. url)
          }
        | None => ()
        }

        let isCopy = eventDataObject->getOptionalJsonFromJson("copy")->getBoolfromjson(false)
        let text =
          eventDataObject->getOptionalJsonFromJson("copyDetails")->getStringfromOptionaljson("")
        if isCopy {
          open Promise
          writeText(text)
          ->then(_ => {
            resolve()
          })
          ->ignore
        }

        let combinedHyperClasses = eventDataObject->getOptionalJsonFromJson("concatedString")
        if combinedHyperClasses->Belt.Option.isSome {
          let id = eventDataObject->getOptionalJsonFromJson("id")->getStringfromOptionaljson("")

          let decodeStringTest = combinedHyperClasses->Belt.Option.flatMap(Js.Json.decodeString)
          switch decodeStringTest {
          | Some(val) => currentClass := val
          | None => ()
          }
          if id == localSelectorString {
            let elem = Window.querySelector(`#orca-element-${localSelectorString}`)
            switch elem->Js.Nullable.toOption {
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
          eventDataObject->getOptionalJsonFromJson("iframeId")->getStringfromOptionaljson("")

        if fullscreenIframe->Belt.Option.isSome {
          fullscreen := fullscreenIframe->getBoolfromjson(false)
          fullscreenParam := param->getStringfromOptionaljson("")
          fullscreenMetadata :=
            metadata
            ->Belt.Option.flatMap(Js.Json.decodeObject)
            ->Belt.Option.getWithDefault(Js.Dict.empty())
            ->Js.Json.object_
          let fullscreenElem = Window.querySelector(
            `#orca-fullscreen-iframeRef-${localSelectorString}`,
          )

          switch fullscreenElem->Js.Nullable.toOption {
          | Some(ele) =>
            ele->Window.innerHTML("")
            let mainElement = Window.querySelector(
              `#orca-payment-element-iframeRef-${localSelectorString}`,
            )
            let iframeURL =
              fullscreenParam.contents != ""
                ? `${ApiEndpoint.sdkDomainUrl}/fullscreenIndex.html?fullscreenType=${fullscreenParam.contents}`
                : `${ApiEndpoint.sdkDomainUrl}/fullscreenIndex.html?fullscreenType=fullscreen`
            fullscreen.contents
              ? {
                  if iframeID == localSelectorString {
                    let handleFullScreenCallback = (ev: Types.event) => {
                      let json = ev.data->eventToJson
                      let dict = json->Utils.getDictFromJson
                      if dict->Js.Dict.get("iframeMountedCallback")->Belt.Option.isSome {
                        let fullScreenEle = Window.querySelector(`#orca-fullscreen`)
                        fullScreenEle->Window.iframePostMessage(
                          [
                            ("fullScreenIframeMounted", true->Js.Json.boolean),
                            ("metadata", fullscreenMetadata.contents),
                          ]->Js.Dict.fromArray,
                        )
                      }
                      if dict->Js.Dict.get("driverMounted")->Belt.Option.isSome {
                        mainElement->Window.iframePostMessage(
                          [
                            ("fullScreenIframeMounted", true->Js.Json.boolean),
                            ("metadata", fullscreenMetadata.contents),
                          ]->Js.Dict.fromArray,
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
                    [("fullScreenIframeMounted", false->Js.Json.boolean)]->Js.Dict.fromArray,
                  )
                }
          | None => ()
          }
        }

        if iframeMounted->Belt.Option.isSome {
          mountPostMessage(
            Window.querySelector(`#orca-payment-element-iframeRef-${localSelectorString}`),
            localSelectorString,
            sdkHandleConfirmPayment,
            sdkHandleOneClickConfirmPayment,
            displaySavedPaymentMethods,
          )
        }
      }
      addSmartEventListener("message", handle, `onMount-${componentType}`)

      let oElement = Window.querySelector(selector)
      let classesBase = optionsDict->OrcaUtils.getClasses("base")
      let additionalIframeStyle = componentType->Utils.isOtherElements ? "height: 2rem;" : ""
      switch oElement->Js.Nullable.toOption {
      | Some(elem) => {
          let iframeDiv = `<div id="orca-element-${localSelectorString}" style= "height: auto;"  class="${componentType} ${currentClass.contents} ${classesBase} ">
          <div id="orca-fullscreen-iframeRef-${localSelectorString}"></div>
           <iframe
           id ="orca-payment-element-iframeRef-${localSelectorString}"
           name="orca-payment-element-iframeRef-${localSelectorString}"
          src="${ApiEndpoint.sdkDomainUrl}/index.html?componentName=${componentType}"
          allow="payment *"
          name="orca-payment"
          style="border: 0px; ${additionalIframeStyle}"
          width="100%"
        ></iframe>
        </div>`
          elem->Window.innerHTML(iframeDiv)
          setPaymentIframeRef(
            Window.querySelector(`#orca-payment-element-iframeRef-${localSelectorString}`),
          )

          let elem = Window.querySelector(`#orca-payment-element-iframeRef-${localSelectorString}`)
          switch elem->Js.Nullable.toOption {
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
    }
  } catch {
  | e => {
      Sentry.captureException(e)
      defaultPaymentElement
    }
  }
}
