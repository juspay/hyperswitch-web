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

let retrievePaymentIntent = async (
  clientSecret,
  ~headers=?,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~isForceSync=false,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=RetrievePaymentIntent,
    ~params={
      clientSecret: Some(clientSecret),
      publishableKey: Some(publishableKey),
      customBackendBaseUrl: None,
      paymentMethodId: None,
      forceSync: isForceSync ? Some("true") : None,
      pollId: None,
      payoutId: None,
    },
  )

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  let headers = switch headers {
  | Some(providedHeaders) => providedHeaders
  | None => Dict.make()
  }

  await fetchApiWithLogging(
    uri,
    ~eventName=RETRIEVE_CALL,
    ~headers,
    ~logger,
    ~method=#GET,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
  )
}

let fetchBlockedBins = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchBlockedBins,
    ~params={
      clientSecret: Some(clientSecret),
      publishableKey: None,
      customBackendBaseUrl: Some(endpoint),
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=BLOCKED_BIN_CALL,
    ~logger,
    ~method=#GET,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
  )
}

let threeDsAuth = async (~clientSecret, ~logger, ~threeDsMethodComp, ~headers) => {
  let url = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchThreeDsAuth,
    ~params={
      clientSecret: Some(clientSecret),
      publishableKey: None,
      customBackendBaseUrl: None,
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )
  let broswerInfo = BrowserSpec.broswerInfo
  let body =
    [
      ("client_secret", clientSecret->JSON.Encode.string),
      ("device_channel", "BRW"->JSON.Encode.string),
      ("threeds_method_comp_ind", threeDsMethodComp->JSON.Encode.string),
    ]
    ->Array.concat(broswerInfo())
    ->getJsonFromArrayOfJson

  let onSuccess = data => data

  let onFailure = data => {
    let dict = data->getDictFromJson
    let errorObj = PaymentError.itemToObjMapper(dict)
    closePaymentLoaderIfAny()
    postFailedSubmitResponse(~errortype=errorObj.error.type_, ~message=errorObj.error.message)
    JSON.Encode.null
  }

  let onCatchCallback = err => {
    closePaymentLoaderIfAny()
    Js.Exn.raiseError(err->JSON.stringify)
  }

  await fetchApiWithLogging(
    url,
    ~eventName=AUTHENTICATION_CALL,
    ~logger,
    ~onSuccess,
    ~onFailure,
    ~bodyStr=body->JSON.stringify,
    ~headers,
    ~method=#POST,
    ~onCatchCallback=Some(onCatchCallback),
  )
}

let rec pollRetrievePaymentIntent = (
  clientSecret,
  ~headers,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~isForceSync=false,
) => {
  open Promise
  retrievePaymentIntent(
    clientSecret,
    ~headers,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~isForceSync,
  )
  ->then(json => {
    let dict = json->getDictFromJson
    let status = dict->getString("status", "")

    if status === "succeeded" || status === "failed" {
      resolve(json)
    } else {
      delay(2000)
      ->then(_val => {
        pollRetrievePaymentIntent(
          clientSecret,
          ~headers,
          ~publishableKey,
          ~logger,
          ~customPodUri,
          ~isForceSync,
        )
      })
      ->catch(_ => Promise.resolve(JSON.Encode.null))
    }
  })
  ->catch(e => {
    Console.error2("Unable to retrieve payment due to following error", e)
    pollRetrievePaymentIntent(
      clientSecret,
      ~headers,
      ~publishableKey,
      ~logger,
      ~customPodUri,
      ~isForceSync,
    )
  })
}

let retrieveStatus = async (~publishableKey, ~customPodUri, pollID, logger) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=RetrieveStatus,
    ~params={
      clientSecret: None,
      publishableKey: Some(publishableKey),
      customBackendBaseUrl: None,
      paymentMethodId: None,
      forceSync: None,
      pollId: Some(pollID),
      payoutId: None,
    },
  )

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=POLL_STATUS_CALL,
    ~logger,
    ~bodyStr="",
    ~method=#GET,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
  )
}

let rec pollStatus = (
  ~publishableKey,
  ~customPodUri,
  ~pollId,
  ~interval,
  ~count,
  ~returnUrl,
  ~logger,
) => {
  open Promise
  retrieveStatus(~publishableKey, ~customPodUri, pollId, logger)
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
              ~publishableKey,
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
      ~publishableKey,
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
    ~customPodUri: option<string>=?,
    ~publishableKey: option<string>=?,
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
      replaceRootHref(url, redirectionFlags)
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
                  // ~internalMetadata=intent.nextAction.redirectToUrl,
                  ~eventName=REDIRECTING_USER,
                  ~paymentMethod,
                )
                handleOpenUrl(intent.nextAction.redirectToUrl)
              } else if intent.nextAction.type_ == "redirect_inside_popup" {
                let popupUrl = intent.nextAction.popupUrl
                let redirectResponseUrl = intent.nextAction.redirectResponseUrl
                handleLogging(
                  ~optLogger,
                  ~value="",
                  // ~internalMetadata=popupUrl,
                  ~eventName=THREE_DS_POPUP_REDIRECTION,
                  ~paymentMethod,
                )
                let metaData = [
                  ("popupUrl", popupUrl->JSON.Encode.string),
                  ("redirectResponseUrl", redirectResponseUrl->JSON.Encode.string),
                ]
                messageParentWindow([
                  ("fullscreen", true->JSON.Encode.bool),
                  ("param", `3dsRedirectionPopup`->JSON.Encode.string),
                  ("iframeId", iframeId->JSON.Encode.string),
                  ("metadata", metaData->getJsonFromArrayOfJson),
                ])
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
                  // ~internalMetadata=dict->JSON.Encode.object->JSON.stringify,
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
                  // ~internalMetadata=metaData->JSON.stringify,
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
                  // ~internalMetadata=metaData->JSON.Encode.object->JSON.stringify,
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
                    // ~internalMetadata=intent.nextAction.type_,
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
  let paymentMethodListV2 = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentMethodsListV2)
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
    ~isExternalVaultFlow=false,
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = clientSecret->Utils.getPaymentId
      let headers = switch GlobalVars.sdkVersion {
      | V1 => [
          ("api-key", confirmParam.publishableKey),
          ("X-Client-Source", paymentTypeFromUrl->CardThemeType.getPaymentModeToStrMapper),
        ]
      | V2 => {
          let authorizationHeader = (
            "Authorization",
            `publishable-key=${keys.publishableKey},client-secret=${clientSecret}`,
          )
          [
            authorizationHeader,
            ("x-profile-id", keys.profileId),
            ...customPodUri != "" ? [("x-feature", customPodUri)] : [],
          ]
        }
      }
      let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]
      let manual_retry = manualRetry ? [("retry_action", "manual_retry"->JSON.Encode.string)] : []
      let body = switch GlobalVars.sdkVersion {
      | V1 =>
        [("client_secret", clientSecret->JSON.Encode.string)]->Array.concatMany([
          returnUrlArr,
          manual_retry,
        ])
      | V2 => []
      }

      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=isThirdPartyFlow,
      )
      let path = switch GlobalVars.sdkVersion {
      | V1 => `payments/${paymentIntentID}/confirm`
      | V2 =>
        let baseUrl = `v2/payments/${keys.paymentId}/confirm-intent`
        isExternalVaultFlow ? `${baseUrl}/external-vault-proxy` : baseUrl
      }
      let uri = `${endpoint}/${path}`

      let callIntent = body => {
        let contentLength = body->String.length->Int.toString
        let maskedPayload =
          body->safeParseOpt->Option.getOr(JSON.Encode.null)->maskPayload->JSON.stringify
        let _loggerPayload =
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
            // ~internalMetadata=loggerPayload,
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
                // ~internalMetadata=loggerPayload,
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

      switch (GlobalVars.sdkVersion, paymentMethodList, paymentMethodListV2) {
      | (V1, LoadError(data), _)
      | (V1, Loaded(data), _) =>
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
      | (V2, _, LoadedV2(data)) =>
        if data.paymentMethodsEnabled->Array.length > 0 {
          intentWithoutMandate("")
        } else {
          postFailedSubmitResponse(
            ~errortype="payment_methods_empty",
            ~message="Payment Failed. Try again!",
          )
          Console.warn("Please enable atleast one Payment method.")
        }
      | (V1, SemiLoaded, _)
      | (V2, _, SemiLoadedV2) =>
        intentWithoutMandate("")
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

let fetchSessions = async (
  ~clientSecret,
  ~publishableKey,
  ~wallets=[],
  ~isDelayedSessionToken=false,
  ~logger,
  ~customPodUri=?,
  ~endpoint,
  ~isPaymentSession=false,
  ~merchantHostname=Window.getRootHostName(),
) => {
  let headers = [("X-Merchant-Domain", merchantHostname)]->Dict.fromArray
  let paymentIntentID = clientSecret->Utils.getPaymentId
  let body =
    [
      ("payment_id", paymentIntentID->JSON.Encode.string),
      ("client_secret", clientSecret->JSON.Encode.string),
      ("wallets", wallets->JSON.Encode.array),
      ("delayed_session_token", isDelayedSessionToken->JSON.Encode.bool),
    ]->getJsonFromArrayOfJson
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchSessions,
    ~params={
      customBackendBaseUrl: Some(endpoint),
      clientSecret: None,
      publishableKey: None,
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=SESSIONS_CALL,
    ~logger,
    ~bodyStr=body->JSON.stringify,
    ~headers,
    ~method=#POST,
    ~customPodUri,
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
    ~isPaymentSession,
  )
}

let confirmPayout = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~body,
  ~payoutId,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=ConfirmPayout,
    ~params={
      clientSecret: Some(clientSecret),
      customBackendBaseUrl: Some(endpoint),
      publishableKey: Some(publishableKey),
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: Some(payoutId),
    },
  )

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  let body =
    body
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson

  await fetchApiWithLogging(
    uri,
    ~eventName=CONFIRM_PAYOUT_CALL,
    ~logger,
    ~bodyStr=body->JSON.stringify,
    ~method=#POST,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
  )
}

let createPaymentMethod = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~body,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=CreatePaymentMethod,
    ~params={
      clientSecret: Some(clientSecret),
      customBackendBaseUrl: Some(endpoint),
      publishableKey: Some(publishableKey),
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  let body =
    body
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson

  await fetchApiWithLogging(
    uri,
    ~eventName=CREATE_CUSTOMER_PAYMENT_METHODS_CALL,
    ~logger,
    ~bodyStr=body->JSON.stringify,
    ~method=#POST,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
  )
}

let fetchPaymentMethodList = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchPaymentMethodList,
    ~params={
      clientSecret: Some(clientSecret),
      customBackendBaseUrl: Some(endpoint),
      publishableKey: None,
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=PAYMENT_METHODS_CALL,
    ~logger,
    ~method=#GET,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
  )
}

let fetchCustomerPaymentMethodList = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~isPaymentSession=false,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchCustomerPaymentMethodList,
    ~params={
      clientSecret: Some(clientSecret),
      customBackendBaseUrl: Some(endpoint),
      publishableKey: None,
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
    ~logger,
    ~method=#GET,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
    ~isPaymentSession,
  )
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

let callAuthLink = async (
  ~publishableKey,
  ~clientSecret,
  ~paymentMethodType,
  ~pmAuthConnectorsArr,
  ~iframeId,
  ~logger,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=CallAuthLink,
    ~params={
      clientSecret: None,
      publishableKey: Some(publishableKey),
      customBackendBaseUrl: None,
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )

  let body =
    [
      ("client_secret", clientSecret->Option.getOr("")->JSON.Encode.string),
      ("payment_id", clientSecret->Option.getOr("")->Utils.getPaymentId->JSON.Encode.string),
      ("payment_method", "bank_debit"->JSON.Encode.string),
      ("payment_method_type", paymentMethodType->JSON.Encode.string),
    ]->getJsonFromArrayOfJson

  let onSuccess = data => {
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
    JSON.Encode.null
  }

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=PAYMENT_METHODS_AUTH_LINK_CALL,
    ~logger,
    ~bodyStr=body->JSON.stringify,
    ~method=#POST,
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
  )
}

let callAuthExchange = async (
  ~publicToken,
  ~clientSecret,
  ~paymentMethodType,
  ~publishableKey,
  ~setOptionValue: (PaymentType.options => PaymentType.options) => unit,
  ~logger,
) => {
  open Promise
  open PaymentType
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=CallAuthExchange,
    ~params={
      clientSecret: None,
      publishableKey: Some(publishableKey),
      customBackendBaseUrl: None,
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )

  let body =
    [
      ("client_secret", clientSecret->Option.getOr("")->JSON.Encode.string),
      ("payment_id", clientSecret->Option.getOr("")->Utils.getPaymentId->JSON.Encode.string),
      ("payment_method", "bank_debit"->JSON.Encode.string),
      ("payment_method_type", paymentMethodType->JSON.Encode.string),
      ("public_token", publicToken->JSON.Encode.string),
    ]->getJsonFromArrayOfJson

  let onSuccess = _ => {
    let endpoint = ApiEndpoint.getApiEndPoint()
    fetchCustomerPaymentMethodList(
      ~clientSecret=clientSecret->Option.getOr(""),
      ~publishableKey,
      ~logger,
      ~customPodUri="",
      ~endpoint,
    )
    ->then(customerListResponse => {
      let customerListResponse = [("customerPaymentMethods", customerListResponse)]->Dict.fromArray
      setOptionValue(prev => {
        ...prev,
        customerPaymentMethods: customerListResponse->createCustomerObjArr(
          "customerPaymentMethods",
        ),
      })
      resolve(JSON.Encode.null)
    })
    ->catch(e => {
      Console.error2(
        "Unable to retrieve customer/payment_methods after auth/exchange because of ",
        e,
      )
      Promise.resolve(JSON.Encode.null)
    })
    ->ignore
    JSON.Encode.null
  }

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=PAYMENT_METHODS_AUTH_EXCHANGE_CALL,
    ~logger,
    ~bodyStr=body->JSON.stringify,
    ~method=#POST,
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
  )
}

let fetchSavedPaymentMethodList = async (
  ~ephemeralKey,
  ~endpoint,
  ~logger,
  ~customPodUri,
  ~isPaymentSession=false,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchSavedPaymentMethodList,
    ~params={
      customBackendBaseUrl: Some(endpoint),
      clientSecret: None,
      publishableKey: Some(ephemeralKey),
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=SAVED_PAYMENT_METHODS_CALL,
    ~logger,
    ~method=#GET,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(ephemeralKey),
    ~onSuccess,
    ~onFailure,
    ~isPaymentSession,
  )
}

let deletePaymentMethod = async (~ephemeralKey, ~paymentMethodId, ~logger, ~customPodUri) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=DeletePaymentMethod,
    ~params={
      customBackendBaseUrl: None,
      clientSecret: None,
      publishableKey: Some(ephemeralKey),
      paymentMethodId: Some(paymentMethodId),
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=DELETE_PAYMENT_METHODS_CALL,
    ~logger,
    ~method=#DELETE,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(ephemeralKey),
    ~onSuccess,
    ~onFailure,
  )
}

let calculateTax = async (
  ~apiKey,
  ~clientSecret,
  ~paymentMethodType,
  ~shippingAddress,
  ~logger,
  ~customPodUri,
  ~sessionId,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=CalculateTax,
    ~params={
      customBackendBaseUrl: None,
      clientSecret: Some(clientSecret),
      publishableKey: Some(apiKey),
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
    },
  )
  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  let body = [
    ("client_secret", clientSecret->JSON.Encode.string),
    ("shipping", shippingAddress),
    ("payment_method_type", paymentMethodType),
  ]
  sessionId->Option.mapOr((), id => body->Array.push(("session_id", id))->ignore)
  await fetchApiWithLogging(
    uri,
    ~eventName=EXTERNAL_TAX_CALCULATION,
    ~logger,
    ~bodyStr=body->getJsonFromArrayOfJson->JSON.stringify,
    ~method=#POST,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(apiKey),
    ~onSuccess,
    ~onFailure,
  )
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
    ~isExternalVaultFlow as _=false,
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
        let _loggerPayload =
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
            // ~internalMetadata=loggerPayload,
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
                // ~internalMetadata=loggerPayload,
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

let fetchEnabledAuthnMethodsToken = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~isPaymentSession=false,
  ~profileId,
  ~authenticationId,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchEnabledAuthnMethodsToken,
    ~params={
      clientSecret: None,
      customBackendBaseUrl: Some(endpoint),
      publishableKey: None,
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
      authenticationId,
    },
  )

  let body = [("client_secret", clientSecret->JSON.Encode.string)]->getJsonFromArrayOfJson

  let headers = [("x-profile-id", profileId)]->Dict.fromArray

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=ENABLED_AUTHN_METHODS_TOKEN_CALL,
    ~logger,
    ~method=#POST,
    ~bodyStr=body->JSON.stringify,
    ~headers,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
    ~isPaymentSession,
  )
}

let fetchEligibilityCheck = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~isPaymentSession=false,
  ~profileId,
  ~authenticationId,
  ~bodyArr: array<(string, Core__JSON.t)>,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchEligibilityCheck,
    ~params={
      clientSecret: None,
      customBackendBaseUrl: Some(endpoint),
      publishableKey: None,
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
      authenticationId,
    },
  )

  let body =
    bodyArr
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson

  let headers = [("x-profile-id", profileId)]->Dict.fromArray

  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=ELIGIBILITY_CHECK_CALL,
    ~logger,
    ~method=#POST,
    ~bodyStr=body->JSON.stringify,
    ~headers,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
    ~isPaymentSession,
  )
}

let fetchAuthenticationSync = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~isPaymentSession=false,
  ~profileId,
  ~authenticationId,
  ~merchantId,
  ~bodyArr: array<(string, Core__JSON.t)>,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchAuthenticationSync,
    ~params={
      clientSecret: None,
      customBackendBaseUrl: Some(endpoint),
      publishableKey: None,
      paymentMethodId: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
      authenticationId,
      merchantId,
    },
  )

  let body =
    bodyArr
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson

  let headers = [("x-profile-id", profileId)]->Dict.fromArray

  let onSuccess = data => data

  let onFailure = err => err

  await fetchApiWithLogging(
    uri,
    ~eventName=AUTHENTICATION_SYNC_CALL,
    ~logger,
    ~method=#POST,
    ~bodyStr=body->JSON.stringify,
    ~headers,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
    ~isPaymentSession,
  )
}

let getConstructedPaymentMethodName = (~paymentMethod, ~paymentMethodType) => {
  switch paymentMethod {
  | "bank_debit" => paymentMethodType ++ "_debit"
  | "bank_transfer" =>
    if !(Constants.bankTransferList->Array.includes(paymentMethodType)) {
      paymentMethodType ++ "_transfer"
    } else {
      paymentMethodType
    }
  | "card" => "card"
  | _ => paymentMethodType
  }
}
