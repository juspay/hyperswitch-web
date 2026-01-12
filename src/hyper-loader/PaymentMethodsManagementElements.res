open Types
open ErrorUtils
open Utils
open EventListenerManager

let make = (
  options,
  setIframeRef,
  ~ephemeralKey,
  ~pmClientSecret,
  ~pmSessionId,
  ~sdkSessionId,
  ~publishableKey,
  ~profileId,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~analyticsMetadata,
  ~customBackendUrl,
) => {
  let hyperComponentName = PaymentMethodsManagementElements
  try {
    let iframeRef = []
    let logger = logger->Option.getOr(LoggerUtils.defaultLoggerConfig)
    let savedPaymentElement = Dict.make()
    let localOptions = options->JSON.Decode.object->Option.getOr(Dict.make())

    let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

    let appearance =
      localOptions->Dict.get("appearance")->Option.getOr(Dict.make()->JSON.Encode.object)
    let launchTime = localOptions->getFloat("launchTime", 0.0)

    let fonts =
      localOptions
      ->Dict.get("fonts")
      ->Option.flatMap(JSON.Decode.array)
      ->Option.getOr([])
      ->JSON.Encode.array

    let customPodUri =
      options
      ->JSON.Decode.object
      ->Option.flatMap(x => x->Dict.get("customPodUri"))
      ->Option.flatMap(JSON.Decode.string)
      ->Option.getOr("")

    let localSelectorString = "hyper-preMountLoader-iframe"
    let mountPreMountLoaderIframe = () => {
      if (
        Window.querySelector(
          `#orca-payment-element-iframeRef-${localSelectorString}`,
        )->Js.Nullable.isNullable
      ) {
        let componentType = "preMountLoader"
        let iframeDivHtml = `<div id="orca-element-${localSelectorString}" style= "height: 0px; width: 0px; display: none;"  class="${componentType}">
          <div id="orca-fullscreen-iframeRef-${localSelectorString}"></div>
           <iframe
           id ="orca-payment-element-iframeRef-${localSelectorString}"
           name="orca-payment-element-iframeRef-${localSelectorString}"
          src="${ApiEndpoint.sdkDomainUrl}/index.html?fullscreenType=${componentType}&publishableKey=${publishableKey}&profileId=${profileId}&ephemeralKey=${ephemeralKey}&pmSessionId=${pmSessionId}&pmClientSecret=${pmClientSecret}&sessionId=${sdkSessionId}&endpoint=${endpoint}&hyperComponentName=${hyperComponentName->getStrFromHyperComponentName}"
          allow="*"
          name="orca-payment"
          style="outline: none;"
        ></iframe>
        </div>`
        let iframeDiv = Window.createElement("div")
        iframeDiv->Window.innerHTML(iframeDivHtml)
        Window.body->Window.appendChild(iframeDiv)
      }

      let elem = Window.querySelector(`#orca-payment-element-iframeRef-${localSelectorString}`)
      elem
    }

    let locale = localOptions->getJsonStringFromDict("locale", "auto")
    let loader = localOptions->getJsonStringFromDict("loader", "")

    let preMountLoaderIframeDiv = mountPreMountLoaderIframe()

    let unMountPreMountLoaderIframe = () => {
      switch preMountLoaderIframeDiv->Nullable.toOption {
      | Some(iframe) => iframe->remove
      | None => ()
      }
    }

    let preMountLoaderMountedPromise = Promise.make((resolve, _reject) => {
      let preMountLoaderIframeCallback = (ev: Types.event) => {
        let json = ev.data->Identity.anyTypeToJson
        let dict = json->getDictFromJson
        if dict->Dict.get("preMountLoaderIframeMountedCallback")->Option.isSome {
          resolve(true->JSON.Encode.bool)
        } else if dict->Dict.get("preMountLoaderIframeUnMount")->Option.isSome {
          unMountPreMountLoaderIframe()
        }
      }
      addSmartEventListener(
        "message",
        preMountLoaderIframeCallback,
        "onPreMountLoaderIframeCallback",
      )
    })

    let fetchSavedPaymentMethods = (mountedIframeRef, disableSaveCards, componentType) => {
      Promise.make((resolve, _) => {
        if !disableSaveCards {
          let handleSavedPaymentMethodsLoaded = (event: Types.event) => {
            let json = event.data->Identity.anyTypeToJson
            let dict = json->getDictFromJson
            let isSavedPaymentMethodsData = dict->getString("data", "") === "saved_payment_methods"
            if isSavedPaymentMethodsData {
              resolve()
              let json = dict->getJsonFromDict("response", JSON.Encode.null)
              let msg = [("savedPaymentMethods", json)]->Dict.fromArray
              mountedIframeRef->Window.iframePostMessage(msg)
            }
          }
          addSmartEventListener(
            "message",
            handleSavedPaymentMethodsLoaded,
            `onSavedPaymentMethodsLoaded-${componentType}`,
          )
        } else {
          resolve()
        }
        let msg =
          [("sendSavedPaymentMethodsResponse", !disableSaveCards->JSON.Encode.bool)]->Dict.fromArray
        preMountLoaderIframeDiv->Window.iframePostMessage(msg)
      })
    }

    let fetchPaymentManagementList = (mountedIframeRef, disableSaveCards, componentType) => {
      Promise.make((resolve, _) => {
        if !disableSaveCards {
          let handleSavedPaymentMethodsLoaded = (event: Types.event) => {
            let json = event.data->Identity.anyTypeToJson
            let dict = json->getDictFromJson
            let isPaymentManagementData = dict->getString("data", "") === "payment_management_list"
            if isPaymentManagementData {
              resolve()
              let json = dict->getJsonFromDict("response", JSON.Encode.null)
              let msg = [("paymentManagementMethods", json)]->Dict.fromArray
              mountedIframeRef->Window.iframePostMessage(msg)
            }
          }
          addSmartEventListener(
            "message",
            handleSavedPaymentMethodsLoaded,
            `onAllPaymentMethodsLoaded-${componentType}`,
          )
        } else {
          resolve()
        }
        let msg =
          [
            ("sendPaymentManagementListResponse", !disableSaveCards->JSON.Encode.bool),
          ]->Dict.fromArray
        preMountLoaderIframeDiv->Window.iframePostMessage(msg)
      })
    }

    let setElementIframeRef = ref => {
      iframeRef->Array.push(ref)->ignore
      setIframeRef(ref)
    }
    let getElement = componentName => {
      savedPaymentElement->Dict.get(componentName)
    }
    let update = newOptions => {
      let newOptionsDict = newOptions->getDictFromJson
      switch newOptionsDict->Dict.get("locale") {
      | Some(val) => localOptions->Dict.set("locale", val)
      | None => ()
      }
      switch newOptionsDict->Dict.get("appearance") {
      | Some(val) => localOptions->Dict.set("appearance", val)
      | None => ()
      }

      iframeRef->Array.forEach(iframe => {
        let message =
          [
            ("ElementsUpdate", true->JSON.Encode.bool),
            ("options", newOptionsDict->JSON.Encode.object),
          ]->Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })
    }
    let fetchUpdates = () => {
      Promise.make((resolve, _) => {
        setTimeout(() => resolve(Dict.make()->JSON.Encode.object), 1000)->ignore
      })
    }

    let create = (componentType, newOptions) => {
      componentType == "" ? manageErrorWarning(REQUIRED_PARAMETER, ~dynamicStr="type", ~logger) : ()
      let otherElements = componentType->isOtherElements
      switch componentType {
      | "paymentMethodsManagement" => ()
      | str => Console.warn(`Unknown Key: ${str} type in create`)
      }

      let mountPostMessage = (
        mountedIframeRef,
        selectorString,
        _sdkHandleOneClickConfirmPayment,
      ) => {
        open Promise

        let widgetOptions =
          [
            ("ephemeralKey", ephemeralKey->JSON.Encode.string),
            ("pmClientSecret", pmClientSecret->JSON.Encode.string),
            ("pmSessionId", pmSessionId->JSON.Encode.string),
            ("appearance", appearance),
            ("locale", locale),
            ("loader", loader),
            ("fonts", fonts),
          ]->getJsonFromArrayOfJson
        let message =
          [
            (
              "paymentElementCreate",
              componentType->getIsComponentTypeForPaymentElementCreate->JSON.Encode.bool,
            ),
            ("otherElements", otherElements->JSON.Encode.bool),
            ("options", newOptions),
            ("componentType", componentType->JSON.Encode.string),
            ("paymentOptions", widgetOptions),
            ("iframeId", selectorString->JSON.Encode.string),
            ("publishableKey", publishableKey->JSON.Encode.string),
            ("profileId", profileId->JSON.Encode.string),
            ("endpoint", endpoint->JSON.Encode.string),
            ("sdkSessionId", sdkSessionId->JSON.Encode.string),
            ("customPodUri", customPodUri->JSON.Encode.string),
            ("parentURL", "*"->JSON.Encode.string),
            ("analyticsMetadata", analyticsMetadata),
            ("launchTime", launchTime->JSON.Encode.float),
            ("customBackendUrl", customBackendUrl->JSON.Encode.string),
          ]->Dict.fromArray

        preMountLoaderMountedPromise
        ->then(async _ => {
          let disableSavedPaymentMethods =
            newOptions
            ->getDictFromJson
            ->getBool("displaySavedPaymentMethods", true)
          if (
            disableSavedPaymentMethods &&
            !(expressCheckoutComponents->Array.includes(componentType))
          ) {
            try {
              switch GlobalVars.sdkVersion {
              | V1 => await fetchSavedPaymentMethods(mountedIframeRef, false, componentType)
              | V2 => await fetchPaymentManagementList(mountedIframeRef, false, componentType)
              }
              let msg = [("cleanUpPreMountLoaderIframe", true->JSON.Encode.bool)]->Dict.fromArray
              preMountLoaderIframeDiv->Window.iframePostMessage(msg)
            } catch {
            | _ => ()
            }
          }
        })
        ->catch(_ => resolve())
        ->ignore
        mountedIframeRef->Window.iframePostMessage(message)
      }

      let paymentElement = LoaderPaymentElement.make(
        componentType,
        newOptions,
        setElementIframeRef,
        iframeRef,
        mountPostMessage,
        ~isPaymentManagementElement=true,
        ~redirectionFlags=RecoilAtoms.defaultRedirectionFlags,
        ~logger=Some(logger),
      )
      savedPaymentElement->Dict.set(componentType, paymentElement)
      paymentElement
    }
    {
      getElement,
      update,
      fetchUpdates,
      create,
    }
  } catch {
  | e => {
      Sentry.captureException(e)
      defaultElement
    }
  }
}
