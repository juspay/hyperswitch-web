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
    let isSavedMethodsFlow = dict->getBool("isSavedMethodsFlow", false)

    LoggerContext.setSessionData(~sessionId=sdkSessionId, ~merchantId=publishableKey, ())
    LoggerContext.setPaymentIdFromCredentials(
      ~clientSecret,
      ~sdkAuthorization=?Some(sdkAuthorization)->getNonEmptyOption,
    )
    SdkLogger.logLifecycle(
      ~event=WalletStageReached({stage: ConfirmRequestReceived}),
      ~paymentMethod=Wallet(ApplePay),
    )

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
    let isPreloadEnabled =
      options
      ->getOptionsDict
      ->getBool("isPreloadEnabled", true)
    let isTestMode =
      options
      ->getOptionsDict
      ->getBool("isTestMode", false)

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
    let isReinit = Window.getHyper->Nullable.toOption->Option.isSome && !isForceInit
    let existingSessionId = LoggerContext.current().sessionId
    let sessionID = switch analyticsInfoDict->getString("sessionID", "") {
    | "" if isReinit && existingSessionId !== "" => existingSessionId
    | "" => "hyp_" ++ generateRandomString(8)
    | provided => provided
    }
    let sdkTimestamp = analyticsInfoDict->getString("timeStamp", Date.now()->Float.toString)
    HyperLoaderLogger.startSession(~sessionId=sessionID, ~merchantId=publishableKey)

    HyperLoaderLogger.logMerchantProps(
      ~event=TestMode({surface: Hyper}),
      ~details=[("test_mode", isTestMode->JSON.Encode.bool)],
    )

    switch options {
    | Some(userOptions) =>
      let customBackendUrl =
        userOptions
        ->JSON.Decode.object
        ->Option.flatMap(x => x->Dict.get("customBackendUrl"))
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOr("")
      if customBackendUrl !== "" {
        HyperLoaderLogger.logMerchantProps(
          ~event=HyperLoaderLogger.CustomBackendUrl({surface: Hyper}),
          ~details=[("url", customBackendUrl->JSON.Encode.string)],
        )
      }
      customBackendUrl === "" ? () : ApiEndpoint.setApiEndPoint(customBackendUrl)
    | None => ()
    }

    switch options->getOptionsDict->Dict.get("redirectionFlags") {
    | Some(_) =>
      HyperLoaderLogger.logMerchantProps(
        ~event=HyperLoaderLogger.RedirectionFlags({surface: Hyper}),
        ~details=[
          (
            "should_use_top_redirection",
            redirectionFlags.shouldUseTopRedirection->JSON.Encode.bool,
          ),
          (
            "should_remove_before_unload_events",
            redirectionFlags.shouldRemoveBeforeUnloadEvents->JSON.Encode.bool,
          ),
        ],
      )
    | None => ()
    }

    {
      () => {
        LoggerContext.setSessionData(~sessionId=sessionID, ~merchantId=publishableKey, ())

        if !isReinit {
          HyperLoaderLogger.logMerchantCall(
            ~event=HyperLoaderLogger.Init({surface: Hyper}),
            ~details=[("timestamp", sdkTimestamp->JSON.Encode.string)],
          )
        }
      }
    }->Sentry.sentryLogger
    let isSecure = Window.isSecureContext
    if !isSecure {
      manageErrorWarning(InsecureProtocol, ~dynamicStr=Window.hrefWithoutSearch)
      JsError.throwWithMessage("Insecure domain: " ++ Window.hrefWithoutSearch)
    }
    switch Window.getHyper->Nullable.toOption {
    | Some(hyperMethod) if !isForceInit =>
      HyperLoaderLogger.observeMerchantCall(
        ~event=HyperLoaderLogger.Reinit({surface: Hyper}),
        ~details=[("timestamp", sdkTimestamp->JSON.Encode.string)],
        ~call=() => hyperMethod,
      )
    | Some(_)
    | None =>
      let loaderTimestamp = Date.now()->Float.toString

      {
        () => {
          HyperLoaderLogger.logMerchantCall(
            ~event=HyperLoaderLogger.LoadHyper({surface: Hyper}),
            ~details=[("timestamp", loaderTimestamp->JSON.Encode.string)],
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

          SdkLogger.observeResource(
            ~event=ApplePayScript,
            ~url="https://applepay.cdn-apple.com/jsapi/v1/apple-pay-sdk.js",
            ~paymentMethod=Wallet(ApplePay),
            ~onError=_ => Console.error("ERROR DURING LOADING APPLE PAY"),
          )->ignore
        }
      }->Sentry.sentryLogger

      SdkLogger.observeResource(
        ~event=GooglePayScript,
        ~url="https://pay.google.com/gp/p/js/pay.js",
        ~paymentMethod=Wallet(GooglePay),
      )->ignore

      SdkLogger.observeResource(
        ~event=SamsungPayScript,
        ~url="https://img.mpay.samsung.com/gsmpi/sdk/samsungpay_web_sdk.js",
        ~paymentMethod=Wallet(SamsungPay),
      )->ignore

      let iframeRef = ref([])
      let clientSecret = ref("")
      let sdkAuthorization = ref("")
      let pmSessionId = ref("")
      let setIframeRef = ref => {
        iframeRef.contents->Array.push(ref)->ignore
      }

      let isUpdateIntentInProgress = ref(false)
      let emptyJsonPromise = Promise.resolve(JSON.Encode.null)
      let sessionTokensDataPromise = ref(emptyJsonPromise)
      let sdkConfigsDataPromise = ref(emptyJsonPromise)
      let clientListDataPromise = ref(emptyJsonPromise)

      let retrievePaymentIntentApiCall = async clientSecretOrSdkAuth => {
        let (actualClientSecret, sdkAuthorizationValue) = try {
          clientSecretOrSdkAuth->Utils.getSdkAuthorizationData->ignore

          ((None: option<string>), Some(clientSecretOrSdkAuth))
        } catch {
        | _ => (Some(clientSecretOrSdkAuth), None)
        }

        LoggerContext.setPaymentIdFromCredentials(
          ~clientSecret=actualClientSecret->Option.getOr(""),
          ~sdkAuthorization=?sdkAuthorizationValue->getNonEmptyOption,
        )

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
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.RetrievePaymentIntent({surface: Hyper}),
          ~call=() => retrievePaymentIntentApiCall(clientSecretOrSdkAuth),
        )

      let confirmPaymentWrapper = (payload, isOneClick, result, ~isSdkButton=false) => {
        let confirmTimestamp = Date.now()
        if !isOneClick && !isSdkButton {
          SdkLogger.logUser(~event=PaymentSubmitted({source: MerchantApi}))
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

      let gatedConfirmCall = payload =>
        if isUpdateIntentInProgress.contents {
          Promise.resolve(UpdateIntentHelpersNew.confirmBlockedResponse())
        } else {
          confirmPaymentWrapper(payload, false, true)
        }

      let confirmPayment = payload =>
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.ConfirmPayment({surface: Hyper}),
          ~details=[("iframe_ready", isReadyResolved.contents->JSON.Encode.bool)],
          ~timeoutMs=LoggerRuntime.userGatedTimeoutMs,
          ~call=() => gatedConfirmCall(payload),
        )

      let confirmTokenization = payload =>
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.ConfirmTokenization({surface: Hyper}),
          ~details=[("iframe_ready", isReadyResolved.contents->JSON.Encode.bool)],
          ~timeoutMs=LoggerRuntime.userGatedTimeoutMs,
          ~call=() => gatedConfirmCall(payload),
        )

      let confirmOneClickPayment = (payload, result: bool) =>
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.ConfirmOneClickPayment({surface: Hyper}),
          ~timeoutMs=LoggerRuntime.userGatedTimeoutMs,
          ~call=() => confirmPaymentWrapper(payload, true, result),
        )

      let confirmPaymentViaSDKButton = payload =>
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.ConfirmPayment({surface: Hyper}),
          ~details=[("iframe_ready", isReadyResolved.contents->JSON.Encode.bool)]->Array.concat([
            ("source", "sdk_button"->JSON.Encode.string),
          ]),
          ~timeoutMs=LoggerRuntime.userGatedTimeoutMs,
          ~call=() => confirmPaymentWrapper(payload, false, true, ~isSdkButton=true),
        )

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
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.CreateElements({surface: Hyper}),
          ~call=() => makeElements(elementsOptions),
        )

      let widgets = elementsOptions =>
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.CreateWidgets({surface: Hyper}),
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
        LoggerContext.setPmSessionId(pmSessionIdVal)

        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.PaymentMethodsManagementElements({surface: Hyper}),
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
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.ConfirmCardPayment({surface: Hyper}),
          ~timeoutMs=LoggerRuntime.userGatedTimeoutMs,
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
        switch Window.paymentRequestSupported {
        | Some(_) => Window.paymentRequest(methodData, details, optionsForPaymentRequest)
        | None => {
            HyperLoaderLogger.logMerchantIssue(
              ~issue=UnsupportedOptionValue,
              ~details=[("method", "paymentRequest"->JSON.Encode.string)],
            )
            JsError.throwWithMessage("PaymentRequest is not supported in this browser")
          }
        }
      }

      let paymentRequest = options =>
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.PaymentRequest({surface: Hyper}),
          ~call=() => makePaymentRequest(options),
        )

      let initPaymentSession = paymentSessionOptions => {
        let paymentSessionOptionsDict = paymentSessionOptions->JSON.Decode.object

        sdkAuthorization := paymentSessionOptionsDict->getStringFromDict("sdkAuthorization", "")

        clientSecret := paymentSessionOptionsDict->Utils.getStringFromDict("clientSecret", "")

        LoggerContext.setPaymentIdFromCredentials(
          ~clientSecret=clientSecret.contents,
          ~sdkAuthorization=?Some(sdkAuthorization.contents)->getNonEmptyOption,
        )

        HyperLoaderLogger.observeMerchantCall(
          ~source=Headless,
          ~event=HyperLoaderLogger.InitPaymentSession({surface: Hyper}),
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
        | JsExn(e) =>
          let errorMsg = JsExn.message(e)->Option.getOr("Something went wrong!")
          [
            ("updateCompleted", false->JSON.Encode.bool),
            ("errorMessage", errorMsg->JSON.Encode.string),
          ]->getJsonFromArrayOfJson
        }
      }

      let completeUpdateIntent = clientSecret =>
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.CompleteUpdateIntent({surface: Hyper}),
          ~failureOf=result => {
            let resultDict = result->getDictFromJson
            resultDict->getBool("updateCompleted", false)
              ? None
              : Some({
                  LoggerTypes.name: "UPDATE_INTENT_FAILED",
                  message: Some(resultDict->getString("errorMessage", "")),
                  details: [],
                })
          },
          ~call=() => sessionUpdate(clientSecret),
        )

      let initiateUpdateIntent = () =>
        HyperLoaderLogger.observeMerchantCall(
          ~event=HyperLoaderLogger.InitiateUpdateIntent({surface: Hyper}),
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

        LoggerContext.setPaymentIdFromCredentials(
          ~clientSecret=clientSecretId,
          ~sdkAuthorization=?authenticationSessionOptions
          ->JSON.Decode.object
          ->Option.flatMap(options => options->Dict.get("sdkAuthorization"))
          ->Option.flatMap(JSON.Decode.string)
          ->getNonEmptyOption,
        )

        HyperLoaderLogger.observeMerchantCall(
          ~source=AuthenticationSession,
          ~event=HyperLoaderLogger.InitAuthenticationSession({surface: Hyper}),
          ~call=() =>
            AuthenticationSession.make(
              authenticationSessionOptions,
              ~clientSecret={clientSecretId},
              ~publishableKey,
            ),
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
        confirmTokenization,
        initPaymentMethodSession: options => {
          let sdkAuthorizationValue = options->getDictFromJson->getString("sdkAuthorization", "")
          LoggerContext.setPaymentIdFromCredentials(
            ~sdkAuthorization=?Some(sdkAuthorizationValue)->getNonEmptyOption,
          )
          HyperLoaderLogger.observeMerchantCall(
            ~event=HyperLoaderLogger.InitPaymentMethodSession({surface: Hyper}),
            ~call=() => PaymentMethodSession.make(options),
          )
        },
      }
      Window.setHyper(Window.window, returnObject)
      returnObject
    }
  } catch {
  | e => {
      Sentry.captureException(e)
      SdkLogger.logCrash(
        ~origin=EntryPoint,
        ~details=[("entry_point", "hyper_create"->JSON.Encode.string)],
        ~exn=e,
      )
      defaultHyperInstance
    }
  }
}
