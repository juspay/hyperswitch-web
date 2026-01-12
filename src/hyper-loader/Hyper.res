open Types
open ErrorUtils
open LoggerUtils
open Utils
open EventListenerManager
open Identity

let checkAndAppend = (selector, child) => {
  if Nullable.toOption(CommonHooks.querySelector(selector)) == None {
    CommonHooks.appendChild(child)
  }
}

if (
  Window.querySelectorAll(`script[src="${GlobalVars.sentryScriptUrl}"]`)->Array.length === 0 &&
    GlobalVars.sentryScriptUrl->typeof !== #undefined
) {
  try {
    let script = Window.createElement("script")
    script->Window.elementSrc(GlobalVars.sentryScriptUrl)
    script->Window.elementOnerror(err => {
      Console.error2("ERROR DURING LOADING Sentry on HyperLoader", err)
    })
    script->Window.elementOnload(() => {
      Sentry.initiateSentryJs(~dsn=GlobalVars.sentryDSN)
    })
    Window.window->Window.windowOnload(_ => {
      Window.body->Window.appendChild(script)
    })
  } catch {
  | e => Console.error2("Sentry load exited", e)
  }
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
    let publishableKey = dict->getString("publishableKey", "")
    let isTaxCalculationEnabled = dict->getBool("isTaxCalculationEnabled", false)
    let sdkSessionId = dict->getString("sdkSessionId", "")
    let analyticsMetadata = dict->getJsonFromDict("analyticsMetadata", JSON.Encode.null)

    let logger = HyperLogger.make(
      ~sessionId=sdkSessionId,
      ~source=Loader,
      ~merchantId=publishableKey,
      ~metadata=analyticsMetadata,
      ~clientSecret,
    )

    let callBackFunc = payment => {
      let msg =
        [
          ("applePayPaymentToken", payment.token),
          ("applePayBillingContact", payment.billingContact),
          ("applePayShippingContact", payment.shippingContact),
          ("componentName", componentName->JSON.Encode.string),
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
      ~logger,
      ~callBackFunc,
      ~clientSecret,
      ~publishableKey,
      ~isTaxCalculationEnabled,
      ~resolvePromise,
    )
  }
}

addSmartEventListener("message", handleHyperApplePayMounted, "onHyperApplePayMount")

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
    let overridenDefaultRedirectionFlags: RecoilAtomTypes.redirectionFlags = {
      shouldUseTopRedirection,
      shouldRemoveBeforeUnloadEvents: false,
    }
    let redirectionFlags =
      options
      ->getOptionsDict
      ->getJsonObjectFromDict("redirectionFlags")
      ->RecoilAtomTypes.decodeRedirectionFlags(overridenDefaultRedirectionFlags)

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
    let logger = HyperLogger.make(
      ~sessionId=sessionID,
      ~source=Loader,
      ~merchantId=publishableKey,
      ~metadata=analyticsMetadata,
    )
    let isReadyPromise = Promise.make((resolve, _) => {
      let handleOnReady = (event: Types.event) => {
        let json = event.data->anyTypeToJson
        let dict = json->getDictFromJson
        if dict->getBool("ready", false) {
          resolve(Date.now())
        }
      }
      addSmartEventListener("message", handleOnReady, "handleOnReady")
    })

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
        logger.setMerchantId(publishableKey)
        logger.setSessionId(sessionID)
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
      let paymentId = ref("")
      let ephemeralKey = ref("")
      let pmSessionId = ref("")
      let pmClientSecret = ref("")
      let setIframeRef = ref => {
        iframeRef.contents->Array.push(ref)->ignore
      }

      let retrievePaymentIntentFn = async clientSecret => {
        let uri = APIUtils.generateApiUrlV1(
          ~apiCallType=RetrievePaymentIntent,
          ~params={
            clientSecret: Some(clientSecret),
            publishableKey: Some(publishableKey),
            customBackendBaseUrl: None,
            paymentMethodId: None,
            forceSync: None,
            pollId: None,
            payoutId: None,
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
        )
      }

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
          let errrorResponse = getFailedSubmitResponse(
            ~errorType="test_mode_bypass",
            ~message="Confirm Payment called in test mode - API call bypassed",
          )
          Promise.resolve(errrorResponse)
        } else {
          Promise.make((resolve1, _) => {
            let isReadyPromise = isReadyPromise
            isReadyPromise
            ->Promise.then(readyTimestamp => {
              let handleMessage = (event: Types.event) => {
                let json = event.data->anyTypeToJson
                let dict = json->getDictFromJson
                switch dict->Dict.get("submitSuccessful") {
                | Some(val) =>
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

      let confirmPayment = payload => {
        confirmPaymentWrapper(payload, false, true)
      }

      let confirmOneClickPayment = (payload, result: bool) => {
        confirmPaymentWrapper(payload, true, result)
      }

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

      // Add console warning for test mode
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

        let clientSecretId = elementsOptionsDict->Utils.getStringFromDict("clientSecret", "")
        let paymentIdVal = elementsOptionsDict->Utils.getStringFromDict("paymentId", "")
        let elementsOptions = elementsOptionsDict->Option.mapOr(elementsOptions, JSON.Encode.object)
        clientSecret := clientSecretId
        paymentId := paymentIdVal
        Promise.make((resolve, _) => {
          logger.setClientSecret(clientSecretId)
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
          setIframeRef,
          ~sdkSessionId=sessionID,
          ~publishableKey,
          ~profileId,
          ~clientSecret={clientSecretId},
          ~paymentId={paymentIdVal},
          ~logger=Some(logger),
          ~analyticsMetadata,
          ~customBackendUrl=options
          ->Option.getOr(JSON.Encode.null)
          ->getDictFromJson
          ->getString("customBackendUrl", ""),
          ~redirectionFlags,
          ~isTestMode,
        )
      }

      let paymentMethodsManagementElements = pmManagementOptions => {
        open Promise
        let pmManagementOptionsDict = pmManagementOptions->JSON.Decode.object
        pmManagementOptionsDict
        ->Option.forEach(x => x->Dict.set("launchTime", Date.now()->JSON.Encode.float))
        ->ignore

        let ephemeralKeyId = pmManagementOptionsDict->getStringFromDict("ephemeralKey", "")
        let pmClientSecretId = pmManagementOptionsDict->getStringFromDict("pmClientSecret", "")
        let pmSessionIdVal = pmManagementOptionsDict->getStringFromDict("pmSessionId", "")

        let pmManagementOptions =
          pmManagementOptionsDict->Option.mapOr(pmManagementOptions, JSON.Encode.object)
        ephemeralKey := ephemeralKeyId
        pmSessionId := pmSessionIdVal
        pmClientSecret := pmClientSecretId
        Promise.make((resolve, _) => {
          logger.setEphemeralKey(ephemeralKeyId)
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
          ~profileId,
          ~ephemeralKey={ephemeralKeyId},
          ~pmClientSecret={pmClientSecretId},
          ~pmSessionId={pmSessionIdVal},
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

        let clientSecretId =
          paymentSessionOptions
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
          logger.setLogInfo(~value=Window.hrefWithoutSearch, ~eventName=PAYMENT_SESSION_INITIATED)
          resolve()
        })
        ->catch(_ => resolve())
        ->ignore

        PaymentSession.make(
          paymentSessionOptions,
          ~clientSecret={clientSecretId},
          ~publishableKey,
          ~logger=Some(logger),
          ~ephemeralKey=ephemeralKey.contents,
          ~redirectionFlags,
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

      let completeUpdateIntent = clientSecret => {
        sessionUpdate(clientSecret)
      }

      let initiateUpdateIntent = () => {
        iframeRef.contents->Array.forEach(ifR => {
          ifR->Window.iframePostMessage([("sessionUpdate", true->JSON.Encode.bool)]->Dict.fromArray)
        })
        let msg = [("updateInitiated", true->JSON.Encode.bool)]->getJsonFromArrayOfJson
        Promise.resolve(msg)
      }

      let preloadSDKWithParams = params => {
        let paramsDict = params->getDictFromJson

        iframeRef.contents->Array.forEach(ifR => {
          // Send paymentMethodsList if provided
          switch paramsDict->Dict.get("paymentMethodsList") {
          | Some(paymentMethodsList) =>
            let message = [("paymentMethodList", paymentMethodsList)]->Dict.fromArray
            ifR->Window.iframePostMessage(message)
          | None => ()
          }

          // Send customerMethodsList if provided
          switch paramsDict->Dict.get("customerMethodsList") {
          | Some(customerMethodsList) =>
            let message = [("customerPaymentMethods", customerMethodsList)]->Dict.fromArray
            ifR->Window.iframePostMessage(message)
          | None => ()
          }

          // Send sessionTokens if provided
          switch paramsDict->Dict.get("sessionTokens") {
          | Some(sessionTokens) =>
            let message = [("sessions", sessionTokens)]->Dict.fromArray
            ifR->Window.iframePostMessage(message)
          | None => ()
          }

          // Send appearance if provided (via paymentOptions format)
          switch paramsDict->Dict.get("appearanceObj") {
          | Some(appearance) =>
            let paymentOptionsMessage =
              [
                ("paymentOptions", appearance),
                ("paymentElementCreate", true->JSON.Encode.bool),
              ]->Dict.fromArray
            ifR->Window.iframePostMessage(paymentOptionsMessage)
          | None => ()
          }
        })

        // Log the preload operation
        logger.setLogInfo(
          ~value="SDK preloaded with external parameters",
          ~eventName=PRELOAD_SDK_WITH_PARAMS,
        )
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

      let returnObject: hyperInstance = {
        confirmOneClickPayment,
        confirmPayment,
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
        preloadSDKWithParams,
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
