open Types
open ErrorUtils

open Utils
open EventListenerManager

open ApplePayTypes

external objToJson: {..} => JSON.t = "%identity"
external eventToJson: Types.eventData => JSON.t = "%identity"

type trustPayFunctions = {
  finishApplePaymentV2: (string, ApplePayTypes.paymentRequestData) => Promise.t<JSON.t>,
  executeGooglePayment: (string, GooglePayType.paymentDataRequest) => Promise.t<JSON.t>,
}
@new external trustPayApi: JSON.t => trustPayFunctions = "TrustPayApi"

let make = (
  options,
  setIframeRef,
  ~clientSecret,
  ~sdkSessionId,
  ~publishableKey,
  ~logger: option<OrcaLogger.loggerMake>,
  ~analyticsMetadata,
) => {
  let handleApplePayMessages = ref(_ => ())
  let applePaySessionRef = ref(Nullable.null)

  try {
    let iframeRef = []
    let logger = logger->Option.getOr(OrcaLogger.defaultLoggerConfig)
    let savedPaymentElement = Dict.make()
    let localOptions = options->JSON.Decode.object->Option.getOr(Dict.make())
    let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey, ())
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
    let switchToCustomPod =
      GlobalVars.isInteg &&
      options
      ->JSON.Decode.object
      ->Option.flatMap(x => x->Dict.get("switchToCustomPod"))
      ->Option.flatMap(JSON.Decode.bool)
      ->Option.getOr(false)

    let paymentMethodListPromise = PaymentHelpers.fetchPaymentMethodList(
      ~clientSecret,
      ~publishableKey,
      ~endpoint,
      ~switchToCustomPod,
      ~logger,
    )

    let sessionsPromise = PaymentHelpers.fetchSessions(
      ~clientSecret,
      ~publishableKey,
      ~endpoint,
      ~switchToCustomPod,
      ~optLogger=Some(logger),
      (),
    )

    let locale = localOptions->getJsonStringFromDict("locale", "")
    let loader = localOptions->getJsonStringFromDict("loader", "")
    let clientSecret = localOptions->getRequiredString("clientSecret", "", ~logger)
    let clientSecretReMatch = RegExp.test(`.+_secret_[A-Za-z0-9]+`->RegExp.fromString, clientSecret)
    let fetchPaymentsList = mountedIframeRef => {
      open Promise
      paymentMethodListPromise
      ->then(json => {
        let isApplePayPresent =
          PaymentMethodsRecord.getPaymentMethodTypeFromList(
            ~list=json->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapper,
            ~paymentMethod="wallet",
            ~paymentMethodType="apple_pay",
          )->Option.isSome

        let isGooglePayPresent =
          PaymentMethodsRecord.getPaymentMethodTypeFromList(
            ~list=json->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapper,
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
            trustPayScript->Window.elementSrc(trustPayScriptURL)
            trustPayScript->Window.elementOnerror(err => {
              Utils.logInfo(Console.log2("ERROR DURING LOADING TRUSTPAY APPLE PAY", err))
            })
            Window.body->Window.appendChild(trustPayScript)
            logger.setLogInfo(~value="TrustPay Script Loaded", ~eventName=TRUSTPAY_SCRIPT, ())
          }
        }

        // setTimeout(() => {
        let msg = [("paymentMethodList", json)]->Dict.fromArray
        mountedIframeRef->Window.iframePostMessage(msg)
        let maskedPayload = json->PaymentHelpers.maskPayload->JSON.stringify
        logger.setLogInfo(~value=maskedPayload, ~eventName=PAYMENT_METHODS_RESPONSE, ())
        // }, 5000)->ignore
        json->resolve
      })
      ->ignore
    }
    let fetchCustomerDetails = mountedIframeRef => {
      let customerDetailsPromise = PaymentHelpers.fetchCustomerDetails(
        ~clientSecret,
        ~publishableKey,
        ~endpoint,
        ~switchToCustomPod,
        ~optLogger=Some(logger),
      )
      open Promise
      customerDetailsPromise
      ->then(json => {
        // setTimeout(() => {
        let msg = [("customerPaymentMethods", json)]->Dict.fromArray
        mountedIframeRef->Window.iframePostMessage(msg)
        // }, 5000)->ignore
        json->resolve
      })
      ->catch(_err => {
        let dict =
          [("customer_payment_methods", []->JSON.Encode.array)]->Dict.fromArray->JSON.Encode.object
        let msg = [("customerPaymentMethods", dict)]->Dict.fromArray
        mountedIframeRef->Window.iframePostMessage(msg)
        resolve(msg->JSON.Encode.object)
      })
      ->ignore
    }

    !clientSecretReMatch
      ? manageErrorWarning(
          INVALID_FORMAT,
          ~dynamicStr="clientSecret is expected to be in format ******_secret_*****",
          ~logger,
          (),
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
      componentType == ""
        ? manageErrorWarning(REQUIRED_PARAMETER, ~dynamicStr="type", ~logger, ())
        : ()
      let otherElements = componentType->Utils.isOtherElements
      switch componentType {
      | "card"
      | "cardNumber"
      | "cardExpiry"
      | "cardCvc"
      | "payment" => ()
      | str => manageErrorWarning(UNKNOWN_KEY, ~dynamicStr=`${str} type in create`, ~logger, ())
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
          ]
          ->Dict.fromArray
          ->JSON.Encode.object
        let message =
          [
            ("paymentElementCreate", (componentType == "payment")->JSON.Encode.bool),
            ("otherElements", otherElements->JSON.Encode.bool),
            ("options", newOptions),
            ("componentType", componentType->JSON.Encode.string),
            ("paymentOptions", widgetOptions),
            ("iframeId", selectorString->JSON.Encode.string),
            ("publishableKey", publishableKey->JSON.Encode.string),
            ("endpoint", endpoint->JSON.Encode.string),
            ("sdkSessionId", sdkSessionId->JSON.Encode.string),
            ("blockConfirm", blockConfirm->JSON.Encode.bool),
            ("switchToCustomPod", switchToCustomPod->JSON.Encode.bool),
            ("endpoint", endpoint->JSON.Encode.string),
            ("sdkHandleOneClickConfirmPayment", sdkHandleOneClickConfirmPayment->JSON.Encode.bool),
            ("parentURL", "*"->JSON.Encode.string),
            ("analyticsMetadata", analyticsMetadata),
            ("launchTime", launchTime->JSON.Encode.float),
          ]->Dict.fromArray

        let handleApplePayMounted = (event: Types.event) => {
          let json = event.data->eventToJson
          let dict = json->getDictFromJson

          if dict->Dict.get("applePayMounted")->Option.isSome {
            switch sessionForApplePay->Nullable.toOption {
            | Some(session) =>
              if session.canMakePayments() {
                let msg = [("applePayCanMakePayments", true->JSON.Encode.bool)]->Dict.fromArray
                mountedIframeRef->Window.iframePostMessage(msg)
              } else {
                logger.setLogInfo(
                  ~value="CANNOT MAKE PAYMENT USING APPLE PAY",
                  ~eventName=APPLE_PAY_FLOW,
                  ~paymentMethod="APPLE_PAY",
                  ~logType=ERROR,
                  (),
                )
              }

            | None => ()
            }
          }
        }

        let handleGooglePayThirdPartyFlow = (event: Types.event) => {
          let json = event.data->eventToJson
          let dict = json->getDictFromJson

          switch dict->Dict.get("googlePayThirdPartyFlow") {
          | Some(googlePayThirdPartyOptSession) => {
              let googlePayThirdPartySession = googlePayThirdPartyOptSession->Utils.getDictFromJson

              let baseDetails = {
                "apiVersion": 2,
                "apiVersionMinor": 0,
                "environment": publishableKey->String.startsWith("pk_prd_") ? "PRODUCTION" : "TEST",
              }

              let paymentDataRequest = GooglePayType.assign2(
                Dict.make()->JSON.Encode.object,
                baseDetails->objToJson,
              )

              let googlePayRequest =
                paymentDataRequest->GooglePayType.jsonToPaymentRequestDataType(
                  googlePayThirdPartySession,
                )
              let secrets =
                googlePayThirdPartySession->Utils.getJsonFromDict("secrets", JSON.Encode.null)

              let payment = secrets->Utils.getDictFromJson->Utils.getString("payment", "")

              try {
                let trustpay = trustPayApi(secrets)
                trustpay.executeGooglePayment(payment, googlePayRequest)
                ->then(res => {
                  logger.setLogInfo(
                    ~value="TrustPay GooglePay Success Response",
                    ~internalMetadata=res->JSON.stringify,
                    ~eventName=GOOGLE_PAY_FLOW,
                    ~paymentMethod="GOOGLE_PAY",
                    (),
                  )
                  let msg = [("googlePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                  mountedIframeRef->Window.iframePostMessage(msg)
                  resolve()
                })
                ->catch(err => {
                  let exceptionMessage = err->Utils.formatException->JSON.stringify
                  logger.setLogInfo(
                    ~value=exceptionMessage,
                    ~eventName=GOOGLE_PAY_FLOW,
                    ~paymentMethod="GOOGLE_PAY",
                    ~logType=ERROR,
                    ~logCategory=USER_ERROR,
                    (),
                  )
                  let msg = [("googlePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                  mountedIframeRef->Window.iframePostMessage(msg)
                  resolve()
                })
                ->ignore
              } catch {
              | err => {
                  let exceptionMessage = err->Utils.formatException->JSON.stringify
                  logger.setLogInfo(
                    ~value=exceptionMessage,
                    ~eventName=GOOGLE_PAY_FLOW,
                    ~paymentMethod="GOOGLE_PAY",
                    ~logType=ERROR,
                    ~logCategory=USER_ERROR,
                    (),
                  )
                  let msg = [("googlePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                  mountedIframeRef->Window.iframePostMessage(msg)
                }
              }
            }
          | _ => ()
          }
        }

        addSmartEventListener("message", handleApplePayMounted, "onApplePayMount")
        addSmartEventListener("message", handleGooglePayThirdPartyFlow, "onGooglePayThirdParty")

        sessionsPromise
        ->then(json => {
          let sessionsArr =
            json
            ->JSON.Decode.object
            ->Option.getOr(Dict.make())
            ->SessionsType.getSessionsTokenJson("session_token")

          let applePayPresent = sessionsArr->Array.find(item => {
            let x =
              item
              ->JSON.Decode.object
              ->Option.flatMap(
                x => {
                  x->Dict.get("wallet_name")
                },
              )
              ->Option.flatMap(JSON.Decode.string)
              ->Option.getOr("")
            x === "apple_pay" || x === "applepay"
          })
          if !(applePayPresent->Option.isSome) {
            let msg = [("applePaySessionObjNotPresent", true->JSON.Encode.bool)]->Dict.fromArray
            mountedIframeRef->Window.iframePostMessage(msg)
          }
          let googlePayPresent = sessionsArr->Array.find(item => {
            let x =
              item
              ->JSON.Decode.object
              ->Option.flatMap(
                x => {
                  x->Dict.get("wallet_name")
                },
              )
              ->Option.flatMap(JSON.Decode.string)
              ->Option.getOr("")
            x === "google_pay" || x === "googlepay"
          })

          (json, applePayPresent, googlePayPresent)->resolve
        })
        ->then(res => {
          let (json, applePayPresent, googlePayPresent) = res
          if componentType === "payment" && applePayPresent->Option.isSome {
            //do operations here
            let processPayment = (token: JSON.t) => {
              //let body = PaymentBody.applePayBody(~token)
              let msg = [("applePayProcessPayment", token)]->Dict.fromArray
              mountedIframeRef->Window.iframePostMessage(msg)
            }

            handleApplePayMessages :=
              (
                (event: Types.event) => {
                  let json = event.data->eventToJson
                  let dict = json->getDictFromJson
                  switch dict->Dict.get("applePayButtonClicked") {
                  | Some(val) =>
                    if val->JSON.Decode.bool->Option.getOr(false) {
                      let isDelayedSessionToken =
                        applePayPresent
                        ->Option.flatMap(JSON.Decode.object)
                        ->Option.getOr(Dict.make())
                        ->Dict.get("delayed_session_token")
                        ->Option.getOr(JSON.Encode.null)
                        ->JSON.Decode.bool
                        ->Option.getOr(false)

                      if isDelayedSessionToken {
                        logger.setLogInfo(
                          ~value="Delayed Session Token Flow",
                          ~eventName=APPLE_PAY_FLOW,
                          ~paymentMethod="APPLE_PAY",
                          (),
                        )

                        let applePayPresent =
                          dict
                          ->Dict.get("applePayPresent")
                          ->Option.flatMap(JSON.Decode.object)
                          ->Option.getOr(Dict.make())

                        let connector =
                          applePayPresent
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
                            (),
                          )
                          let secrets =
                            applePayPresent
                            ->Dict.get("session_token_data")
                            ->Option.getOr(JSON.Encode.null)
                            ->JSON.Decode.object
                            ->Option.getOr(Dict.make())
                            ->Dict.get("secrets")
                            ->Option.getOr(JSON.Encode.null)

                          let paymentRequest =
                            applePayPresent
                            ->Dict.get("payment_request_data")
                            ->Option.flatMap(JSON.Decode.object)
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
                              logger.setLogInfo(
                                ~value="TrustPay ApplePay Success Response",
                                ~internalMetadata=res->JSON.stringify,
                                ~eventName=APPLE_PAY_FLOW,
                                ~paymentMethod="APPLE_PAY",
                                (),
                              )
                              let msg =
                                [("applePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                              mountedIframeRef->Window.iframePostMessage(msg)
                              logger.setLogInfo(
                                ~value="",
                                ~eventName=PAYMENT_DATA_FILLED,
                                ~paymentMethod="APPLE_PAY",
                                (),
                              )
                              resolve()
                            })
                            ->catch(err => {
                              let exceptionMessage = err->Utils.formatException->JSON.stringify
                              logger.setLogInfo(
                                ~eventName=APPLE_PAY_FLOW,
                                ~paymentMethod="APPLE_PAY",
                                ~value=exceptionMessage,
                                (),
                              )
                              let msg =
                                [("applePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                              mountedIframeRef->Window.iframePostMessage(msg)
                              resolve()
                            })
                            ->ignore
                          } catch {
                          | exn => {
                              logger.setLogInfo(
                                ~value=exn->Utils.formatException->JSON.stringify,
                                ~eventName=APPLE_PAY_FLOW,
                                ~paymentMethod="APPLE_PAY",
                                (),
                              )
                              let msg =
                                [("applePaySyncPayment", true->JSON.Encode.bool)]->Dict.fromArray
                              mountedIframeRef->Window.iframePostMessage(msg)
                            }
                          }
                        | _ => ()
                        }
                      } else {
                        try {
                          let paymentRequest =
                            applePayPresent
                            ->Option.flatMap(JSON.Decode.object)
                            ->Option.getOr(Dict.make())
                            ->Dict.get("payment_request_data")
                            ->Option.getOr(Dict.make()->JSON.Encode.object)
                            ->Utils.transformKeys(Utils.CamelCase)

                          let ssn = applePaySession(3, paymentRequest)
                          switch applePaySessionRef.contents->Nullable.toOption {
                          | Some(session) =>
                            try {
                              session.abort()
                            } catch {
                            | error => Console.log2("Abort fail", error)
                            }
                          | None => ()
                          }

                          applePaySessionRef := ssn->Nullable.make

                          ssn.onvalidatemerchant = _event => {
                            let merchantSession =
                              applePayPresent
                              ->Option.flatMap(JSON.Decode.object)
                              ->Option.getOr(Dict.make())
                              ->Dict.get("session_token_data")
                              ->Option.getOr(Dict.make()->JSON.Encode.object)
                              ->Utils.transformKeys(Utils.CamelCase)
                            ssn.completeMerchantValidation(merchantSession)
                          }

                          ssn.onpaymentauthorized = event => {
                            ssn.completePayment({"status": ssn.\"STATUS_SUCCESS"}->objToJson)
                            applePaySessionRef := Nullable.null
                            processPayment(event.payment.token)
                          }
                          ssn.oncancel = _ev => {
                            let msg =
                              [("showApplePayButton", true->JSON.Encode.bool)]->Dict.fromArray
                            mountedIframeRef->Window.iframePostMessage(msg)
                            applePaySessionRef := Nullable.null
                            Utils.logInfo(Console.log("Apple Pay payment cancelled"))
                          }

                          ssn.begin()
                        } catch {
                        | exn => {
                            logger.setLogInfo(
                              ~value=exn->Utils.formatException->JSON.stringify,
                              ~eventName=APPLE_PAY_FLOW,
                              ~paymentMethod="APPLE_PAY",
                              (),
                            )
                            Utils.logInfo(Console.error2("Apple Pay Error", exn))

                            let msg =
                              [("showApplePayButton", true->JSON.Encode.bool)]->Dict.fromArray
                            mountedIframeRef->Window.iframePostMessage(msg)
                            applePaySessionRef := Nullable.null
                          }
                        }
                      }
                    } else {
                      ()
                    }
                  | None => ()
                  }
                }
              )

            addSmartEventListener("message", handleApplePayMessages.contents, "onApplePayMessages")
          }
          if componentType === "payment" && googlePayPresent->Option.isSome {
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

            let baseRequest = {
              "apiVersion": 2,
              "apiVersionMinor": 0,
            }
            let paymentDataRequest = GooglePayType.assign2(
              Dict.make()->JSON.Encode.object,
              baseRequest->toJson,
            )

            let payRequest = GooglePayType.assign(
              Dict.make()->JSON.Encode.object,
              baseRequest->toJson,
              {
                "allowedPaymentMethods": gpayobj.allowed_payment_methods->arrayJsonToCamelCase,
              }->toJson,
            )
            paymentDataRequest.allowedPaymentMethods =
              gpayobj.allowed_payment_methods->arrayJsonToCamelCase
            paymentDataRequest.transactionInfo = gpayobj.transaction_info->transformKeys(CamelCase)
            paymentDataRequest.merchantInfo = gpayobj.merchant_info->transformKeys(CamelCase)
            try {
              let gPayClient = GooglePayType.google(
                {
                  "environment": publishableKey->String.startsWith("pk_prd_")
                    ? "PRODUCTION"
                    : "TEST",
                }->toJson,
              )

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
                  ~value=err->toJson->JSON.stringify,
                  ~eventName=GOOGLE_PAY_FLOW,
                  ~paymentMethod="GOOGLE_PAY",
                  ~logType=DEBUG,
                  (),
                )
                resolve()
              })
              ->ignore

              let handleGooglePayMessages = (event: Types.event) => {
                let evJson = event.data->eventToJson
                let gpayClicked =
                  evJson
                  ->OrcaUtils.getOptionalJsonFromJson("GpayClicked")
                  ->OrcaUtils.getBoolfromjson(false)

                if gpayClicked {
                  setTimeout(() => {
                    gPayClient.loadPaymentData(paymentDataRequest->toJson)
                    ->then(
                      json => {
                        logger.setLogInfo(
                          ~value=json->toJson->JSON.stringify,
                          ~eventName=GOOGLE_PAY_FLOW,
                          ~paymentMethod="GOOGLE_PAY",
                          ~logType=DEBUG,
                          (),
                        )
                        let msg = [("gpayResponse", json->toJson)]->Dict.fromArray
                        mountedIframeRef->Window.iframePostMessage(msg)
                        resolve()
                      },
                    )
                    ->catch(
                      err => {
                        logger.setLogInfo(
                          ~value=err->toJson->JSON.stringify,
                          ~eventName=GOOGLE_PAY_FLOW,
                          ~paymentMethod="GOOGLE_PAY",
                          ~logType=DEBUG,
                          (),
                        )

                        let msg = [("gpayError", err->toJson)]->Dict.fromArray
                        mountedIframeRef->Window.iframePostMessage(msg)
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
          }

          json->resolve
        })
        ->then(json => {
          let msg = [("sessions", json)]->Dict.fromArray
          mountedIframeRef->Window.iframePostMessage(msg)
          json->resolve
        })
        ->ignore
        fetchPaymentsList(mountedIframeRef)
        fetchCustomerDetails(mountedIframeRef)
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
