open Types
open ErrorUtils
open Identity
open Utils
open EventListenerManager
open ApplePayTypes
@send external alert: ('t, string) => unit = "alert"

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
      if (
        Window.querySelector(
          `#orca-payment-element-iframeRef-${localSelectorString}`,
        )->Js.Nullable.isNullable
      ) {
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

    let unMountPreMountLoaderIframe = () => {
      switch preMountLoaderIframeDiv->Nullable.toOption {
      | Some(iframe) => iframe->remove
      | None => ()
      }
    }

    let preMountLoaderMountedPromise = Promise.make((resolve, _reject) => {
      let preMountLoaderIframeCallback = (ev: Types.event) => {
        let json = ev.data->Identity.anyTypeToJson
        let dict = json->Utils.getDictFromJson
        if dict->Dict.get("preMountLoaderIframeMountedCallback")->Belt.Option.isSome {
          resolve(true->JSON.Encode.bool)
        } else if dict->Dict.get("preMountLoaderIframeUnMount")->Belt.Option.isSome {
          unMountPreMountLoaderIframe()
        }
      }
      addSmartEventListener(
        "message",
        preMountLoaderIframeCallback,
        "onPreMountLoaderIframeCallback",
      )
    })

    let fetchPaymentsList = mountedIframeRef => {
      let handlePaymentMethodsLoaded = (event: Types.event) => {
        let json = event.data->Identity.anyTypeToJson
        let dict = json->getDictFromJson
        let isPaymentMethodsData = dict->Utils.getString("data", "") === "payment_methods"
        if isPaymentMethodsData {
          let json = dict->Utils.getJsonFromDict("response", JSON.Encode.null)
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
          let msg = [("paymentMethodList", json)]->Dict.fromArray
          mountedIframeRef->Window.iframePostMessage(msg)
        }
      }
      let msg = [("sendPaymentMethodsResponse", true->JSON.Encode.bool)]->Dict.fromArray
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
            let json = dict->Utils.getJsonFromDict("response", JSON.Encode.null)
            let msg = [("customerPaymentMethods", json)]->Dict.fromArray
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
          ("sendCustomerPaymentMethodsResponse", !disableSaveCards->JSON.Encode.bool),
        ]->Dict.fromArray
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

        let handlePollStatusMessage = (ev: Types.event) => {
          let eventDataObject = ev.data->anyTypeToJson
          let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
          switch eventDataObject->getOptionalJsonFromJson("poll_status") {
          | Some(val) => {
              handlePostMessage([
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
              PaymentHelpers.pollStatus(~headers, ~switchToCustomPod, ~pollId, ~interval, ~count)
              ->then(res => {
                let dict = res->JSON.Decode.object->Option.getOr(Dict.make())
                let status = dict->getString("status", "")
                if status === "completed" {
                  Window.Location.replace(url)->ignore // retrive status
                }->resolve
              })
              ->catch(_e =>
                postFailedSubmitResponse(
                  ~errortype="Server_error",
                  ~message="Something went Wrong",
                )->resolve
              )
              ->ignore
            }
          | None => ()
          }
        }

        addSmartEventListener("message", handleApplePayMounted, "onApplePayMount")
        addSmartEventListener("message", handlePollStatusMessage, "onPollStatusMsg")
        addSmartEventListener("message", handleGooglePayThirdPartyFlow, "onGooglePayThirdParty")

        let fetchSessionTokens = mountedIframeRef => {
          let handleSessionTokensLoaded = (event: Types.event) => {
            let json = event.data->Identity.anyTypeToJson
            let dict = json->getDictFromJson
            let sessionTokensData = dict->Utils.getString("data", "") === "session_tokens"
            if sessionTokensData {
              let json = dict->Utils.getJsonFromDict("response", JSON.Encode.null)

              {
                let sessionsArr =
                  json
                  ->JSON.Decode.object
                  ->Belt.Option.getWithDefault(Dict.make())
                  ->SessionsType.getSessionsTokenJson("session_token")

                let applePayPresent = sessionsArr->Array.find(item => {
                  let x =
                    item
                    ->JSON.Decode.object
                    ->Belt.Option.flatMap(x => {
                      x->Dict.get("wallet_name")
                    })
                    ->Belt.Option.flatMap(JSON.Decode.string)
                    ->Belt.Option.getWithDefault("")
                  x === "apple_pay" || x === "applepay"
                })
                if !(applePayPresent->Belt.Option.isSome) {
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
                    ->Belt.Option.getWithDefault("")
                  x === "google_pay" || x === "googlepay"
                })

                (json, applePayPresent, googlePayPresent)->resolve
              }
              ->then(res => {
                let (json, applePayPresent, googlePayPresent) = res
                if componentType === "payment" && applePayPresent->Belt.Option.isSome {
                  //do operations here
                  let processPayment = (token: JSON.t) => {
                    //let body = PaymentBody.applePayBody(~token)
                    let msg = [("applePayProcessPayment", token)]->Dict.fromArray
                    mountedIframeRef->Window.iframePostMessage(msg)
                  }

                  handleApplePayMessages :=
                    (
                      (event: Types.event) => {
                        let json = event.data->Identity.anyTypeToJson
                        let dict = json->getDictFromJson
                        switch dict->Dict.get("applePayButtonClicked") {
                        | Some(val) =>
                          if val->JSON.Decode.bool->Belt.Option.getWithDefault(false) {
                            let isDelayedSessionToken =
                              applePayPresent
                              ->Belt.Option.flatMap(JSON.Decode.object)
                              ->Belt.Option.getWithDefault(Dict.make())
                              ->Dict.get("delayed_session_token")
                              ->Belt.Option.getWithDefault(JSON.Encode.null)
                              ->JSON.Decode.bool
                              ->Belt.Option.getWithDefault(false)

                            Window.window->alert(
                              "isDelayedSessionToken: " ++
                              isDelayedSessionToken->anyTypeToJson->JSON.stringify,
                            )

                            if isDelayedSessionToken {
                              logger.setLogInfo(
                                ~value="Delayed Session Token Flow",
                                ~eventName=APPLE_PAY_FLOW,
                                ~paymentMethod="APPLE_PAY",
                                (),
                              )

                              let applePaySessionTokenData =
                                dict
                                ->Dict.get("applePayPresent")
                                ->Belt.Option.flatMap(JSON.Decode.object)
                                ->Belt.Option.getWithDefault(Dict.make())

                              Window.window->alert(
                                "applePaySessionTokenData: " ++
                                applePaySessionTokenData->anyTypeToJson->JSON.stringify,
                              )

                              let connector =
                                applePaySessionTokenData
                                ->Dict.get("connector")
                                ->Belt.Option.getWithDefault(JSON.Encode.null)
                                ->JSON.Decode.string
                                ->Belt.Option.getWithDefault("")

                              Window.window->alert(
                                "connector: " ++ connector->anyTypeToJson->JSON.stringify,
                              )

                              switch connector {
                              | "trustpay" =>
                                logger.setLogInfo(
                                  ~value="TrustPay Connector Flow",
                                  ~eventName=APPLE_PAY_FLOW,
                                  ~paymentMethod="APPLE_PAY",
                                  (),
                                )
                                let secrets =
                                  applePaySessionTokenData
                                  ->Dict.get("session_token_data")
                                  ->Belt.Option.getWithDefault(JSON.Encode.null)
                                  ->JSON.Decode.object
                                  ->Belt.Option.getWithDefault(Dict.make())
                                  ->Dict.get("secrets")
                                  ->Belt.Option.getWithDefault(JSON.Encode.null)

                                Window.window->alert(
                                  "secrets: " ++ secrets->anyTypeToJson->JSON.stringify,
                                )

                                let paymentRequest =
                                  applePaySessionTokenData
                                  ->Dict.get("payment_request_data")
                                  ->Belt.Option.flatMap(JSON.Decode.object)
                                  ->Belt.Option.getWithDefault(Dict.make())
                                  ->ApplePayTypes.jsonToPaymentRequestDataType

                                Window.window->alert(
                                  "paymentRequest: " ++
                                  paymentRequest->anyTypeToJson->JSON.stringify,
                                )

                                let payment =
                                  secrets
                                  ->JSON.Decode.object
                                  ->Belt.Option.getWithDefault(Dict.make())
                                  ->Dict.get("payment")
                                  ->Belt.Option.getWithDefault(JSON.Encode.null)
                                  ->JSON.Decode.string
                                  ->Belt.Option.getWithDefault("")

                                Window.window->alert(
                                  "payment: " ++ payment->anyTypeToJson->JSON.stringify,
                                )

                                try {
                                  let trustpay = trustPayApi(secrets)
                                  trustpay.finishApplePaymentV2(payment, paymentRequest)
                                  ->then(res => {
                                    Window.window->alert(
                                      "res: " ++ res->anyTypeToJson->JSON.stringify,
                                    )
                                    logger.setLogInfo(
                                      ~value="TrustPay ApplePay Success Response",
                                      ~internalMetadata=res->JSON.stringify,
                                      ~eventName=APPLE_PAY_FLOW,
                                      ~paymentMethod="APPLE_PAY",
                                      (),
                                    )
                                    let msg =
                                      [
                                        ("applePaySyncPayment", true->JSON.Encode.bool),
                                        ("breakpoint", "1"->JSON.Encode.string),
                                      ]->Dict.fromArray
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
                                      err->Utils.formatException->JSON.stringify
                                    Window.window->alert(
                                      "err: " ++ err->anyTypeToJson->JSON.stringify,
                                    )
                                    logger.setLogInfo(
                                      ~eventName=APPLE_PAY_FLOW,
                                      ~paymentMethod="APPLE_PAY",
                                      ~value=exceptionMessage,
                                      (),
                                    )
                                    let msg =
                                      [
                                        ("applePaySyncPayment", true->JSON.Encode.bool),
                                        ("breakpoint", "2"->JSON.Encode.string),
                                      ]->Dict.fromArray
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
                                    Window.window->alert(
                                      "exn: " ++ exn->Utils.formatException->JSON.stringify,
                                    )
                                    let msg =
                                      [
                                        ("applePaySyncPayment", true->JSON.Encode.bool),
                                        ("breakpoint", "3"->JSON.Encode.string),
                                      ]->Dict.fromArray
                                    mountedIframeRef->Window.iframePostMessage(msg)
                                  }
                                }
                              | _ => ()
                              }
                            } else {
                              let paymentRequest =
                                applePayPresent
                                ->Belt.Option.flatMap(JSON.Decode.object)
                                ->Belt.Option.getWithDefault(Dict.make())
                                ->Dict.get("payment_request_data")
                                ->Belt.Option.getWithDefault(Dict.make()->JSON.Encode.object)
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

                              ssn.begin()
                              applePaySessionRef := ssn->Js.Nullable.return

                              ssn.onvalidatemerchant = _event => {
                                let merchantSession =
                                  applePayPresent
                                  ->Belt.Option.flatMap(JSON.Decode.object)
                                  ->Belt.Option.getWithDefault(Dict.make())
                                  ->Dict.get("session_token_data")
                                  ->Belt.Option.getWithDefault(Dict.make()->JSON.Encode.object)
                                  ->Utils.transformKeys(Utils.CamelCase)
                                ssn.completeMerchantValidation(merchantSession)
                              }

                              ssn.onpaymentauthorized = event => {
                                ssn.completePayment(
                                  {"status": ssn.\"STATUS_SUCCESS"}->Identity.anyTypeToJson,
                                )
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
                    Dict.make()->JSON.Encode.object,
                    baseRequest->Identity.anyTypeToJson,
                  )

                  let payRequest = GooglePayType.assign(
                    Dict.make()->JSON.Encode.object,
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
                        "environment": publishableKey->String.startsWith("pk_prd_")
                          ? "PRODUCTION"
                          : "TEST",
                      }->Identity.anyTypeToJson,
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
                        ~value=err->Identity.anyTypeToJson->JSON.stringify,
                        ~eventName=GOOGLE_PAY_FLOW,
                        ~paymentMethod="GOOGLE_PAY",
                        ~logType=DEBUG,
                        (),
                      )
                      resolve()
                    })
                    ->ignore

                    let handleGooglePayMessages = (event: Types.event) => {
                      let evJson = event.data->anyTypeToJson
                      let gpayClicked =
                        evJson
                        ->getOptionalJsonFromJson("GpayClicked")
                        ->getBoolFromJson(false)

                      if gpayClicked {
                        setTimeout(() => {
                          gPayClient.loadPaymentData(paymentDataRequest->anyTypeToJson)
                          ->then(
                            json => {
                              let msg = [("gpayResponse", json->anyTypeToJson)]->Dict.fromArray
                              mountedIframeRef->Window.iframePostMessage(msg)
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
                                (),
                              )

                              let msg = [("gpayError", err->anyTypeToJson)]->Dict.fromArray
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
            }
          }
          let msg = [("sendSessionTokensResponse", true->JSON.Encode.bool)]->Dict.fromArray
          addSmartEventListener("message", handleSessionTokensLoaded, "onSessionTokensLoaded")
          preMountLoaderIframeDiv->Window.iframePostMessage(msg)
        }
        preMountLoaderMountedPromise
        ->then(_ => {
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
