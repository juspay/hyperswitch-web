open Types
open ErrorUtils
open Identity
open Utils
open EventListenerManager
open ApplePayTypes

type trustPayFunctions = {
  finishApplePaymentV2: (string, paymentRequestData) => Promise.t<JSON.t>,
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

    let localSelectorString = "hyper-preMountLoader-iframe"
    let mountPreMountLoaderIframe = () => {
      let componentType = "preMountLoader"
      let iframeDivHtml = `<div id="orca-element-${localSelectorString}" style= "height: 0px; width: 0px; display: none;"  class="${componentType}">
          <div id="orca-fullscreen-iframeRef-${localSelectorString}"></div>
           <iframe
           id ="orca-payment-element-iframeRef-${localSelectorString}"
           name="orca-payment-element-iframeRef-${localSelectorString}"
          src="${ApiEndpoint.sdkDomainUrl}/?fullscreenType=${componentType}&publishableKey=${publishableKey}&clientSecret=${clientSecret}&sessionId=${sdkSessionId}"
          allow="*"
          name="orca-payment"
        ></iframe>
        </div>`
      let iframeDiv = Window.createElement("div")
      iframeDiv->Window.innerHTML(iframeDivHtml)
      Window.body->Window.appendChild(iframeDiv)

      let elem = Window.querySelector(`#orca-payment-element-iframeRef-${localSelectorString}`)
      elem
    }

    let locale = localOptions->getJsonStringFromDict("locale", "")
    let loader = localOptions->getJsonStringFromDict("loader", "")
    let clientSecret = localOptions->getRequiredString("clientSecret", "", ~logger)
    let clientSecretReMatch = Js.Re.test_(`.+_secret_[A-Za-z0-9]+`->Js.Re.fromString, clientSecret)

    let preMountLoaderMountedPromise = Js.Promise.make((~resolve, ~reject as _) => {
      let preMountLoaderIframeCallback = (ev: Types.event) => {
        let json = ev.data->Identity.anyTypeToJson
        let dict = json->Utils.getDictFromJson
        if dict->Js.Dict.get("preMountLoaderIframeMountedCallback")->Belt.Option.isSome {
          Js.log("preMountLoaderIframeMountedCallback")
          resolve(true->Js.Json.boolean)
        }
      }
      addSmartEventListener(
        "message",
        preMountLoaderIframeCallback,
        "onPreMountLoaderIframeCallback",
      )
    })

    let preMountLoaderIframeDiv = mountPreMountLoaderIframe()

    let fetchPaymentsList = mountedIframeRef => {
      let handlePaymentMethodsLoaded = (event: Types.event) => {
        let json = event.data->Identity.anyTypeToJson
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
      preMountLoaderIframeDiv->Window.iframePostMessage(msg)
    }
    let fetchCustomerPaymentMethods = (mountedIframeRef, disableSaveCards) => {
      if !disableSaveCards {
        let handleCustomerPaymentMethodsLoaded = (event: Types.event) => {
          let json = event.data->Identity.anyTypeToJson
          let dict = json->getDictFromJson
          let isCustomerPaymentMethodsData =
            dict->Utils.getString("data", "") === "customer_payment_methods"
          if isCustomerPaymentMethodsData {
            let json = dict->Utils.getJsonFromDict("response", Js.Json.null)
            let msg = [("customerPaymentMethods", json)]->Js.Dict.fromArray
            mountedIframeRef->Window.iframePostMessage(msg)
          }
        }
        addSmartEventListener(
          "message",
          handleCustomerPaymentMethodsLoaded,
          "onCustomerPaymentMethodsLoaded",
        )
      }
      let msg =
        [
          ("sendCustomerPaymentMethodsResponse", !disableSaveCards->Js.Json.boolean),
        ]->Js.Dict.fromArray
      preMountLoaderIframeDiv->Window.iframePostMessage(msg)
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
      let otherElements = componentType->isOtherElements
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
          let json = event.data->anyTypeToJson
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
                          ~switchToCustomPod,
                          ~isForceSync=true,
                        )
                      )
                    let executeGooglePayment = trustpay.executeGooglePayment(
                      payment,
                      googlePayRequest,
                    )
                    let timeOut = delay(600000)->then(_ => {
                      let errorMsg =
                        [("error", "Request Timed Out"->JSON.Encode.string)]
                        ->Dict.fromArray
                        ->JSON.Encode.object
                      reject(Exn.anyToExnInternal(errorMsg))
                    })

                    Promise.race([polling, executeGooglePayment, timeOut])
                    ->then(res => {
                      logger.setLogInfo(
                        ~value="TrustPay GooglePay Response",
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
                      let exceptionMessage = err->formatException->JSON.stringify
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
        Window.removeEventListener("message", handleApplePayMessages.contents)

        let fetchSessionTokens = mountedIframeRef => {
          let handleSessionTokensLoaded = (event: Types.event) => {
            let json = event.data->Identity.anyTypeToJson
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
                if !(applePayPresent->Belt.Option.isSome) {
                  let msg =
                    [("applePaySessionObjNotPresent", true->Js.Json.boolean)]->Js.Dict.fromArray
                  mountedIframeRef->Window.iframePostMessage(msg)
                }
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
                  //do operations here

                  let processPayment = (token: Js.Json.t) => {
                    //let body = PaymentBody.applePayBody(~token)
                    let msg = [("applePayProcessPayment", token)]->Js.Dict.fromArray
                    mountedIframeRef->Window.iframePostMessage(msg)
                  }

                  handleApplePayMessages :=
                    (
                      (event: Types.event) => {
                        let json = event.data->Identity.anyTypeToJson
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
                                  trustpay.finishApplePaymentV2(payment, paymentRequest)
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
                                  session.abort()
                                } catch {
                                | error => Js.log2("Abort fail", error)
                                }
                              | None => ()
                              }

                              ssn.begin()
                              applePaySessionRef := ssn->Js.Nullable.return

                              ssn.onvalidatemerchant = _event => {
                                let merchantSession =
                                  applePayPresent
                                  ->Belt.Option.flatMap(Js.Json.decodeObject)
                                  ->Belt.Option.getWithDefault(Js.Dict.empty())
                                  ->Js.Dict.get("session_token_data")
                                  ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
                                  ->Utils.transformKeys(Utils.CamelCase)
                                ssn.completeMerchantValidation(merchantSession)
                              }

                              ssn.onpaymentauthorized = event => {
                                ssn.completePayment(
                                  {"status": ssn.\"STATUS_SUCCESS"}->Identity.anyTypeToJson,
                                )
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
                    baseRequest->Identity.anyTypeToJson,
                  )

                  let payRequest = GooglePayType.assign(
                    Js.Dict.empty()->Js.Json.object_,
                    baseRequest->Identity.anyTypeToJson,
                    {
                      "allowedPaymentMethods": gpayobj.allowed_payment_methods->arrayJsonToCamelCase,
                    }->Identity.anyTypeToJson,
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
                      }->Identity.anyTypeToJson,
                    )

                    gPayClient.isReadyToPay(payRequest)
                    ->then(res => {
                      let dict = res->getDictFromJson
                      let isReadyToPay = getBool(dict, "result", false)
                      let msg = [("isReadyToPay", isReadyToPay->Js.Json.boolean)]->Js.Dict.fromArray
                      mountedIframeRef->Window.iframePostMessage(msg)
                      resolve()
                    })
                    ->catch(err => {
                      logger.setLogInfo(
                        ~value=err->Identity.anyTypeToJson->Js.Json.stringify,
                        ~eventName=GOOGLE_PAY_FLOW,
                        ~paymentMethod="GOOGLE_PAY",
                        ~logType=DEBUG,
                        (),
                      )
                      resolve()
                    })
                    ->ignore

                    let handleGooglePayMessages = (event: Types.event) => {
                      let evJson = event.data->Identity.anyTypeToJson
                      let gpayClicked =
                        evJson
                        ->Utils.getOptionalJsonFromJson("GpayClicked")
                        ->Utils.getBoolFromJson(false)

                      if gpayClicked {
                        Js.Global.setTimeout(() => {
                          gPayClient.loadPaymentData(paymentDataRequest->Identity.anyTypeToJson)
                          ->then(
                            json => {
                              logger.setLogInfo(
                                ~value=json->Identity.anyTypeToJson->Js.Json.stringify,
                                ~eventName=GOOGLE_PAY_FLOW,
                                ~paymentMethod="GOOGLE_PAY",
                                ~logType=DEBUG,
                                (),
                              )
                              let msg =
                                [("gpayResponse", json->Identity.anyTypeToJson)]->Js.Dict.fromArray
                              mountedIframeRef->Window.iframePostMessage(msg)
                              resolve()
                            },
                          )
                          ->catch(
                            err => {
                              logger.setLogInfo(
                                ~value=err->Identity.anyTypeToJson->Js.Json.stringify,
                                ~eventName=GOOGLE_PAY_FLOW,
                                ~paymentMethod="GOOGLE_PAY",
                                ~logType=DEBUG,
                                (),
                              )

                              let msg =
                                [("gpayError", err->Identity.anyTypeToJson)]->Js.Dict.fromArray
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
          preMountLoaderIframeDiv->Window.iframePostMessage(msg)
        }
        preMountLoaderMountedPromise
        ->then(_ => {
          Js.log("preMountLoaderIframeMountedCallback then")
          fetchPaymentsList(mountedIframeRef)
          if (
            newOptions
            ->getDictFromJson
            ->getBool("displaySavedPaymentMethods", true)
          ) {
            fetchCustomerPaymentMethods(mountedIframeRef, false)
          }
          fetchSessionTokens(mountedIframeRef)
          mountedIframeRef->Window.iframePostMessage(message)
          resolve()
        })
        ->ignore
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
