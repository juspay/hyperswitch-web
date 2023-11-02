open Types
open ErrorUtils

open Utils
open EventListenerManager

open ApplePayTypes

external objToJson: {..} => Js.Json.t = "%identity"
external eventToJson: Types.eventData => Js.Json.t = "%identity"

type trustPayFunctions = {
  finishApplePaymentV2: (. string, ApplePayTypes.paymentRequestData) => Js.Promise.t<Js.Json.t>,
  executeGooglePayment: (. string, GooglePayType.paymentDataRequest) => Js.Promise.t<Js.Json.t>,
}
@new external trustPayApi: Js.Json.t => trustPayFunctions = "TrustPayApi"

let make = (
  options,
  setIframeRef,
  ~sdkSessionId,
  ~publishableKey,
  ~logger: option<OrcaLogger.loggerMake>,
) => {
  let handleApplePayMessages = ref(_ => ())
  let applePaySessionRef = ref(Js.Nullable.null)

  try {
    let iframeRef = []
    let logger = logger->Belt.Option.getWithDefault(OrcaLogger.defaultLoggerConfig)
    let savedPaymentElement = Js.Dict.empty()
    let localOptions = options->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
    let clientSecret = localOptions->getRequiredString("clientSecret", "", ~logger)
    let appearance =
      localOptions
      ->Js.Dict.get("appearance")
      ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)

    let fonts =
      localOptions
      ->Js.Dict.get("fonts")
      ->Belt.Option.flatMap(Js.Json.decodeArray)
      ->Belt.Option.getWithDefault([])
      ->Js.Json.array

    let blockConfirm = GlobalVars.isInteg
      ? options
        ->Js.Json.decodeObject
        ->Belt.Option.flatMap(x => x->Js.Dict.get("orcaBlockConfirmABP"))
        ->Belt.Option.flatMap(Js.Json.decodeBoolean)
        ->Belt.Option.getWithDefault(false)
      : false
    let switchToCustomPod = GlobalVars.isInteg
      ? options
        ->Js.Json.decodeObject
        ->Belt.Option.flatMap(x => x->Js.Dict.get("switchToCustomPodABP"))
        ->Belt.Option.flatMap(Js.Json.decodeBoolean)
        ->Belt.Option.getWithDefault(false)
      : false
    let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey, ())

    let localSelectorString = "hyper-preMountLoader-iframe"
    let mountPreMountLoaderIframe = () => {
      let elemAlreadyExists = Window.querySelector(
        `#orca-payment-element-iframeRef-${localSelectorString}-parent`,
      )

      switch elemAlreadyExists->Js.Nullable.toOption {
      | Some(dom) => dom->Window.remove
      | None => ()
      }

      let componentType = "preMountLoader"
      let iframeDivHtml = `<div id="orca-element-${localSelectorString}" style= "height: 0px; width: 0px; display: none;"  class="${componentType}">
          <div id="orca-fullscreen-iframeRef-${localSelectorString}"></div>
           <iframe
           id ="orca-payment-element-iframeRef-${localSelectorString}"
           name="orca-payment-element-iframeRef-${localSelectorString}"
          src="${ApiEndpoint.sdkDomainUrl}/index.html?fullscreenType=${componentType}&publishableKey=${publishableKey}&clientSecret=${clientSecret}&sessionId=${sdkSessionId}"
          allow="*"
          name="orca-payment"
        ></iframe>
        </div>`

      let iframeDiv = Window.createElement("div")
      iframeDiv->Window.setAttribute(
        "id",
        `orca-payment-element-iframeRef-${localSelectorString}-parent`,
      )
      iframeDiv->Window.innerHTML(iframeDivHtml)
      Window.body->Window.appendChild(iframeDiv)

      let elem = Window.querySelector(`#orca-payment-element-iframeRef-${localSelectorString}`)
      elem
    }

    let locale = localOptions->getJsonStringFromDict("locale", "")
    let loader = localOptions->getJsonStringFromDict("loader", "")
    let clientSecretReMatch = Js.Re.test_(`.+_secret_[A-Za-z0-9]+`->Js.Re.fromString, clientSecret)
    let iframeIsReadyPromise = {
      Js.Promise.make((~resolve, ~reject as _) => {
        let handleIframeIsReadyHandler = (event: Types.event) => {
          let json = event.data->eventToJson
          let dict = json->getDictFromJson
          if dict->Js.Dict.get("preMountLoaderInitCallback")->Belt.Option.isSome {
            resolve(. Js.Dict.empty())
          }
        }
        addSmartEventListener(
          "message",
          handleIframeIsReadyHandler,
          "handlePreMountIframeIsReadyHandler",
        )
      })
    }
    let preMountLoaderIframeDiv = mountPreMountLoaderIframe()

    let fetchPaymentsList = mountedIframeRef => {
      let handlePaymentMethodsLoaded = (event: Types.event) => {
        let json = event.data->eventToJson
        let dict = json->getDictFromJson
        let isPaymentMethodsData = dict->Utils.getString("data", "") === "payment_methods"
        if isPaymentMethodsData {
          let json = dict->Utils.getJsonFromDict("response", Js.Json.null)
          let isApplePayPresent =
            PaymentMethodsRecord.getPaymentMethodTypeFromList(
              ~list=json->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapper,
              ~paymentMethod="wallet",
              ~paymentMethodType="apple_pay",
            )->Belt.Option.isSome

          let isGooglePayPresent =
            PaymentMethodsRecord.getPaymentMethodTypeFromList(
              ~list=json->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapper,
              ~paymentMethod="wallet",
              ~paymentMethodType="google_pay",
            )->Belt.Option.isSome

          if isApplePayPresent || isGooglePayPresent {
            if (
              Window.querySelectorAll(`script[src="https://tpgw.trustpay.eu/js/v1.js"]`)->Js.Array2.length === 0 &&
                Window.querySelectorAll(`script[src="https://test-tpgw.trustpay.eu/js/v1.js"]`)->Js.Array2.length === 0
            ) {
              let trustPayScriptURL =
                publishableKey->Js.String2.startsWith("pk_prd_")
                  ? "https://tpgw.trustpay.eu/js/v1.js"
                  : "https://test-tpgw.trustpay.eu/js/v1.js"
              let trustPayScript = Window.createElement("script")
              trustPayScript->Window.elementSrc(trustPayScriptURL)
              trustPayScript->Window.elementOnerror(err => {
                Utils.logInfo(Js.log2("ERROR DURING LOADING TRUSTPAY APPLE PAY", err))
              })
              Window.body->Window.appendChild(trustPayScript)
              logger.setLogInfo(~value="TrustPay Script Loaded", ~eventName=TRUSTPAY_SCRIPT, ())
            }
          }
          let msg = [("paymentMethodList", json)]->Js.Dict.fromArray
          mountedIframeRef->Window.iframePostMessage(msg)
        }
      }
      let msg = [("sendPaymentMethodsResponse", true->Js.Json.boolean)]->Js.Dict.fromArray
      addSmartEventListener("message", handlePaymentMethodsLoaded, "onPaymentMethodsLoaded")
      open Promise
      iframeIsReadyPromise
      ->then(_ => {
        preMountLoaderIframeDiv->Window.iframePostMessage(msg)
        Js.Json.null->resolve
      })
      ->ignore
    }

    let fetchCustomerPaymentMethods = mountedIframeRef => {
      let handleCustomerPaymentMethodsLoaded = (event: Types.event) => {
        let json = event.data->eventToJson
        let dict = json->getDictFromJson
        let isCustomerPaymentMethodsData =
          dict->Utils.getString("data", "") === "customer_payment_methods"
        if isCustomerPaymentMethodsData {
          let json = dict->Utils.getJsonFromDict("response", Js.Json.null)
          let msg = [("customerPaymentMethods", json)]->Js.Dict.fromArray
          mountedIframeRef->Window.iframePostMessage(msg)
        }
      }
      let msg = [("sendCustomerPaymentMethodsResponse", true->Js.Json.boolean)]->Js.Dict.fromArray
      addSmartEventListener(
        "message",
        handleCustomerPaymentMethodsLoaded,
        "onCustomerPaymentMethodsLoaded",
      )
      open Promise
      iframeIsReadyPromise
      ->then(_ => {
        preMountLoaderIframeDiv->Window.iframePostMessage(msg)
        Js.Json.null->resolve
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
      iframeRef->Js.Array2.push(ref)->ignore
      setIframeRef(ref)
    }
    let getElement = componentName => {
      savedPaymentElement->Js.Dict.get(componentName)
    }
    let update = newOptions => {
      let newOptionsDict = newOptions->getDictFromJson
      switch newOptionsDict->Js.Dict.get("locale") {
      | Some(val) => localOptions->Js.Dict.set("locale", val)
      | None => ()
      }
      switch newOptionsDict->Js.Dict.get("appearance") {
      | Some(val) => localOptions->Js.Dict.set("appearance", val)
      | None => ()
      }
      switch newOptionsDict->Js.Dict.get("clientSecret") {
      | Some(val) => localOptions->Js.Dict.set("clientSecret", val)
      | None => ()
      }

      iframeRef->Js.Array2.forEach(iframe => {
        let message =
          [
            ("ElementsUpdate", true->Js.Json.boolean),
            ("options", newOptionsDict->Js.Json.object_),
          ]->Js.Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })
    }
    let fetchUpdates = () => {
      Js.Promise.make((~resolve, ~reject as _) => {
        Js.Global.setTimeout(() => resolve(. Js.Dict.empty()->Js.Json.object_), 1000)->ignore
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
        sdkHandleConfirmPayment,
        disableSaveCards,
      ) => {
        open Promise

        let widgetOptions =
          [
            ("clientSecret", clientSecret->Js.Json.string),
            ("appearance", appearance),
            ("locale", locale),
            ("loader", loader),
            ("fonts", fonts),
          ]
          ->Js.Dict.fromArray
          ->Js.Json.object_
        let message =
          [
            ("paymentElementCreate", (componentType == "payment")->Js.Json.boolean),
            ("otherElements", otherElements->Js.Json.boolean),
            ("options", newOptions),
            ("componentType", componentType->Js.Json.string),
            ("paymentOptions", widgetOptions),
            ("iframeId", selectorString->Js.Json.string),
            ("publishableKey", publishableKey->Js.Json.string),
            ("sdkSessionId", sdkSessionId->Js.Json.string),
            ("sdkHandleConfirmPayment", sdkHandleConfirmPayment->Js.Json.boolean),
            ("AOrcaBBlockPConfirm", blockConfirm->Js.Json.boolean),
            ("switchToCustomPodABP", switchToCustomPod->Js.Json.boolean),
            ("parentURL", "*"->Js.Json.string),
          ]->Js.Dict.fromArray

        let handleApplePayMounted = (event: Types.event) => {
          let json = event.data->eventToJson
          let dict = json->getDictFromJson

          if dict->Js.Dict.get("applePayMounted")->Belt.Option.isSome {
            switch sessionForApplePay->Js.Nullable.toOption {
            | Some(session) =>
              if session.canMakePayments(.) {
                let msg = [("applePayCanMakePayments", true->Js.Json.boolean)]->Js.Dict.fromArray
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

          switch dict->Js.Dict.get("googlePayThirdPartyFlow") {
          | Some(googlePayThirdPartyOptSession) => {
              let googlePayThirdPartySession = googlePayThirdPartyOptSession->Utils.getDictFromJson

              let baseDetails = {
                "apiVersion": 2,
                "apiVersionMinor": 0,
                "environment": publishableKey->Js.String2.startsWith("pk_prd_")
                  ? "PRODUCTION"
                  : "TEST",
              }

              let paymentDataRequest = GooglePayType.assign2(
                Js.Dict.empty()->Js.Json.object_,
                baseDetails->objToJson,
              )

              let googlePayRequest =
                paymentDataRequest->GooglePayType.jsonToPaymentRequestDataType(
                  googlePayThirdPartySession,
                )
              let secrets =
                googlePayThirdPartySession->Utils.getJsonFromDict("secrets", Js.Json.null)

              let payment = secrets->Utils.getDictFromJson->Utils.getString("payment", "")

              try {
                let trustpay = trustPayApi(secrets)
                trustpay.executeGooglePayment(. payment, googlePayRequest)
                ->then(res => {
                  logger.setLogInfo(
                    ~value="TrustPay GooglePay Success Response",
                    ~internalMetadata=res->Js.Json.stringify,
                    ~eventName=GOOGLE_PAY_FLOW,
                    ~paymentMethod="GOOGLE_PAY",
                    (),
                  )
                  let msg = [("googlePaySyncPayment", true->Js.Json.boolean)]->Js.Dict.fromArray
                  mountedIframeRef->Window.iframePostMessage(msg)
                  resolve()
                })
                ->catch(err => {
                  let exceptionMessage = err->Utils.formatException->Js.Json.stringify
                  logger.setLogInfo(
                    ~value=exceptionMessage,
                    ~eventName=GOOGLE_PAY_FLOW,
                    ~paymentMethod="GOOGLE_PAY",
                    ~logType=ERROR,
                    ~logCategory=USER_ERROR,
                    (),
                  )
                  let msg = [("googlePaySyncPayment", true->Js.Json.boolean)]->Js.Dict.fromArray
                  mountedIframeRef->Window.iframePostMessage(msg)
                  resolve()
                })
                ->ignore
              } catch {
              | err => {
                  let exceptionMessage = err->Utils.formatException->Js.Json.stringify
                  logger.setLogInfo(
                    ~value=exceptionMessage,
                    ~eventName=GOOGLE_PAY_FLOW,
                    ~paymentMethod="GOOGLE_PAY",
                    ~logType=ERROR,
                    ~logCategory=USER_ERROR,
                    (),
                  )
                  let msg = [("googlePaySyncPayment", true->Js.Json.boolean)]->Js.Dict.fromArray
                  mountedIframeRef->Window.iframePostMessage(msg)
                }
              }
            }
          | _ => ()
          }
        }

        addSmartEventListener("message", handleApplePayMounted, "onApplePayMount")
        addSmartEventListener("message", handleGooglePayThirdPartyFlow, "onGooglePayThirdParty")

        let fetchSessionTokens = mountedIframeRef => {
          let handleSessionTokensLoaded = (event: Types.event) => {
            let json = event.data->eventToJson
            let dict = json->getDictFromJson
            let sessionTokensData = dict->Utils.getString("data", "") === "session_tokens"
            if sessionTokensData {
              let json = dict->Utils.getJsonFromDict("response", Js.Json.null)

              {
                let sessionsArr =
                  json
                  ->Js.Json.decodeObject
                  ->Belt.Option.getWithDefault(Js.Dict.empty())
                  ->SessionsType.getSessionsTokenJson("session_token")

                let applePayPresent = sessionsArr->Js.Array2.find(item => {
                  let x =
                    item
                    ->Js.Json.decodeObject
                    ->Belt.Option.flatMap(x => {
                      x->Js.Dict.get("wallet_name")
                    })
                    ->Belt.Option.flatMap(Js.Json.decodeString)
                    ->Belt.Option.getWithDefault("")
                  x === "apple_pay" || x === "applepay"
                })
                let googlePayPresent = sessionsArr->Js.Array2.find(item => {
                  let x =
                    item
                    ->Js.Json.decodeObject
                    ->Belt.Option.flatMap(x => {
                      x->Js.Dict.get("wallet_name")
                    })
                    ->Belt.Option.flatMap(Js.Json.decodeString)
                    ->Belt.Option.getWithDefault("")
                  x === "google_pay" || x === "googlepay"
                })

                (json, applePayPresent, googlePayPresent)->resolve
              }
              ->then(res => {
                let (json, applePayPresent, googlePayPresent) = res
                if componentType === "payment" && applePayPresent->Belt.Option.isSome {

                  let processPayment = (token: Js.Json.t) => {
                    let msg = [("applePayProcessPayment", token)]->Js.Dict.fromArray
                    mountedIframeRef->Window.iframePostMessage(msg)
                  }

                  handleApplePayMessages :=
                    (
                      (event: Types.event) => {
                        let json = event.data->eventToJson
                        let dict = json->getDictFromJson

                        switch dict->Js.Dict.get("applePayButtonClicked") {
                        | Some(val) =>
                          if val->Js.Json.decodeBoolean->Belt.Option.getWithDefault(false) {
                            let isDelayedSessionToken =
                              applePayPresent
                              ->Belt.Option.flatMap(Js.Json.decodeObject)
                              ->Belt.Option.getWithDefault(Js.Dict.empty())
                              ->Js.Dict.get("delayed_session_token")
                              ->Belt.Option.getWithDefault(Js.Json.null)
                              ->Js.Json.decodeBoolean
                              ->Belt.Option.getWithDefault(false)

                            if isDelayedSessionToken {
                              logger.setLogInfo(
                                ~value="Delayed Session Token Flow",
                                ~eventName=APPLE_PAY_FLOW,
                                ~paymentMethod="APPLE_PAY",
                                (),
                              )

                              let applePayPresent =
                                dict
                                ->Js.Dict.get("applePayPresent")
                                ->Belt.Option.flatMap(Js.Json.decodeObject)
                                ->Belt.Option.getWithDefault(Js.Dict.empty())

                              let connector =
                                applePayPresent
                                ->Js.Dict.get("connector")
                                ->Belt.Option.getWithDefault(Js.Json.null)
                                ->Js.Json.decodeString
                                ->Belt.Option.getWithDefault("")

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
                                  ->Js.Dict.get("session_token_data")
                                  ->Belt.Option.getWithDefault(Js.Json.null)
                                  ->Js.Json.decodeObject
                                  ->Belt.Option.getWithDefault(Js.Dict.empty())
                                  ->Js.Dict.get("secrets")
                                  ->Belt.Option.getWithDefault(Js.Json.null)

                                let paymentRequest =
                                  applePayPresent
                                  ->Js.Dict.get("payment_request_data")
                                  ->Belt.Option.flatMap(Js.Json.decodeObject)
                                  ->Belt.Option.getWithDefault(Js.Dict.empty())
                                  ->ApplePayTypes.jsonToPaymentRequestDataType

                                let payment =
                                  secrets
                                  ->Js.Json.decodeObject
                                  ->Belt.Option.getWithDefault(Js.Dict.empty())
                                  ->Js.Dict.get("payment")
                                  ->Belt.Option.getWithDefault(Js.Json.null)
                                  ->Js.Json.decodeString
                                  ->Belt.Option.getWithDefault("")

                                try {
                                  let trustpay = trustPayApi(secrets)
                                  trustpay.finishApplePaymentV2(. payment, paymentRequest)
                                  ->then(res => {
                                    logger.setLogInfo(
                                      ~value="TrustPay ApplePay Success Response",
                                      ~internalMetadata=res->Js.Json.stringify,
                                      ~eventName=APPLE_PAY_FLOW,
                                      ~paymentMethod="APPLE_PAY",
                                      (),
                                    )
                                    let msg =
                                      [
                                        ("applePaySyncPayment", true->Js.Json.boolean),
                                      ]->Js.Dict.fromArray
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
                                    let exceptionMessage =
                                      err->Utils.formatException->Js.Json.stringify
                                    logger.setLogInfo(
                                      ~eventName=APPLE_PAY_FLOW,
                                      ~paymentMethod="APPLE_PAY",
                                      ~value=exceptionMessage,
                                      (),
                                    )
                                    let msg =
                                      [
                                        ("applePaySyncPayment", true->Js.Json.boolean),
                                      ]->Js.Dict.fromArray
                                    mountedIframeRef->Window.iframePostMessage(msg)
                                    resolve()
                                  })
                                  ->ignore
                                } catch {
                                | exn => {
                                    logger.setLogInfo(
                                      ~value=exn->Utils.formatException->Js.Json.stringify,
                                      ~eventName=APPLE_PAY_FLOW,
                                      ~paymentMethod="APPLE_PAY",
                                      (),
                                    )
                                    let msg =
                                      [
                                        ("applePaySyncPayment", true->Js.Json.boolean),
                                      ]->Js.Dict.fromArray
                                    mountedIframeRef->Window.iframePostMessage(msg)
                                  }
                                }
                              | _ => ()
                              }
                            } else {
                              let paymentRequest =
                                applePayPresent
                                ->Belt.Option.flatMap(Js.Json.decodeObject)
                                ->Belt.Option.getWithDefault(Js.Dict.empty())
                                ->Js.Dict.get("payment_request_data")
                                ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
                                ->Utils.transformKeys(Utils.CamelCase)

                              let ssn = applePaySession(3, paymentRequest)
                              switch applePaySessionRef.contents->Js.Nullable.toOption {
                              | Some(session) =>
                                try {
                                  session.abort(.)
                                } catch {
                                | error => Js.log2("Abort fail", error)
                                }
                              | None => ()
                              }

                              ssn.begin(.)
                              applePaySessionRef := ssn->Js.Nullable.return

                              ssn.onvalidatemerchant = _event => {
                                let merchantSession =
                                  applePayPresent
                                  ->Belt.Option.flatMap(Js.Json.decodeObject)
                                  ->Belt.Option.getWithDefault(Js.Dict.empty())
                                  ->Js.Dict.get("session_token_data")
                                  ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
                                  ->Utils.transformKeys(Utils.CamelCase)
                                ssn.completeMerchantValidation(. merchantSession)
                              }

                              ssn.onpaymentauthorized = event => {
                                ssn.completePayment(. {"status": ssn.\"STATUS_SUCCESS"}->objToJson)
                                applePaySessionRef := Js.Nullable.null
                                processPayment(event.payment.token)
                              }
                              ssn.oncancel = _ev => {
                                let msg =
                                  [("showApplePayButton", true->Js.Json.boolean)]->Js.Dict.fromArray
                                mountedIframeRef->Window.iframePostMessage(msg)
                                applePaySessionRef := Js.Nullable.null
                                Utils.logInfo(Js.log("Apple Pay payment cancelled"))
                              }
                            }
                          } else {
                            ()
                          }
                        | None => ()
                        }
                      }
                    )

                  addSmartEventListener(
                    "message",
                    handleApplePayMessages.contents,
                    "onApplePayMessages",
                  )
                }
                if componentType === "payment" && googlePayPresent->Belt.Option.isSome {
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
                    Js.Dict.empty()->Js.Json.object_,
                    baseRequest->toJson,
                  )

                  let payRequest = GooglePayType.assign(
                    Js.Dict.empty()->Js.Json.object_,
                    baseRequest->toJson,
                    {
                      "allowedPaymentMethods": gpayobj.allowed_payment_methods->arrayJsonToCamelCase,
                    }->toJson,
                  )
                  paymentDataRequest.allowedPaymentMethods =
                    gpayobj.allowed_payment_methods->arrayJsonToCamelCase
                  paymentDataRequest.transactionInfo =
                    gpayobj.transaction_info->transformKeys(CamelCase)
                  paymentDataRequest.merchantInfo = gpayobj.merchant_info->transformKeys(CamelCase)
                  try {
                    let gPayClient = GooglePayType.google(
                      {
                        "environment": publishableKey->Js.String2.startsWith("pk_prd_")
                          ? "PRODUCTION"
                          : "TEST",
                      }->toJson,
                    )

                    if gpayobj.allowed_payment_methods->Belt.Array.length !== 0 {
                      gPayClient.isReadyToPay(. payRequest)
                      ->then(res => {
                        let dict = res->getDictFromJson
                        let isReadyToPay = getBool(dict, "result", false)
                        let msg =
                          [("isReadyToPay", isReadyToPay->Js.Json.boolean)]->Js.Dict.fromArray
                        mountedIframeRef->Window.iframePostMessage(msg)
                        resolve()
                      })
                      ->catch(err => {
                        logger.setLogInfo(
                          ~value=err->toJson->Js.Json.stringify,
                          ~eventName=GOOGLE_PAY_FLOW,
                          ~paymentMethod="GOOGLE_PAY",
                          ~logType=DEBUG,
                          (),
                        )
                        resolve()
                      })
                      ->ignore
                    }

                    let handleGooglePayMessages = (event: Types.event) => {
                      let evJson = event.data->eventToJson
                      let gpayClicked =
                        evJson
                        ->OrcaUtils.getOptionalJsonFromJson("GpayClicked")
                        ->OrcaUtils.getBoolfromjson(false)

                      if gpayClicked {
                        Js.Global.setTimeout(() => {
                          gPayClient.loadPaymentData(. paymentDataRequest->toJson)
                          ->then(json => {
                            logger.setLogInfo(
                              ~value=json->toJson->Js.Json.stringify,
                              ~eventName=GOOGLE_PAY_FLOW,
                              ~paymentMethod="GOOGLE_PAY",
                              ~logType=DEBUG,
                              (),
                            )
                            let msg = [("gpayResponse", json->toJson)]->Js.Dict.fromArray
                            mountedIframeRef->Window.iframePostMessage(msg)
                            resolve()
                          })
                          ->catch(err => {
                            logger.setLogInfo(
                              ~value=err->toJson->Js.Json.stringify,
                              ~eventName=GOOGLE_PAY_FLOW,
                              ~paymentMethod="GOOGLE_PAY",
                              ~logType=DEBUG,
                              (),
                            )

                            let msg = [("gpayError", err->toJson)]->Js.Dict.fromArray
                            mountedIframeRef->Window.iframePostMessage(msg)
                            resolve()
                          })
                          ->ignore
                        }, 0)->ignore
                      }
                    }
                    addSmartEventListener("message", handleGooglePayMessages, "onGooglePayMessages")
                  } catch {
                  | _ => Js.log("Error loading Gpay")
                  }
                }

                json->resolve
              })
              ->then(json => {
                let msg = [("sessions", json)]->Js.Dict.fromArray
                mountedIframeRef->Window.iframePostMessage(msg)
                json->resolve
              })
              ->ignore
            }
          }
          let msg = [("sendSessionTokensResponse", true->Js.Json.boolean)]->Js.Dict.fromArray
          addSmartEventListener("message", handleSessionTokensLoaded, "onSessionTokensLoaded")

          iframeIsReadyPromise
          ->then(_ => {
            preMountLoaderIframeDiv->Window.iframePostMessage(msg)
            Js.Json.null->resolve
          })
          ->ignore
        }

        fetchPaymentsList(mountedIframeRef)
        disableSaveCards ? () : fetchCustomerPaymentMethods(mountedIframeRef)
        fetchSessionTokens(mountedIframeRef)
        mountedIframeRef->Window.iframePostMessage(message)
      }

      let paymentElement = LoaderPaymentElement.make(
        componentType,
        newOptions,
        setElementIframeRef,
        iframeRef,
        mountPostMessage,
      )
      savedPaymentElement->Js.Dict.set(componentType, paymentElement)
      paymentElement
    }
    {
      getElement: getElement,
      update: update,
      fetchUpdates: fetchUpdates,
      create: create,
    }
  } catch {
  | e => {
      Sentry.captureException(e)
      defaultElement
    }
  }
}
