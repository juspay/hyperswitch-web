open Types
open ErrorUtils
open Utils
open EventListenerManager

type fullscreenSource = {source: Dom.element}

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
) => {
  let hyperComponentName = PaymentMethodsManagementElements
  try {
    let iframeRef = []
    let sdkOrigin = URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin
    let fullscreenSources = []
    let onFullscreenCreated = (iframe, _metadata) => {
      fullscreenSources->Array.push({source: iframe->Window.contentWindow})->ignore
    }
    let isTrustedPaymentMessage = (event: Types.event) =>
      event.origin === sdkOrigin &&
        (iframeRef->Array.some(iframe =>
          iframe
          ->Nullable.toOption
          ->Option.map(element =>
            element->Window.Element.isConnected && event.source === element->Window.contentWindow
          )
          ->Option.getOr(false)
        ) || fullscreenSources->Array.some(entry => event.source === entry.source))
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

    let ownerId = generateRandomString(16)
    let localSelectorString = `hyper-management-preMountLoader-${ownerId}`
    let mountPreMountLoaderIframe = () => {
      if (
        Window.querySelector(
          `#orca-payment-element-iframeRef-${localSelectorString}`,
        )->Nullable.isNullable
      ) {
        let componentType = "preMountLoader"
        UpdateIntentHelpersNew.mountPreMountLoaderFrame(
          ~selectorString=localSelectorString,
          ~queryParams=[
            ("fullscreenType", componentType),
            ("publishableKey", publishableKey),
            ("pmSessionId", pmSessionId),
            ("sessionId", sdkSessionId),
            ("endpoint", endpoint),
            ("hyperComponentName", hyperComponentName->getStrFromHyperComponentName),
            ("sdkAuthorization", sdkAuthorization),
          ],
        )->ignore
      }

      let elem = Window.querySelector(`#orca-payment-element-iframeRef-${localSelectorString}`)
      elem
    }

    let locale = localOptions->getJsonStringFromDict("locale", "auto")
    let loader = localOptions->getJsonStringFromDict("loader", "")

    let preMountLoaderIframeDiv = mountPreMountLoaderIframe()

    let isFromPreMountLoader = (event: Types.event) =>
      preMountLoaderIframeDiv
      ->Nullable.toOption
      ->Option.map(iframe =>
        PaymentMessageSecurity.isExpectedSender(
          ~source=iframe->Window.contentWindow,
          ~origin=sdkOrigin,
          ~eventSource=event.source,
          ~eventOrigin=event.origin,
        )
      )
      ->Option.getOr(false)

    let unMountPreMountLoaderIframe = () => {
      removeSmartEventListener("message", `onPreMountLoaderIframeCallback-${ownerId}`)
      removeSmartEventListener("message", `onPaymentManagementList-${ownerId}`)
      switch Window.querySelector(`#orca-element-${localSelectorString}`)->Nullable.toOption {
      | Some(wrapper) => wrapper->remove
      | None => ()
      }
    }

    let preMountLoaderMountedPromise = Promise.make((resolve, _reject) => {
      let preMountLoaderIframeCallback = (ev: Types.event) => {
        let json = ev.data->Identity.anyTypeToJson
        let dict = json->getDictFromJson
        if (
          isFromPreMountLoader(ev) &&
          dict->Dict.get("preMountLoaderIframeMountedCallback")->Option.isSome
        ) {
          resolve(true->JSON.Encode.bool)
        } else if (
          isFromPreMountLoader(ev) && dict->Dict.get("preMountLoaderIframeUnMount")->Option.isSome
        ) {
          unMountPreMountLoaderIframe()
          logger.setLogInfo(~value="", ~eventName=PRE_MOUNT_LOADER_CLEANUP)
        }
      }
      addSmartEventListener(
        "message",
        preMountLoaderIframeCallback,
        `onPreMountLoaderIframeCallback-${ownerId}`,
      )
    })

    // Cache the response for this collection, not the destination widget.
    // Each mount forwards the shared result to its own still-connected frame.
    let paymentManagementListPromise = ref((None: option<promise<JSON.t>>))
    let fetchPaymentManagementList = () => {
      switch paymentManagementListPromise.contents {
      | Some(promise) => promise
      | None =>
        let promise = preMountLoaderMountedPromise->Promise.then(_ =>
          Promise.make((resolve, _) => {
            let listenerName = `onPaymentManagementList-${ownerId}`
            addSmartEventListener("message", (event: Types.event) => {
              let dict = event.data->Identity.anyTypeToJson->getDictFromJson
              if isFromPreMountLoader(event) && dict->getString("data", "") === "payment_management_list" {
                removeSmartEventListener("message", listenerName)
                resolve(dict->getJsonFromDict("response", JSON.Encode.null))
                preMountLoaderIframeDiv->Window.iframePostMessage(
                  [("cleanUpPreMountLoaderIframe", true->JSON.Encode.bool)]->Dict.fromArray,
                  ~targetOrigin=sdkOrigin,
                )
              }
            }, listenerName)
            preMountLoaderIframeDiv->Window.iframePostMessage(
              [("sendPaymentManagementListResponse", true->JSON.Encode.bool)]->Dict.fromArray,
              ~targetOrigin=sdkOrigin,
            )
          })
        )
        paymentManagementListPromise := Some(promise)
        promise
      }
    }

    let setElementIframeRef = ref => {
      iframeRef->Array.push(ref)->ignore
      setIframeRef(ref)
    }
    let getElement = componentName => {
      WidgetRegistry.getMountedElement(iframeRef, componentName)
      ->Option.orElse(savedPaymentElement->Dict.get(componentName))
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
        iframe->Window.iframePostMessage(message, ~targetOrigin=sdkOrigin)
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
      let otherElements = componentType->isOtherElements
      switch componentType {
      | "paymentMethodsManagement" => ()
      | str => Console.warn(`Unknown Key: ${str} type in create`)
      }

      let mountPostMessage = (
        mountedIframeRef,
        selectorString,
        _sdkHandleOneClickConfirmPayment,
        newOptions,
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

        if newOptions->getDictFromJson->getBool("displaySavedPaymentMethods", true) {
          fetchPaymentManagementList()
          ->then(json => {
            mountedIframeRef->Nullable.toOption->Option.forEach(frame => {
              if frame->Window.Element.isConnected {
                mountedIframeRef->Window.iframePostMessage(
                  [("paymentManagementMethods", json)]->Dict.fromArray,
                  ~targetOrigin=sdkOrigin,
                )
              }
            })
            resolve()
          })
          ->catch(_ => resolve())
          ->ignore
        }
        mountedIframeRef->Window.iframePostMessage(message, ~targetOrigin=sdkOrigin)
      }

      let paymentElement = LoaderPaymentElement.make(
        componentType,
        newOptions,
        setElementIframeRef,
        mountPostMessage,
        ~appearance,
        ~isPaymentManagementElement=true,
        ~ownerId,
        ~redirectionFlags=JotaiAtoms.defaultRedirectionFlags,
        ~logger=Some(logger),
        ~confirmPayment=_payload => Promise.resolve(Dict.make()->JSON.Encode.object),
        ~onFullscreenCreated,
      )
      savedPaymentElement->Dict.set(componentType, paymentElement)
      paymentElement
    }
    let elements = {
      getElement,
      update,
      fetchUpdates,
      create,
      updateIntent: _ => Promise.resolve(JSON.Encode.null),
      createCardForm: () => defaultCardForm,
    }
    WidgetRegistry.registerHandle(elements, () => iframeRef->Array.filterMap(Nullable.toOption))
    elements
  } catch {
  | e => {
      Sentry.captureException(e)
      defaultElement
    }
  }
}
