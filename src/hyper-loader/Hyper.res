open Types
open ErrorUtils
open Utils
open EventListenerManager
open Identity

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

  if dict->Dict.get("hyperApplePayCanMakePayments")->Option.isSome {
    let msg =
      [
        ("applePayCanMakePayments", true->JSON.Encode.bool),
        ("componentName", componentName->JSON.Encode.string),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object
    event.source->Window.sendPostMessageJSON(msg)
  } else if dict->Dict.get("hyperApplePayButtonClicked")->Option.isSome {
    let paymentRequest = dict->Dict.get("paymentRequest")->Option.getOr(JSON.Encode.null)
    let applePayPresent = dict->Dict.get("applePayPresent")
    let clientSecret = dict->getString("clientSecret", "")
    let sdkAuthorization = dict->getString("sdkAuthorization", "")
    let publishableKey = dict->getString("publishableKey", "")
    let isTaxCalculationEnabled = dict->getBool("isTaxCalculationEnabled", false)
    let sdkSessionId = dict->getString("sdkSessionId", "")
    let _analyticsMetadata = dict->getJsonFromDict("analyticsMetadata", JSON.Encode.null)
    let isSavedMethodsFlow = dict->getBool("isSavedMethodsFlow", false)

    LoggerContext.setSessionData(~sessionId=sdkSessionId, ~merchantId=publishableKey, ())

    let callBackFunc = payment => {
      let msg =
        [
          ("applePayPaymentToken", payment.token),
          ("applePayBillingContact", payment.billingContact),
          ("applePayShippingContact", payment.shippingContact),
          ("componentName", componentName->JSON.Encode.string),
          ("isSavedMethodsFlow", isSavedMethodsFlow->JSON.Encode.bool),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      event.source->Window.sendPostMessageJSON(msg)
    }

    let resolvePromise = _ => {
      let msg =
        [
          ("showApplePayButton", true->JSON.Encode.bool),
          ("componentName", componentName->JSON.Encode.string),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      event.source->Window.sendPostMessageJSON(msg)
    }

    ApplePayHelpers.startApplePaySession(
      ~paymentRequest,
      ~applePaySessionRef,
      ~applePayPresent,
      ~callBackFunc,
      ~clientSecret,
      ~publishableKey,
      ~isTaxCalculationEnabled,
      ~resolvePromise,
      ~sdkAuthorization=Some(sdkAuthorization),
    )
  }
}

addSmartEventListener("message", handleHyperApplePayMounted, "onHyperApplePayMount")

let isReadyResolved = ref(false)

let isReadyPromise = Promise.make((resolve, _) => {
  let handleOnReady = (event: Types.event) => {
    let json = event.data->anyTypeToJson
    let dict = json->getDictFromJson
    if dict->getBool("ready", false) {
      isReadyResolved := true
      resolve(Date.now())
    }
  }
  addSmartEventListener("message", handleOnReady, "handleOnReady")
})

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
    let sessionID = analyticsInfoDict->getString("sessionID", "hyp_" ++ generateRandomString(8))
    let sdkTimestamp = analyticsInfoDict->getString("timeStamp", Date.now()->Float.toString)
    LoggerRuntime.configure(~runtimeSource=HyperLoader)
    LoggerContext.setSessionData(~sessionId=sessionID, ~merchantId=publishableKey, ())

    switch options {
    | Some(userOptions) =>
      let customBackendUrl =
        userOptions
        ->JSON.Decode.object
        ->Option.flatMap(x => x->Dict.get("customBackendUrl"))
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOr("")
      if customBackendUrl !== "" {
        SdkRuntimeLogger.logMerchantProps(
          ~event=SdkRuntimeLogger.HyperProp(CustomBackendUrl),
          ~details=[
            ("url", customBackendUrl->LoggerCommonHelpers.sanitizedUrl->JSON.Encode.string),
          ],
        )
      }
      customBackendUrl === "" ? () : ApiEndpoint.setApiEndPoint(customBackendUrl)
    | None => ()
    }

    switch options->getOptionsDict->Dict.get("redirectionFlags") {
    | Some(_) =>
      SdkRuntimeLogger.logMerchantProps(
        ~event=SdkRuntimeLogger.HyperProp(RedirectionFlags),
        ~details=[
          ("shouldUseTopRedirection", redirectionFlags.shouldUseTopRedirection->JSON.Encode.bool),
          (
            "shouldRemoveBeforeUnloadEvents",
            redirectionFlags.shouldRemoveBeforeUnloadEvents->JSON.Encode.bool,
          ),
        ],
      )
    | None => ()
    }

    {
      () => {
        LoggerContext.setSessionData(~sessionId=sessionID, ~merchantId=publishableKey, ())
        SdkRuntimeLogger.observeMerchantSync(
          ~event=SdkRuntimeLogger.Hyper(Init),
          ~message=Window.hrefWithoutSearch,
          ~details=[("timestamp", sdkTimestamp->JSON.Encode.string)],
          ~call=() => (),
        )
      }
    }->Sentry.sentryLogger
    let isSecure = Window.isSecureContext
    if !isSecure {
      manageErrorWarning(HttpNotAllowed, ~dynamicStr=Window.hrefWithoutSearch)
      Exn.raiseError("Insecure domain: " ++ Window.hrefWithoutSearch)
    }
    switch Window.getHyper->Nullable.toOption {
    | Some(hyperMethod) if !isForceInit =>
      SdkRuntimeLogger.observeMerchantSync(
        ~event=SdkRuntimeLogger.Hyper(Reinit),
        ~message="orca-sdk initiated",
        ~details=[("timestamp", sdkTimestamp->JSON.Encode.string)],
        ~call=() => hyperMethod,
      )
    | Some(_)
    | None =>
      let loaderTimestamp = Date.now()->Float.toString

      {
        () => {
          SdkRuntimeLogger.observeMerchantSync(
            ~event=SdkRuntimeLogger.Hyper(LoadHyper),
            ~message="loadHyper has been called",
            ~details=[("timestamp", loaderTimestamp->JSON.Encode.string)],
            ~call=() => (),
          )
          if (
            publishableKey == "" ||
              !(
                ["pk_dev_", "pk_snd_", "pk_prd_"]->Array.some(prefix =>
                  publishableKey->String.startsWith(prefix)
                )
              )
          ) {
            manageErrorWarning(InvalidPublishableKey)
          }

          if (
            Window.querySelectorAll(`script[src="https://applepay.cdn-apple.com/jsapi/v1/apple-pay-sdk.js"]`)->Array.length === 0
          ) {
            let scriptURL = "https://applepay.cdn-apple.com/jsapi/v1/apple-pay-sdk.js"
            let script = Window.createElement("script")
            SdkRuntimeLogger.logResource(
              ~event=ScriptLoad(ApplePayScript, Init),
              ~message="Apple Pay Script Loading",
              ~paymentMethod=Wallet(ApplePay),
            )
            script->Window.elementSrc(scriptURL)
            script->Window.elementOnerror(err => {
              Console.error2("ERROR DURING LOADING APPLE PAY", err)
              SdkRuntimeLogger.logResource(
                ~event=ScriptLoad(ApplePayScript, Failed),
                ~message="ERROR DURING LOADING APPLE PAY SCRIPT",
                ~paymentMethod=Wallet(ApplePay),
              )
            })
            script->Window.elementOnload(_ =>
              SdkRuntimeLogger.logResource(
                ~event=ScriptLoad(ApplePayScript, Done),
                ~message="Apple Pay Script Loaded",
                ~paymentMethod=Wallet(ApplePay),
              )
            )
            Window.body->Window.appendChild(script)
          }
        }
      }->Sentry.sentryLogger

      if (
        Window.querySelectorAll(`script[src="https://pay.google.com/gp/p/js/pay.js"]`)->Array.length === 0
      ) {
        let googlePayScriptURL = "https://pay.google.com/gp/p/js/pay.js"
        let googlePayScript = Window.createElement("script")
        SdkRuntimeLogger.logResource(
          ~event=ScriptLoad(GooglePayScript, Init),
          ~message="GooglePay Script Loading",
          ~paymentMethod=Wallet(GooglePay),
        )
        googlePayScript->Window.elementSrc(googlePayScriptURL)
        googlePayScript->Window.elementOnerror(_ => {
          SdkRuntimeLogger.logResource(
            ~event=ScriptLoad(GooglePayScript, Failed),
            ~message="ERROR DURING LOADING GOOGLE PAY SCRIPT",
            ~paymentMethod=Wallet(GooglePay),
          )
        })
        googlePayScript->Window.elementOnload(_ =>
          SdkRuntimeLogger.logResource(
            ~event=ScriptLoad(GooglePayScript, Done),
            ~message="GooglePay Script Loaded",
            ~paymentMethod=Wallet(GooglePay),
          )
        )
        Window.body->Window.appendChild(googlePayScript)
      }

      if (
        Window.querySelectorAll(`script[src="https://img.mpay.samsung.com/gsmpi/sdk/samsungpay_web_sdk.js"]`)->Array.length === 0
      ) {
        let samsungPayScriptUrl = "https://img.mpay.samsung.com/gsmpi/sdk/samsungpay_web_sdk.js"
        let samsungPayScript = Window.createElement("script")
        SdkRuntimeLogger.logResource(
          ~event=ScriptLoad(SamsungPayScript, Init),
          ~message="SamsungPay Script Loading",
          ~paymentMethod=Wallet(SamsungPay),
        )
        samsungPayScript->Window.elementSrc(samsungPayScriptUrl)
        samsungPayScript->Window.elementOnerror(_ => {
          SdkRuntimeLogger.logResource(
            ~event=ScriptLoad(SamsungPayScript, Failed),
            ~message="ERROR DURING LOADING SAMSUNG PAY SCRIPT",
            ~paymentMethod=Wallet(SamsungPay),
          )
        })
        Window.body->Window.appendChild(samsungPayScript)
        samsungPayScript->Window.elementOnload(_ =>
          SdkRuntimeLogger.logResource(
            ~event=ScriptLoad(SamsungPayScript, Done),
            ~message="SamsungPay Script Loaded",
            ~paymentMethod=Wallet(SamsungPay),
          )
        )
      }

      let iframeRef = ref([])
      let clientSecret = ref("")
      let sdkAuthorization = ref("")
      let pmSessionId = ref("")
      let setIframeRef = ref => {
        iframeRef.contents->Array.push(ref)->ignore
      }

      // Shared refs for updateIntent — created once, passed to both Elements and PaymentSession.
      let isUpdateIntentInProgress = ref(false)
      let emptyJsonPromise = Promise.resolve(JSON.Encode.null)
      let sessionTokensDataPromise = ref(emptyJsonPromise)
      let sdkConfigsDataPromise = ref(emptyJsonPromise)
      let clientListDataPromise = ref(emptyJsonPromise)
      // TODO(sdk-configs): profileId is available here at init time for consumers who provide
      // it at Hyper.init stage. sdk-configs could be prefetched early (before elements() is
      // called) for a latency optimisation. Currently deferred to PreMountLoader for consistency.

      let retrievePaymentIntentApiCall = async clientSecretOrSdkAuth => {
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
          ~event=RetrievePaymentIntent,
          ~method=#GET,
          ~customPodUri=None,
          ~publishableKey=Some(publishableKey),
          ~onSuccess,
          ~onFailure,
          ~sdkAuthorization=sdkAuthorizationValue,
        )
      }

      let retrievePaymentIntentFn = clientSecretOrSdkAuth =>
        SdkRuntimeLogger.observeMerchant(
          ~event=SdkRuntimeLogger.Hyper(RetrievePaymentIntent),
          ~call=() => retrievePaymentIntentApiCall(clientSecretOrSdkAuth),
        )

      let confirmPaymentWrapper = (payload, isOneClick, result, ~isSdkButton=false) => {
        let confirmTimestamp = Date.now()
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
          iframeRef.contents->Array.forEach(ifR => {
            ifR->Window.iframePostMessage(message)
          })
        }

        if isTestMode {
          let errorResponse = getFailedSubmitResponse(
            ~errorType="test_mode_bypass",
            ~message="Confirm Payment called in test mode - API call bypassed",
          )
          Promise.resolve(errorResponse)
        } else {
          Promise.make((resolve1, _) => {
            CorePaymentLogger.logLifecycle(
              ~event=IsReadyStatusCheck,
              ~message="isReadyPromise status: " ++ (
                isReadyResolved.contents ? "resolved" : "pending"
              ),
            )
            isReadyPromise
            ->Promise.then(readyTimestamp => {
              let handleMessage = (event: Types.event) => {
                let json = event.data->anyTypeToJson
                let dict = json->getDictFromJson
                switch dict->Dict.get("submitSuccessful") {
                | Some(val) =>
                  let data = dict->Dict.get("data")->Option.getOr(Dict.make()->JSON.Encode.object)
                  let returnUrl =
                    dict->Dict.get("url")->Option.flatMap(JSON.Decode.string)->Option.getOr(url)

                  if isOneClick {
                    iframeRef.contents->Array.forEach(
                      ifR => {
                        // to unset one click button loader
                        ifR->Window.iframePostMessage(
                          [("oneClickDoSubmit", false->JSON.Encode.bool)]->Dict.fromArray,
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
                    resolve1(json)
                  } else {
                    resolve1(data)
                  }
                | None => ()
                }
              }
              let message = isOneClick
                ? [("oneClickDoSubmit", result->JSON.Encode.bool)]->Dict.fromArray
                : [
                    ("doSubmit", true->JSON.Encode.bool),
                    ("clientSecret", clientSecret.contents->JSON.Encode.string),
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
              addSmartEventListener("message", handleMessage, "onSubmit")
              postSubmitMessage(message)
              Promise.resolve(JSON.Encode.null)
            })
            ->Promise.catch(_ => Promise.resolve(JSON.Encode.null))
            ->ignore
          })
        }
      }

      let confirmPayment = payload =>
        SdkRuntimeLogger.observeMerchant(
          ~event=SdkRuntimeLogger.Hyper(ConfirmPayment),
          ~timeoutMs=LoggerCommonHelpers.userGatedOperationTimeoutMs,
          ~resultFailure=LoggerCommonHelpers.errorResponseSummary,
          ~call=() =>
            if isUpdateIntentInProgress.contents {
              Promise.resolve(UpdateIntentHelpersNew.confirmBlockedResponse())
            } else {
              confirmPaymentWrapper(payload, false, true)
            },
        )

      let confirmOneClickPayment = (payload, result: bool) =>
        SdkRuntimeLogger.observeMerchant(
          ~event=SdkRuntimeLogger.Hyper(ConfirmOneClickPayment),
          ~timeoutMs=LoggerCommonHelpers.userGatedOperationTimeoutMs,
          ~resultFailure=LoggerCommonHelpers.errorResponseSummary,
          ~call=() => confirmPaymentWrapper(payload, true, result),
        )

      let confirmPaymentViaSDKButton = payload => {
        confirmPaymentWrapper(payload, false, true, ~isSdkButton=true)
      }

      let handleSdkConfirm = (event: Types.event) => {
        let json = event.data->anyTypeToJson
        let dict = json->getDictFromJson
        switch dict->Dict.get("handleSdkConfirm") {
        | Some(payload) => confirmPaymentViaSDKButton(payload)->ignore
        | None => ()
        }
      }

      addSmartEventListener("message", handleSdkConfirm, "handleSdkConfirm")

      if isTestMode {
        Console.warn(
          "The SDK is running in test mode. API calls are bypassed and wallet interactions are disabled.",
        )
        Console.warn(
          "This is a non-transactional simulation environment for UI configuration and testing purposes only.",
        )
      }

      let makeElements = elementsOptions => {
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

        Elements.make(
          elementsOptions,
          setIframeRef,
          ~sdkSessionId=sessionID,
          ~publishableKey,
          ~analyticsMetadata,
          ~customBackendUrl=options
          ->Option.getOr(JSON.Encode.null)
          ->getDictFromJson
          ->getString("customBackendUrl", ""),
          ~redirectionFlags,
          ~isTestMode,
          ~preloadSDKWithParams,
          ~isUpdateIntentInProgress,
          ~clientSecretRef=clientSecret,
          ~sdkAuthorizationRef=sdkAuthorization,
          ~sessionTokensDataPromise,
          ~sdkConfigsDataPromise,
          ~clientListDataPromise,
          ~confirmPayment,
        )
      }

      let elements = elementsOptions =>
        SdkRuntimeLogger.observeMerchantSync(
          ~event=SdkRuntimeLogger.Hyper(CreateElements),
          ~message=Window.hrefWithoutSearch,
          ~call=() => makeElements(elementsOptions),
        )

      let widgets = elementsOptions =>
        SdkRuntimeLogger.observeMerchantSync(
          ~event=SdkRuntimeLogger.Hyper(CreateWidgets),
          ~message=Window.hrefWithoutSearch,
          ~call=() => makeElements(elementsOptions),
        )

      let paymentMethodsManagementElements = pmManagementOptions => {
        let pmManagementOptionsDict = pmManagementOptions->JSON.Decode.object
        pmManagementOptionsDict
        ->Option.forEach(x => x->Dict.set("launchTime", Date.now()->JSON.Encode.float))
        ->ignore
        let sdkAuthorizationId = pmManagementOptionsDict->getStringFromDict("sdkAuthorization", "")
        let sdkAuthorizationData = sdkAuthorizationId->Utils.getSdkAuthorizationData

        sdkAuthorization := sdkAuthorizationId
        let pmSessionIdVal = sdkAuthorizationData.pmSessionId->Option.getOr("")

        let pmManagementOptions =
          pmManagementOptionsDict->Option.mapOr(pmManagementOptions, JSON.Encode.object)
        pmSessionId := pmSessionIdVal

        SdkRuntimeLogger.observeMerchantSync(
          ~event=SdkRuntimeLogger.Hyper(PaymentManagementElements),
          ~message=Window.hrefWithoutSearch,
          ~call=() =>
            PaymentMethodsManagementElements.make(
              pmManagementOptions,
              setIframeRef,
              ~sdkSessionId=sessionID,
              ~publishableKey,
              ~pmSessionId={pmSessionIdVal},
              ~sdkAuthorization=sdkAuthorizationId,
              ~analyticsMetadata,
              ~customBackendUrl=options
              ->Option.getOr(JSON.Encode.null)
              ->getDictFromJson
              ->getString("customBackendUrl", ""),
            ),
        )
      }

      let confirmCardPaymentCall = (clientSecretId: string, data: option<JSON.t>) => {
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
            )

            let handleMessage = (event: Types.event) => {
              let json = event.data->anyTypeToJson
              let dict = json->getDictFromJson
              switch dict->Dict.get("submitSuccessful") {
              | Some(val) =>
                let url = decodedData->getString("return_url", "/")
                if val->JSON.Decode.bool->Option.getOr(false) && url !== "/" {
                  Utils.replaceRootHref(url, redirectionFlags)
                } else {
                  resolve(json)
                }
              | None => resolve(json)
              }
            }
            addSmartEventListener("message", handleMessage, "")
          })
          ->ignore
        })
      }

      let confirmCardPaymentFn = (
        clientSecretId: string,
        data: option<JSON.t>,
        _options: option<JSON.t>,
      ) =>
        SdkRuntimeLogger.observeMerchant(
          ~event=SdkRuntimeLogger.Hyper(ConfirmCardPayment),
          ~timeoutMs=LoggerCommonHelpers.userGatedOperationTimeoutMs,
          ~resultFailure=LoggerCommonHelpers.errorResponseSummary,
          ~call=() => confirmCardPaymentCall(clientSecretId, data),
        )

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
      let makePaymentRequest = options => {
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

      let paymentRequest = options =>
        SdkRuntimeLogger.observeMerchantSync(
          ~event=SdkRuntimeLogger.Hyper(PaymentRequest),
          ~call=() => makePaymentRequest(options),
        )

      let initPaymentSession = paymentSessionOptions => {
        let paymentSessionOptionsDict = paymentSessionOptions->JSON.Decode.object

        sdkAuthorization := paymentSessionOptionsDict->getStringFromDict("sdkAuthorization", "")

        clientSecret := paymentSessionOptionsDict->Utils.getStringFromDict("clientSecret", "")

        SdkRuntimeLogger.observeMerchantSync(
          ~event=SdkRuntimeLogger.Hyper(InitPaymentSession),
          ~message=Window.hrefWithoutSearch,
          ~call=() =>
            PaymentSession.make(
              paymentSessionOptions,
              ~publishableKey,
              ~sdkSessionId=sessionID,
              ~redirectionFlags,
              ~iframeRef,
              ~isTestMode,
              ~isUpdateIntentInProgress,
              ~clientSecretRef=clientSecret,
              ~sdkAuthorizationRef=sdkAuthorization,
              ~sessionTokensDataPromise,
              ~sdkConfigsDataPromise,
              ~clientListDataPromise,
            ),
        )
      }

      let sessionUpdate = async clientSecret => {
        try {
          let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)
          let session = await PaymentHelpers.fetchSessions(
            ~clientSecret,
            ~publishableKey,
            ~endpoint,
          )
          iframeRef.contents->Array.forEach(ifR => {
            ifR->Window.iframePostMessage([("sessions", session)]->Dict.fromArray)
            ifR->Window.iframePostMessage(
              [("sessionUpdate", false->JSON.Encode.bool)]->Dict.fromArray,
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

      let completeUpdateIntent = clientSecret =>
        SdkRuntimeLogger.observeMerchant(
          ~event=SdkRuntimeLogger.Hyper(CompleteUpdateIntent),
          ~resultFailure=result => {
            let resultDict = result->getDictFromJson
            resultDict->getBool("updateCompleted", false)
              ? None
              : Some({
                  LoggerCommonHelpers.name: "UPDATE_INTENT_FAILED",
                  message: Some(resultDict->getString("errorMessage", "")),
                  details: [],
                })
          },
          ~call=() => sessionUpdate(clientSecret),
        )

      let initiateUpdateIntent = () =>
        SdkRuntimeLogger.observeMerchant(
          ~event=SdkRuntimeLogger.Hyper(InitiateUpdateIntent),
          ~call=() => {
            iframeRef.contents->Array.forEach(ifR => {
              ifR->Window.iframePostMessage(
                [("sessionUpdate", true->JSON.Encode.bool)]->Dict.fromArray,
              )
            })
            let msg = [("updateInitiated", true->JSON.Encode.bool)]->getJsonFromArrayOfJson
            Promise.resolve(msg)
          },
        )

      let initAuthenticationSession = authenticationSessionOptions => {
        let clientSecretId =
          authenticationSessionOptions
          ->JSON.Decode.object
          ->Option.flatMap(x => x->Dict.get("clientSecret"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")
        clientSecret := clientSecretId

        ClickToPayLogger.observeMerchantSync(~event=InitAuthenticationSession, ~call=() =>
          AuthenticationSession.make(
            authenticationSessionOptions,
            ~clientSecret={clientSecretId},
            ~publishableKey,
          )
        )
      }

      let returnObject: hyperInstance = {
        confirmOneClickPayment,
        confirmPayment,
        elements,
        widgets,
        confirmCardPayment: confirmCardPaymentFn,
        retrievePaymentIntent: retrievePaymentIntentFn,
        paymentRequest,
        initPaymentSession,
        initAuthenticationSession,
        paymentMethodsManagementElements,
        completeUpdateIntent,
        initiateUpdateIntent,
        confirmTokenization: confirmPayment,
        paymentMethodsSession: options => PaymentMethodsSession.make(options),
      }
      Window.setHyper(Window.window, returnObject)
      returnObject
    }
  } catch {
  | e => {
      Sentry.captureException(e)
      SdkRuntimeLogger.logCrash(
        ~message="Hyper instance creation failed",
        ~details=e
        ->LoggerCommonHelpers.summarizeException
        ->LoggerCommonHelpers.exceptionSummaryDetails,
      )
      defaultHyperInstance
    }
  }
}
