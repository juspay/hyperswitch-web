open Types
open ErrorUtils
open LoggerUtils
open Utils
open EventListenerManager

external eventToJson: Types.eventData => Js.Json.t = "%identity"

let checkAndAppend = (selector, child) => {
  if Js.Nullable.toOption(CommonHooks.querySelector(selector)) == None {
    CommonHooks.appendChild(child)
  }
}

if (
  Window.querySelectorAll(`script[src="${GlobalVars.sentryScriptUrl}"]`)->Js.Array2.length === 0 &&
    Js.typeof(GlobalVars.sentryScriptUrl) !== "undefined"
) {
  try {
    let script = Window.createElement("script")
    script->Window.elementSrc(GlobalVars.sentryScriptUrl)
    script->Window.elementOnerror(err => {
      Js.log2("ERROR DURING LOADING Sentry on HyperLoader", err)
    })
    script->Window.elementOnload(() => {
      Sentry.initiateSentryJs(~dsn=GlobalVars.sentryDSN)
    })
    Window.window->Window.windowOnload(_ => {
      Window.body->Window.appendChild(script)
    })
  } catch {
  | e => Js.log2("Sentry load exited", e)
  }
}

let preloadFile = (~type_, ~href=``, ()) => {
  let link = CommonHooks.createElement("link")
  link.href = href
  link.\"as" = type_
  link.rel = "preload"
  link.crossorigin = "anonymous"
  checkAndAppend(`link[href="${href}"]`, link)
}

let preloader = () => {
  preloadFile(~type_="script", ~href=`${ApiEndpoint.sdkDomainUrl}/app.js`, ())
  preloadFile(~type_="style", ~href=`${ApiEndpoint.sdkDomainUrl}/app.css`, ())
  preloadFile(~type_="image", ~href=`${ApiEndpoint.sdkDomainUrl}/icons/orca.svg`, ())
  preloadFile(
    ~type_="style",
    ~href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;600;700;800&display=swap",
    (),
  )
  preloadFile(
    ~type_="style",
    ~href="https://fonts.googleapis.com/css2?family=Quicksand:wght@400;500;600;700&family=Qwitcher+Grypen:wght@400;700&display=swap",
    (),
  )
  preloadFile(
    ~type_="script",
    ~href="https://js.braintreegateway.com/web/3.88.4/js/paypal-checkout.min.js",
    (),
  )
  preloadFile(
    ~type_="script",
    ~href="https://js.braintreegateway.com/web/3.88.4/js/client.min.js",
    (),
  )
}

let make = (publishableKey, options: option<Js.Json.t>, analyticsInfo: option<Js.Json.t>) => {
  try {
    let isPreloadEnabled =
      options
      ->Belt.Option.getWithDefault(Js.Json.null)
      ->Utils.getDictFromJson
      ->Utils.getBool("isPreloadEnabled", true)
    let analyticsMetadata =
      options
      ->Belt.Option.getWithDefault(Js.Json.null)
      ->Utils.getDictFromJson
      ->Utils.getDictFromObj("analytics")
      ->Utils.getJsonObjectFromDict("metadata")
    if isPreloadEnabled {
      preloader()
    }
    let analyticsInfoDict =
      analyticsInfo
      ->Belt.Option.flatMap(Js.Json.decodeObject)
      ->Belt.Option.getWithDefault(Js.Dict.empty())
    let sessionID = analyticsInfoDict->getString("sessionID", "")
    let sdkTimestamp = analyticsInfoDict->getString("timeStamp", Js.Date.now()->Belt.Float.toString)
    let logger = OrcaLogger.make(
      ~sessionId=sessionID,
      ~source=Loader,
      ~merchantId=publishableKey,
      ~metadata=analyticsMetadata,
      (),
    )
    switch options {
    | Some(userOptions) =>
      let customBackendUrl =
        userOptions
        ->Js.Json.decodeObject
        ->Belt.Option.flatMap(x => x->Js.Dict.get("customBackendUrl"))
        ->Belt.Option.flatMap(Js.Json.decodeString)
        ->Belt.Option.getWithDefault("")
      customBackendUrl === "" ? () : ApiEndpoint.setApiEndPoint(customBackendUrl)
    | None => ()
    }

    {
      () => {
        logger.setMerchantId(publishableKey)
        logger.setSessionId(sessionID)
        logger.setLogInfo(~value=Window.href, ~eventName=APP_INITIATED, ~timestamp=sdkTimestamp, ())
      }
    }->Sentry.sentryLogger
    switch Window.getHyper->Js.Nullable.toOption {
    | Some(hyperMethod) => {
        logger.setLogInfo(
          ~value="orca-sdk initiated",
          ~eventName=APP_REINITIATED,
          ~timestamp=sdkTimestamp,
          (),
        )
        hyperMethod
      }
    | None =>
      let loaderTimestamp = Js.Date.now()->Belt.Float.toString

      {
        () => {
          logger.setLogInfo(
            ~value="loadHyper has been called",
            ~eventName=LOADER_CALLED,
            ~timestamp=loaderTimestamp,
            (),
          )
          if (
            publishableKey == "" ||
              !(
                publishableKey->Js.String2.startsWith("pk_snd_") ||
                  publishableKey->Js.String2.startsWith("pk_prd_")
              )
          ) {
            manageErrorWarning(INVALID_PK, (), ~logger)
          }

          if (
            Window.querySelectorAll(`script[src="https://applepay.cdn-apple.com/jsapi/v1/apple-pay-sdk.js"]`)->Js.Array2.length === 0
          ) {
            let scriptURL = "https://applepay.cdn-apple.com/jsapi/v1/apple-pay-sdk.js"
            let script = Window.createElement("script")
            script->Window.elementSrc(scriptURL)
            script->Window.elementOnerror(err => {
              Js.log2("ERROR DURING LOADING APPLE PAY", err)
            })
            Window.body->Window.appendChild(script)
          }
        }
      }->Sentry.sentryLogger

      if (
        Window.querySelectorAll(`script[src="https://pay.google.com/gp/p/js/pay.js"]`)->Js.Array2.length === 0
      ) {
        let googlePayScriptURL = "https://pay.google.com/gp/p/js/pay.js"
        let googlePayScript = Window.createElement("script")
        googlePayScript->Window.elementSrc(googlePayScriptURL)
        googlePayScript->Window.elementOnerror(err => {
          Utils.logInfo(Js.log2("ERROR DURING LOADING GOOGLE PAY SCRIPT", err))
        })
        Window.body->Window.appendChild(googlePayScript)
        logger.setLogInfo(~value="GooglePay Script Loaded", ~eventName=GOOGLE_PAY_SCRIPT, ())
      }

      let iframeRef = ref([])
      let clientSecret = ref("")
      let setIframeRef = ref => {
        iframeRef.contents->Js.Array2.push(ref)->ignore
      }

      let retrievePaymentIntentFn = clientSecret => {
        let headers = {
          "Accept": "application/json",
          "api-key": publishableKey,
        }
        let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey, ())
        let paymentIntentID = Js.String2.split(clientSecret, "_secret_")[0]->Option.getOr("")
        let retrievePaymentUrl = `${endpoint}/payments/${paymentIntentID}?client_secret=${clientSecret}`
        open Promise
        logApi(
          ~optLogger=Some(logger),
          ~url=retrievePaymentUrl,
          ~type_="request",
          ~eventName=RETRIEVE_CALL_INIT,
          ~logType=INFO,
          ~logCategory=API,
          (),
        )
        Fetch.fetch(
          retrievePaymentUrl,
          {
            method: #GET,
            headers: Fetch.Headers.fromObject(headers),
          },
        )
        ->then(resp => {
          let statusCode = resp->Fetch.Response.status->string_of_int
          if statusCode->Js.String2.charAt(0) !== "2" {
            resp
            ->Fetch.Response.json
            ->then(data => {
              logApi(
                ~optLogger=Some(logger),
                ~url=retrievePaymentUrl,
                ~data,
                ~statusCode,
                ~type_="err",
                ~eventName=RETRIEVE_CALL,
                ~logType=ERROR,
                ~logCategory=API,
                (),
              )
              resolve()
            })
            ->ignore
          } else {
            logApi(
              ~optLogger=Some(logger),
              ~url=retrievePaymentUrl,
              ~statusCode,
              ~type_="response",
              ~eventName=RETRIEVE_CALL,
              ~logType=INFO,
              ~logCategory=API,
              (),
            )
          }
          Fetch.Response.json(resp)
        })
        ->then(data => {
          [("paymentIntent", data)]->Js.Dict.fromArray->Js.Json.object_->Promise.resolve
        })
      }

      let confirmPaymentWrapper = (payload, isOneClick, result) => {
        let confirmParams =
          payload
          ->Js.Json.decodeObject
          ->Belt.Option.flatMap(x => x->Js.Dict.get("confirmParams"))
          ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)

        let redirect =
          payload
          ->Js.Json.decodeObject
          ->Belt.Option.flatMap(x => x->Js.Dict.get("redirect"))
          ->Belt.Option.flatMap(Js.Json.decodeString)
          ->Belt.Option.getWithDefault("if_required")

        let url =
          confirmParams
          ->Js.Json.decodeObject
          ->Belt.Option.flatMap(x => x->Js.Dict.get("return_url"))
          ->Belt.Option.flatMap(Js.Json.decodeString)
          ->Belt.Option.getWithDefault("")

        Js.Promise.make((~resolve, ~reject as _) => {
          let handleMessage = (event: Types.event) => {
            let json = event.data->eventToJson
            let dict = json->getDictFromJson

            switch dict->Js.Dict.get("submitSuccessful") {
            | Some(val) =>
              let message = [("submitSuccessful", val)]->Dict.fromArray
              iframeRef.contents->Array.forEach(ifR => {
                ifR->Window.iframePostMessage(message)
              })
              logApi(
                ~type_="method",
                ~optLogger=Some(logger),
                ~result=val,
                ~paymentMethod="confirmPayment",
                ~eventName=CONFIRM_PAYMENT,
                (),
              )
              let data =
                dict
                ->Js.Dict.get("data")
                ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
              let returnUrl =
                dict
                ->Js.Dict.get("url")
                ->Belt.Option.flatMap(Js.Json.decodeString)
                ->Belt.Option.getWithDefault(url)

              if isOneClick {
                iframeRef.contents->Js.Array2.forEach(ifR => {
                  // to unset one click button loader
                  ifR->Window.iframePostMessage(
                    [("oneClickDoSubmit", false->Js.Json.boolean)]->Js.Dict.fromArray,
                  )
                })
              }

              if (
                val->Js.Json.decodeBoolean->Belt.Option.getWithDefault(false) &&
                  redirect === "always"
              ) {
                Window.replace(returnUrl)
              } else if !(val->Js.Json.decodeBoolean->Belt.Option.getWithDefault(false)) {
                resolve(. json)
              } else {
                resolve(. data)
              }
            | None => ()
            }
          }
          let message = isOneClick
            ? [("oneClickDoSubmit", result->Js.Json.boolean)]->Js.Dict.fromArray
            : [
                ("doSubmit", true->Js.Json.boolean),
                ("clientSecret", clientSecret.contents->Js.Json.string),
                (
                  "confirmParams",
                  [
                    ("return_url", url->Js.Json.string),
                    ("publishableKey", publishableKey->Js.Json.string),
                  ]
                  ->Js.Dict.fromArray
                  ->Js.Json.object_,
                ),
              ]->Js.Dict.fromArray
          addSmartEventListener("message", handleMessage, "onSubmit")
          iframeRef.contents->Js.Array2.forEach(ifR => {
            ifR->Window.iframePostMessage(message)
          })
        })
      }

      let confirmPayment = payload => {
        confirmPaymentWrapper(payload, false, true)
      }

      let confirmOneClickPayment = (payload, result: bool) => {
        confirmPaymentWrapper(payload, true, result)
      }

      let handleSdkConfirm = (event: Types.event) => {
        let json = event.data->eventToJson
        let dict = json->getDictFromJson
        switch dict->Js.Dict.get("handleSdkConfirm") {
        | Some(payload) => confirmPayment(payload)->ignore
        | None => ()
        }
      }

      addSmartEventListener("message", handleSdkConfirm, "handleSdkConfirm")

      let elements = elementsOptions => {
        open Promise
        let clientSecretId =
          elementsOptions
          ->Js.Json.decodeObject
          ->Belt.Option.flatMap(x => x->Js.Dict.get("clientSecret"))
          ->Belt.Option.flatMap(Js.Json.decodeString)
          ->Belt.Option.getWithDefault("")
        clientSecret := clientSecretId
        Js.Promise.make((~resolve, ~reject as _) => {
          logger.setClientSecret(clientSecretId)
          resolve(. Js.Json.null)
        })
        ->then(_ => {
          logger.setLogInfo(~value=Window.href, ~eventName=ORCA_ELEMENTS_CALLED, ())
          resolve()
        })
        ->ignore

        Elements.make(
          elementsOptions,
          setIframeRef,
          ~sdkSessionId=sessionID,
          ~publishableKey,
          ~clientSecret={clientSecretId},
          ~logger=Some(logger),
          ~analyticsMetadata,
        )
      }
      let confirmCardPaymentFn =
        @this
        (
          _this: This.t,
          clientSecretId: string,
          data: option<Js.Json.t>,
          _options: option<Js.Json.t>,
        ) => {
          let decodedData =
            data
            ->Belt.Option.flatMap(Js.Json.decodeObject)
            ->Belt.Option.getWithDefault(Js.Dict.empty())
          Js.Promise.make((~resolve, ~reject as _) => {
            iframeRef.contents
            ->Js.Array2.map(iframe => {
              iframe->Window.iframePostMessage(
                [
                  ("doSubmit", true->Js.Json.boolean),
                  ("clientSecret", clientSecretId->Js.Json.string),
                  (
                    "confirmParams",
                    [("publishableKey", publishableKey->Js.Json.string)]
                    ->Js.Dict.fromArray
                    ->Js.Json.object_,
                  ),
                ]->Js.Dict.fromArray,
              )

              let handleMessage = (event: Types.event) => {
                let json = event.data->eventToJson
                let dict = json->getDictFromJson
                switch dict->Js.Dict.get("submitSuccessful") {
                | Some(val) =>
                  logApi(
                    ~type_="method",
                    ~optLogger=Some(logger),
                    ~result=val,
                    ~paymentMethod="confirmCardPayment",
                    ~eventName=CONFIRM_CARD_PAYMENT,
                    (),
                  )
                  let url = decodedData->getString("return_url", "/")
                  if val->Js.Json.decodeBoolean->Belt.Option.getWithDefault(false) && url !== "/" {
                    Window.replace(url)
                  } else {
                    resolve(. json)
                  }
                | None => resolve(. json)
                }
              }
              addSmartEventListener("message", handleMessage)
            })
            ->ignore
          })
        }

      let addAmountToDict = (dict, currency) => {
        if dict->Js.Dict.get("amount")->Belt.Option.isNone {
          Js.Console.error("Amount is not specified, please input an amount")
        }
        let amount = dict->Js.Dict.get("amount")->Belt.Option.getWithDefault(0.0->Js.Json.number)
        dict->Js.Dict.set(
          "amount",
          [("currency", currency), ("value", amount)]->Js.Dict.fromArray->Js.Json.object_,
        )
        Some(dict->Js.Json.object_)
      }
      let paymentRequest = options => {
        let optionsDict = options->getDictFromJson
        let currency = optionsDict->getJsonStringFromDict("currency", "")
        let optionsTotal =
          optionsDict
          ->Js.Dict.get("total")
          ->Belt.Option.flatMap(Js.Json.decodeObject)
          ->Belt.Option.flatMap(x => addAmountToDict(x, currency))
          ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
        let displayItems = optionsDict->getJsonArrayFromDict("displayItems", [])
        let requestPayerName = optionsDict->getJsonStringFromDict("requestPayerName", "")
        let requestPayerEmail = optionsDict->getJsonBoolValue("requestPayerEmail", false)
        let requestPayerPhone = optionsDict->getJsonBoolValue("requestPayerPhone", false)
        let requestShipping = optionsDict->getJsonBoolValue("requestShipping", false)

        let shippingOptions =
          optionsDict
          ->Js.Dict.get("shippingOptions")
          ->Belt.Option.flatMap(Js.Json.decodeObject)
          ->Belt.Option.flatMap(x => addAmountToDict(x, currency))
          ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)

        let applePayPaymentMethodData =
          [
            ("supportedMethods", "https://apple.com/apple-pay"->Js.Json.string),
            ("data", [("version", 12.00->Js.Json.number)]->Js.Dict.fromArray->Js.Json.object_),
          ]
          ->Js.Dict.fromArray
          ->Js.Json.object_
        let methodData = [applePayPaymentMethodData]->Js.Json.array
        let details =
          [
            ("id", publishableKey->Js.Json.string),
            ("displayItems", displayItems),
            ("total", optionsTotal),
            ("shippingOptions", shippingOptions),
          ]
          ->Js.Dict.fromArray
          ->Js.Json.object_

        let optionsForPaymentRequest =
          [
            ("requestPayerName", requestPayerName),
            ("requestPayerEmail", requestPayerEmail),
            ("requestPayerPhone", requestPayerPhone),
            ("requestShipping", requestShipping),
            ("shippingType", "shipping"->Js.Json.string),
          ]
          ->Js.Dict.fromArray
          ->Js.Json.object_
        Window.paymentRequest(methodData, details, optionsForPaymentRequest)
      }

      let initPaymentSession = paymentSessionOptions => {
        open Promise

        let clientSecretId =
          paymentSessionOptions
          ->Js.Json.decodeObject
          ->Belt.Option.flatMap(x => x->Js.Dict.get("clientSecret"))
          ->Belt.Option.flatMap(Js.Json.decodeString)
          ->Belt.Option.getWithDefault("")
        clientSecret := clientSecretId
        Js.Promise.make((~resolve, ~reject as _) => {
          logger.setClientSecret(clientSecretId)
          resolve(. Js.Json.null)
        })
        ->then(_ => {
          logger.setLogInfo(~value=Window.href, ~eventName=PAYMENT_SESSION_INITIATED, ())
          resolve()
        })
        ->ignore

        PaymentSession.make(
          paymentSessionOptions,
          ~clientSecret={clientSecretId},
          ~publishableKey,
          ~logger=Some(logger),
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
