open Types
open ErrorUtils
open LoggerUtils
open Utils
open EventListenerManager
open Identity

type fullscreenMessageSource = {
  iframe: Dom.element,
  source: Dom.element,
  redirectOrigin: option<string>,
}

type paymentContext = {
  mutable identity: string,
  clientSecret: ref<string>,
  sdkAuthorization: ref<string>,
  frames: ref<array<Nullable.t<Dom.element>>>,
  sessionTokens: ref<promise<JSON.t>>,
  sdkConfigs: ref<promise<JSON.t>>,
  clientList: ref<promise<JSON.t>>,
}

let checkAndAppend = (selector, child) => {
  if Nullable.toOption(CommonHooks.querySelector(selector)) == None {
    CommonHooks.appendChild(child)
  }
}

if GlobalVars.sentryDSN->typeof !== #undefined {
  Sentry.initiateSentryJs(~dsn=GlobalVars.sentryDSN)
}

let preloadFile = (~type_, ~href=``) => {
  let link = CommonHooks.createElement("link")
  link.href = href
  link.\"as" = type_
  link.rel = "prefetch"
  link.crossorigin = "anonymous"
  checkAndAppend(`link[href="${href}"]`, link)
}

let preloader = () => {
  preloadFile(~type_="script", ~href=`${ApiEndpoint.sdkDomainUrl}/app.js`)
  preloadFile(~type_="style", ~href=`${ApiEndpoint.sdkDomainUrl}/app.css`)
  preloadFile(~type_="image", ~href=`${ApiEndpoint.sdkDomainUrl}/icons/orca.svg`)
  preloadFile(
    ~type_="style",
    ~href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;600;700;800&display=swap",
  )
  preloadFile(
    ~type_="style",
    ~href="https://fonts.googleapis.com/css2?family=Quicksand:wght@400;500;600;700&family=Qwitcher+Grypen:wght@400;700&display=swap",
  )
  preloadFile(
    ~type_="script",
    ~href="https://js.braintreegateway.com/web/3.92.1/js/paypal-checkout.min.js",
  )
  preloadFile(~type_="script", ~href="https://js.braintreegateway.com/web/3.92.1/js/client.min.js")
}

let handleHyperApplePayMounted = (event: Types.event) => {
  open ApplePayTypes
  let json = event.data->anyTypeToJson
  let dict = json->getDictFromJson
  let applePaySessionRef = ref(Nullable.null)

  let componentName = dict->getString("componentName", "payment")
  let walletRoutingId = dict->getString("walletRoutingId", "")

  if dict->Dict.get("hyperApplePayCanMakePayments")->Option.isSome {
    let msg =
      [
        ("applePayCanMakePayments", true->JSON.Encode.bool),
        ("componentName", componentName->JSON.Encode.string),
        ("walletRoutingId", walletRoutingId->JSON.Encode.string),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object
    event.source->Utils.postMessage(msg, event.origin)
  } else if dict->Dict.get("hyperApplePayButtonClicked")->Option.isSome {
    let paymentRequest = dict->Dict.get("paymentRequest")->Option.getOr(JSON.Encode.null)
    let applePayPresent = dict->Dict.get("applePayPresent")
    let clientSecret = dict->getString("clientSecret", "")
    let sdkAuthorization = dict->getString("sdkAuthorization", "")
    let publishableKey = dict->getString("publishableKey", "")
    let isTaxCalculationEnabled = dict->getBool("isTaxCalculationEnabled", false)
    let sdkSessionId = dict->getString("sdkSessionId", "")
    let analyticsMetadata = dict->getJsonFromDict("analyticsMetadata", JSON.Encode.null)
    let isSavedMethodsFlow = dict->getBool("isSavedMethodsFlow", false)

    let logger = HyperLogger.make(
      ~sessionId=sdkSessionId,
      ~source=Loader,
      ~merchantId=publishableKey,
      ~metadata=analyticsMetadata,
      ~clientSecret,
      ~sdkAuthorization,
    )

    let callBackFunc = payment => {
      let msg =
        [
          ("applePayPaymentToken", payment.token),
          ("applePayBillingContact", payment.billingContact),
          ("applePayShippingContact", payment.shippingContact),
          ("componentName", componentName->JSON.Encode.string),
          ("walletRoutingId", walletRoutingId->JSON.Encode.string),
          ("isSavedMethodsFlow", isSavedMethodsFlow->JSON.Encode.bool),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      event.source->Utils.postMessage(msg, event.origin)
    }

    let postShowApplePayButton = (~isApplePaySheetCancelled) => {
      let msg =
        [
          ("showApplePayButton", true->JSON.Encode.bool),
          ("componentName", componentName->JSON.Encode.string),
          ("walletRoutingId", walletRoutingId->JSON.Encode.string),
          ("isApplePaySheetCancelled", isApplePaySheetCancelled->JSON.Encode.bool),
          ("isSavedMethodsFlow", isSavedMethodsFlow->JSON.Encode.bool),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      event.source->Utils.postMessage(msg, event.origin)
    }

    let resolvePromise = _ => postShowApplePayButton(~isApplePaySheetCancelled=false)

    ApplePayHelpers.startApplePaySession(
      ~walletRoutingId,
      ~sdkHandleIsThere=LoaderPaymentElement.hasPaymentButtonHandlerForEvent(event),
      ~paymentRequest,
      ~applePaySessionRef,
      ~applePayPresent,
      ~logger,
      ~callBackFunc,
      ~clientSecret,
      ~publishableKey,
      ~isTaxCalculationEnabled,
      ~resolvePromise,
      ~sdkAuthorization=Some(sdkAuthorization),
      ~onCancel=() => postShowApplePayButton(~isApplePaySheetCancelled=true),
    )
  }
}

addSmartEventListener(
  "message",
  ev => {
    // Same-origin merchant intermediaries share the top window's security
    // principal. Foreign embedded frames must not drive its Apple Pay session.
    let fromMerchantChild = PaymentMessageSecurity.isSameOriginDescendant(
      ~window,
      ~origin=Window.Location.origin,
      ~eventSource=ev.source,
      ~eventOrigin=ev.origin,
    )
    if (
      fromMerchantChild ||
      PaymentMessageSecurity.isExpectedSender(
        ~source=window,
        ~origin=Window.Location.origin,
        ~eventSource=ev.source,
        ~eventOrigin=ev.origin,
      )
    ) {
      handleHyperApplePayMounted(ev)
    }
  },
  "onHyperApplePayMount",
)

let logger = HyperLogger.make(~sessionId=getSessionId(), ~source=Loader)

logger.setLogInfo(
  ~eventName=HYPERLOADER_SCRIPT_LOADED,
  ~value=[("origin", Window.Location.origin->JSON.Encode.string)]
  ->Dict.fromArray
  ->JSON.Encode.object
  ->JSON.stringify,
)

let make = (keys, options: option<JSON.t>, analyticsInfo: option<JSON.t>) => {
  try {
    let publishableKey = switch keys->JSON.Classify.classify {
    | String(val) => val
    | Object(json) => json->getString("publishableKey", "")
    | _ => ""
    }
    let profileId = switch keys->JSON.Classify.classify {
    | String(_) => ""
    | Object(json) => json->getString("profileId", "")
    | _ => ""
    }
    let isPreloadEnabled =
      options
      ->getOptionsDict
      ->getBool("isPreloadEnabled", true)
    let isTestMode =
      options
      ->getOptionsDict
      ->getBool("isTestMode", false)

    // INFO: kept for backwards compatibility - remove once removed from hyperswitch backend and deployed
    let shouldUseTopRedirection =
      options
      ->getOptionsDict
      ->getBool("shouldUseTopRedirection", false)
    let overridenDefaultRedirectionFlags: JotaiAtomTypes.redirectionFlags = {
      shouldUseTopRedirection,
      shouldRemoveBeforeUnloadEvents: false,
    }
    let redirectionFlags =
      options
      ->getOptionsDict
      ->getJsonObjectFromDict("redirectionFlags")
      ->JotaiAtomTypes.decodeRedirectionFlags(overridenDefaultRedirectionFlags)

    /*
     * Forces re-initialization of HyperLoader.
     * If HyperLoader is already loaded and needs to reload with an updated publishable key,
     * this flag ensures the script is remounted and re-executed.
     */

    let isForceInit =
      options
      ->getOptionsDict
      ->getBool("isForceInit", false)

    let analyticsMetadata =
      options
      ->getOptionsDict
      ->getDictFromObj("analytics")
      ->getJsonObjectFromDict("metadata")
    if isPreloadEnabled {
      preloader()
    }
    let analyticsInfoDict =
      analyticsInfo->Option.flatMap(JSON.Decode.object)->Option.getOr(Dict.make())
    let sessionID = analyticsInfoDict->getString("sessionID", getSessionId())
    let sdkTimestamp = analyticsInfoDict->getString("timeStamp", Date.now()->Float.toString)
    logger.setSessionId(sessionID)
    logger.setMerchantId(publishableKey)
    logger.setMetadata(analyticsMetadata)

    switch options {
    | Some(userOptions) =>
      let customBackendUrl =
        userOptions
        ->JSON.Decode.object
        ->Option.flatMap(x => x->Dict.get("customBackendUrl"))
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOr("")
      customBackendUrl === "" ? () : ApiEndpoint.setApiEndPoint(customBackendUrl)
    | None => ()
    }

    {
      () => {
        logger.setLogInfo(
          ~value=Window.hrefWithoutSearch,
          ~eventName=APP_INITIATED,
          ~timestamp=sdkTimestamp,
        )
      }
    }->Sentry.sentryLogger
    let isSecure = Window.isSecureContext
    if !isSecure {
      manageErrorWarning(HTTP_NOT_ALLOWED, ~dynamicStr=Window.hrefWithoutSearch, ~logger)
      Exn.raiseError("Insecure domain: " ++ Window.hrefWithoutSearch)
    }
    switch Window.getHyper->Nullable.toOption {
    | Some(hyperMethod) if !isForceInit => {
        logger.setLogInfo(
          ~value="orca-sdk initiated",
          ~eventName=APP_REINITIATED,
          ~timestamp=sdkTimestamp,
        )
        hyperMethod
      }
    | Some(_)
    | None =>
      let loaderTimestamp = Date.now()->Float.toString

      {
        () => {
          logger.setLogInfo(
            ~value="loadHyper has been called",
            ~eventName=LOADER_CALLED,
            ~timestamp=loaderTimestamp,
          )
          if (
            publishableKey == "" ||
              !(
                ["pk_dev_", "pk_snd_", "pk_prd_"]->Array.some(prefix =>
                  publishableKey->String.startsWith(prefix)
                )
              )
          ) {
            manageErrorWarning(INVALID_PK, ~logger)
          }

          if (
            Window.querySelectorAll(`script[src="https://applepay.cdn-apple.com/jsapi/v1/apple-pay-sdk.js"]`)->Array.length === 0
          ) {
            let scriptURL = "https://applepay.cdn-apple.com/jsapi/v1/apple-pay-sdk.js"
            let script = Window.createElement("script")
            script->Window.elementSrc(scriptURL)
            script->Window.elementOnerror(err => {
              Console.error2("ERROR DURING LOADING APPLE PAY", err)
            })
            Window.body->Window.appendChild(script)
          }
        }
      }->Sentry.sentryLogger

      if (
        Window.querySelectorAll(`script[src="https://pay.google.com/gp/p/js/pay.js"]`)->Array.length === 0
      ) {
        let googlePayScriptURL = "https://pay.google.com/gp/p/js/pay.js"
        let googlePayScript = Window.createElement("script")
        googlePayScript->Window.elementSrc(googlePayScriptURL)
        googlePayScript->Window.elementOnerror(_ => {
          logger.setLogError(
            ~value="ERROR DURING LOADING GOOGLE PAY SCRIPT",
            ~eventName=GOOGLE_PAY_SCRIPT,
            // ~internalMetadata=err->formatException->JSON.stringify,
            ~paymentMethod="GOOGLE_PAY",
          )
        })
        Window.body->Window.appendChild(googlePayScript)
        logger.setLogInfo(~value="GooglePay Script Loaded", ~eventName=GOOGLE_PAY_SCRIPT)
      }

      if (
        Window.querySelectorAll(`script[src="https://img.mpay.samsung.com/gsmpi/sdk/samsungpay_web_sdk.js"]`)->Array.length === 0
      ) {
        let samsungPayScriptUrl = "https://img.mpay.samsung.com/gsmpi/sdk/samsungpay_web_sdk.js"
        let samsungPayScript = Window.createElement("script")
        samsungPayScript->Window.elementSrc(samsungPayScriptUrl)
        samsungPayScript->Window.elementOnerror(_ => {
          logger.setLogError(
            ~value="ERROR DURING LOADING SAMSUNG PAY SCRIPT",
            ~eventName=SAMSUNG_PAY_SCRIPT,
            // ~internalMetadata=err->formatException->JSON.stringify,
            ~paymentMethod="SAMSUNG_PAY",
          )
        })
        Window.body->Window.appendChild(samsungPayScript)
        samsungPayScript->Window.elementOnload(_ =>
          logger.setLogInfo(~value="SamsungPay Script Loaded", ~eventName=SAMSUNG_PAY_SCRIPT)
        )
      }

      let iframeRef = ref([])
      let clientSecret = ref("")
      let sdkAuthorization = ref("")
      let pmSessionId = ref("")
      let setIframeRef = ref => {
        iframeRef.contents->Array.push(ref)->ignore
      }
      let sdkOrigin = URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin
      let fullscreenSources = ref([])
      let onFullscreenCreated = (iframe, metadata) => {
        let redirectOrigin =
          metadata
          ->getDictFromJson
          ->getDictFromDict("threeDSData")
          ->getString("three_ds_authorize_url", "")
          ->PaymentMessageSecurity.originOf
        fullscreenSources.contents
        ->Array.push({
          iframe,
          // Keep the WindowProxy for terminal messages queued just before the overlay closes.
          source: iframe->Window.contentWindow,
          redirectOrigin,
        })
        ->ignore
      }
      let submitResponseHandlers: WeakMap.t<Dom.element, JSON.t => unit> = WeakMap.make()
      let isFromPaymentIframe = (event: Types.event) =>
        iframeRef.contents->Array.some(iframeRef =>
          iframeRef
          ->Nullable.toOption
          ->Option.map(iframe =>
            iframe->Window.Element.isConnected &&
              CardFormGroupShared.isFromIframe(~ev=event, ~iframe=Some(iframe), ~origin=sdkOrigin)
          )
          ->Option.getOr(false)
        )

      let isTrustedPaymentMessage = (event: Types.event) =>
        isFromPaymentIframe(event) ||
        (event.origin === sdkOrigin &&
          fullscreenSources.contents->Array.some(entry => entry.source === event.source))
      let isTrustedRedirectMessage = (event: Types.event) =>
        isTrustedPaymentMessage(event) ||
        // A frictionless 3DS form navigates this overlay to its configured authorize URL.
        fullscreenSources.contents->Array.some(entry =>
          entry.source === event.source && entry.redirectOrigin === Some(event.origin)
        )

      // Companion Elements and PaymentSession share state only for the same payment.
      let isUpdateIntentInProgress = ref(false)
      let emptyJsonPromise = Promise.resolve(JSON.Encode.null)
      let paymentContexts: array<paymentContext> = []
      let getPaymentContextIdentity = (clientSecretId, sdkAuthorizationId) => {
        let paymentId = Utils.getPaymentIdOrExtractFromSdkAuth(
          ~clientSecret=clientSecretId,
          ~sdkAuthorization=Some(sdkAuthorizationId)->getNonEmptyOption,
        )
        if paymentId !== "" {
          paymentId
        } else if sdkAuthorizationId !== "" {
          try {
            let data = sdkAuthorizationId->Utils.getSdkAuthorizationData
            data.pmSessionId->Option.getOr(sdkAuthorizationId)
          } catch { | _ => sdkAuthorizationId }
        } else { "" }
      }
      let synchronizePaymentContext = context => {
        let identity = getPaymentContextIdentity(
          context.clientSecret.contents,
          context.sdkAuthorization.contents,
        )
        // A companion may have been created for the new intent while prefetch
        // was pending. Keep its captured refs, and reconcile them at commit.
        let related = paymentContexts->Array.filter(candidate =>
          candidate === context ||
          (context.identity !== "" && candidate.identity === context.identity) ||
          (identity !== "" && candidate.identity === identity)
        )
        let frames = []
        related->Array.forEach(candidate =>
          candidate.frames.contents
          ->UpdateIntentHelpersNew.connectedFrames
          ->Array.forEach(frame => {
            if !(frames->Array.includes(frame)) {
              frames->Array.push(frame)->ignore
            }
          })
        )
        related->Array.forEach(candidate => {
          candidate.identity = identity
          candidate.clientSecret := context.clientSecret.contents
          candidate.sdkAuthorization := context.sdkAuthorization.contents
          candidate.sessionTokens := context.sessionTokens.contents
          candidate.sdkConfigs := context.sdkConfigs.contents
          candidate.clientList := context.clientList.contents
          // Share the array too, so mounts made through either collection remain visible.
          candidate.frames := frames
        })
      }
      let getPaymentContext = (clientSecretId, sdkAuthorizationId) => {
        let identity = getPaymentContextIdentity(clientSecretId, sdkAuthorizationId)
        switch paymentContexts->Array.find(context => identity !== "" && context.identity === identity) {
        | Some(context) =>
          if clientSecretId !== "" { context.clientSecret := clientSecretId }
          if sdkAuthorizationId !== "" { context.sdkAuthorization := sdkAuthorizationId }
          synchronizePaymentContext(context)
          context
        | None =>
          let context = {
            identity,
            clientSecret: ref(clientSecretId),
            sdkAuthorization: ref(sdkAuthorizationId),
            frames: ref([]),
            sessionTokens: ref(emptyJsonPromise),
            sdkConfigs: ref(emptyJsonPromise),
            clientList: ref(emptyJsonPromise),
          }
          paymentContexts->Array.push(context)->ignore
          context
        }
      }
      // TODO(sdk-configs): profileId is available here at init time for consumers who provide
      // it at Hyper.init stage. sdk-configs could be prefetched early (before elements() is
      // called) for a latency optimisation. Currently deferred to PreMountLoader for consistency.

      let retrievePaymentIntentFn = async clientSecretOrSdkAuth => {
        // Try to decode as base64 — if decodable, it's an SDK authorization token.
        let (actualClientSecret, sdkAuthorizationValue) = try {
          clientSecretOrSdkAuth->Utils.getSdkAuthorizationData->ignore
          // Successfully decoded — treat as SDK auth; clientSecret is not embedded
          ((None: option<string>), Some(clientSecretOrSdkAuth))
        } catch {
        | _ => (Some(clientSecretOrSdkAuth), None)
        }

        let uri = APIUtils.generateApiUrlV1(
          ~apiCallType=RetrievePaymentIntent,
          ~params={
            clientSecret: actualClientSecret,
            publishableKey: Some(publishableKey),
            customBackendBaseUrl: None,
            forceSync: None,
            pollId: None,
            payoutId: None,
            sdkAuthorization: sdkAuthorizationValue,
          },
        )

        let onSuccess = data => [("paymentIntent", data)]->getJsonFromArrayOfJson

        let onFailure = _ => JSON.Encode.null

        await fetchApiWithLogging(
          uri,
          ~eventName=RETRIEVE_CALL,
          ~logger,
          ~method=#GET,
          ~customPodUri=None,
          ~publishableKey=Some(publishableKey),
          ~onSuccess,
          ~onFailure,
          ~sdkAuthorization=sdkAuthorizationValue,
        )
      }

      // Overlays still on the page may belong to an in-flight confirmation.
      let pruneRemovedOverlays = () =>
        fullscreenSources :=
          fullscreenSources.contents->Array.filter(entry =>
            entry.iframe->Window.Element.isConnected
          )

      let confirmPaymentWrapper = (
        payload,
        isOneClick,
        result,
        ~isSdkButton=false,
        ~useElementTarget=true,
      ) => {
        pruneRemovedOverlays()
        let confirmTimestamp = Date.now()
        let payloadDict = payload->getDictFromJson
        let requestedHandle = switch payloadDict->Dict.get("element") {
        | Some(handle) => Some(handle)
        | None => payloadDict->Dict.get("elements")
        }
        let ownedFrames =
          iframeRef.contents
          ->Array.filterMap(Nullable.toOption)
          ->Array.filter(Window.Element.isConnected)
        // Public hyper.confirmPayment historically ignored element references.
        // Keep targeting private to widget confirmation and the scoped APIs.
        let hasAmbiguousLegacyReference = !useElementTarget && ownedFrames->Array.length > 1 && (
          requestedHandle->Option.isSome ||
          payloadDict->Dict.get("elementId")->Option.isSome ||
          payloadDict->Dict.get("paymentElementId")->Option.isSome
        )
        let candidates = if useElementTarget {
          switch requestedHandle {
          | Some(handle) =>
            WidgetRegistry.getFrames(handle)
            ->Option.getOr([])
            ->Array.filter(frame => ownedFrames->Array.includes(frame))
          | None => ownedFrames
          }
        } else {
          ownedFrames
        }
        let paymentFrames =
          candidates->Array.filter(frame =>
            WidgetRegistry.frames
            ->WeakMap.get(frame)
            ->Option.mapOr(false, state => state.componentType === "payment")
          )
        let cardFrames = candidates->Array.filter(frame =>
          WidgetRegistry.frames
          ->WeakMap.get(frame)
          ->Option.mapOr(false, state => Utils.isOtherElements(state.componentType))
        )
        // Wallet buttons initiate their own confirmation. A merchant card submit
        // must not wait on, lock, or broadcast to a neighboring wallet surface.
        let targets = if paymentFrames->Array.length > 0 {
          paymentFrames
        } else if !isOneClick && cardFrames->Array.length > 0 {
          cardFrames
        } else {
          candidates
        }
        let hasDuplicateType = targets->Array.some(frame => {
          let state = WidgetRegistry.frames->WeakMap.get(frame)
          targets
          ->Array.filter(other =>
            WidgetRegistry.frames
            ->WeakMap.get(other)
            ->Option.mapOr(
              false,
              otherState =>
                state->Option.mapOr(
                  false,
                  state => state.componentType === otherState.componentType,
                ),
            )
          )
          ->Array.length > 1
        })
        let states = targets->Array.filterMap(frame => WidgetRegistry.frames->WeakMap.get(frame))
        let activeFrames = targets->Array.map(Nullable.make)
        let activity = `onSubmit-${generateRandomString(16)}`
        let finish = () => {
          states->Array.forEach(state => {
            state.confirming = false
            state.onClose := (() => ())
          })
          targets->Array.forEach(frame => submitResponseHandlers->WeakMap.delete(frame)->ignore)
          removeSmartEventListener("message", activity)
        }
        let confirmParams =
          payload
          ->JSON.Decode.object
          ->Option.flatMap(x => x->Dict.get("confirmParams"))
          ->Option.getOr(Dict.make()->JSON.Encode.object)

        let redirect = payload->getDictFromJson->getString("redirect", "if_required")

        let url =
          confirmParams
          ->JSON.Decode.object
          ->Option.flatMap(x => x->Dict.get("return_url"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")

        let postSubmitMessage = message => {
          activeFrames->Array.forEach(ifR => {
            ifR->Window.iframePostMessage(message, ~targetOrigin=sdkOrigin)
          })
        }

        let confirmTrigger = switch (isSdkButton, isOneClick) {
        | (true, _) => HyperLoggerTypes.SdkButton
        | (_, true) => HyperLoggerTypes.OneClick
        | _ => HyperLoggerTypes.Merchant
        }

        LoggerUtils.logConfirmTriggered(~logger, ~source=confirmTrigger)

        if targets->Array.length === 0 {
          Promise.resolve(
            getFailedSubmitResponse(
              ~errorType="invalid_element",
              ~message="No mounted widget belongs to this confirmation target",
            ),
          )
        } else if hasDuplicateType || hasAmbiguousLegacyReference {
          Promise.resolve(
            getFailedSubmitResponse(
              ~errorType="ambiguous_element",
              ~message=useElementTarget
                ? "Multiple widgets are mounted. Pass the specific widget as element or call widget.confirmPayment()."
                : "Multiple widgets are mounted. Call widget.confirmPayment() on the widget to confirm.",
            ),
          )
        } else if states->Array.some(state => state.confirming) {
          Promise.resolve(
            getFailedSubmitResponse(
              ~errorType="confirmation_in_progress",
              ~message="This widget already has a confirmation in progress",
            ),
          )
        } else if isTestMode {
          let errorResponse = getFailedSubmitResponse(
            ~errorType="test_mode_bypass",
            ~message="Confirm Payment called in test mode - API call bypassed",
          )
          Promise.resolve(errorResponse)
        } else {
          states->Array.forEach(state => state.confirming = true)
          Promise.make((resolve1, _) => {
            let settled = ref(false)
            let resolveOnce = response => {
              if !settled.contents {
                settled := true
                finish()
                resolve1(response)
              }
            }
            let readyTimeout = setTimeout(
              () =>
                resolveOnce(
                  getFailedSubmitResponse(
                    ~errorType="element_not_ready",
                    ~message="The selected widget did not become ready",
                  ),
                ),
              30000,
            )
            states->Array.forEach(state => {
              state.onClose :=
                (
                  () => {
                    clearTimeout(readyTimeout)
                    resolveOnce(
                      getFailedSubmitResponse(
                        ~errorType="invalid_element",
                        ~message="The widget was unmounted during confirmation",
                      ),
                    )
                  }
                )
            })
            // Standalone wallet surfaces do not emit the form-ready event.
            let readyStates = states->Array.filter(state =>
              !(state.componentType->CardThemeType.getPaymentMode->Utils.checkIsWalletElement)
            )
            Promise.all(readyStates->Array.map(state => state.ready))
            ->Promise.then(timestamps => {
              clearTimeout(readyTimeout)
              let readyTimestamp = timestamps->Array.get(0)->Option.getOr(confirmTimestamp)
              if settled.contents {
                ()
              } else if targets->Array.some(frame => !(frame->Window.Element.isConnected)) {
                resolveOnce(
                  getFailedSubmitResponse(
                    ~errorType="invalid_element",
                    ~message="The widget was unmounted before confirmation",
                  ),
                )
              } else {
                let handleSubmitResponse = json => {
                  let dict = json->getDictFromJson
                  switch (settled.contents, dict->Dict.get("submitSuccessful")) {
                  | (false, Some(val)) =>
                    logApi(
                      ~apiLogType=Method,
                      ~optLogger=Some(logger),
                      ~result=val,
                      ~paymentMethod="confirmPayment",
                      ~eventName=CONFIRM_PAYMENT,
                    )
                    let data = dict->Dict.get("data")->Option.getOr(Dict.make()->JSON.Encode.object)
                    let returnUrl =
                      dict->Dict.get("url")->Option.flatMap(JSON.Decode.string)->Option.getOr(url)

                    if isOneClick {
                      activeFrames->Array.forEach(
                        ifR => {
                          // to unset one click button loader
                          ifR->Window.iframePostMessage(
                            [("oneClickDoSubmit", false->JSON.Encode.bool)]->Dict.fromArray,
                            ~targetOrigin=sdkOrigin,
                          )
                        },
                      )
                    }
                    postSubmitMessage(dict)

                    let submitSuccessfulValue = val->JSON.Decode.bool->Option.getOr(false)

                    if isSdkButton && submitSuccessfulValue {
                      Utils.replaceRootHref(returnUrl, redirectionFlags)
                    } else if submitSuccessfulValue && redirect === "always" {
                      Utils.replaceRootHref(returnUrl, redirectionFlags)
                    } else if !submitSuccessfulValue {
                      resolveOnce(json)
                    } else {
                      resolveOnce(data)
                    }
                  | _ => ()
                  }
                }
                targets->Array.forEach(
                  frame => submitResponseHandlers->WeakMap.set(frame, handleSubmitResponse)->ignore,
                )
                let handleMessage = (event: Types.event) => {
                  let fromTarget =
                    targets->Array.some(
                      frame =>
                        frame->Window.Element.isConnected &&
                        event.source === frame->Window.contentWindow &&
                        event.origin === sdkOrigin,
                    )
                  let fromOverlay =
                    fullscreenSources.contents->Array.some(
                      entry =>
                        entry.source === event.source &&
                        event.origin === sdkOrigin &&
                        WidgetRegistry.ownsOverlay(entry.iframe, targets),
                    )
                  if fromTarget || fromOverlay {
                    handleSubmitResponse(event.data->anyTypeToJson)
                  }
                }
                let message = isOneClick
                  ? [("oneClickDoSubmit", result->JSON.Encode.bool)]->Dict.fromArray
                  : [
                      ("doSubmit", true->JSON.Encode.bool),
                      (
                        "clientSecret",
                        states
                        ->Array.get(0)
                        ->Option.mapOr(clientSecret.contents, state => state.getClientSecret())
                        ->JSON.Encode.string,
                      ),
                      ("confirmTimestamp", confirmTimestamp->JSON.Encode.float),
                      ("readyTimestamp", readyTimestamp->JSON.Encode.float),
                      (
                        "confirmParams",
                        [
                          ("return_url", url->JSON.Encode.string),
                          ("publishableKey", publishableKey->JSON.Encode.string),
                          ("redirect", redirect->JSON.Encode.string),
                        ]->getJsonFromArrayOfJson,
                      ),
                    ]->Dict.fromArray
                addSmartEventListener("message", handleMessage, activity)
                postSubmitMessage(message)
              }
              Promise.resolve(JSON.Encode.null)
            })
            ->Promise.catch(_ => {
              clearTimeout(readyTimeout)
              resolveOnce(
                getFailedSubmitResponse(
                  ~errorType="confirmation_error",
                  ~message="Unable to confirm the selected widget",
                ),
              )
              Promise.resolve(JSON.Encode.null)
            })
            ->ignore
          })
        }
      }

      let confirmPayment = (payload, ~useElementTarget=true) => {
        if isUpdateIntentInProgress.contents {
          Promise.resolve(UpdateIntentHelpersNew.confirmBlockedResponse())
        } else {
          confirmPaymentWrapper(payload, false, true, ~useElementTarget)
        }
      }

      let confirmOneClickPayment = (payload, result: bool) => {
        confirmPaymentWrapper(payload, true, result)
      }

      let confirmPaymentViaSDKButton = payload => {
        confirmPaymentWrapper(payload, false, true, ~isSdkButton=true)
      }

      let handleSdkConfirm = (event: Types.event) => {
        if isFromPaymentIframe(event) {
          let json = event.data->anyTypeToJson
          let dict = json->getDictFromJson
          switch dict->Dict.get("handleSdkConfirm") {
          | Some(payload) =>
            let sender =
              iframeRef.contents
              ->Array.filterMap(Nullable.toOption)
              ->Array.find(frame => event.source === frame->Window.contentWindow)
            sender->Option.forEach(frame => {
              let target = Dict.make()->JSON.Encode.object
              WidgetRegistry.registerHandle(target, () => [frame])
              let dict = payload->getDictFromJson->Dict.copy
              dict->Dict.set("element", target)
              confirmPaymentViaSDKButton(dict->JSON.Encode.object)->ignore
            })
          | None => ()
          }
        }
      }

      addSmartEventListener("message", handleSdkConfirm, `handleSdkConfirm-${sessionID}`)

      if isTestMode {
        Console.warn(
          "The SDK is running in test mode. API calls are bypassed and wallet interactions are disabled.",
        )
        Console.warn(
          "This is a non-transactional simulation environment for UI configuration and testing purposes only.",
        )
      }

      let elements = elementsOptions => {
        open Promise
        let elementsOptionsDict = elementsOptions->JSON.Decode.object
        elementsOptionsDict
        ->Option.forEach(x => x->Dict.set("launchTime", Date.now()->JSON.Encode.float))
        ->ignore

        let sdkAuthorizationId = elementsOptionsDict->getStringFromDict("sdkAuthorization", "")

        let clientSecretId = elementsOptionsDict->Utils.getStringFromDict("clientSecret", "")

        let elementsOptions = elementsOptionsDict->Option.mapOr(elementsOptions, JSON.Encode.object)
        let preloadSDKWithParams =
          elementsOptions->getDictFromJson->getDictFromDict("preloadSDKWithParams")

        sdkAuthorization := sdkAuthorizationId
        clientSecret := clientSecretId
        let context = getPaymentContext(clientSecretId, sdkAuthorizationId)

        Promise.make((resolve, _) => {
          logger.setClientSecret(clientSecretId)
          logger.setSdkAuthorization(sdkAuthorizationId)
          resolve(JSON.Encode.null)
        })
        ->then(_ => {
          logger.setLogInfo(~value=Window.hrefWithoutSearch, ~eventName=ORCA_ELEMENTS_CALLED)
          resolve()
        })
        ->catch(_ => resolve())
        ->ignore

        Elements.make(
          elementsOptions,
          frame => {
            setIframeRef(frame)
            context.frames.contents->Array.push(frame)->ignore
          },
          ~sdkSessionId=sessionID,
          ~publishableKey,
          ~logger=Some(logger),
          ~analyticsMetadata,
          ~customBackendUrl=options
          ->Option.getOr(JSON.Encode.null)
          ->getDictFromJson
          ->getString("customBackendUrl", ""),
          ~redirectionFlags,
          ~isTestMode,
          ~preloadSDKWithParams,
          ~isUpdateIntentInProgress,
          ~clientSecretRef=context.clientSecret,
          ~sdkAuthorizationRef=context.sdkAuthorization,
          ~sessionTokensDataPromise=context.sessionTokens,
          ~sdkConfigsDataPromise=context.sdkConfigs,
          ~clientListDataPromise=context.clientList,
          ~paymentContextFrames=context.frames,
          ~onPaymentContextChange=() => synchronizePaymentContext(context),
          ~confirmPayment=payload => confirmPayment(payload),
          ~onSubmitResponse=(frame, json) =>
            frame
            ->Nullable.toOption
            ->Option.flatMap(frame => submitResponseHandlers->WeakMap.get(frame))
            ->Option.forEach(handler => handler(json)),
          ~isTrustedPaymentMessage,
          ~isTrustedRedirectMessage,
          ~onFullscreenCreated,
        )
      }

      let paymentMethodsManagementElements = pmManagementOptions => {
        open Promise
        let pmManagementOptionsDict = pmManagementOptions->JSON.Decode.object
        pmManagementOptionsDict
        ->Option.forEach(x => x->Dict.set("launchTime", Date.now()->JSON.Encode.float))
        ->ignore
        let sdkAuthorizationId = pmManagementOptionsDict->getStringFromDict("sdkAuthorization", "")
        let sdkAuthorizationData = sdkAuthorizationId->Utils.getSdkAuthorizationData

        sdkAuthorization := sdkAuthorizationId
        let pmSessionIdVal = sdkAuthorizationData.pmSessionId->Option.getOr("")
        let logger = HyperLogger.make(
          ~sessionId=sessionID,
          ~source=Loader,
          ~merchantId=publishableKey,
          ~metadata=analyticsMetadata,
          ~sdkAuthorization=sdkAuthorizationId,
        )
        logger.setPaymentId(pmSessionIdVal)

        let pmManagementOptions =
          pmManagementOptionsDict->Option.mapOr(pmManagementOptions, JSON.Encode.object)
        pmSessionId := pmSessionIdVal
        Promise.make((resolve, _) => {
          resolve(JSON.Encode.null)
        })
        ->then(_ => {
          logger.setLogInfo(
            ~value=Window.hrefWithoutSearch,
            ~eventName=PAYMENT_MANAGEMENT_ELEMENTS_CALLED,
          )
          resolve()
        })
        ->catch(_ => resolve())
        ->ignore

        PaymentMethodsManagementElements.make(
          pmManagementOptions,
          setIframeRef,
          ~sdkSessionId=sessionID,
          ~publishableKey,
          ~pmSessionId={pmSessionIdVal},
          ~sdkAuthorization=sdkAuthorizationId,
          ~logger=Some(logger),
          ~analyticsMetadata,
          ~customBackendUrl=options
          ->Option.getOr(JSON.Encode.null)
          ->getDictFromJson
          ->getString("customBackendUrl", ""),
        )
      }

      let confirmCardPaymentFn = (
        clientSecretId: string,
        data: option<JSON.t>,
        _options: option<JSON.t>,
      ) => {
        pruneRemovedOverlays()
        let decodedData = data->Option.flatMap(JSON.Decode.object)->Option.getOr(Dict.make())
        Promise.make((resolve, _) => {
          iframeRef.contents
          ->Array.map(iframe => {
            iframe->Window.iframePostMessage(
              [
                ("doSubmit", true->JSON.Encode.bool),
                ("clientSecret", clientSecretId->JSON.Encode.string),
                (
                  "confirmParams",
                  [("publishableKey", publishableKey->JSON.Encode.string)]->getJsonFromArrayOfJson,
                ),
              ]->Dict.fromArray,
              ~targetOrigin=sdkOrigin,
            )

            let handleSubmitResponse = json => {
              let dict = json->getDictFromJson
              switch dict->Dict.get("submitSuccessful") {
              | Some(val) =>
                logApi(
                  ~apiLogType=Method,
                  ~optLogger=Some(logger),
                  ~result=val,
                  ~paymentMethod="confirmCardPayment",
                  ~eventName=CONFIRM_CARD_PAYMENT,
                )
                let url = decodedData->getString("return_url", "/")
                if val->JSON.Decode.bool->Option.getOr(false) && url !== "/" {
                  Utils.replaceRootHref(url, redirectionFlags)
                } else {
                  resolve(json)
                }
              | None => resolve(json)
              }
            }
            iframe
            ->Nullable.toOption
            ->Option.forEach(
              frame => submitResponseHandlers->WeakMap.set(frame, handleSubmitResponse)->ignore,
            )
            let handleMessage = (event: Types.event) => {
              if isTrustedPaymentMessage(event) {
                handleSubmitResponse(event.data->anyTypeToJson)
              }
            }
            addSmartEventListener("message", handleMessage, "")
          })
          ->ignore
        })
      }

      let addAmountToDict = (dict, currency) => {
        if dict->Dict.get("amount")->Option.isNone {
          Console.error("Amount is not specified, please input an amount")
        }
        let amount = dict->Dict.get("amount")->Option.getOr(0.0->JSON.Encode.float)
        dict->Dict.set(
          "amount",
          [("currency", currency), ("value", amount)]->getJsonFromArrayOfJson,
        )
        Some(dict->JSON.Encode.object)
      }
      let paymentRequest = options => {
        let optionsDict = options->getDictFromJson
        let currency = optionsDict->getJsonStringFromDict("currency", "")
        let optionsTotal =
          optionsDict
          ->Dict.get("total")
          ->Option.flatMap(JSON.Decode.object)
          ->Option.flatMap(x => addAmountToDict(x, currency))
          ->Option.getOr(Dict.make()->JSON.Encode.object)
        let displayItems = optionsDict->getJsonArrayFromDict("displayItems", [])
        let requestPayerName = optionsDict->getJsonStringFromDict("requestPayerName", "")
        let requestPayerEmail = optionsDict->getJsonBoolValue("requestPayerEmail", false)
        let requestPayerPhone = optionsDict->getJsonBoolValue("requestPayerPhone", false)
        let requestShipping = optionsDict->getJsonBoolValue("requestShipping", false)

        let shippingOptions =
          optionsDict
          ->Dict.get("shippingOptions")
          ->Option.flatMap(JSON.Decode.object)
          ->Option.flatMap(x => addAmountToDict(x, currency))
          ->Option.getOr(Dict.make()->JSON.Encode.object)

        let applePayPaymentMethodData =
          [
            ("supportedMethods", "https://apple.com/apple-pay"->JSON.Encode.string),
            ("data", [("version", 12.00->JSON.Encode.float)]->getJsonFromArrayOfJson),
          ]->getJsonFromArrayOfJson
        let methodData = [applePayPaymentMethodData]->JSON.Encode.array
        let details =
          [
            ("id", publishableKey->JSON.Encode.string),
            ("displayItems", displayItems),
            ("total", optionsTotal),
            ("shippingOptions", shippingOptions),
          ]->getJsonFromArrayOfJson

        let optionsForPaymentRequest =
          [
            ("requestPayerName", requestPayerName),
            ("requestPayerEmail", requestPayerEmail),
            ("requestPayerPhone", requestPayerPhone),
            ("requestShipping", requestShipping),
            ("shippingType", "shipping"->JSON.Encode.string),
          ]->getJsonFromArrayOfJson
        Window.paymentRequest(methodData, details, optionsForPaymentRequest)
      }

      let initPaymentSession = paymentSessionOptions => {
        open Promise

        let paymentSessionOptionsDict = paymentSessionOptions->JSON.Decode.object

        sdkAuthorization := paymentSessionOptionsDict->getStringFromDict("sdkAuthorization", "")

        clientSecret := paymentSessionOptionsDict->Utils.getStringFromDict("clientSecret", "")
        let context = getPaymentContext(clientSecret.contents, sdkAuthorization.contents)

        Promise.make((resolve, _) => {
          logger.setClientSecret(clientSecret.contents)
          logger.setSdkAuthorization(sdkAuthorization.contents)
          resolve(JSON.Encode.null)
        })
        ->then(_ => {
          logger.setLogInfo(~value=Window.hrefWithoutSearch, ~eventName=PAYMENT_SESSION_INITIATED)
          resolve()
        })
        ->catch(_ => resolve())
        ->ignore

        PaymentSession.make(
          paymentSessionOptions,
          ~publishableKey,
          ~sdkSessionId=sessionID,
          ~logger=Some(logger),
          ~redirectionFlags,
          ~iframeRef=context.frames,
          ~isTestMode,
          ~isUpdateIntentInProgress,
          ~clientSecretRef=context.clientSecret,
          ~sdkAuthorizationRef=context.sdkAuthorization,
          ~sessionTokensDataPromise=context.sessionTokens,
          ~sdkConfigsDataPromise=context.sdkConfigs,
          ~clientListDataPromise=context.clientList,
          ~onPaymentContextChange=() => synchronizePaymentContext(context),
        )
      }

      let sessionUpdate = async clientSecret => {
        try {
          let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)
          let session = await PaymentHelpers.fetchSessions(
            ~clientSecret,
            ~publishableKey,
            ~logger,
            ~endpoint,
          )
          iframeRef.contents->Array.forEach(ifR => {
            ifR->Window.iframePostMessage(
              [("sessions", session)]->Dict.fromArray,
              ~targetOrigin=sdkOrigin,
            )
            ifR->Window.iframePostMessage(
              [("sessionUpdate", false->JSON.Encode.bool)]->Dict.fromArray,
              ~targetOrigin=sdkOrigin,
            )
          })
          [("updateCompleted", true->JSON.Encode.bool)]->getJsonFromArrayOfJson
        } catch {
        | Exn.Error(e) =>
          let errorMsg = Exn.message(e)->Option.getOr("Something went wrong!")
          [
            ("updateCompleted", false->JSON.Encode.bool),
            ("errorMessage", errorMsg->JSON.Encode.string),
          ]->getJsonFromArrayOfJson
        }
      }

      let completeUpdateIntent = clientSecret => {
        sessionUpdate(clientSecret)
      }

      let initiateUpdateIntent = () => {
        iframeRef.contents->Array.forEach(ifR => {
          ifR->Window.iframePostMessage(
            [("sessionUpdate", true->JSON.Encode.bool)]->Dict.fromArray,
            ~targetOrigin=sdkOrigin,
          )
        })
        let msg = [("updateInitiated", true->JSON.Encode.bool)]->getJsonFromArrayOfJson
        Promise.resolve(msg)
      }

      let initAuthenticationSession = authenticationSessionOptions => {
        open Promise

        let clientSecretId =
          authenticationSessionOptions
          ->JSON.Decode.object
          ->Option.flatMap(x => x->Dict.get("clientSecret"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")
        clientSecret := clientSecretId
        Promise.make((resolve, _) => {
          logger.setClientSecret(clientSecretId)
          resolve(JSON.Encode.null)
        })
        ->then(_ => {
          logger.setLogInfo(
            ~value=Window.hrefWithoutSearch,
            ~eventName=AUTHENTICATED_SESSION_INITIATED,
          )
          resolve()
        })
        ->catch(_ => resolve())
        ->ignore

        AuthenticationSession.make(
          authenticationSessionOptions,
          ~clientSecret={clientSecretId},
          ~publishableKey,
          ~logger=Some(logger),
        )
      }

      // Deliberately leaves the shared sdkAuthorization ref and the logger's auth alone: they
      // belong to elements/paymentSession on this instance, and a vault session token would
      // overwrite theirs. Payment method sessions log through a separate logger instead, so
      // payment_id stays scoped to them. Every session on this instance shares that one logger,
      // created on first use, since each logger keeps a flush timer alive.
      let paymentMethodSessionLoggerRef = ref((None: option<HyperLoggerTypes.loggerMake>))
      let initPaymentMethodSession = paymentMethodSessionOptions => {
        let pmSessionIdVal = (
          paymentMethodSessionOptions
          ->getDictFromJson
          ->PaymentMethodSession.resolveSdkAuthorization
          ->Utils.getSdkAuthorizationData
        ).pmSessionId->Option.getOr("")
        let sessionLogger = switch paymentMethodSessionLoggerRef.contents {
        | Some(existingLogger) => existingLogger
        | None =>
          let newLogger = HyperLogger.make(
            ~sessionId=sessionID,
            ~source=Loader,
            ~merchantId=publishableKey,
            ~metadata=analyticsMetadata,
          )
          paymentMethodSessionLoggerRef := Some(newLogger)
          newLogger
        }
        sessionLogger.setSdkAuthorization(
          paymentMethodSessionOptions
          ->getDictFromJson
          ->PaymentMethodSession.resolveSdkAuthorization,
        )
        sessionLogger.setPaymentId(pmSessionIdVal)
        sessionLogger.setLogInfo(
          ~value=[
            ("url", Window.hrefWithoutSearch->JSON.Encode.string),
            ("pmSessionId", pmSessionIdVal->JSON.Encode.string),
          ]
          ->getJsonFromArrayOfJson
          ->JSON.stringify,
          ~eventName=PAYMENT_METHOD_SESSION_INITIATED,
        )

        PaymentMethodSession.make(
          paymentMethodSessionOptions,
          ~publishableKey,
          ~sdkSessionId=sessionID,
          ~logger=sessionLogger,
        )
      }

      let returnObject: hyperInstance = {
        confirmOneClickPayment,
        confirmPayment: payload => confirmPayment(payload, ~useElementTarget=false),
        elements,
        widgets: elements,
        confirmCardPayment: confirmCardPaymentFn,
        retrievePaymentIntent: retrievePaymentIntentFn,
        paymentRequest,
        initPaymentSession,
        initAuthenticationSession,
        paymentMethodsManagementElements,
        completeUpdateIntent,
        initiateUpdateIntent,
        confirmTokenization: payload => confirmPayment(payload),
        initPaymentMethodSession,
      }
      Window.setHyper(Window.window, returnObject)
      returnObject
    }
  } catch {
  | e => {
      Sentry.captureException(e)
      defaultHyperInstance
    }
  }
}
