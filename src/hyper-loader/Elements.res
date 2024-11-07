open Types
open ErrorUtils
open Identity
open Utils
open EventListenerManager

type trustPayFunctions = {
  finishApplePaymentV2: (string, ApplePayTypes.paymentRequestData) => promise<JSON.t>,
  executeGooglePayment: (string, GooglePayType.paymentDataRequest) => promise<JSON.t>,
}
@new external trustPayApi: JSON.t => trustPayFunctions = "TrustPayApi"

let make = (
  options,
  setIframeRef,
  ~clientSecret,
  ~sdkSessionId,
  ~publishableKey,
  ~logger: option<HyperLogger.loggerMake>,
  ~analyticsMetadata,
  ~customBackendUrl,
) => {
  try {
    let iframeRef = []
    let logger = logger->Option.getOr(HyperLogger.defaultLoggerConfig)
    let savedPaymentElement = Dict.make()
    let localOptions = options->JSON.Decode.object->Option.getOr(Dict.make())

    let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)
    let redirect = ref("if_required")

    let appearance =
      localOptions->Dict.get("appearance")->Option.getOr(Dict.make()->JSON.Encode.object)
    let launchTime = localOptions->getFloat("launchTime", 0.0)

    let fonts =
      localOptions
      ->Dict.get("fonts")
      ->Option.flatMap(JSON.Decode.array)
      ->Option.getOr([])
      ->JSON.Encode.array

    let blockConfirm =
      GlobalVars.isInteg &&
      options
      ->JSON.Decode.object
      ->Option.flatMap(x => x->Dict.get("blockConfirm"))
      ->Option.flatMap(JSON.Decode.bool)
      ->Option.getOr(false)
    let customPodUri =
      options
      ->JSON.Decode.object
      ->Option.flatMap(x => x->Dict.get("customPodUri"))
      ->Option.flatMap(JSON.Decode.string)
      ->Option.getOr("")

    let merchantHostname = Window.Location.hostname

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
              id="orca-payment-element-iframeRef-${localSelectorString}"
              name="orca-payment-element-iframeRef-${localSelectorString}"
              src="${ApiEndpoint.sdkDomainUrl}/index.html?fullscreenType=${componentType}&publishableKey=${publishableKey}&clientSecret=${clientSecret}&sessionId=${sdkSessionId}&endpoint=${endpoint}&merchantHostname=${merchantHostname}&customPodUri=${customPodUri}"              allow="*"
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

    let locale = localOptions->getJsonStringFromDict("locale", "")
    let loader = localOptions->getJsonStringFromDict("loader", "")
    let clientSecret = localOptions->getRequiredString("clientSecret", "", ~logger)
    let clientSecretReMatch = Re.test(`.+_secret_[A-Za-z0-9]+`->Re.fromString, clientSecret)

    let preMountLoaderIframeDiv = mountPreMountLoaderIframe()
    let isTaxCalculationEnabled = ref(false)

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

    let onPlaidCallback = mountedIframeRef => {
      (ev: Types.event) => {
        let json = ev.data->Identity.anyTypeToJson
        let dict = json->getDictFromJson
        let isPlaidExist = dict->getBool("isPlaid", false)
        if isPlaidExist {
          mountedIframeRef->Window.iframePostMessage(
            [("isPlaid", true->JSON.Encode.bool), ("data", json)]->Dict.fromArray,
          )
        }
      }
    }

    let onPazeCallback = (event: Types.event) => {
      let json = event.data->Identity.anyTypeToJson
      let dict = json->getDictFromJson
      if dict->getBool("isPaze", false) {
        let componentName = dict->getString("componentName", "payment")
        let msg = [("data", json)]->Dict.fromArray
        handlePazeIframePostMessage(msg, componentName, event.source)
      }
    }

    let fetchPaymentsList = (mountedIframeRef, componentType) => {
      let handlePaymentMethodsLoaded = (event: Types.event) => {
        let json = event.data->Identity.anyTypeToJson
        let dict = json->getDictFromJson
        let isPaymentMethodsData = dict->getString("data", "") === "payment_methods"
        if isPaymentMethodsData {
          isTaxCalculationEnabled.contents =
            dict->getDictFromDict("response")->getBool("is_tax_calculation_enabled", false)
          addSmartEventListener("message", onPlaidCallback(mountedIframeRef), "onPlaidCallback")
          addSmartEventListener("message", onPazeCallback, "onPazeCallback")

          let json = dict->getJsonFromDict("response", JSON.Encode.null)
          let isApplePayPresent = PaymentMethodsRecord.getPaymentMethodTypeFromList(
            ~paymentMethodListValue=json
            ->getDictFromJson
            ->PaymentMethodsRecord.itemToObjMapper,
            ~paymentMethod="wallet",
            ~paymentMethodType="apple_pay",
          )->Option.isSome

          let isGooglePayPresent = PaymentMethodsRecord.getPaymentMethodTypeFromList(
            ~paymentMethodListValue=json
            ->getDictFromJson
            ->PaymentMethodsRecord.itemToObjMapper,
            ~paymentMethod="wallet",
            ~paymentMethodType="google_pay",
          )->Option.isSome

          if isApplePayPresent || isGooglePayPresent {
            if (
              Window.querySelectorAll(`script[src="https://tpgw.trustpay.eu/js/v1.js"]`)->Array.length === 0 &&
                Window.querySelectorAll(`script[src="https://test-tpgw.trustpay.eu/js/v1.js"]`)->Array.length === 0
            ) {
              let trustPayScriptURL =
                publishableKey->String.startsWith("pk_prd_")
                  ? "https://tpgw.trustpay.eu/js/v1.js"
                  : "https://test-tpgw.trustpay.eu/js/v1.js"
              let trustPayScript = Window.createElement("script")
              logger.setLogInfo(~value="TrustPay Script Loading", ~eventName=TRUSTPAY_SCRIPT)
              trustPayScript->Window.elementSrc(trustPayScriptURL)
              trustPayScript->Window.elementOnerror(err => {
                logInfo(Console.log2("ERROR DURING LOADING TRUSTPAY APPLE PAY", err))
              })
              trustPayScript->Window.elementOnload(_ => {
                logger.setLogInfo(~value="TrustPay Script Loaded", ~eventName=TRUSTPAY_SCRIPT)
              })
              Window.body->Window.appendChild(trustPayScript)
            }
          }
          let msg = [("paymentMethodList", json)]->Dict.fromArray
          mountedIframeRef->Window.iframePostMessage(msg)
        }
      }
      let msg = [("sendPaymentMethodsResponse", true->JSON.Encode.bool)]->Dict.fromArray
      addSmartEventListener(
        "message",
        handlePaymentMethodsLoaded,
        `onPaymentMethodsLoaded-${componentType}`,
      )
      preMountLoaderIframeDiv->Window.iframePostMessage(msg)
    }

    let fetchCustomerPaymentMethods = (
      mountedIframeRef,
      disableSavedPaymentMethods,
      componentType,
    ) => {
      if !disableSavedPaymentMethods {
        let handleCustomerPaymentMethodsLoaded = (event: Types.event) => {
          let json = event.data->Identity.anyTypeToJson
          let dict = json->getDictFromJson
          let isCustomerPaymentMethodsData =
            dict->getString("data", "") === "customer_payment_methods"
          if isCustomerPaymentMethodsData {
            let json = dict->getJsonFromDict("response", JSON.Encode.null)
            let msg = [("customerPaymentMethods", json)]->Dict.fromArray
            mountedIframeRef->Window.iframePostMessage(msg)
          }
        }
        addSmartEventListener(
          "message",
          handleCustomerPaymentMethodsLoaded,
          `onCustomerPaymentMethodsLoaded-${componentType}`,
        )
      }
      let msg =
        [
          ("sendCustomerPaymentMethodsResponse", !disableSavedPaymentMethods->JSON.Encode.bool),
        ]->Dict.fromArray
      preMountLoaderIframeDiv->Window.iframePostMessage(msg)
    }

    !clientSecretReMatch
      ? manageErrorWarning(
          INVALID_FORMAT,
          ~dynamicStr="clientSecret is expected to be in format ******_secret_*****",
          ~logger,
        )
      : ()

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
      switch newOptionsDict->Dict.get("clientSecret") {
      | Some(val) => localOptions->Dict.set("clientSecret", val)
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
      | "card"
      | "cardNumber"
      | "cardExpiry"
      | "cardCvc"
      | "paymentMethodCollect"
      | "googlePay"
      | "payPal"
      | "applePay"
      | "klarna"
      | "expressCheckout"
      | "paze"
      | "paymentMethodsManagement"
      | "payment" => ()
      | str => manageErrorWarning(UNKNOWN_KEY, ~dynamicStr=`${str} type in create`, ~logger)
      }

      let mountPostMessage = (
        mountedIframeRef,
        selectorString,
        sdkHandleOneClickConfirmPayment,
      ) => {
        open Promise

        let widgetOptions =
          [
            ("clientSecret", clientSecret->JSON.Encode.string),
            ("appearance", appearance),
            ("locale", locale),
            ("loader", loader),
            ("fonts", fonts),
          ]->getJsonFromArrayOfJson
        let message = [
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
          ("blockConfirm", blockConfirm->JSON.Encode.bool),
          ("customPodUri", customPodUri->JSON.Encode.string),
          ("sdkHandleOneClickConfirmPayment", sdkHandleOneClickConfirmPayment->JSON.Encode.bool),
          ("parentURL", "*"->JSON.Encode.string),
          ("analyticsMetadata", analyticsMetadata),
          ("launchTime", launchTime->JSON.Encode.float),
          ("customBackendUrl", customBackendUrl->JSON.Encode.string),
          (
            "isPaymentButtonHandlerProvided",
            LoaderPaymentElement.isPaymentButtonHandlerProvided.contents->JSON.Encode.bool,
          ),
          (
            "onCompleteDoThisUsed",
            EventListenerManager.eventListenerMap
            ->Dict.get("onCompleteDoThis")
            ->Option.isSome
            ->JSON.Encode.bool,
          ),
        ]->Dict.fromArray

        let wallets = PaymentType.getWallets(newOptions->getDictFromJson, "wallets", logger)

        let handleApplePayMounted = (event: Types.event) => {
          let json = event.data->anyTypeToJson
          let dict = json->getDictFromJson
          let componentName = getString(dict, "componentName", "payment")

          if dict->Dict.get("applePayMounted")->Option.isSome {
            if wallets.applePay === Auto {
              switch ApplePayTypes.sessionForApplePay->Nullable.toOption {
              | Some(session) =>
                try {
                  if session.canMakePayments() {
                    let msg = [
                      ("hyperApplePayCanMakePayments", true->JSON.Encode.bool),
                      ("componentName", componentName->JSON.Encode.string),
                    ]
                    messageTopWindow(msg)
                  } else {
                    Console.log("CANNOT MAKE PAYMENT USING APPLE PAY")
                    logger.setLogInfo(
                      ~value="CANNOT MAKE PAYMENT USING APPLE PAY",
                      ~eventName=APPLE_PAY_FLOW,
                      ~paymentMethod="APPLE_PAY",
                      ~logType=ERROR,
                    )
                  }
                } catch {
                | exn => {
                    let exnString = exn->anyTypeToJson->JSON.stringify
                    Console.log("CANNOT MAKE PAYMENT USING APPLE PAY: " ++ exnString)
                    logger.setLogInfo(
                      ~value=exnString,
                      ~eventName=APPLE_PAY_FLOW,
                      ~paymentMethod="APPLE_PAY",
                      ~logType=ERROR,
                    )
                  }
                }
              | None => ()
              }
            } else {
              logger.setLogInfo(
                ~value="ApplePay is set as 'never' by merchant",
                ~eventName=APPLE_PAY_FLOW,
                ~paymentMethod="APPLE_PAY",
                ~logType=INFO,
              )
            }
          } else if dict->Dict.get("applePayCanMakePayments")->Option.isSome {
            let applePayCanMakePayments = getBool(dict, "applePayCanMakePayments", false)

            if applePayCanMakePayments {
              try {
                let msg = [("applePayCanMakePayments", true->JSON.Encode.bool)]->Dict.fromArray

                handleApplePayIframePostMessage(msg, componentName, mountedIframeRef)
              } catch {
              | exn => {
                  let exnString = exn->anyTypeToJson->JSON.stringify

                  Console.log("CANNOT MAKE PAYMENT USING APPLE PAY: " ++ exnString)
                  logger.setLogInfo(
                    ~value=exnString,
                    ~eventName=APPLE_PAY_FLOW,
                    ~paymentMethod="APPLE_PAY",
                    ~logType=ERROR,
                  )
                }
              }
            }
          }
        }

        let handleGooglePayThirdPartyFlow = (event: Types.event) => {
          let json = event.data->anyTypeToJson
          let dict = json->getDictFromJson

          switch dict->Dict.get("googlePayThirdPartyFlow") {
          | Some(googlePayThirdPartyOptSession) => {
              let googlePayThirdPartySession = googlePayThirdPartyOptSession->getDictFromJson

              let baseDetails = {
                "apiVersion": 2,
                "apiVersionMinor": 0,
                "environment": publishableKey->String.startsWith("pk_prd_") ? "PRODUCTION" : "TEST",
              }

              let paymentDataRequest = GooglePayType.assign2(
                Dict.make()->JSON.Encode.object,
                baseDetails->anyTypeToJson,
              )

              let googlePayRequest =
                paymentDataRequest->GooglePayType.jsonToPaymentRequestDataType(
                  googlePayThirdPartySession,
                )

              let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]

              let connector =
                googlePayThirdPartySession
                ->Dict.get("connector")
                ->Option.getOr(JSON.Encode.null)
                ->JSON.Decode.string
                ->Option.getOr("")

              try {
                switch connector {
                | "trustpay" => {
                    let secrets =
                      googlePayThirdPartySession->getJsonFromDict("secrets", JSON.Encode.null)

                    let payment = secrets->getDictFromJson->getString("payment", "")

                    let trustpay = trustPayApi(secrets)

                    let polling =
                      delay(2000)->then(_ =>
                        PaymentHelpers.pollRetrievePaymentIntent(
                          clientSecret,
                          headers,
                          ~optLogger=Some(logger),
                          ~customPodUri,
                          ~isForceSync=true,
                        )
                      )
                    let executeGooglePayment = trustpay.executeGooglePayment(
                      payment,
                      googlePayRequest,
                    )
                    let timeOut = delay(600000)->then(_ => {
                      let errorMsg =
                        [("error", "Request Timed Out"->JSON.Encode.string)]->getJsonFromArrayOfJson
                      reject(Exn.anyToExnInternal(errorMsg))
                    })

                    Promise.race([polling, executeGooglePayment, timeOut])
                    ->then(res => {
                      logger.setLogInfo(
                        ~value="TrustPay GooglePay Response",
                        ~internalMetadata=res->JSON.stringify,
                        ~eventName=GOOGLE_PAY_FLOW,
                        ~paymentMethod="GOOGLE_PAY",
                      )
                      let value = "Payment Data Filled: New Payment Method"
                      logger.setLogInfo(
                        ~value,
                        ~eventName=PAYMENT_DATA_FILLED,
                        ~paymentMethod="GOOGLE_PAY",
                      )
                      let msg = [("googlePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                      event.source->Window.sendPostMessage(msg)
                      resolve()
                    })
                    ->catch(err => {
                      let exceptionMessage = err->formatException->JSON.stringify
                      logger.setLogInfo(
                        ~value=exceptionMessage,
                        ~eventName=GOOGLE_PAY_FLOW,
                        ~paymentMethod="GOOGLE_PAY",
                        ~logType=ERROR,
                        ~logCategory=USER_ERROR,
                      )
                      let msg = [("googlePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                      event.source->Window.sendPostMessage(msg)
                      resolve()
                    })
                    ->ignore
                  }
                | _ => ()
                }
              } catch {
              | err => {
                  let exceptionMessage = err->formatException->JSON.stringify
                  logger.setLogInfo(
                    ~value=exceptionMessage,
                    ~eventName=GOOGLE_PAY_FLOW,
                    ~paymentMethod="GOOGLE_PAY",
                    ~logType=ERROR,
                    ~logCategory=USER_ERROR,
                  )
                  let msg = [("googlePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                  event.source->Window.sendPostMessage(msg)
                }
              }
            }
          | _ => ()
          }
        }

        let handleApplePayThirdPartyFlow = (event: Types.event) => {
          let json = event.data->Identity.anyTypeToJson
          let dict = json->getDictFromJson
          switch dict->Dict.get("applePayButtonClicked") {
          | Some(val) =>
            if val->JSON.Decode.bool->Option.getOr(false) {
              let applePaySessionTokenData =
                dict
                ->Dict.get("applePayPresent")
                ->Belt.Option.flatMap(JSON.Decode.object)
                ->Option.getOr(Dict.make())

              let isDelayedSessionToken =
                applePaySessionTokenData
                ->Dict.get("delayed_session_token")
                ->Option.getOr(JSON.Encode.null)
                ->JSON.Decode.bool
                ->Option.getOr(false)

              if isDelayedSessionToken {
                logger.setLogInfo(
                  ~value="Delayed Session Token Flow",
                  ~eventName=APPLE_PAY_FLOW,
                  ~paymentMethod="APPLE_PAY",
                )

                let connector =
                  applePaySessionTokenData
                  ->Dict.get("connector")
                  ->Option.getOr(JSON.Encode.null)
                  ->JSON.Decode.string
                  ->Option.getOr("")

                switch connector {
                | "trustpay" =>
                  logger.setLogInfo(
                    ~value="TrustPay Connector Flow",
                    ~eventName=APPLE_PAY_FLOW,
                    ~paymentMethod="APPLE_PAY",
                  )
                  let secrets =
                    applePaySessionTokenData
                    ->Dict.get("session_token_data")
                    ->Option.getOr(JSON.Encode.null)
                    ->JSON.Decode.object
                    ->Option.getOr(Dict.make())
                    ->Dict.get("secrets")
                    ->Option.getOr(JSON.Encode.null)

                  let paymentRequest =
                    applePaySessionTokenData
                    ->Dict.get("payment_request_data")
                    ->Belt.Option.flatMap(JSON.Decode.object)
                    ->Option.getOr(Dict.make())
                    ->ApplePayTypes.jsonToPaymentRequestDataType

                  let payment =
                    secrets
                    ->JSON.Decode.object
                    ->Option.getOr(Dict.make())
                    ->Dict.get("payment")
                    ->Option.getOr(JSON.Encode.null)
                    ->JSON.Decode.string
                    ->Option.getOr("")

                  try {
                    let trustpay = trustPayApi(secrets)
                    trustpay.finishApplePaymentV2(payment, paymentRequest)
                    ->then(res => {
                      let value = "Payment Data Filled: New Payment Method"
                      logger.setLogInfo(
                        ~value,
                        ~eventName=PAYMENT_DATA_FILLED,
                        ~paymentMethod="APPLE_PAY",
                      )
                      logger.setLogInfo(
                        ~value="TrustPay ApplePay Success Response",
                        ~internalMetadata=res->JSON.stringify,
                        ~eventName=APPLE_PAY_FLOW,
                        ~paymentMethod="APPLE_PAY",
                      )
                      let msg = [("applePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                      event.source->Window.sendPostMessage(msg)
                      resolve()
                    })
                    ->catch(err => {
                      let exceptionMessage = err->formatException->JSON.stringify
                      logger.setLogInfo(
                        ~eventName=APPLE_PAY_FLOW,
                        ~paymentMethod="APPLE_PAY",
                        ~value=exceptionMessage,
                      )
                      let msg = [("applePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                      event.source->Window.sendPostMessage(msg)
                      resolve()
                    })
                    ->ignore
                  } catch {
                  | exn => {
                      logger.setLogInfo(
                        ~value=exn->formatException->JSON.stringify,
                        ~eventName=APPLE_PAY_FLOW,
                        ~paymentMethod="APPLE_PAY",
                      )
                      let msg = [("applePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                      event.source->Window.sendPostMessage(msg)
                    }
                  }
                | _ => ()
                }
              }
            } else {
              ()
            }
          | None => ()
          }
        }

        let handlePollStatusMessage = (ev: Types.event) => {
          let eventDataObject = ev.data->anyTypeToJson
          let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
          switch eventDataObject->getOptionalJsonFromJson("confirmParams") {
          | Some(obj) => redirect := obj->getDictFromJson->getString("redirect", "if_required")
          | None => ()
          }

          let handleRetrievePaymentResponse = json => {
            let dict = json->getDictFromJson
            let status = dict->getString("status", "")
            let returnUrl = dict->getString("return_url", "")
            let redirectUrl = `${returnUrl}?payment_intent_client_secret=${clientSecret}&status=${status}`
            if redirect.contents === "always" {
              Window.replaceRootHref(redirectUrl)
              resolve(JSON.Encode.null)
            } else {
              messageCurrentWindow([
                ("submitSuccessful", true->JSON.Encode.bool),
                ("data", json),
                ("url", redirectUrl->JSON.Encode.string),
              ])
              resolve(json)
            }
          }

          switch eventDataObject->getOptionalJsonFromJson("poll_status") {
          | Some(val) => {
              messageCurrentWindow([
                ("fullscreen", true->JSON.Encode.bool),
                ("param", "paymentloader"->JSON.Encode.string),
                ("iframeId", selectorString->JSON.Encode.string),
              ])
              let dict = val->getDictFromJson
              let pollId = dict->getString("poll_id", "")
              let interval =
                dict->getString("delay_in_secs", "")->Int.fromString->Option.getOr(1) * 1000
              let count = dict->getString("frequency", "")->Int.fromString->Option.getOr(5)
              let url = dict->getString("return_url_with_query_params", "")

              let handleErrorResponse = err => {
                if redirect.contents === "always" {
                  Window.replaceRootHref(url)
                }
                messageCurrentWindow([
                  ("submitSuccessful", false->JSON.Encode.bool),
                  ("error", err->Identity.anyTypeToJson),
                  ("url", url->JSON.Encode.string),
                ])
              }

              PaymentHelpers.pollStatus(
                ~headers,
                ~customPodUri,
                ~pollId,
                ~interval,
                ~count,
                ~returnUrl=url,
                ~logger,
              )
              ->then(_ => {
                PaymentHelpers.retrievePaymentIntent(
                  clientSecret,
                  headers,
                  ~optLogger=Some(logger),
                  ~customPodUri,
                  ~isForceSync=true,
                )
                ->then(json => json->handleRetrievePaymentResponse)
                ->catch(err => {
                  err->handleErrorResponse
                  resolve(err->Identity.anyTypeToJson)
                })
                ->ignore
                ->resolve
              })
              ->catch(err => {
                err->handleErrorResponse
                resolve()
              })
              ->finally(_ => messageCurrentWindow([("fullscreen", false->JSON.Encode.bool)]))
              ->ignore
            }
          | None => ()
          }

          switch eventDataObject->getOptionalJsonFromJson("openurl_if_required") {
          | Some(redirectUrl) =>
            messageCurrentWindow([
              ("fullscreen", true->JSON.Encode.bool),
              ("param", "paymentloader"->JSON.Encode.string),
              ("iframeId", selectorString->JSON.Encode.string),
            ])
            PaymentHelpers.retrievePaymentIntent(
              clientSecret,
              headers,
              ~optLogger=Some(logger),
              ~customPodUri,
              ~isForceSync=true,
            )
            ->then(json => json->handleRetrievePaymentResponse)
            ->catch(err => {
              if redirect.contents === "always" {
                Window.replaceRootHref(redirectUrl->JSON.Decode.string->Option.getOr(""))
                resolve(JSON.Encode.null)
              } else {
                messageCurrentWindow([
                  ("submitSuccessful", false->JSON.Encode.bool),
                  ("error", err->Identity.anyTypeToJson),
                  ("url", redirectUrl),
                ])
                resolve(err->Identity.anyTypeToJson)
              }
            })
            ->finally(_ => messageCurrentWindow([("fullscreen", false->JSON.Encode.bool)]))
            ->ignore

          | None => ()
          }
        }

        addSmartEventListener("message", handleApplePayMounted, "onApplePayMount")
        addSmartEventListener("message", handlePollStatusMessage, "onPollStatusMsg")
        addSmartEventListener("message", handleGooglePayThirdPartyFlow, "onGooglePayThirdParty")
        addSmartEventListener("message", handleApplePayThirdPartyFlow, "onApplePayThirdParty")

        let fetchSessionTokens = mountedIframeRef => {
          let handleSessionTokensLoaded = (event: Types.event) => {
            let json = event.data->Identity.anyTypeToJson
            let dict = json->getDictFromJson
            let sessionTokensData = dict->getString("data", "") === "session_tokens"
            if sessionTokensData {
              let json = dict->getJsonFromDict("response", JSON.Encode.null)

              {
                let sessionsArr =
                  json
                  ->JSON.Decode.object
                  ->Option.getOr(Dict.make())
                  ->SessionsType.getSessionsTokenJson("session_token")

                let applePayPresent = sessionsArr->Array.find(item => {
                  let x =
                    item
                    ->JSON.Decode.object
                    ->Belt.Option.flatMap(x => {
                      x->Dict.get("wallet_name")
                    })
                    ->Belt.Option.flatMap(JSON.Decode.string)
                    ->Option.getOr("")
                  x === "apple_pay" || x === "applepay"
                })
                if !(applePayPresent->Option.isSome) {
                  let msg =
                    [("applePaySessionObjNotPresent", true->JSON.Encode.bool)]->Dict.fromArray
                  mountedIframeRef->Window.iframePostMessage(msg)
                }
                let googlePayPresent = sessionsArr->Array.find(item => {
                  let x =
                    item
                    ->JSON.Decode.object
                    ->Belt.Option.flatMap(x => {
                      x->Dict.get("wallet_name")
                    })
                    ->Belt.Option.flatMap(JSON.Decode.string)
                    ->Option.getOr("")
                  x === "google_pay" || x === "googlepay"
                })

                (json, applePayPresent, googlePayPresent)->resolve
              }
              ->then(res => {
                let (json, applePayPresent, googlePayPresent) = res
                if (
                  componentType->getIsComponentTypeForPaymentElementCreate &&
                    applePayPresent->Option.isSome
                ) {
                  let handleApplePayMessages = (applePayEvent: Types.event) => {
                    let json = applePayEvent.data->Identity.anyTypeToJson
                    let dict = json->getDictFromJson
                    let componentName = dict->getString("componentName", "payment")

                    switch (
                      dict->Dict.get("applePayButtonClicked"),
                      dict->Dict.get("applePayPaymentRequest"),
                      dict
                      ->Dict.get("isTaxCalculationEnabled")
                      ->Option.flatMap(JSON.Decode.bool)
                      ->Option.getOr(false),
                    ) {
                    | (Some(val), Some(paymentRequest), isTaxCalculationEnabled) =>
                      if val->JSON.Decode.bool->Option.getOr(false) {
                        let isDelayedSessionToken =
                          applePayPresent
                          ->Belt.Option.flatMap(JSON.Decode.object)
                          ->Option.getOr(Dict.make())
                          ->Dict.get("delayed_session_token")
                          ->Option.getOr(JSON.Encode.null)
                          ->JSON.Decode.bool
                          ->Option.getOr(false)
                        if !isDelayedSessionToken {
                          logger.setLogInfo(
                            ~value="Normal Session Token Flow",
                            ~eventName=APPLE_PAY_FLOW,
                            ~paymentMethod="APPLE_PAY",
                          )

                          let msg = [
                            ("hyperApplePayButtonClicked", true->JSON.Encode.bool),
                            ("paymentRequest", paymentRequest),
                            ("applePayPresent", applePayPresent->Option.getOr(JSON.Encode.null)),
                            ("clientSecret", clientSecret->JSON.Encode.string),
                            ("publishableKey", publishableKey->JSON.Encode.string),
                            ("isTaxCalculationEnabled", isTaxCalculationEnabled->JSON.Encode.bool),
                            ("sdkSessionId", sdkSessionId->JSON.Encode.string),
                            ("analyticsMetadata", analyticsMetadata),
                            ("componentName", componentName->JSON.Encode.string),
                          ]
                          messageTopWindow(msg)
                        }
                      }
                    | _ => ()
                    }

                    if dict->Dict.get("applePayPaymentToken")->Option.isSome {
                      let token = dict->getJsonFromDict("applePayPaymentToken", JSON.Encode.null)
                      let billingContact =
                        dict->getJsonFromDict("applePayBillingContact", JSON.Encode.null)
                      let shippingContact =
                        dict->getJsonFromDict("applePayShippingContact", JSON.Encode.null)

                      let msg =
                        [
                          ("applePayPaymentToken", token),
                          ("applePayBillingContact", billingContact),
                          ("applePayShippingContact", shippingContact),
                        ]->Dict.fromArray

                      handleApplePayIframePostMessage(msg, componentName, mountedIframeRef)
                    }

                    if dict->Dict.get("showApplePayButton")->Option.isSome {
                      let msg = [("showApplePayButton", true->JSON.Encode.bool)]->Dict.fromArray

                      handleApplePayIframePostMessage(msg, componentName, mountedIframeRef)
                    }
                  }

                  addSmartEventListener("message", handleApplePayMessages, "onApplePayMessages")
                }
                if (
                  componentType->getIsComponentTypeForPaymentElementCreate &&
                  googlePayPresent->Option.isSome &&
                  wallets.googlePay === Auto
                ) {
                  let dict = json->getDictFromJson
                  let sessionObj = SessionsType.itemToObjMapper(dict, Others)
                  let gPayToken = SessionsType.getPaymentSessionObj(sessionObj.sessionsToken, Gpay)

                  let tokenObj = switch gPayToken {
                  | OtherTokenOptional(optToken) => optToken
                  | _ => Some(SessionsType.defaultToken)
                  }

                  let gpayobj = switch tokenObj {
                  | Some(val) => val
                  | _ => SessionsType.defaultToken
                  }

                  let payRequest = GooglePayType.assign(
                    Dict.make()->JSON.Encode.object,
                    GooglePayType.baseRequest->Identity.anyTypeToJson,
                    {
                      "allowedPaymentMethods": gpayobj.allowed_payment_methods->arrayJsonToCamelCase,
                    }->Identity.anyTypeToJson,
                  )

                  try {
                    let transactionInfo = gpayobj.transaction_info->getDictFromJson

                    let onPaymentDataChanged = intermediatePaymentData => {
                      let shippingAddress =
                        intermediatePaymentData
                        ->getDictFromJson
                        ->getDictFromDict("shippingAddress")
                        ->ApplePayTypes.billingContactItemToObjMapper
                      let newShippingAddress =
                        [
                          ("state", shippingAddress.administrativeArea->JSON.Encode.string),
                          ("country", shippingAddress.countryCode->JSON.Encode.string),
                          ("zip", shippingAddress.postalCode->JSON.Encode.string),
                        ]->getJsonFromArrayOfJson

                      let paymentMethodType = "google_pay"->JSON.Encode.string

                      let currentPaymentRequest = [
                        (
                          "newTransactionInfo",
                          [
                            (
                              "countryCode",
                              transactionInfo
                              ->getString("country_code", "")
                              ->JSON.Encode.string,
                            ),
                            (
                              "currencyCode",
                              transactionInfo
                              ->getString("currency_code", "")
                              ->JSON.Encode.string,
                            ),
                            ("totalPriceStatus", "FINAL"->JSON.Encode.string),
                            (
                              "totalPrice",
                              transactionInfo
                              ->getString("total_price", "")
                              ->JSON.Encode.string,
                            ),
                          ]->getJsonFromArrayOfJson,
                        ),
                      ]->getJsonFromArrayOfJson

                      if isTaxCalculationEnabled.contents {
                        TaxCalculation.calculateTax(
                          ~shippingAddress=[
                            ("address", newShippingAddress),
                          ]->getJsonFromArrayOfJson,
                          ~logger,
                          ~publishableKey,
                          ~clientSecret,
                          ~paymentMethodType,
                        )->then(resp => {
                          switch resp->TaxCalculation.taxResponseToObjMapper {
                          | Some(taxCalculationResponse) => {
                              let updatePaymentRequest = [
                                (
                                  "newTransactionInfo",
                                  [
                                    (
                                      "countryCode",
                                      shippingAddress.countryCode->JSON.Encode.string,
                                    ),
                                    (
                                      "currencyCode",
                                      transactionInfo
                                      ->getString("currency_code", "")
                                      ->JSON.Encode.string,
                                    ),
                                    ("totalPriceStatus", "FINAL"->JSON.Encode.string),
                                    (
                                      "totalPrice",
                                      taxCalculationResponse.net_amount
                                      ->minorUnitToString
                                      ->JSON.Encode.string,
                                    ),
                                  ]->getJsonFromArrayOfJson,
                                ),
                              ]->getJsonFromArrayOfJson
                              updatePaymentRequest->resolve
                            }
                          | None => currentPaymentRequest->resolve
                          }
                        })
                      } else {
                        currentPaymentRequest->resolve
                      }
                    }
                    let gpayClientRequest = if componentType->getIsExpressCheckoutComponent {
                      {
                        "environment": publishableKey->String.startsWith("pk_prd_")
                          ? "PRODUCTION"
                          : "TEST",
                        "paymentDataCallbacks": {
                          "onPaymentDataChanged": onPaymentDataChanged,
                        },
                      }->Identity.anyTypeToJson
                    } else {
                      {
                        "environment": publishableKey->String.startsWith("pk_prd_")
                          ? "PRODUCTION"
                          : "TEST",
                      }->Identity.anyTypeToJson
                    }
                    let gPayClient = GooglePayType.google(gpayClientRequest)

                    gPayClient.isReadyToPay(payRequest)
                    ->then(res => {
                      let dict = res->getDictFromJson
                      let isReadyToPay = getBool(dict, "result", false)
                      let msg = [("isReadyToPay", isReadyToPay->JSON.Encode.bool)]->Dict.fromArray
                      mountedIframeRef->Window.iframePostMessage(msg)
                      resolve()
                    })
                    ->catch(err => {
                      logger.setLogInfo(
                        ~value=err->Identity.anyTypeToJson->JSON.stringify,
                        ~eventName=GOOGLE_PAY_FLOW,
                        ~paymentMethod="GOOGLE_PAY",
                        ~logType=DEBUG,
                      )
                      resolve()
                    })
                    ->ignore

                    let handleGooglePayMessages = (event: Types.event) => {
                      let evJson = event.data->anyTypeToJson

                      let gpayClicked =
                        evJson
                        ->getOptionalJsonFromJson("GpayClicked")
                        ->getBoolFromOptionalJson(false)

                      let paymentDataRequest =
                        evJson
                        ->getOptionalJsonFromJson("GpayPaymentDataRequest")
                        ->Option.getOr(JSON.Encode.null)

                      if gpayClicked && paymentDataRequest !== JSON.Encode.null {
                        setTimeout(() => {
                          gPayClient.loadPaymentData(paymentDataRequest)
                          ->then(
                            json => {
                              let msg = [("gpayResponse", json->anyTypeToJson)]->Dict.fromArray
                              event.source->Window.sendPostMessage(msg)
                              let value = "Payment Data Filled: New Payment Method"
                              logger.setLogInfo(
                                ~value,
                                ~eventName=PAYMENT_DATA_FILLED,
                                ~paymentMethod="GOOGLE_PAY",
                              )
                              resolve()
                            },
                          )
                          ->catch(
                            err => {
                              logger.setLogInfo(
                                ~value=err->anyTypeToJson->JSON.stringify,
                                ~eventName=GOOGLE_PAY_FLOW,
                                ~paymentMethod="GOOGLE_PAY",
                                ~logType=DEBUG,
                              )

                              let msg = [("gpayError", err->anyTypeToJson)]->Dict.fromArray
                              event.source->Window.sendPostMessage(msg)
                              resolve()
                            },
                          )
                          ->ignore
                        }, 0)->ignore
                      }
                    }
                    addSmartEventListener("message", handleGooglePayMessages, "onGooglePayMessages")
                  } catch {
                  | _ => Console.log("Error loading Gpay")
                  }
                } else if wallets.googlePay === Never {
                  logger.setLogInfo(
                    ~value="GooglePay is set as never by merchant",
                    ~eventName=GOOGLE_PAY_FLOW,
                    ~paymentMethod="GOOGLE_PAY",
                    ~logType=INFO,
                  )
                }

                json->resolve
              })
              ->then(json => {
                let msg = [("sessions", json)]->Dict.fromArray
                mountedIframeRef->Window.iframePostMessage(msg)
                json->resolve
              })
              ->ignore
            }
          }
          let msg = [("sendSessionTokensResponse", true->JSON.Encode.bool)]->Dict.fromArray
          addSmartEventListener(
            "message",
            handleSessionTokensLoaded,
            `onSessionTokensLoaded-${componentType}`,
          )
          preMountLoaderIframeDiv->Window.iframePostMessage(msg)
        }
        preMountLoaderMountedPromise
        ->then(_ => {
          fetchPaymentsList(mountedIframeRef, componentType)
          let disableSavedPaymentMethods =
            newOptions
            ->getDictFromJson
            ->getBool("displaySavedPaymentMethods", true) &&
              !(spmComponents->Array.includes(componentType))->not
          fetchCustomerPaymentMethods(mountedIframeRef, disableSavedPaymentMethods, componentType)
          fetchSessionTokens(mountedIframeRef)
          resolve()
        })
        ->ignore
        mountedIframeRef->Window.iframePostMessage(message)
      }

      let paymentElement = LoaderPaymentElement.make(
        componentType,
        newOptions,
        setElementIframeRef,
        iframeRef,
        mountPostMessage,
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
