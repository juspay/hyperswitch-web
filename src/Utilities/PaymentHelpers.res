open Utils
open Identity
open PaymentHelpersTypes
open LoggerUtils
open URLModule

let getPaymentType = paymentMethodType =>
  switch paymentMethodType {
  | "apple_pay" => Applepay
  | "samsung_pay" => Samsungpay
  | "google_pay" => Gpay
  | "paze" => Paze
  | "debit"
  | "credit"
  | "" =>
    Card
  | _ => Other
  }

let closePaymentLoaderIfAny = () => messageParentWindow([("fullscreen", false->JSON.Encode.bool)])

let retrievePaymentIntent = (
  clientSecret,
  headers,
  ~optLogger,
  ~customPodUri,
  ~isForceSync=false,
) => {
  open Promise
  let paymentIntentID = clientSecret->Utils.getPaymentId
  let endpoint = ApiEndpoint.getApiEndPoint()
  let forceSync = isForceSync ? "&force_sync=true" : ""
  let uri = `${endpoint}/payments/${paymentIntentID}?client_secret=${clientSecret}${forceSync}`

  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=RETRIEVE_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=RETRIEVE_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=RETRIEVE_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      res->Fetch.Response.json
    }
  })
  ->catch(e => {
    Console.error2("Unable to retrieve payment details because of ", e)
    JSON.Encode.null->resolve
  })
}

let threeDsAuth = (~clientSecret, ~optLogger, ~threeDsMethodComp, ~headers) => {
  let endpoint = ApiEndpoint.getApiEndPoint()
  let paymentIntentID = String.split(clientSecret, "_secret_")[0]->Option.getOr("")
  let url = `${endpoint}/payments/${paymentIntentID}/3ds/authentication`
  let broswerInfo = BrowserSpec.broswerInfo
  let body =
    [
      ("client_secret", clientSecret->JSON.Encode.string),
      ("device_channel", "BRW"->JSON.Encode.string),
      ("threeds_method_comp_ind", threeDsMethodComp->JSON.Encode.string),
    ]
    ->Array.concat(broswerInfo())
    ->getJsonFromArrayOfJson

  open Promise
  logApi(
    ~optLogger,
    ~url,
    ~apiLogType=Request,
    ~eventName=AUTHENTICATION_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(url, ~method=#POST, ~bodyStr=body->JSON.stringify, ~headers=headers->Dict.fromArray)
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=AUTHENTICATION_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        let dict = data->getDictFromJson
        let errorObj = PaymentError.itemToObjMapper(dict)
        closePaymentLoaderIfAny()
        postFailedSubmitResponse(~errortype=errorObj.error.type_, ~message=errorObj.error.message)
        JSON.Encode.null->resolve
      })
    } else {
      logApi(~optLogger, ~url, ~statusCode, ~apiLogType=Response, ~eventName=AUTHENTICATION_CALL)
      res->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    Console.error2("Unable to call 3ds auth ", exceptionMessage)
    logApi(
      ~optLogger,
      ~url,
      ~eventName=AUTHENTICATION_CALL,
      ~apiLogType=NoResponse,
      ~data=exceptionMessage,
      ~logType=ERROR,
      ~logCategory=API,
    )
    reject(err)
  })
}

let rec pollRetrievePaymentIntent = (
  clientSecret,
  headers,
  ~optLogger,
  ~customPodUri,
  ~isForceSync=false,
) => {
  open Promise
  retrievePaymentIntent(clientSecret, headers, ~optLogger, ~customPodUri, ~isForceSync)
  ->then(json => {
    let dict = json->getDictFromJson
    let status = dict->getString("status", "")

    if status === "succeeded" || status === "failed" {
      resolve(json)
    } else {
      delay(2000)
      ->then(_val => {
        pollRetrievePaymentIntent(clientSecret, headers, ~optLogger, ~customPodUri, ~isForceSync)
      })
      ->catch(_ => Promise.resolve(JSON.Encode.null))
    }
  })
  ->catch(e => {
    Console.error2("Unable to retrieve payment due to following error", e)
    pollRetrievePaymentIntent(clientSecret, headers, ~optLogger, ~customPodUri, ~isForceSync)
  })
}

let retrieveStatus = (~headers, ~customPodUri, pollID, logger) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let uri = `${endpoint}/poll/status/${pollID}`
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=POLL_STATUS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=POLL_STATUS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=POLL_STATUS_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      res->Fetch.Response.json
    }
  })
  ->catch(e => {
    Console.error2("Unable to Poll status details because of ", e)
    JSON.Encode.null->resolve
  })
}

let rec pollStatus = (~headers, ~customPodUri, ~pollId, ~interval, ~count, ~returnUrl, ~logger) => {
  open Promise
  retrieveStatus(~headers, ~customPodUri, pollId, logger)
  ->then(json => {
    let dict = json->getDictFromJson
    let status = dict->getString("status", "")
    Promise.make((resolve, _) => {
      if status === "completed" {
        resolve(json)
      } else if count === 0 {
        messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
        openUrl(returnUrl)
      } else {
        delay(interval)
        ->then(
          _ => {
            pollStatus(
              ~headers,
              ~customPodUri,
              ~pollId,
              ~interval,
              ~count=count - 1,
              ~returnUrl,
              ~logger,
            )->then(
              res => {
                resolve(res)
                Promise.resolve()
              },
            )
          },
        )
        ->catch(_ => Promise.resolve())
        ->ignore
      }
    })
  })
  ->catch(e => {
    Console.error2("Unable to retrieve payment due to following error", e)
    pollStatus(
      ~headers,
      ~customPodUri,
      ~pollId,
      ~interval,
      ~count=count - 1,
      ~returnUrl,
      ~logger,
    )->then(res => resolve(res))
  })
}

let rec intentCall = (
  ~fetchApi: (
    string,
    ~bodyStr: string=?,
    ~headers: Dict.t<string>=?,
    ~method: Fetch.method,
  ) => promise<Fetch.Response.t>,
  ~uri,
  ~headers,
  ~bodyStr,
  ~confirmParam: ConfirmType.confirmParams,
  ~clientSecret,
  ~optLogger,
  ~handleUserError,
  ~paymentType,
  ~iframeId,
  ~fetchMethod,
  ~setIsManualRetryEnabled,
  ~customPodUri,
  ~sdkHandleOneClickConfirmPayment,
  ~counter,
  ~isPaymentSession=false,
  ~isCallbackUsedVal=?,
  ~componentName="payment",
  ~redirectionFlags,
) => {
  open Promise
  let isConfirm = uri->String.includes("/confirm")

  let isCompleteAuthorize = uri->String.includes("/complete_authorize")
  let isPostSessionTokens = uri->String.includes("/post_session_tokens")
  let (eventName: HyperLoggerTypes.eventName, initEventName: HyperLoggerTypes.eventName) = switch (
    isConfirm,
    isCompleteAuthorize,
    isPostSessionTokens,
  ) {
  | (true, _, _) => (CONFIRM_CALL, CONFIRM_CALL_INIT)
  | (_, true, _) => (COMPLETE_AUTHORIZE_CALL, COMPLETE_AUTHORIZE_CALL_INIT)
  | (_, _, true) => (POST_SESSION_TOKENS_CALL, POST_SESSION_TOKENS_CALL_INIT)
  | _ => (RETRIEVE_CALL, RETRIEVE_CALL_INIT)
  }
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=initEventName,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession,
  )
  let handleOpenUrl = url => {
    if isPaymentSession {
      Utils.replaceRootHref(url, redirectionFlags)
    } else {
      openUrl(url)
    }
  }
  fetchApi(
    uri,
    ~method=fetchMethod,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
    ~bodyStr,
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    let url = makeUrl(confirmParam.return_url)
    url.searchParams.set("payment_intent_client_secret", clientSecret)
    url.searchParams.set("status", "failed")
    url.searchParams.set("payment_id", clientSecret->Utils.getPaymentId)
    messageParentWindow([("confirmParams", confirmParam->anyTypeToJson)])

    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        Promise.make(
          (resolve, _) => {
            if isConfirm {
              let paymentMethod = switch paymentType {
              | Card => "CARD"
              | _ =>
                bodyStr
                ->safeParse
                ->getDictFromJson
                ->getString("payment_method_type", "")
              }
              handleLogging(
                ~optLogger,
                ~value=data->JSON.stringify,
                ~eventName=PAYMENT_FAILED,
                ~paymentMethod,
              )
            }
            logApi(
              ~optLogger,
              ~url=uri,
              ~data,
              ~statusCode,
              ~apiLogType=Err,
              ~eventName,
              ~logType=ERROR,
              ~logCategory=API,
              ~isPaymentSession,
            )

            let dict = data->getDictFromJson
            let errorObj = PaymentError.itemToObjMapper(dict)
            if !isPaymentSession {
              closePaymentLoaderIfAny()
              postFailedSubmitResponse(
                ~errortype=errorObj.error.type_,
                ~message=errorObj.error.message,
              )
            }
            if handleUserError {
              handleOpenUrl(url.href)
            } else {
              let failedSubmitResponse = getFailedSubmitResponse(
                ~errorType=errorObj.error.type_,
                ~message=errorObj.error.message,
              )
              resolve(failedSubmitResponse)
            }
          },
        )->then(resolve)
      })
      ->catch(err => {
        Promise.make(
          (resolve, _) => {
            let exceptionMessage = err->formatException
            logApi(
              ~optLogger,
              ~url=uri,
              ~statusCode,
              ~apiLogType=NoResponse,
              ~data=exceptionMessage,
              ~eventName,
              ~logType=ERROR,
              ~logCategory=API,
              ~isPaymentSession,
            )
            if counter >= 5 {
              if !isPaymentSession {
                closePaymentLoaderIfAny()
                postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
              }
              if handleUserError {
                handleOpenUrl(url.href)
              } else {
                let failedSubmitResponse = getFailedSubmitResponse(
                  ~errorType="server_error",
                  ~message="Something went wrong",
                )
                resolve(failedSubmitResponse)
              }
            } else {
              let paymentIntentID = clientSecret->Utils.getPaymentId
              let endpoint = ApiEndpoint.getApiEndPoint(
                ~publishableKey=confirmParam.publishableKey,
                ~isConfirmCall=isConfirm,
              )
              let retrieveUri = `${endpoint}/payments/${paymentIntentID}?client_secret=${clientSecret}`
              intentCall(
                ~fetchApi,
                ~uri=retrieveUri,
                ~headers,
                ~bodyStr,
                ~confirmParam: ConfirmType.confirmParams,
                ~clientSecret,
                ~optLogger,
                ~handleUserError,
                ~paymentType,
                ~iframeId,
                ~fetchMethod=#GET,
                ~setIsManualRetryEnabled,
                ~customPodUri,
                ~sdkHandleOneClickConfirmPayment,
                ~counter=counter + 1,
                ~componentName,
                ~redirectionFlags,
              )
              ->then(
                res => {
                  resolve(res)
                  Promise.resolve()
                },
              )
              ->catch(_ => Promise.resolve())
              ->ignore
            }
          },
        )->then(resolve)
      })
    } else {
      res
      ->Fetch.Response.json
      ->then(data => {
        Promise.make(
          (resolve, _) => {
            logApi(
              ~optLogger,
              ~url=uri,
              ~statusCode,
              ~apiLogType=Response,
              ~eventName,
              ~isPaymentSession,
            )
            let intent = PaymentConfirmTypes.itemToObjMapper(data->getDictFromJson)
            let paymentMethod = switch paymentType {
            | Card => "CARD"
            | _ => intent.payment_method_type
            }

            let url = makeUrl(confirmParam.return_url)
            url.searchParams.set("payment_intent_client_secret", clientSecret)
            url.searchParams.set("payment_id", clientSecret->Utils.getPaymentId)
            url.searchParams.set("status", intent.status)

            let handleProcessingStatus = (paymentType, sdkHandleOneClickConfirmPayment) => {
              switch (paymentType, sdkHandleOneClickConfirmPayment) {
              | (Card, _)
              | (Gpay, false)
              | (Applepay, false)
              | (Paypal, false) =>
                if !isPaymentSession {
                  if isCallbackUsedVal->Option.getOr(false) {
                    handleOnCompleteDoThisMessage()
                  } else {
                    closePaymentLoaderIfAny()
                  }

                  postSubmitResponse(~jsonData=data, ~url=url.href)
                } else if confirmParam.redirect === Some("always") {
                  if isCallbackUsedVal->Option.getOr(false) {
                    handleOnCompleteDoThisMessage()
                  } else {
                    handleOpenUrl(url.href)
                  }
                } else {
                  resolve(data)
                }
              | _ =>
                if isCallbackUsedVal->Option.getOr(false) {
                  closePaymentLoaderIfAny()
                  handleOnCompleteDoThisMessage()
                } else {
                  handleOpenUrl(url.href)
                }
              }
            }

            if intent.status == "requires_customer_action" {
              if intent.nextAction.type_ == "redirect_to_url" {
                handleLogging(
                  ~optLogger,
                  ~value="",
                  ~internalMetadata=intent.nextAction.redirectToUrl,
                  ~eventName=REDIRECTING_USER,
                  ~paymentMethod,
                )
                handleOpenUrl(intent.nextAction.redirectToUrl)
              } else if intent.nextAction.type_ == "display_bank_transfer_information" {
                let metadata = switch intent.nextAction.bank_transfer_steps_and_charges_details {
                | Some(obj) => obj->getDictFromJson
                | None => Dict.make()
                }
                let dict = deepCopyDict(metadata)
                dict->Dict.set("data", data)
                dict->Dict.set("url", url.href->JSON.Encode.string)
                handleLogging(
                  ~optLogger,
                  ~value="",
                  ~internalMetadata=dict->JSON.Encode.object->JSON.stringify,
                  ~eventName=DISPLAY_BANK_TRANSFER_INFO_PAGE,
                  ~paymentMethod,
                )
                if !isPaymentSession {
                  messageParentWindow([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `${intent.payment_method_type}BankTransfer`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", dict->JSON.Encode.object),
                  ])
                }
                resolve(data)
              } else if intent.nextAction.type_ === "qr_code_information" {
                let qrData = intent.nextAction.image_data_url->Option.getOr("")
                let displayText = intent.nextAction.display_text->Option.getOr("")
                let borderColor = intent.nextAction.border_color->Option.getOr("")
                let expiryTime = intent.nextAction.display_to_timestamp->Option.getOr(0.0)
                let headerObj = Dict.make()
                mergeHeadersIntoDict(~dict=headerObj, ~headers)
                let metaData =
                  [
                    ("qrData", qrData->JSON.Encode.string),
                    ("paymentIntentId", clientSecret->JSON.Encode.string),
                    ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
                    ("headers", headerObj->JSON.Encode.object),
                    ("expiryTime", expiryTime->Float.toString->JSON.Encode.string),
                    ("url", url.href->JSON.Encode.string),
                    ("paymentMethod", paymentMethod->JSON.Encode.string),
                    ("display_text", displayText->JSON.Encode.string),
                    ("border_color", borderColor->JSON.Encode.string),
                  ]->getJsonFromArrayOfJson
                handleLogging(
                  ~optLogger,
                  ~value="",
                  ~internalMetadata=metaData->JSON.stringify,
                  ~eventName=DISPLAY_QR_CODE_INFO_PAGE,
                  ~paymentMethod,
                )
                if !isPaymentSession {
                  messageParentWindow([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `qrData`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", metaData),
                  ])
                }
                resolve(data)
              } else if intent.nextAction.type_ === "three_ds_invoke" {
                let threeDsData =
                  intent.nextAction.three_ds_data
                  ->Option.flatMap(JSON.Decode.object)
                  ->Option.getOr(Dict.make())
                let do3dsMethodCall =
                  threeDsData
                  ->Dict.get("three_ds_method_details")
                  ->Option.flatMap(JSON.Decode.object)
                  ->Option.flatMap(x => x->Dict.get("three_ds_method_data_submission"))
                  ->Option.getOr(Dict.make()->JSON.Encode.object)
                  ->JSON.Decode.bool
                  ->getBoolValue

                let headerObj = Dict.make()
                mergeHeadersIntoDict(~dict=headerObj, ~headers)

                let metaData =
                  [
                    ("threeDSData", threeDsData->JSON.Encode.object),
                    ("paymentIntentId", clientSecret->JSON.Encode.string),
                    ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
                    ("headers", headerObj->JSON.Encode.object),
                    ("url", url.href->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                  ]->Dict.fromArray

                handleLogging(
                  ~optLogger,
                  ~value=do3dsMethodCall ? "Y" : "N",
                  ~eventName=THREE_DS_METHOD,
                  ~paymentMethod,
                )

                if do3dsMethodCall {
                  messageParentWindow([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `3ds`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", metaData->JSON.Encode.object),
                  ])
                } else {
                  metaData->Dict.set("3dsMethodComp", "U"->JSON.Encode.string)
                  messageParentWindow([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `3dsAuth`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", metaData->JSON.Encode.object),
                  ])
                }
              } else if intent.nextAction.type_ === "invoke_hidden_iframe" {
                let iframeData =
                  intent.nextAction.iframe_data
                  ->Option.flatMap(JSON.Decode.object)
                  ->Option.getOr(Dict.make())

                let headerObj = Dict.make()
                mergeHeadersIntoDict(~dict=headerObj, ~headers)
                let metaData =
                  [
                    ("iframeData", iframeData->JSON.Encode.object),
                    ("paymentIntentId", clientSecret->JSON.Encode.string),
                    ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
                    ("headers", headerObj->JSON.Encode.object),
                    ("url", url.href->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("confirmParams", confirmParam->anyTypeToJson),
                  ]->Dict.fromArray

                messageParentWindow([
                  ("fullscreen", true->JSON.Encode.bool),
                  ("param", `redsys3ds`->JSON.Encode.string),
                  ("iframeId", iframeId->JSON.Encode.string),
                  ("metadata", metaData->JSON.Encode.object),
                ])
              } else if intent.nextAction.type_ === "display_voucher_information" {
                let voucherData = intent.nextAction.voucher_details->Option.getOr({
                  download_url: "",
                  reference: "",
                })
                let headerObj = Dict.make()
                mergeHeadersIntoDict(~dict=headerObj, ~headers)
                let metaData =
                  [
                    ("voucherUrl", voucherData.download_url->JSON.Encode.string),
                    ("reference", voucherData.reference->JSON.Encode.string),
                    ("returnUrl", url.href->JSON.Encode.string),
                    ("paymentMethod", paymentMethod->JSON.Encode.string),
                    ("payment_intent_data", data),
                  ]->Dict.fromArray
                handleLogging(
                  ~optLogger,
                  ~value="",
                  ~internalMetadata=metaData->JSON.Encode.object->JSON.stringify,
                  ~eventName=DISPLAY_VOUCHER,
                  ~paymentMethod,
                )
                messageParentWindow([
                  ("fullscreen", true->JSON.Encode.bool),
                  ("param", `voucherData`->JSON.Encode.string),
                  ("iframeId", iframeId->JSON.Encode.string),
                  ("metadata", metaData->JSON.Encode.object),
                ])
              } else if intent.nextAction.type_ == "third_party_sdk_session_token" {
                let session_token = switch intent.nextAction.session_token {
                | Some(token) => token->getDictFromJson
                | None => Dict.make()
                }
                let walletName = session_token->getString("wallet_name", "")

                let message = switch walletName {
                | "apple_pay" => [
                    ("applePayButtonClicked", true->JSON.Encode.bool),
                    ("applePayPresent", session_token->anyTypeToJson),
                    ("componentName", componentName->JSON.Encode.string),
                  ]
                | "google_pay" => [("googlePayThirdPartyFlow", session_token->anyTypeToJson)]
                | "open_banking" => {
                    let metaData = [
                      (
                        "linkToken",
                        session_token
                        ->getString("open_banking_session_token", "")
                        ->JSON.Encode.string,
                      ),
                      ("pmAuthConnectorArray", ["plaid"]->anyTypeToJson),
                      ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
                      ("clientSecret", clientSecret->JSON.Encode.string),
                      ("isForceSync", true->JSON.Encode.bool),
                    ]->getJsonFromArrayOfJson
                    [
                      ("fullscreen", true->JSON.Encode.bool),
                      ("param", "plaidSDK"->JSON.Encode.string),
                      ("iframeId", iframeId->JSON.Encode.string),
                      ("metadata", metaData),
                    ]
                  }
                | _ => []
                }

                if !isPaymentSession {
                  messageParentWindow(message)
                }
                resolve(data)
              } else if intent.nextAction.type_ === "invoke_sdk_client" {
                let nextActionData =
                  intent.nextAction.next_action_data->Option.getOr(JSON.Encode.null)
                let response =
                  [
                    ("orderId", intent.connectorTransactionId->JSON.Encode.string),
                    ("nextActionData", nextActionData),
                  ]->getJsonFromArrayOfJson
                resolve(response)
              } else {
                if !isPaymentSession {
                  postFailedSubmitResponse(
                    ~errortype="confirm_payment_failed",
                    ~message="Payment failed. Try again!",
                  )
                }
                if uri->String.includes("force_sync=true") {
                  handleLogging(
                    ~optLogger,
                    ~value=intent.nextAction.type_,
                    ~internalMetadata=intent.nextAction.type_,
                    ~eventName=REDIRECTING_USER,
                    ~paymentMethod,
                    ~logType=ERROR,
                  )
                  handleOpenUrl(url.href)
                } else {
                  let failedSubmitResponse = getFailedSubmitResponse(
                    ~errorType="confirm_payment_failed",
                    ~message="Payment failed. Try again!",
                  )
                  resolve(failedSubmitResponse)
                }
              }
            } else if intent.status == "requires_payment_method" {
              if intent.nextAction.type_ === "invoke_sdk_client" {
                let nextActionData =
                  intent.nextAction.next_action_data->Option.getOr(JSON.Encode.null)
                let response =
                  [
                    ("orderId", intent.connectorTransactionId->JSON.Encode.string),
                    ("nextActionData", nextActionData),
                  ]->getJsonFromArrayOfJson
                resolve(response)
              }
            } else if intent.status == "processing" {
              if intent.nextAction.type_ == "third_party_sdk_session_token" {
                let session_token = switch intent.nextAction.session_token {
                | Some(token) => token->getDictFromJson
                | None => Dict.make()
                }
                let walletName = session_token->getString("wallet_name", "")
                let message = switch walletName {
                | "apple_pay" => [
                    ("applePayButtonClicked", true->JSON.Encode.bool),
                    ("applePayPresent", session_token->anyTypeToJson),
                  ]
                | "google_pay" => [("googlePayThirdPartyFlow", session_token->anyTypeToJson)]
                | _ => []
                }

                if !isPaymentSession {
                  messageParentWindow(message)
                }
              } else {
                handleProcessingStatus(paymentType, sdkHandleOneClickConfirmPayment)
              }
              resolve(data)
            } else if intent.status != "" {
              if intent.status === "succeeded" {
                handleLogging(
                  ~optLogger,
                  ~value=intent.status,
                  ~eventName=PAYMENT_SUCCESS,
                  ~paymentMethod,
                )
              } else if intent.status === "failed" {
                handleLogging(
                  ~optLogger,
                  ~value=intent.status,
                  ~eventName=PAYMENT_FAILED,
                  ~paymentMethod,
                )
              }
              if intent.status === "failed" {
                setIsManualRetryEnabled(_ => intent.manualRetryAllowed)
              }
              handleProcessingStatus(paymentType, sdkHandleOneClickConfirmPayment)
            } else if !isPaymentSession {
              postFailedSubmitResponse(
                ~errortype="confirm_payment_failed",
                ~message="Payment failed. Try again!",
              )
            } else {
              let failedSubmitResponse = getFailedSubmitResponse(
                ~errorType="confirm_payment_failed",
                ~message="Payment failed. Try again!",
              )
              resolve(failedSubmitResponse)
            }
          },
        )->then(resolve)
      })
    }
  })
  ->catch(err => {
    Promise.make((resolve, _) => {
      try {
        let url = makeUrl(confirmParam.return_url)
        url.searchParams.set("payment_intent_client_secret", clientSecret)
        url.searchParams.set("payment_id", clientSecret->Utils.getPaymentId)
        url.searchParams.set("status", "failed")
        let exceptionMessage = err->formatException
        logApi(
          ~optLogger,
          ~url=uri,
          ~eventName,
          ~apiLogType=NoResponse,
          ~data=exceptionMessage,
          ~logType=ERROR,
          ~logCategory=API,
          ~isPaymentSession,
        )
        if counter >= 5 {
          if !isPaymentSession {
            closePaymentLoaderIfAny()
            postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
          }
          if handleUserError {
            handleOpenUrl(url.href)
          } else {
            let failedSubmitResponse = getFailedSubmitResponse(
              ~errorType="server_error",
              ~message="Something went wrong",
            )
            resolve(failedSubmitResponse)
          }
        } else {
          let paymentIntentID = clientSecret->Utils.getPaymentId
          let endpoint = ApiEndpoint.getApiEndPoint(
            ~publishableKey=confirmParam.publishableKey,
            ~isConfirmCall=isConfirm,
          )
          let retrieveUri = `${endpoint}/payments/${paymentIntentID}?client_secret=${clientSecret}`
          intentCall(
            ~fetchApi,
            ~uri=retrieveUri,
            ~headers,
            ~bodyStr,
            ~confirmParam: ConfirmType.confirmParams,
            ~clientSecret,
            ~optLogger,
            ~handleUserError,
            ~paymentType,
            ~iframeId,
            ~fetchMethod=#GET,
            ~setIsManualRetryEnabled,
            ~customPodUri,
            ~sdkHandleOneClickConfirmPayment,
            ~counter=counter + 1,
            ~isPaymentSession,
            ~componentName,
            ~redirectionFlags,
          )
          ->then(
            res => {
              resolve(res)
              Promise.resolve()
            },
          )
          ->catch(_ => Promise.resolve())
          ->ignore
        }
      } catch {
      | _ =>
        if !isPaymentSession {
          postFailedSubmitResponse(~errortype="error", ~message="Something went wrong")
        }
        let failedSubmitResponse = getFailedSubmitResponse(
          ~errorType="server_error",
          ~message="Something went wrong",
        )
        resolve(failedSubmitResponse)
      }
    })->then(resolve)
  })
}

let usePaymentSync = (optLogger: option<HyperLoggerTypes.loggerMake>, paymentType: payment) => {
  open RecoilAtoms
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let isCallbackUsedVal = Recoil.useRecoilValueFromAtom(RecoilAtoms.isCompleteCallbackUsed)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(redirectionFlagsAtom)
  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  (~handleUserError=false, ~confirmParam: ConfirmType.confirmParams, ~iframeId="") => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = clientSecret->Utils.getPaymentId
      let headers = [("Content-Type", "application/json"), ("api-key", confirmParam.publishableKey)]
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)
      let uri = `${endpoint}/payments/${paymentIntentID}?force_sync=true&client_secret=${clientSecret}`

      let paymentSync = () => {
        intentCall(
          ~fetchApi,
          ~uri,
          ~headers,
          ~bodyStr="",
          ~confirmParam: ConfirmType.confirmParams,
          ~clientSecret,
          ~optLogger,
          ~handleUserError,
          ~paymentType,
          ~iframeId,
          ~fetchMethod=#GET,
          ~setIsManualRetryEnabled,
          ~customPodUri,
          ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
          ~counter=0,
          ~isCallbackUsedVal,
          ~redirectionFlags,
        )->ignore
      }
      switch paymentMethodList {
      | Loaded(_) => paymentSync()
      | _ => ()
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="sync_payment_failed",
        ~message="Sync Payment Failed. Try Again!",
      )
    }
  }
}

let maskStr = str => str->Js.String2.replaceByRe(%re(`/\S/g`), "x")

let rec maskPayload = payloadJson => {
  switch payloadJson->JSON.Classify.classify {
  | Object(valueDict) =>
    valueDict
    ->Dict.toArray
    ->Array.map(entry => {
      let (key, value) = entry
      (key, maskPayload(value))
    })
    ->getJsonFromArrayOfJson

  | Array(arr) => arr->Array.map(maskPayload)->JSON.Encode.array
  | String(valueStr) => valueStr->maskStr->JSON.Encode.string
  | Number(float) => Float.toString(float)->maskStr->JSON.Encode.string
  | Bool(bool) => (bool ? "true" : "false")->JSON.Encode.string
  | Null => JSON.Encode.string("null")
  }
}

let useCompleteAuthorizeHandler = () => {
  open RecoilAtoms

  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  let isCallbackUsedVal = Recoil.useRecoilValueFromAtom(isCompleteCallbackUsed)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(redirectionFlagsAtom)

  (
    ~clientSecret: option<string>,
    ~bodyArr,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId,
    ~optLogger,
    ~handleUserError,
    ~paymentType,
    ~sdkHandleOneClickConfirmPayment,
    ~headers: option<array<(string, string)>>=?,
    ~paymentMode: option<string>=?,
  ) =>
    switch clientSecret {
    | Some(cs) =>
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)
      let uri = `${endpoint}/payments/${cs->Utils.getPaymentId}/complete_authorize`

      let finalHeaders = switch headers {
      | Some(h) => h
      | None => [
          ("Content-Type", "application/json"),
          ("api-key", confirmParam.publishableKey),
          ("X-Client-Source", paymentMode->Option.getOr("")),
        ]
      }
      let bodyStr =
        [("client_secret", cs->JSON.Encode.string)]
        ->Array.concatMany([bodyArr, BrowserSpec.broswerInfo()])
        ->getJsonFromArrayOfJson
        ->JSON.stringify

      intentCall(
        ~fetchApi,
        ~uri,
        ~headers=finalHeaders,
        ~bodyStr,
        ~confirmParam,
        ~clientSecret=cs,
        ~optLogger,
        ~handleUserError,
        ~paymentType,
        ~iframeId,
        ~fetchMethod=#POST,
        ~setIsManualRetryEnabled,
        ~customPodUri,
        ~sdkHandleOneClickConfirmPayment,
        ~counter=0,
        ~isCallbackUsedVal,
        ~redirectionFlags,
      )->ignore
    | None =>
      postFailedSubmitResponse(
        ~errortype="complete_authorize_failed",
        ~message="Complete Authorize Failed. Try Again!",
      )
    }
}

let useCompleteAuthorize = (optLogger, paymentType) => {
  let completeAuthorizeHandler = useCompleteAuthorizeHandler()
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let paymentMethodList = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentMethodList)
  let url = RescriptReactRouter.useUrl()
  let mode =
    CardUtils.getQueryParamsDictforKey(url.search, "componentName")
    ->CardThemeType.getPaymentMode
    ->CardThemeType.getPaymentModeToStrMapper

  (~handleUserError=false, ~bodyArr, ~confirmParam, ~iframeId=keys.iframeId) =>
    switch paymentMethodList {
    | Loaded(_) =>
      completeAuthorizeHandler(
        ~clientSecret=keys.clientSecret,
        ~bodyArr,
        ~confirmParam,
        ~iframeId,
        ~optLogger,
        ~handleUserError,
        ~paymentType,
        ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
        ~paymentMode=mode,
      )
    | _ => ()
    }
}

let useRedsysCompleteAuthorize = optLogger => {
  let completeAuthorizeHandler = useCompleteAuthorizeHandler()
  (
    ~handleUserError=false,
    ~bodyArr,
    ~confirmParam,
    ~iframeId="redsys3ds",
    ~clientSecret,
    ~headers,
  ) =>
    completeAuthorizeHandler(
      ~clientSecret,
      ~bodyArr,
      ~confirmParam,
      ~iframeId,
      ~optLogger,
      ~handleUserError,
      ~paymentType=Card,
      ~sdkHandleOneClickConfirmPayment=false,
      ~headers,
    )
}

let usePaymentIntent = (optLogger, paymentType) => {
  open RecoilAtoms
  open Promise
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let paymentTypeFromUrl = componentName->CardThemeType.getPaymentMode
  let blockConfirm = Recoil.useRecoilValueFromAtom(isConfirmBlocked)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let isCallbackUsedVal = Recoil.useRecoilValueFromAtom(RecoilAtoms.isCompleteCallbackUsed)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(redirectionFlagsAtom)

  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId=keys.iframeId,
    ~isThirdPartyFlow=false,
    ~intentCallback=_ => (),
    ~manualRetry=false,
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = clientSecret->Utils.getPaymentId
      let headers = [
        ("Content-Type", "application/json"),
        ("api-key", confirmParam.publishableKey),
        ("X-Client-Source", paymentTypeFromUrl->CardThemeType.getPaymentModeToStrMapper),
      ]
      let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]
      let manual_retry = manualRetry ? [("retry_action", "manual_retry"->JSON.Encode.string)] : []
      let body =
        [("client_secret", clientSecret->JSON.Encode.string)]->Array.concatMany([
          returnUrlArr,
          manual_retry,
        ])
      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=isThirdPartyFlow,
      )
      let uri = `${endpoint}/payments/${paymentIntentID}/confirm`

      let callIntent = body => {
        let contentLength = body->String.length->Int.toString
        let maskedPayload =
          body->safeParseOpt->Option.getOr(JSON.Encode.null)->maskPayload->JSON.stringify
        let loggerPayload =
          [
            ("payload", maskedPayload->JSON.Encode.string),
            (
              "headers",
              headers
              ->Array.map(header => {
                let (key, value) = header
                (key, value->JSON.Encode.string)
              })
              ->getJsonFromArrayOfJson,
            ),
          ]
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        switch paymentType {
        | Card =>
          handleLogging(
            ~optLogger,
            ~internalMetadata=loggerPayload,
            ~value=contentLength,
            ~eventName=PAYMENT_ATTEMPT,
            ~paymentMethod="CARD",
          )
        | _ =>
          bodyArr->Array.forEach(((str, json)) => {
            if str === "payment_method_type" {
              handleLogging(
                ~optLogger,
                ~value=contentLength,
                ~internalMetadata=loggerPayload,
                ~eventName=PAYMENT_ATTEMPT,
                ~paymentMethod=json->getStringFromJson(""),
              )
            }
            ()
          })
        }
        if blockConfirm && GlobalVars.isInteg {
          Console.warn2("CONFIRM IS BLOCKED - Body", body)
          Console.warn2(
            "CONFIRM IS BLOCKED - Headers",
            headers->Dict.fromArray->Identity.anyTypeToJson->JSON.stringify,
          )
        } else {
          intentCall(
            ~fetchApi,
            ~uri,
            ~headers,
            ~bodyStr=body,
            ~confirmParam: ConfirmType.confirmParams,
            ~clientSecret,
            ~optLogger,
            ~handleUserError,
            ~paymentType,
            ~iframeId,
            ~fetchMethod=#POST,
            ~setIsManualRetryEnabled,
            ~customPodUri,
            ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
            ~counter=0,
            ~isCallbackUsedVal,
            ~componentName,
            ~redirectionFlags,
          )
          ->then(val => {
            intentCallback(val)
            resolve()
          })
          ->catch(_ => resolve())
          ->ignore
        }
      }

      let broswerInfo = BrowserSpec.broswerInfo
      let intentWithoutMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concatMany([
            bodyArr->Array.concat(broswerInfo()),
            mandatePaymentType->PaymentBody.paymentTypeBody,
          ])
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      let intentWithMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concat(
            bodyArr->Array.concatMany([PaymentBody.mandateBody(mandatePaymentType), broswerInfo()]),
          )
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      switch paymentMethodList {
      | LoadError(data)
      | Loaded(data) =>
        let paymentList = data->getDictFromJson->PaymentMethodsRecord.itemToObjMapper
        let mandatePaymentType =
          paymentList.payment_type->PaymentMethodsRecord.paymentTypeToStringMapper
        if paymentList.payment_methods->Array.length > 0 {
          switch paymentList.mandate_payment {
          | Some(_) =>
            switch paymentType {
            | Card
            | Gpay
            | Applepay
            | KlarnaRedirect
            | Paypal
            | BankDebits =>
              intentWithMandate(mandatePaymentType)
            | _ => intentWithoutMandate(mandatePaymentType)
            }
          | None => intentWithoutMandate(mandatePaymentType)
          }
        } else {
          postFailedSubmitResponse(
            ~errortype="payment_methods_empty",
            ~message="Payment Failed. Try again!",
          )
          Console.warn("Please enable atleast one Payment method.")
        }
      | SemiLoaded => intentWithoutMandate("")
      | _ =>
        postFailedSubmitResponse(
          ~errortype="payment_methods_loading",
          ~message="Please wait. Try again!",
        )
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="confirm_payment_failed",
        ~message="Payment failed. Try again!",
      )
    }
  }
}

let fetchSessions = (
  ~clientSecret,
  ~publishableKey,
  ~wallets=[],
  ~isDelayedSessionToken=false,
  ~optLogger,
  ~customPodUri,
  ~endpoint,
  ~isPaymentSession=false,
  ~merchantHostname=Window.Location.hostname,
) => {
  open Promise
  let headers = [
    ("Content-Type", "application/json"),
    ("api-key", publishableKey),
    ("X-Merchant-Domain", merchantHostname),
  ]
  let paymentIntentID = clientSecret->Utils.getPaymentId
  let body =
    [
      ("payment_id", paymentIntentID->JSON.Encode.string),
      ("client_secret", clientSecret->JSON.Encode.string),
      ("wallets", wallets->JSON.Encode.array),
      ("delayed_session_token", isDelayedSessionToken->JSON.Encode.bool),
    ]->getJsonFromArrayOfJson
  let uri = `${endpoint}/payments/session_tokens`
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=SESSIONS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession,
  )
  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=body->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=SESSIONS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
          ~isPaymentSession,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=SESSIONS_CALL,
        ~logType=INFO,
        ~logCategory=API,
        ~isPaymentSession,
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=SESSIONS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
      ~isPaymentSession,
    )
    JSON.Encode.null->resolve
  })
}

let confirmPayout = (~clientSecret, ~publishableKey, ~logger, ~customPodUri, ~uri, ~body) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=CONFIRM_PAYOUT_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  let body =
    body
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson

  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=body->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status

    resp
    ->Fetch.Response.json
    ->then(data => {
      if !(resp->Fetch.Response.ok) {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=CONFIRM_PAYOUT_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
      } else {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~statusCode,
          ~apiLogType=Response,
          ~eventName=CONFIRM_PAYOUT_CALL,
          ~logType=INFO,
          ~logCategory=API,
        )
      }
      resolve(data)
    })
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=CONFIRM_PAYOUT_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}

let createPaymentMethod = (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~body,
) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
  let uri = `${endpoint}/payment_methods`
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  let body =
    body
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson

  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=body->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=CREATE_CUSTOMER_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=CREATE_CUSTOMER_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=CREATE_CUSTOMER_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}

let fetchPaymentMethodList = (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
  let uri = `${endpoint}/account/payment_methods?client_secret=${clientSecret}`
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}

let fetchCustomerPaymentMethodList = (
  ~clientSecret,
  ~publishableKey,
  ~endpoint,
  ~optLogger,
  ~customPodUri,
  ~isPaymentSession=false,
) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
  let uri = `${endpoint}/customers/payment_methods?client_secret=${clientSecret}`
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=CUSTOMER_PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
          ~isPaymentSession,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
        ~isPaymentSession,
      )
      res->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
      ~isPaymentSession,
    )
    JSON.Encode.null->resolve
  })
}

let paymentIntentForPaymentSession = (
  ~body,
  ~paymentType,
  ~payload,
  ~publishableKey,
  ~clientSecret,
  ~logger,
  ~customPodUri,
  ~redirectionFlags,
) => {
  let confirmParams =
    payload
    ->getDictFromJson
    ->getDictFromDict("confirmParams")

  let redirect = confirmParams->getString("redirect", "if_required")

  let returnUrl = confirmParams->getString("return_url", "")

  let confirmParam: ConfirmType.confirmParams = {
    return_url: returnUrl,
    publishableKey,
    redirect,
  }

  let paymentIntentID = String.split(clientSecret, "_secret_")[0]->Option.getOr("")

  let endpoint = ApiEndpoint.getApiEndPoint(
    ~publishableKey=confirmParam.publishableKey,
    ~isConfirmCall=true,
  )
  let uri = `${endpoint}/payments/${paymentIntentID}/confirm`
  let headers = [("Content-Type", "application/json"), ("api-key", confirmParam.publishableKey)]

  let broswerInfo = BrowserSpec.broswerInfo()

  let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]

  let bodyStr =
    body
    ->Array.concatMany([
      broswerInfo,
      [("client_secret", clientSecret->JSON.Encode.string)],
      returnUrlArr,
    ])
    ->getJsonFromArrayOfJson
    ->JSON.stringify

  intentCall(
    ~fetchApi,
    ~uri,
    ~headers,
    ~bodyStr,
    ~confirmParam: ConfirmType.confirmParams,
    ~clientSecret,
    ~optLogger=Some(logger),
    ~handleUserError=false,
    ~paymentType,
    ~iframeId="",
    ~fetchMethod=#POST,
    ~setIsManualRetryEnabled={_ => ()},
    ~customPodUri,
    ~sdkHandleOneClickConfirmPayment=false,
    ~counter=0,
    ~isPaymentSession=true,
    ~redirectionFlags,
  )
}

let callAuthLink = (
  ~publishableKey,
  ~clientSecret,
  ~paymentMethodType,
  ~pmAuthConnectorsArr,
  ~iframeId,
  ~optLogger,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let uri = `${endpoint}/payment_methods/auth/link`
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]->Dict.fromArray

  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=PAYMENT_METHODS_AUTH_LINK_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )

  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=[
      ("client_secret", clientSecret->Option.getOr("")->JSON.Encode.string),
      ("payment_id", clientSecret->Option.getOr("")->Utils.getPaymentId->JSON.Encode.string),
      ("payment_method", "bank_debit"->JSON.Encode.string),
      ("payment_method_type", paymentMethodType->JSON.Encode.string),
    ]
    ->getJsonFromArrayOfJson
    ->JSON.stringify,
    ~headers,
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=PAYMENT_METHODS_AUTH_LINK_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      res
      ->Fetch.Response.json
      ->then(data => {
        let metaData =
          [
            ("linkToken", data->getDictFromJson->getString("link_token", "")->JSON.Encode.string),
            ("pmAuthConnectorArray", pmAuthConnectorsArr->anyTypeToJson),
            ("publishableKey", publishableKey->JSON.Encode.string),
            ("clientSecret", clientSecret->Option.getOr("")->JSON.Encode.string),
            ("isForceSync", false->JSON.Encode.bool),
          ]->getJsonFromArrayOfJson

        messageParentWindow([
          ("fullscreen", true->JSON.Encode.bool),
          ("param", "plaidSDK"->JSON.Encode.string),
          ("iframeId", iframeId->JSON.Encode.string),
          ("metadata", metaData),
        ])
        logApi(
          ~optLogger,
          ~url=uri,
          ~statusCode,
          ~apiLogType=Response,
          ~eventName=PAYMENT_METHODS_AUTH_LINK_CALL,
          ~logType=INFO,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    }
  })
  ->catch(e => {
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=PAYMENT_METHODS_AUTH_LINK_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data={e->formatException},
    )
    Console.error2("Unable to retrieve payment_methods auth/link because of ", e)
    JSON.Encode.null->resolve
  })
}

let callAuthExchange = (
  ~publicToken,
  ~clientSecret,
  ~paymentMethodType,
  ~publishableKey,
  ~setOptionValue: (PaymentType.options => PaymentType.options) => unit,
  ~optLogger,
) => {
  open Promise
  open PaymentType
  let endpoint = ApiEndpoint.getApiEndPoint()
  let logger = HyperLogger.make(~source=Elements(Payment))
  let uri = `${endpoint}/payment_methods/auth/exchange`
  let updatedBody = [
    ("client_secret", clientSecret->Option.getOr("")->JSON.Encode.string),
    ("payment_id", clientSecret->Option.getOr("")->Utils.getPaymentId->JSON.Encode.string),
    ("payment_method", "bank_debit"->JSON.Encode.string),
    ("payment_method_type", paymentMethodType->JSON.Encode.string),
    ("public_token", publicToken->JSON.Encode.string),
  ]

  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]->Dict.fromArray

  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )

  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=updatedBody->getJsonFromArrayOfJson->JSON.stringify,
    ~headers,
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=PAYMENT_METHODS_AUTH_EXCHANGE_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=PAYMENT_METHODS_AUTH_EXCHANGE_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      fetchCustomerPaymentMethodList(
        ~clientSecret=clientSecret->Option.getOr(""),
        ~publishableKey,
        ~optLogger=Some(logger),
        ~customPodUri="",
        ~endpoint,
      )
      ->then(customerListResponse => {
        let customerListResponse =
          [("customerPaymentMethods", customerListResponse)]->Dict.fromArray
        setOptionValue(
          prev => {
            ...prev,
            customerPaymentMethods: customerListResponse->createCustomerObjArr(
              "customerPaymentMethods",
            ),
          },
        )
        JSON.Encode.null->resolve
      })
      ->catch(e => {
        Console.error2(
          "Unable to retrieve customer/payment_methods after auth/exchange because of ",
          e,
        )
        JSON.Encode.null->resolve
      })
    }
  })
  ->catch(e => {
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=PAYMENT_METHODS_AUTH_EXCHANGE_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data={e->formatException},
    )
    Console.error2("Unable to retrieve payment_methods auth/exchange because of ", e)
    JSON.Encode.null->resolve
  })
}

let fetchSavedPaymentMethodList = (
  ~ephemeralKey,
  ~endpoint,
  ~optLogger,
  ~customPodUri,
  ~isPaymentSession=false,
) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", ephemeralKey)]
  let uri = `${endpoint}/customers/payment_methods`
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=SAVED_PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
          ~isPaymentSession,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
        ~isPaymentSession,
      )
      res->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
      ~isPaymentSession,
    )
    JSON.Encode.null->resolve
  })
}

let deletePaymentMethod = (~ephemeralKey, ~paymentMethodId, ~logger, ~customPodUri) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Content-Type", "application/json"), ("api-key", ephemeralKey)]
  let uri = `${endpoint}/payment_methods/${paymentMethodId}`
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=DELETE_PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(uri, ~method=#DELETE, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=DELETE_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=DELETE_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=DELETE_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}

let calculateTax = (
  ~apiKey,
  ~paymentId,
  ~clientSecret,
  ~paymentMethodType,
  ~shippingAddress,
  ~logger,
  ~customPodUri,
  ~sessionId,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Content-Type", "application/json"), ("api-key", apiKey)]
  let uri = `${endpoint}/payments/${paymentId}/calculate_tax`
  let body = [
    ("client_secret", clientSecret),
    ("shipping", shippingAddress),
    ("payment_method_type", paymentMethodType),
  ]
  sessionId->Option.mapOr((), id => body->Array.push(("session_id", id))->ignore)

  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=EXTERNAL_TAX_CALCULATION,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(
    uri,
    ~method=#POST,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
    ~bodyStr=body->getJsonFromArrayOfJson->JSON.stringify,
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=EXTERNAL_TAX_CALCULATION,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=EXTERNAL_TAX_CALCULATION,
        ~logType=INFO,
        ~logCategory=API,
      )
      resp->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=EXTERNAL_TAX_CALCULATION,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}

let usePostSessionTokens = (
  optLogger,
  paymentType: payment,
  paymentMethod: PaymentMethodCollectTypes.paymentMethod,
) => {
  open RecoilAtoms
  open Promise
  let url = RescriptReactRouter.useUrl()
  let paymentTypeFromUrl =
    CardUtils.getQueryParamsDictforKey(url.search, "componentName")->CardThemeType.getPaymentMode
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(RecoilAtoms.redirectionFlagsAtom)

  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId=keys.iframeId,
    ~isThirdPartyFlow=false,
    ~intentCallback=_ => (),
    ~manualRetry as _=false,
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = clientSecret->Utils.getPaymentId
      let headers = [
        ("Content-Type", "application/json"),
        ("api-key", confirmParam.publishableKey),
        ("X-Client-Source", paymentTypeFromUrl->CardThemeType.getPaymentModeToStrMapper),
      ]
      let body = [
        ("client_secret", clientSecret->JSON.Encode.string),
        ("payment_id", paymentIntentID->JSON.Encode.string),
        ("payment_method_type", (paymentType :> string)->JSON.Encode.string),
        ("payment_method", (paymentMethod :> string)->JSON.Encode.string),
      ]

      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=isThirdPartyFlow,
      )
      let uri = `${endpoint}/payments/${paymentIntentID}/post_session_tokens`

      let callIntent = body => {
        let contentLength = body->String.length->Int.toString
        let maskedPayload =
          body->safeParseOpt->Option.getOr(JSON.Encode.null)->maskPayload->JSON.stringify
        let loggerPayload =
          [
            ("payload", maskedPayload->JSON.Encode.string),
            (
              "headers",
              headers
              ->Array.map(header => {
                let (key, value) = header
                (key, value->JSON.Encode.string)
              })
              ->getJsonFromArrayOfJson,
            ),
          ]
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        switch paymentType {
        | Card =>
          handleLogging(
            ~optLogger,
            ~internalMetadata=loggerPayload,
            ~value=contentLength,
            ~eventName=PAYMENT_ATTEMPT,
            ~paymentMethod="CARD",
          )
        | _ =>
          bodyArr->Array.forEach(((str, json)) => {
            if str === "payment_method_type" {
              handleLogging(
                ~optLogger,
                ~value=contentLength,
                ~internalMetadata=loggerPayload,
                ~eventName=PAYMENT_ATTEMPT,
                ~paymentMethod=json->getStringFromJson(""),
              )
            }
            ()
          })
        }

        intentCall(
          ~fetchApi,
          ~uri,
          ~headers,
          ~bodyStr=body,
          ~confirmParam: ConfirmType.confirmParams,
          ~clientSecret,
          ~optLogger,
          ~handleUserError,
          ~paymentType,
          ~iframeId,
          ~fetchMethod=#POST,
          ~setIsManualRetryEnabled,
          ~customPodUri,
          ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
          ~counter=0,
          ~redirectionFlags,
        )
        ->then(val => {
          intentCallback(val)
          resolve()
        })
        ->catch(_ => Promise.resolve())
        ->ignore
      }

      let broswerInfo = BrowserSpec.broswerInfo
      let intentWithoutMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concatMany([
            bodyArr->Array.concat(broswerInfo()),
            mandatePaymentType->PaymentBody.paymentTypeBody,
          ])
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      let intentWithMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concat(
            bodyArr->Array.concatMany([PaymentBody.mandateBody(mandatePaymentType), broswerInfo()]),
          )
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      switch paymentMethodList {
      | LoadError(data)
      | Loaded(data) =>
        let paymentList = data->getDictFromJson->PaymentMethodsRecord.itemToObjMapper
        let mandatePaymentType =
          paymentList.payment_type->PaymentMethodsRecord.paymentTypeToStringMapper
        if paymentList.payment_methods->Array.length > 0 {
          switch paymentList.mandate_payment {
          | Some(_) =>
            switch paymentType {
            | Card
            | Gpay
            | Applepay
            | KlarnaRedirect
            | Paypal
            | BankDebits =>
              intentWithMandate(mandatePaymentType)
            | _ => intentWithoutMandate(mandatePaymentType)
            }
          | None => intentWithoutMandate(mandatePaymentType)
          }
        } else {
          postFailedSubmitResponse(
            ~errortype="payment_methods_empty",
            ~message="Payment Failed. Try again!",
          )
          Console.warn("Please enable atleast one Payment method.")
        }
      | SemiLoaded => intentWithoutMandate("")
      | _ =>
        postFailedSubmitResponse(
          ~errortype="payment_methods_loading",
          ~message="Please wait. Try again!",
        )
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="post_session_tokens_failed",
        ~message="Post Session Tokens failed. Try again!",
      )
    }
  }
}
