open Types
open ErrorUtils
open Utils
open EventListenerManager

let make = (
  options,
  setIframeRef,
  ~pmSessionId,
  ~sdkSessionId,
  ~publishableKey,
  ~sdkAuthorization,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~analyticsMetadata,
  ~customBackendUrl,
  ~tokenize: JSON.t => promise<JSON.t>,
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

    // Suffixed so this never collides with the regular Elements' own
    // preMountLoader iframe when both are mounted on the same page — each
    // type owns its own DOM id for this hidden bootstrap iframe.
    let localSelectorString = "hyper-preMountLoader-iframe-pmm"
    // Unique per call to `make`: this whole flow can run more than once for
    // the same localSelectorString (e.g. React.StrictMode double-invoking
    // the mounting effect in dev). addSmartEventListener replaces any
    // listener already registered under the same name, so without this a
    // stale invocation's (possibly slower under concurrent load) listener
    // registration could silently steal the current invocation's response.
    let invocationId = generateRandomString(8)
    let listenerKey = `${localSelectorString}-${invocationId}`
    let mountPreMountLoaderIframe = () => {
      if (
        Window.querySelector(
          `#orca-payment-element-iframeRef-${localSelectorString}`,
        )->Nullable.isNullable
      ) {
        let componentType = "preMountLoader"
        let iframeDivHtml = `<div id="orca-element-${localSelectorString}" style= "height: 0px; width: 0px; display: none;"  class="${componentType}">
          <div id="orca-fullscreen-iframeRef-${localSelectorString}"></div>
           <iframe
           id ="orca-payment-element-iframeRef-${localSelectorString}"
           name="orca-payment-element-iframeRef-${localSelectorString}"
          src="${ApiEndpoint.sdkDomainUrl}/index.html?fullscreenType=${componentType}&publishableKey=${publishableKey}&pmSessionId=${pmSessionId}&sessionId=${sdkSessionId}&endpoint=${endpoint}&hyperComponentName=${hyperComponentName->getStrFromHyperComponentName}&sdkAuthorization=${sdkAuthorization}"
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
      // Guards against cross-talk with the regular Elements flow's own
      // preMountLoader (UpdateIntentHelpersNew.res) — both post the exact
      // same message shape via the shared useMessageHandler code, and a
      // plain window "message" listener receives every message regardless
      // of sender, so without this the other flow's mount/unmount signal
      // would tear this iframe down (or vice versa).
      let isFromThisIframe = (ev: Types.event) =>
        switch preMountLoaderIframeDiv->Nullable.toOption {
        | Some(iframeEl) => iframeEl->Window.contentWindow === ev.source
        | None => false
        }
      let preMountLoaderIframeCallback = (ev: Types.event) => {
        if isFromThisIframe(ev) {
          let json = ev.data->Identity.anyTypeToJson
          let dict = json->getDictFromJson
          if dict->Dict.get("preMountLoaderIframeMountedCallback")->Option.isSome {
            resolve(true->JSON.Encode.bool)
          } else if dict->Dict.get("preMountLoaderIframeUnMount")->Option.isSome {
            unMountPreMountLoaderIframe()
          }
        }
      }
      addSmartEventListener(
        "message",
        preMountLoaderIframeCallback,
        "onPreMountLoaderIframeCallback-" ++ listenerKey,
      )
    })

    let fetchPaymentManagementList = (mountedIframeRef, disableSaveCards, componentType) => {
      // Fresh per call: create()/mount() for this componentType can run more
      // than once (e.g. React.StrictMode double-invoking the mount effect,
      // or the render-time + effect-time create() calls in
      // PaymentMethodsManagementElementWrapper.res both reaching this), and
      // addSmartEventListener replaces any listener already registered
      // under the same name.
      let fetchInvocationId = generateRandomString(8)
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
            `onAllPaymentMethodsLoaded-${componentType}-${fetchInvocationId}`,
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
      switch newOptionsDict->Dict.get("sdkAuthorization") {
      | Some(val) => localOptions->Dict.set("sdkAuthorization", val)
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

    let create = (componentTypeOrOptions: JSON.t, legacyOptions: Nullable.t<JSON.t>) => {
      let (componentType, newOptions) = parseComponentTypeAndOptions(
        ~componentTypeOrOptions,
        ~legacyOptions,
        ~defaultComponentType="paymentMethodsManagement",
      )
      componentType == "" ? manageErrorWarning(REQUIRED_PARAMETER, ~dynamicStr="type", ~logger) : ()

      if componentType !== "paymentMethodsManagement" {
        Console.warn(
          `Unknown Key: ${componentType} type in create — paymentMethodsManagementElements().create() only supports "paymentMethodsManagement"; nothing will be mounted.`,
        )
        defaultPaymentElement
      } else {
        let otherElements = componentType->isOtherElements

        let mountPostMessage = (
          mountedIframeRef,
          selectorString,
          _sdkHandleOneClickConfirmPayment,
        ) => {
          open Promise

          let widgetAppearance = CardFormGroupShared.resolveFieldAppearance(
            ~fieldOptionsDict=newOptions->getDictFromJson,
            ~groupAppearance=appearance,
          )

          let widgetOptions =
            [
              ("pmSessionId", pmSessionId->JSON.Encode.string),
              ("sdkAuthorization", sdkAuthorization->JSON.Encode.string),
              ("appearance", widgetAppearance),
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
                await fetchPaymentManagementList(mountedIframeRef, false, componentType)
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
          ~appearance,
          ~isPaymentManagementElement=true,
          ~redirectionFlags=JotaiAtoms.defaultRedirectionFlags,
          ~logger=Some(logger),
          ~confirmPayment=_payload => Promise.resolve(Dict.make()->JSON.Encode.object),
          ~tokenize,
        )
        savedPaymentElement->Dict.set(componentType, paymentElement)
        paymentElement
      }
    }
    {
      getElement,
      update,
      fetchUpdates,
      create,
      updateIntent: _ => Promise.resolve(JSON.Encode.null),
      createCardForm: () => defaultCardForm,
    }
  } catch {
  | e => {
      Sentry.captureException(e)
      defaultElement
    }
  }
}
