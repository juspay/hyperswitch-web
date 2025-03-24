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
    ~href="https://js.braintreegateway.com/web/3.88.4/js/paypal-checkout.min.js",
  )
  preloadFile(~type_="script", ~href="https://js.braintreegateway.com/web/3.88.4/js/client.min.js")
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

let make = (publishableKey, options: option<JSON.t>, analyticsInfo: option<JSON.t>) => {
  try {
    let isPreloadEnabled =
      options
      ->Option.getOr(JSON.Encode.null)
      ->getDictFromJson
      ->getBool("isPreloadEnabled", true)
    // INFO: kept for backwards compatibility - remove once removed from hyperswitch backend and deployed
    let shouldUseTopRedirection =
      options
      ->Option.getOr(JSON.Encode.null)
      ->getDictFromJson
      ->getBool("shouldUseTopRedirection", false)
    let overridenDefaultRedirectionFlags: RecoilAtomTypes.redirectionFlags = {
      shouldUseTopRedirection,
      shouldRemoveBeforeUnloadEvents: false,
    }
    let redirectionFlags =
      options
      ->Option.getOr(JSON.Encode.null)
      ->getDictFromJson
      ->getJsonObjectFromDict("redirectionFlags")
      ->RecoilAtomTypes.decodeRedirectionFlags(overridenDefaultRedirectionFlags)
    let analyticsMetadata =
      options
      ->Option.getOr(JSON.Encode.null)
      ->getDictFromJson
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
        if (
          dict
          ->Dict.get("ready")
          ->Option.getOr(JSON.Encode.bool(false))
          ->JSON.Decode.bool
          ->Option.getOr(false)
        ) {
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
    let isSecure = Window.Location.protocol === "https:"
    let isLocal =
      ["localhost", "127.0.0.1"]
      ->Array.find(url => Window.Location.hostname->String.includes(url))
      ->Option.isSome
    if !isSecure && !isLocal {
      manageErrorWarning(HTTP_NOT_ALLOWED, ~dynamicStr=Window.hrefWithoutSearch, ~logger)
      Exn.raiseError("Insecure domain: " ++ Window.hrefWithoutSearch)
    }
    switch Window.getHyper->Nullable.toOption {
    | Some(hyperMethod) => {
        logger.setLogInfo(
          ~value="orca-sdk initiated",
          ~eventName=APP_REINITIATED,
          ~timestamp=sdkTimestamp,
        )
        hyperMethod
      }
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
                publishableKey->String.startsWith("pk_dev_") ||
                publishableKey->String.startsWith("pk_snd_") ||
                publishableKey->String.startsWith("pk_prd_")
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
        googlePayScript->Window.elementOnerror(err => {
          logger.setLogError(
            ~value="ERROR DURING LOADING GOOGLE PAY SCRIPT",
            ~eventName=GOOGLE_PAY_SCRIPT,
            ~internalMetadata=err->formatException->JSON.stringify,
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
        samsungPayScript->Window.elementOnerror(err => {
          logger.setLogError(
            ~value="ERROR DURING LOADING SAMSUNG PAY SCRIPT",
            ~eventName=SAMSUNG_PAY_SCRIPT,
            ~internalMetadata=err->formatException->JSON.stringify,
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
      let ephemeralKey = ref("")
      let setIframeRef = ref => {
        iframeRef.contents->Array.push(ref)->ignore
      }

      let retrievePaymentIntentFn = clientSecret => {
        let headers = {
          "Accept": "application/json",
          "api-key": publishableKey,
        }
        let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)
        let paymentIntentID = clientSecret->getPaymentId
        let retrievePaymentUrl = `${endpoint}/payments/${paymentIntentID}?client_secret=${clientSecret}`
        open Promise
        logApi(
          ~optLogger=Some(logger),
          ~url=retrievePaymentUrl,
          ~apiLogType=Request,
          ~eventName=RETRIEVE_CALL_INIT,
          ~logType=INFO,
          ~logCategory=API,
        )
        Fetch.fetch(
          retrievePaymentUrl,
          {
            method: #GET,
            headers: Fetch.Headers.fromObject(headers),
          },
        )
        ->then(resp => {
          let statusCode = resp->Fetch.Response.status->Int.toString
          if statusCode->String.charAt(0) !== "2" {
            resp
            ->Fetch.Response.json
            ->then(data => {
              logApi(
                ~optLogger=Some(logger),
                ~url=retrievePaymentUrl,
                ~data,
                ~statusCode,
                ~apiLogType=Err,
                ~eventName=RETRIEVE_CALL,
                ~logType=ERROR,
                ~logCategory=API,
              )
              resolve()
            })
            ->catch(_ => resolve())
            ->ignore
          } else {
            logApi(
              ~optLogger=Some(logger),
              ~url=retrievePaymentUrl,
              ~statusCode,
              ~apiLogType=Response,
              ~eventName=RETRIEVE_CALL,
              ~logType=INFO,
              ~logCategory=API,
            )
          }
          Fetch.Response.json(resp)
        })
        ->then(data => {
          [("paymentIntent", data)]->getJsonFromArrayOfJson->Promise.resolve
        })
        ->catch(_ => Promise.resolve(JSON.Encode.null))
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

        Promise.make((resolve1, _) => {
          let isReadyPromise = isReadyPromise
          isReadyPromise
          ->Promise.then(readyTimestamp => {
            let handleMessage = (event: Types.event) => {
              let json = event.data->anyTypeToJson
              let dict = json->getDictFromJson
              switch dict->Dict.get("submitSuccessful") {
              | Some(val) =>
                Console.log("412 Hyper.res Inside handleMessage Some submitSuccessful")
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
                Console.log2("423 Hyper.res Inside handleMessage returnUrl =>", returnUrl)
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
                Console.log2("437 Hyper.res submitSuccessfulValue =>", submitSuccessfulValue)
                if isSdkButton && submitSuccessfulValue {
                  Console.log3(
                    "439 Hyper.res Redirect If SDK and True",
                    returnUrl,
                    redirectionFlags->Identity.anyTypeToJson->JSON.stringify,
                  )
                  Utils.replaceRootHref(returnUrl, redirectionFlags)
                } else if submitSuccessfulValue && redirect === "always" {
                  Console.log3(
                    "447 Hyper.res Redirect submitSuccessfulValue True and always",
                    returnUrl,
                    redirectionFlags->Identity.anyTypeToJson->JSON.stringify,
                  )
                  Utils.replaceRootHref(returnUrl, redirectionFlags)
                } else if !submitSuccessfulValue {
                  Console.log2("453 Hyper.res !submitSuccessfull json =>", json->JSON.stringify)
                  resolve1(json)
                } else {
                  Console.log2("456 Hyper.res else json =>", json->JSON.stringify)
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

      let elements = elementsOptions => {
        open Promise
        let elementsOptionsDict = elementsOptions->JSON.Decode.object
        elementsOptionsDict
        ->Option.forEach(x => x->Dict.set("launchTime", Date.now()->JSON.Encode.float))
        ->ignore

        let clientSecretId =
          elementsOptionsDict
          ->Option.flatMap(x => x->Dict.get("clientSecret"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")
        let elementsOptions = elementsOptionsDict->Option.mapOr(elementsOptions, JSON.Encode.object)
        clientSecret := clientSecretId
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
          ~clientSecret={clientSecretId},
          ~logger=Some(logger),
          ~analyticsMetadata,
          ~customBackendUrl=options
          ->Option.getOr(JSON.Encode.null)
          ->getDictFromJson
          ->getString("customBackendUrl", ""),
          ~redirectionFlags,
        )
      }

      let paymentMethodsManagementElements = paymentMethodsManagementElementsOptions => {
        open Promise
        let paymentMethodsManagementElementsOptionsDict =
          paymentMethodsManagementElementsOptions->JSON.Decode.object
        paymentMethodsManagementElementsOptionsDict
        ->Option.forEach(x => x->Dict.set("launchTime", Date.now()->JSON.Encode.float))
        ->ignore

        let ephemeralKeyId =
          paymentMethodsManagementElementsOptionsDict
          ->Option.flatMap(x => x->Dict.get("ephemeralKey"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")

        let paymentMethodsManagementElementsOptions =
          paymentMethodsManagementElementsOptionsDict->Option.mapOr(
            paymentMethodsManagementElementsOptions,
            JSON.Encode.object,
          )
        ephemeralKey := ephemeralKeyId
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
          paymentMethodsManagementElementsOptions,
          setIframeRef,
          ~sdkSessionId=sessionID,
          ~publishableKey,
          ~ephemeralKey={ephemeralKeyId},
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
                Console.log("625 Hyper.res Inside handleMessage Some submitSuccessful")
                logApi(
                  ~apiLogType=Method,
                  ~optLogger=Some(logger),
                  ~result=val,
                  ~paymentMethod="confirmCardPayment",
                  ~eventName=CONFIRM_CARD_PAYMENT,
                )
                let url = decodedData->getString("return_url", "/")
                Console.log2("634 Hyper.res Inside handleMessage Some submitSuccessful url =>", url)
                if val->JSON.Decode.bool->Option.getOr(false) && url !== "/" {
                  Console.log3(
                    "636 Hyper.res Inside handleMessage val true and url",
                    url,
                    redirectionFlags->Identity.anyTypeToJson->JSON.stringify,
                  )
                  Utils.replaceRootHref(url, redirectionFlags)
                } else {
                  Console.log2("644 Hyper.res Inside handleMessage else", json->JSON.stringify)
                  resolve(json)
                }
              | None => {
                  Console.log2("647 Hyper.res Inside handleMessage None", json->JSON.stringify)
                  resolve(json)
                }
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

      let returnObject = {
        confirmOneClickPayment,
        confirmPayment,
        elements,
        widgets: elements,
        confirmCardPayment: confirmCardPaymentFn,
        retrievePaymentIntent: retrievePaymentIntentFn,
        paymentRequest,
        initPaymentSession,
        paymentMethodsManagementElements,
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
