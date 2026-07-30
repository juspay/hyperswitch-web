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

let retrievePaymentIntent = async (
  clientSecret,
  ~headers=?,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~isForceSync=false,
  ~sdkAuthorization=None,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=RetrievePaymentIntent,
    ~params={
      clientSecret: Some(clientSecret),
      publishableKey: Some(publishableKey),
      customBackendBaseUrl: None,
      forceSync: isForceSync ? Some("true") : None,
      pollId: None,
      payoutId: None,
      sdkAuthorization,
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
    ~sdkAuthorization,
  )
}

let fetchPaymentMethodEligibility = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~bodyArr,
  ~sdkAuthorization=None,
  ~endpoint,
  ~signal: option<Fetch.AbortSignal.t>=?,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchPaymentMethodEligibility,
    ~params={
      clientSecret: Some(clientSecret),
      publishableKey: Some(publishableKey),
      customBackendBaseUrl: Some(endpoint),
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization,
    },
  )

  let body = switch sdkAuthorization->Utils.getNonEmptyOption {
  | Some(_) => bodyArr->getJsonFromArrayOfJson
  | _ =>
    bodyArr
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson
  }

  let onSuccess = data => {
    let surchargeval = `{
    "payment_id": "pay_3f7ptHpuEDKfyNbmt3vL",
    "sdk_next_action": {
        "next_action": "confirm",
        "should_block_confirm": null
    },
    "surcharge_details": {
    "surcharge": { "type": "fixed", "value": 162 },
    "tax_on_surcharge": null,
    "display_surcharge_amount": 1.62,
    "display_tax_on_surcharge_amount": 0,
    "display_total_surcharge_amount": 1.62
  }

}`->JSON.parseExn
    let blockedval = `{
  "payment_id": "pay_xxx",
  "sdk_next_action": {
    "next_action": {
      "deny": {
        "message": "Card number is blocklisted"
      }
    }
  }
}`->JSON.parseExn

    surchargeval
    // blockedval
    // data
  }

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=PAYMENT_METHOD_ELIGIBILITY_CALL,
    ~logger,
    ~bodyStr=body->JSON.stringify,
    ~method=#POST,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
    ~sdkAuthorization,
    ~signal?,
  )
}

let threeDsAuth = async (
  ~clientSecret,
  ~logger,
  ~threeDsMethodComp,
  ~headers,
  ~sdkAuthorization=None,
) => {
  let url = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchThreeDsAuth,
    ~params={
      clientSecret: Some(clientSecret),
      publishableKey: None,
      customBackendBaseUrl: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization,
    },
  )
  let broswerInfo = BrowserSpec.broswerInfo
  let clientSecretArr = switch sdkAuthorization->Utils.getNonEmptyOption {
  | Some(_) => []
  | None => [("client_secret", clientSecret->JSON.Encode.string)]
  }
  let body =
    [
      ("device_channel", "BRW"->JSON.Encode.string),
      ("threeds_method_comp_ind", threeDsMethodComp->JSON.Encode.string),
    ]
    ->Array.concatMany([broswerInfo(), clientSecretArr])
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
    ~sdkAuthorization,
  )
}

let rec pollRetrievePaymentIntent = (
  clientSecret,
  ~headers,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~isForceSync=false,
  ~sdkAuthorization=None,
) => {
  open Promise
  retrievePaymentIntent(
    clientSecret,
    ~headers,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~isForceSync,
    ~sdkAuthorization,
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
          ~sdkAuthorization,
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
      ~sdkAuthorization,
    )
  })
}

let retrieveStatus = async (~publishableKey, ~customPodUri, pollID, logger, ~sdkAuthorization) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=RetrieveStatus,
    ~params={
      clientSecret: None,
      publishableKey: Some(publishableKey),
      customBackendBaseUrl: None,
      forceSync: None,
      pollId: Some(pollID),
      payoutId: None,
      sdkAuthorization,
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
    ~sdkAuthorization,
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
  ~sdkAuthorization,
) => {
  open Promise
  retrieveStatus(~publishableKey, ~customPodUri, pollId, logger, ~sdkAuthorization)
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
              ~sdkAuthorization,
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
      ~sdkAuthorization,
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
    ~sdkAuthorization: option<string>=?,
    ~signal: Fetch.AbortSignal.t=?,
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
  ~sdkAuthorization=None,
  ~mode: CardThemeType.mode=NONE,
  ~isTrustpayInterceptorConfirm=false,
) => {
  open Promise
  let isConfirm = uri->String.includes("/confirm")
  let isLegacyClientSecretFlow = sdkAuthorization->Utils.getNonEmptyOption->Option.isNone

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
    if isPaymentSession && mode != CardCVCElement {
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
    ~sdkAuthorization,
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    let url = makeUrl(confirmParam.return_url)
    if isLegacyClientSecretFlow {
      url.searchParams.set("payment_intent_client_secret", clientSecret)
    }
    url.searchParams.set("status", "failed")
    url.searchParams.set(
      "payment_id",
      Utils.getPaymentIdOrExtractFromSdkAuth(~clientSecret, ~sdkAuthorization),
    )
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
              let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
                ~clientSecret,
                ~sdkAuthorization,
              )
              let endpoint = ApiEndpoint.getApiEndPoint(
                ~publishableKey=confirmParam.publishableKey,
                ~isConfirmCall=isConfirm,
              )
              let clientSecretParam = isLegacyClientSecretFlow
                ? `?client_secret=${clientSecret}`
                : ""
              let retrieveUri = `${endpoint}/payments/${paymentIntentId}${clientSecretParam}`
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
                ~sdkAuthorization,
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
            if isLegacyClientSecretFlow {
              url.searchParams.set("payment_intent_client_secret", clientSecret)
            }
            url.searchParams.set(
              "payment_id",
              Utils.getPaymentIdOrExtractFromSdkAuth(~clientSecret, ~sdkAuthorization),
            )
            url.searchParams.set("status", intent.status)

            let handleProcessingStatus = (paymentType, sdkHandleOneClickConfirmPayment) => {
              switch (paymentType, sdkHandleOneClickConfirmPayment, mode) {
              | (Card, _, _)
              | (Gpay, false, _)
              | (Applepay, false, _)
              | (Paypal, false, _) =>
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
              | (_, _, CardCVCElement) =>
                resolve(
                  [
                    ("data", data),
                    ("returnUrl", url.href->JSON.Encode.string),
                  ]->Utils.getJsonFromArrayOfJson,
                )
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
                let rawQrData = intent.nextAction.raw_qr_data->Option.getOr("")
                let displayText = intent.nextAction.display_text->Option.getOr("")
                let borderColor = intent.nextAction.border_color->Option.getOr("")
                let expiryTime = intent.nextAction.display_to_timestamp->Option.getOr(0.0)
                let headerObj = Dict.make()
                mergeHeadersIntoDict(~dict=headerObj, ~headers)
                let metaData =
                  [
                    ("qrData", qrData->JSON.Encode.string),
                    ("rawQrData", rawQrData->JSON.Encode.string),
                    ("paymentIntentId", clientSecret->JSON.Encode.string),
                    ("sdkAuthorization", sdkAuthorization->Option.getOr("")->JSON.Encode.string),
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
                    ("sdkAuthorization", sdkAuthorization->Option.getOr("")->JSON.Encode.string),
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
                    ("clientSecret", clientSecret->JSON.Encode.string),
                    ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
                    ("sdkAuthorization", sdkAuthorization->Option.getOr("")->JSON.Encode.string),
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
              } else if intent.nextAction.type_ === "invoke_ddc" {
                NextActionHelpers.handleDDC(
                  ~ddcData=intent.nextAction.ddc_data,
                  ~iframeId,
                  ~isPaymentSession,
                  ~resolve,
                  ~data,
                  ~optLogger,
                  ~paymentMethod,
                )
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
                | "apple_pay" =>
                  if isTrustpayInterceptorConfirm {
                    let secrets =
                      session_token
                      ->getDictFromDict("session_token_data")
                      ->Dict.get("secrets")
                      ->Option.getOr(JSON.Encode.null)
                    [("applePayConfirmSecrets", secrets)]
                  } else {
                    [
                      ("applePayButtonClicked", true->JSON.Encode.bool),
                      ("applePayPresent", session_token->anyTypeToJson),
                      ("componentName", componentName->JSON.Encode.string),
                    ]
                  }
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
                      ("sdkAuthorization", sdkAuthorization->Option.getOr("")->JSON.Encode.string),
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
                | "apple_pay" =>
                  if isTrustpayInterceptorConfirm {
                    let secrets =
                      session_token
                      ->getDictFromDict("session_token_data")
                      ->Dict.get("secrets")
                      ->Option.getOr(JSON.Encode.null)
                    [("applePayConfirmSecrets", secrets)]
                  } else {
                    [
                      ("applePayButtonClicked", true->JSON.Encode.bool),
                      ("applePayPresent", session_token->anyTypeToJson),
                    ]
                  }
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
        if isLegacyClientSecretFlow {
          url.searchParams.set("payment_intent_client_secret", clientSecret)
        }
        url.searchParams.set(
          "payment_id",
          Utils.getPaymentIdOrExtractFromSdkAuth(~clientSecret, ~sdkAuthorization),
        )
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
          let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
            ~clientSecret,
            ~sdkAuthorization,
          )
          let endpoint = ApiEndpoint.getApiEndPoint(
            ~publishableKey=confirmParam.publishableKey,
            ~isConfirmCall=isConfirm,
          )
          let clientSecretParam = isLegacyClientSecretFlow ? `?client_secret=${clientSecret}` : ""
          let retrieveUri = `${endpoint}/payments/${paymentIntentId}${clientSecretParam}`
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
            ~sdkAuthorization,
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
  open JotaiAtoms
  let paymentMethodList = Jotai.useAtomValue(paymentMethodList)
  let keys = Jotai.useAtomValue(keys)
  let isCallbackUsedVal = Jotai.useAtomValue(JotaiAtoms.isCompleteCallbackUsed)
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let redirectionFlags = Jotai.useAtomValue(redirectionFlagsAtom)
  let setIsManualRetryEnabled = Jotai.useSetAtom(isManualRetryEnabled)
  (~handleUserError=false, ~confirmParam: ConfirmType.confirmParams, ~iframeId="") => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
        ~clientSecret,
        ~sdkAuthorization=keys.sdkAuthorization->Utils.getNonEmptyOption,
      )
      let headers = [("Content-Type", "application/json")]

      switch keys.sdkAuthorization->Utils.getNonEmptyOption {
      | Some(_) => ()
      | None => headers->Array.push(("api-key", confirmParam.publishableKey))
      }

      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)

      let clientSecretUriStr = switch keys.sdkAuthorization->Utils.getNonEmptyOption {
      | Some(_) => ""
      | None => `&client_secret=${clientSecret}`
      }

      let uri = `${endpoint}/payments/${paymentIntentId}?force_sync=true${clientSecretUriStr}`

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
          ~sdkAuthorization=keys.sdkAuthorization,
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
  | Bool(bool) => bool->getStringFromBool->JSON.Encode.string
  | Null => JSON.Encode.string("null")
  }
}

let useCompleteAuthorizeHandler = () => {
  open JotaiAtoms

  let customPodUri = Jotai.useAtomValue(customPodUri)
  let setIsManualRetryEnabled = Jotai.useSetAtom(isManualRetryEnabled)
  let isCallbackUsedVal = Jotai.useAtomValue(isCompleteCallbackUsed)
  let redirectionFlags = Jotai.useAtomValue(redirectionFlagsAtom)
  let keys = Jotai.useAtomValue(keys)

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
    ~sdkAuthorization: option<string>=?,
  ) =>
    switch clientSecret {
    | Some(cs) =>
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)
      let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
        ~clientSecret=cs,
        ~sdkAuthorization,
      )
      let uri = `${endpoint}/payments/${paymentIntentId}/complete_authorize`

      let finalHeaders = switch headers {
      | Some(h) => h
      | None => [
          ("Content-Type", "application/json"),
          ("X-Client-Source", paymentMode->Option.getOr("")),
        ]
      }

      let sdkAuth = switch (
        keys.sdkAuthorization->Utils.getNonEmptyOption,
        sdkAuthorization->Utils.getNonEmptyOption,
      ) {
      | (Some(sdkAuth), _)
      | (_, Some(sdkAuth)) =>
        Some(sdkAuth)
      | _ => None
      }

      switch sdkAuth {
      | Some(auth) => finalHeaders->Array.push(("Authorization", auth))
      | None => finalHeaders->Array.push(("api-key", confirmParam.publishableKey))
      }

      let clientSecretArr = switch sdkAuth {
      | Some(_) => []
      | None => [("client_secret", cs->JSON.Encode.string)]
      }

      let bodyStr =
        clientSecretArr
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
        ~sdkAuthorization=sdkAuth,
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
  let keys = Jotai.useAtomValue(JotaiAtoms.keys)
  let paymentMethodList = Jotai.useAtomValue(JotaiAtoms.paymentMethodList)
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
        ~sdkAuthorization=?keys.sdkAuthorization->Utils.getNonEmptyOption,
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
    ~sdkAuthorization,
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
      ~sdkAuthorization,
    )
}

let usePaymentIntent = (optLogger, paymentType) => {
  open JotaiAtoms
  open Promise
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let paymentTypeFromUrl = componentName->CardThemeType.getPaymentMode
  let blockConfirm = Jotai.useAtomValue(isConfirmBlocked)
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let paymentMethodList = Jotai.useAtomValue(paymentMethodList)
  let keys = Jotai.useAtomValue(keys)
  let isCallbackUsedVal = Jotai.useAtomValue(JotaiAtoms.isCompleteCallbackUsed)
  let redirectionFlags = Jotai.useAtomValue(redirectionFlagsAtom)

  let setIsManualRetryEnabled = Jotai.useSetAtom(isManualRetryEnabled)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId=keys.iframeId,
    ~isThirdPartyFlow=false,
    ~intentCallback=_ => (),
    ~manualRetry=false,
    ~isTrustpayInterceptorConfirm=false,
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
        ~clientSecret,
        ~sdkAuthorization=keys.sdkAuthorization->Utils.getNonEmptyOption,
      )
      let headers = {
        let baseHeaders = [
          ("X-Client-Source", paymentTypeFromUrl->CardThemeType.getPaymentModeToStrMapper),
        ]
        switch keys.sdkAuthorization->Utils.getNonEmptyOption {
        | Some(sdkAuth) => baseHeaders->Array.push(("Authorization", sdkAuth))
        | _ => baseHeaders->Array.push(("api-key", confirmParam.publishableKey))
        }

        baseHeaders
      }

      let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]
      let manual_retry = manualRetry ? [("retry_action", "manual_retry"->JSON.Encode.string)] : []
      let clientSecretArr = switch keys.sdkAuthorization->Utils.getNonEmptyOption {
      | Some(_) => []
      | None => [("client_secret", clientSecret->JSON.Encode.string)]
      }
      let body = clientSecretArr->Array.concatMany([returnUrlArr, manual_retry])

      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=isThirdPartyFlow,
      )
      let path = `payments/${paymentIntentId}/confirm`

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
            ~sdkAuthorization=keys.sdkAuthorization->Utils.getNonEmptyOption,
            ~isTrustpayInterceptorConfirm,
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
        let paymentList = data->getDictFromJson->PaymentMethodsRecord.itemToObjMapperFromClientList
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
  ~sdkAuthorization=None,
) => {
  let headers = [("X-Merchant-Domain", merchantHostname)]->Dict.fromArray
  let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
    ~clientSecret,
    ~sdkAuthorization=sdkAuthorization->Utils.getNonEmptyOption,
  )

  let bodyArr = [
    ("payment_id", paymentIntentId->JSON.Encode.string),
    ("wallets", wallets->JSON.Encode.array),
    ("delayed_session_token", isDelayedSessionToken->JSON.Encode.bool),
  ]

  let body = switch sdkAuthorization->Utils.getNonEmptyOption {
  | Some(_) => bodyArr->getJsonFromArrayOfJson
  | _ =>
    bodyArr
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson
  }

  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchSessions,
    ~params={
      customBackendBaseUrl: Some(endpoint),
      clientSecret: None,
      publishableKey: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization,
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
    ~sdkAuthorization,
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
      forceSync: None,
      pollId: None,
      payoutId: Some(payoutId),
      sdkAuthorization: None,
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
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization: None,
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

let fetchClientList = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~isPaymentSession=false,
  ~sdkAuthorization=None,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchClientList,
    ~params={
      clientSecret: Some(clientSecret),
      customBackendBaseUrl: Some(endpoint),
      publishableKey: Some(publishableKey),
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization,
    },
  )

  let onSuccess = data => data
  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=CLIENT_LIST_CALL,
    ~logger,
    ~method=#GET,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
    ~isPaymentSession,
    ~sdkAuthorization,
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
  ~isPaymentSession=true,
  ~sdkAuthorization=None,
  ~mode: CardThemeType.mode=NONE,
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

  let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
    ~clientSecret,
    ~sdkAuthorization=sdkAuthorization->Utils.getNonEmptyOption,
  )

  let endpoint = ApiEndpoint.getApiEndPoint(
    ~publishableKey=confirmParam.publishableKey,
    ~isConfirmCall=true,
  )
  let uri = `${endpoint}/payments/${paymentIntentId}/confirm`
  let headers = switch sdkAuthorization->Utils.getNonEmptyOption {
  | Some(sdkAuth) => [("Authorization", sdkAuth)]
  | None => [("api-key", confirmParam.publishableKey)]
  }

  let broswerInfo = BrowserSpec.broswerInfo()

  let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]

  let clientSecretArr = switch sdkAuthorization->Utils.getNonEmptyOption {
  | Some(_) => []
  | None => [("client_secret", clientSecret->JSON.Encode.string)]
  }

  let bodyStr =
    body
    ->Array.concatMany([broswerInfo, clientSecretArr, returnUrlArr])
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
    ~isPaymentSession,
    ~redirectionFlags,
    ~sdkAuthorization,
    ~mode,
  )
}

let callAuthLink = async (
  ~publishableKey,
  ~clientSecret,
  ~paymentMethodType,
  ~pmAuthConnectorsArr,
  ~iframeId,
  ~logger,
  ~sdkAuthorization=None,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=CallAuthLink,
    ~params={
      clientSecret: None,
      publishableKey: Some(publishableKey),
      customBackendBaseUrl: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization,
    },
  )

  let bodyArr = [
    (
      "payment_id",
      Utils.getPaymentIdOrExtractFromSdkAuth(
        ~clientSecret=clientSecret->Option.getOr(""),
        ~sdkAuthorization=sdkAuthorization->Utils.getNonEmptyOption,
      )->JSON.Encode.string,
    ),
    ("payment_method", "bank_debit"->JSON.Encode.string),
    ("payment_method_type", paymentMethodType->JSON.Encode.string),
  ]

  let body = switch sdkAuthorization->Utils.getNonEmptyOption {
  | Some(_) => bodyArr->getJsonFromArrayOfJson
  | _ =>
    bodyArr
    ->Array.concat([("client_secret", clientSecret->Option.getOr("")->JSON.Encode.string)])
    ->getJsonFromArrayOfJson
  }

  let onSuccess = data => {
    let metaData =
      [
        ("linkToken", data->getDictFromJson->getString("link_token", "")->JSON.Encode.string),
        ("pmAuthConnectorArray", pmAuthConnectorsArr->anyTypeToJson),
        ("publishableKey", publishableKey->JSON.Encode.string),
        ("sdkAuthorization", sdkAuthorization->Option.getOr("")->JSON.Encode.string),
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
    ~sdkAuthorization,
  )
}

let callAuthExchange = async (
  ~publicToken,
  ~clientSecret,
  ~paymentMethodType,
  ~publishableKey,
  ~setOptionValue: (PaymentType.options => PaymentType.options) => unit,
  ~logger,
  ~sdkAuthorization=None,
) => {
  open Promise
  open PaymentType
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=CallAuthExchange,
    ~params={
      clientSecret: None,
      publishableKey: Some(publishableKey),
      customBackendBaseUrl: None,
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization,
    },
  )

  let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
    ~clientSecret=clientSecret->Option.getOr(""),
    ~sdkAuthorization=sdkAuthorization->Utils.getNonEmptyOption,
  )

  let bodyArr = [
    ("payment_id", paymentIntentId->JSON.Encode.string),
    ("payment_method", "bank_debit"->JSON.Encode.string),
    ("payment_method_type", paymentMethodType->JSON.Encode.string),
    ("public_token", publicToken->JSON.Encode.string),
  ]

  let body = switch sdkAuthorization->Utils.getNonEmptyOption {
  | Some(_) => bodyArr->getJsonFromArrayOfJson
  | _ =>
    bodyArr
    ->Array.concat([("client_secret", clientSecret->Option.getOr("")->JSON.Encode.string)])
    ->getJsonFromArrayOfJson
  }

  let onSuccess = _ => {
    let endpoint = ApiEndpoint.getApiEndPoint()
    fetchClientList(
      ~clientSecret=clientSecret->Option.getOr(""),
      ~publishableKey,
      ~logger,
      ~customPodUri="",
      ~endpoint,
      ~sdkAuthorization,
    )
    ->then(clientListResponse => {
      let clientListResponse = [("clientList", clientListResponse)]->Dict.fromArray
      setOptionValue(prev => {
        ...prev,
        customerPaymentMethods: clientListResponse->createCustomerObjArrFromClientList(
          "clientList",
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
    ~sdkAuthorization,
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
  ~sdkAuthorization,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=CalculateTax,
    ~params={
      customBackendBaseUrl: None,
      clientSecret: Some(clientSecret),
      publishableKey: Some(apiKey),
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization,
    },
  )
  let onSuccess = data => data

  let onFailure = _ => JSON.Encode.null

  let body = [("shipping", shippingAddress), ("payment_method_type", paymentMethodType)]

  switch sdkAuthorization->Utils.getNonEmptyOption {
  | Some(_) => ()
  | None => body->Array.push(("client_secret", clientSecret->JSON.Encode.string))
  }

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
    ~sdkAuthorization,
  )
}

let usePostSessionTokens = (
  optLogger,
  paymentType: payment,
  paymentMethod: PaymentMethodCollectTypes.paymentMethod,
) => {
  open JotaiAtoms
  open Promise
  let url = RescriptReactRouter.useUrl()
  let paymentTypeFromUrl =
    CardUtils.getQueryParamsDictforKey(url.search, "componentName")->CardThemeType.getPaymentMode
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let paymentMethodList = Jotai.useAtomValue(paymentMethodList)
  let keys = Jotai.useAtomValue(keys)
  let redirectionFlags = Jotai.useAtomValue(JotaiAtoms.redirectionFlagsAtom)

  let setIsManualRetryEnabled = Jotai.useSetAtom(isManualRetryEnabled)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId=keys.iframeId,
    ~isThirdPartyFlow=false,
    ~intentCallback=_ => (),
    ~manualRetry as _=false,
    ~isTrustpayInterceptorConfirm as _=false,
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
        ~clientSecret,
        ~sdkAuthorization=keys.sdkAuthorization->Utils.getNonEmptyOption,
      )

      let headers = [
        ("Content-Type", "application/json"),
        ("X-Client-Source", paymentTypeFromUrl->CardThemeType.getPaymentModeToStrMapper),
      ]

      let body = [
        ("payment_id", paymentIntentId->JSON.Encode.string),
        ("payment_method_type", (paymentType :> string)->JSON.Encode.string),
        ("payment_method", (paymentMethod :> string)->JSON.Encode.string),
      ]

      switch keys.sdkAuthorization->Utils.getNonEmptyOption {
      | Some(sdkAuth) => headers->Array.push(("Authorization", sdkAuth))
      | _ => {
          headers->Array.push(("api-key", confirmParam.publishableKey))
          body->Array.push(("client_secret", clientSecret->JSON.Encode.string))
        }
      }

      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=isThirdPartyFlow,
      )
      let uri = `${endpoint}/payments/${paymentIntentId}/post_session_tokens`

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
          ~sdkAuthorization=keys.sdkAuthorization,
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
        let paymentList = data->getDictFromJson->PaymentMethodsRecord.itemToObjMapperFromClientList
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
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization: None,
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
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization: None,
      authenticationId,
    },
  )

  let body =
    bodyArr
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson

  let headers = [("x-profile-id", profileId)]->Dict.fromArray

  let onSuccess = data => {
    let surchargeval = `{
    "payment_id": "pay_3f7ptHpuEDKfyNbmt3vL",
    "sdk_next_action": {
        "next_action": "confirm",
        "should_block_confirm": null
    },
    "surcharge_details": {
    "surcharge": { "type": "fixed", "value": 162 },
    "taxOnSurcharge": null,
    "displaySurchargeAmount": 1.62,
    "displayTaxOnSurchargeAmount": 0,
    "displayTotalSurchargeAmount": 1.62
  }

}`->JSON.parseExn
    let blockedval = `{
  "payment_id": "pay_xxx",
  "sdk_next_action": {
    "next_action": {
      "deny": {
        "message": "Card number is blocklisted"
      }
    }
  }
}`->JSON.parseExn

    // surchargeval
    blockedval
    // data
  }

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
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization: None,
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

let fetchSdkConfigs = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~sdkAuthorization=None,
) => {
  let uri = APIUtils.generateApiUrlV1(
    ~apiCallType=FetchSdkConfigs,
    ~params={
      clientSecret: Some(clientSecret),
      customBackendBaseUrl: Some(endpoint),
      publishableKey: Some(publishableKey),
      forceSync: None,
      pollId: None,
      payoutId: None,
      sdkAuthorization,
    },
  )

  let onSuccess = data => {
    let val = `{
    "raw_configs": {
        "contexts": [
            {
                "id": "b77ac32d5d3c5f67b72921c967a21c86c571e57ee7317fdd3e2d1a13a734f8f0",
                "condition": {
                    "payment_method": "Card"
                },
                "priority": 13,
                "weight": 13,
                "override_with_keys": [
                    "8a3edf7d6247e71698a13c17f47c69d08c6ad4428d35752adff149dffe50f110"
                ]
            },
            {
                "id": "53f50e021064772fed85fdad34601ee7c99b589b47f5a151eacac92c93316148",
                "condition": {
                    "connector": "authorizedotnet",
                    "payment_method": "Card",
                    "payment_method_type": "Credit"
                },
                "priority": 55,
                "weight": 55,
                "override_with_keys": [
                    "650435d35b38cee342dc34f566214545d0b603ae0f5bb49992afbd1d0b83177f"
                ]
            },
            {
                "id": "34e722e70fc17fea6d51bc34204f10b03fd2da544c22c074a2ba5a6961d47404",
                "condition": {
                    "payment_method_type": "Debit",
                    "payment_method": "Card",
                    "connector": "authorizedotnet"
                },
                "priority": 93,
                "weight": 93,
                "override_with_keys": [
                    "650435d35b38cee342dc34f566214545d0b603ae0f5bb49992afbd1d0b83177f"
                ]
            },
            {
                "id": "3a32ae14128e11c72937bdbd05cf4af2e8b2446db9b078e811861708d682bf97",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "AC"
                },
                "priority": 169,
                "weight": 169,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e23a2e97afab3d230a6a8756460de8659373aed3550d693195210243ea864d31",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "AD"
                },
                "priority": 170,
                "weight": 170,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "afba0372c56924900e79792ca07d12a85e054b0d921dd806a122ac2977970361",
                "condition": {
                    "country": "AE",
                    "payment_method": "Wallet"
                },
                "priority": 171,
                "weight": 171,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "76e40fd862eb8b43cdacc53c3c6530b97e76495cfc9f8f735a9d9e7df955478b",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "AF"
                },
                "priority": 172,
                "weight": 172,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "019cd5ffab5b337c3422225c9897b18065fb8b74de4ddefb2056c066ef3fb6c7",
                "condition": {
                    "country": "AG",
                    "payment_method": "Wallet"
                },
                "priority": 173,
                "weight": 173,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7cd567e9331eb7542490b2e84f21c2430180f84bd6e21db51416068876e9672b",
                "condition": {
                    "country": "AI",
                    "payment_method": "Wallet"
                },
                "priority": 174,
                "weight": 174,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "860939ad075139970d4270bf8feeae5c884fff2c60ab51fc148456bd453993b7",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "AL"
                },
                "priority": 175,
                "weight": 175,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "15f3994389e2679f9d4421281fd15909d40230291b6ce76db34c02055f8ccc08",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "AM"
                },
                "priority": 176,
                "weight": 176,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fdf4a9e38c9adb6c3014d662e9f5285991ec5c8b8364f7a8217872b087a0c007",
                "condition": {
                    "country": "AO",
                    "payment_method": "Wallet"
                },
                "priority": 177,
                "weight": 177,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "79efcbdf3c8666740f2b48b068a41723a804fb80293b44f841e518cae6e9e397",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "AQ"
                },
                "priority": 178,
                "weight": 178,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "873315250ea6de766a72a62da220b5780704dfc7a14d98f261c515b4fa586c88",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "AS"
                },
                "priority": 179,
                "weight": 179,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "86ff6817a80f4b4c05ce09796d22071bafea35a922639ff8cb517355522eee7f",
                "condition": {
                    "country": "AT",
                    "payment_method": "Wallet"
                },
                "priority": 180,
                "weight": 180,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "bfc56da060d7ad4e03259e83cb25018944cbbe7e63c17f253f4cae3754a11b93",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "AW"
                },
                "priority": 181,
                "weight": 181,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a7df952cc6fe4fc2d0f7e6e098578edb4aec5df080f2eadc3dfde3463680d6e6",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "AX"
                },
                "priority": 182,
                "weight": 182,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "23301ffff0d78883e13ebcec3910e7dc087260fb4cc8676a34c97cbe5af3d81a",
                "condition": {
                    "country": "AZ",
                    "payment_method": "Wallet"
                },
                "priority": 183,
                "weight": 183,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1f454f2be8bf401356ce3d69886976197acd89c8a700a59a2fd55e34eba25eab",
                "condition": {
                    "country": "BA",
                    "payment_method": "Wallet"
                },
                "priority": 184,
                "weight": 184,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3552a4f25c629d51de8788043cb63483743ea268c74af9adacb0c33a746650de",
                "condition": {
                    "country": "BB",
                    "payment_method": "Wallet"
                },
                "priority": 185,
                "weight": 185,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c962f4c7dad927e2a6491111b486a1c48784ce7c6b98eb95bf1a1b2f3aeee5bd",
                "condition": {
                    "country": "BD",
                    "payment_method": "Wallet"
                },
                "priority": 186,
                "weight": 186,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fa87ae474c07fb2333141893b3d64213d0f0273f83870c3fa5c1ed58f4f24226",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "BE"
                },
                "priority": 187,
                "weight": 187,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "46f4e461815763ebe81e9c426e337f3c18054c490419a342885257f52f3792da",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "BF"
                },
                "priority": 188,
                "weight": 188,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d783ea3e49fb06a12ec6f01ec6601e44fa3e37a0d4628e1171ec48a9a6a35016",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "BG"
                },
                "priority": 189,
                "weight": 189,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e811871c2aefaa252d51b3f3f4c1f9c42dd3ba61dccb2ea3e1f43aa1983bebe1",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "BH"
                },
                "priority": 190,
                "weight": 190,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a932e77a364dcb82c1957f99107e30d2fbed4f411a129fdecb10dd4c3ef970e3",
                "condition": {
                    "country": "BI",
                    "payment_method": "Wallet"
                },
                "priority": 191,
                "weight": 191,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1557b12ab1dc77f7c7d972967e4ae4805bd3bdeb5806a4f55bb6e2d0027e050f",
                "condition": {
                    "country": "BJ",
                    "payment_method": "Wallet"
                },
                "priority": 192,
                "weight": 192,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c350c70bda70897d921a0196c6558dfc624728e8c3598db0f3ae0d39088789f8",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "BL"
                },
                "priority": 193,
                "weight": 193,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "21d7388b5b57b0c63ab9d3974836ab6a901dfbdfe1a5fff09e36049514355f1c",
                "condition": {
                    "country": "BM",
                    "payment_method": "Wallet"
                },
                "priority": 194,
                "weight": 194,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "263c90286f5bead165378c4c8fcccc61665211e8c639ea72fc7677d4fd2a59d5",
                "condition": {
                    "country": "BN",
                    "payment_method": "Wallet"
                },
                "priority": 195,
                "weight": 195,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e5b7edbd8e4f461e7fcd3041f29fa44f935dfabe6c7b7dbe2af07bab6c72f531",
                "condition": {
                    "country": "BO",
                    "payment_method": "Wallet"
                },
                "priority": 196,
                "weight": 196,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "04b727ef6f521ab1a6526dc3606b100de0ee7ca57f71ddefbf142e821216aa5a",
                "condition": {
                    "country": "BQ",
                    "payment_method": "Wallet"
                },
                "priority": 197,
                "weight": 197,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7d82018a1ac750595d2d25e72de6ae8cf68282ad14a89a8c0ad464c879870289",
                "condition": {
                    "country": "BS",
                    "payment_method": "Wallet"
                },
                "priority": 198,
                "weight": 198,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "63d0df43f0db5f1eb9a1f59bda730d1003b073b7117d07cd01e2a213ed5fdd83",
                "condition": {
                    "country": "BT",
                    "payment_method": "Wallet"
                },
                "priority": 199,
                "weight": 199,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c7c19ef4a5ad686bff93129b3d9af924e8cb3e6ea8ac2610bf29182a7af51447",
                "condition": {
                    "country": "BV",
                    "payment_method": "Wallet"
                },
                "priority": 200,
                "weight": 200,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e108486df5d7882253ac0b99bfaf33fa7c4814c4177cadff63bb3fc80e496fc6",
                "condition": {
                    "country": "BW",
                    "payment_method": "Wallet"
                },
                "priority": 201,
                "weight": 201,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a53ef19f426554e6f3b3f57ade3e18eda5c695cca78548152d69ed893ac2d748",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "CC"
                },
                "priority": 202,
                "weight": 202,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fc444a5a12caa0f0e7bc3cb4536ed14485d26b4e90aff6e8f75a6a38bf5668eb",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "CD"
                },
                "priority": 203,
                "weight": 203,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3c44a836896a2acae4bd75da25410ebf2f8c608a7d2cd9fa0aae09b15c1c3644",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "CF"
                },
                "priority": 204,
                "weight": 204,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "46367a1eee11bf4c6da7ccf0e2251df111764bade1877ed120db9f1e54d1537c",
                "condition": {
                    "country": "CG",
                    "payment_method": "Wallet"
                },
                "priority": 205,
                "weight": 205,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "00b6e426f3c69f734028e006c1ff3f556149ce51e95c0a78e52da5a89cdd3c39",
                "condition": {
                    "country": "CH",
                    "payment_method": "Wallet"
                },
                "priority": 206,
                "weight": 206,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e0fc502baec920dbf50421a074040a7775bcd48086806039c18450ead50a002d",
                "condition": {
                    "country": "CI",
                    "payment_method": "Wallet"
                },
                "priority": 207,
                "weight": 207,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "332b55dff1e9a1f4dee38be1efd66c818c50b7ed94e0c69620139a1c7a9fcf73",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "CK"
                },
                "priority": 208,
                "weight": 208,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "855c376cbeff1a88c019e882ed5c9bccb4189b3dc4d19d56322bec3443f979e0",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "CM"
                },
                "priority": 209,
                "weight": 209,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "451b58c63ea879f664f792e6de2802e47095858df92dcc19d1f848db41ff44d7",
                "condition": {
                    "country": "CR",
                    "payment_method": "Wallet"
                },
                "priority": 210,
                "weight": 210,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c64792bb0b14a653dd53650a1de1cf42b37595841b8715c1cb903ae77ebaab42",
                "condition": {
                    "country": "CU",
                    "payment_method": "Wallet"
                },
                "priority": 211,
                "weight": 211,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7e602209c14b04a8d29506478898ea1dbe6b0d38a6a6b840bb3b4fc04738551f",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "CV"
                },
                "priority": 212,
                "weight": 212,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "bbe2663f7ff110de88afd2eb16dda677bc0b69400969ee6c2d48352c79e03400",
                "condition": {
                    "country": "CW",
                    "payment_method": "Wallet"
                },
                "priority": 213,
                "weight": 213,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2e3f0b345c87fd3d7c71a3eb4376e4dbd35d555cf9c0521009642f836e79eda0",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "CX"
                },
                "priority": 214,
                "weight": 214,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "df9ac407a754390915cc7e26af067d1777cdb187ce17e9c492864549e7dcb38b",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "CY"
                },
                "priority": 215,
                "weight": 215,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f8b02e4f08cd78b8a9addd22169b7e8014d6fffb59b8595cac6f1ba5f2f7dfed",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "CZ"
                },
                "priority": 216,
                "weight": 216,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "48015041bdc34ea533d372f1ea21705964ffeb40c3c4d1145a1976292684e377",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "DE"
                },
                "priority": 217,
                "weight": 217,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1673c5bc158edf3d5fede106c82f002dad33566563d0556d816eb2102ee9a8bf",
                "condition": {
                    "country": "DJ",
                    "payment_method": "Wallet"
                },
                "priority": 218,
                "weight": 218,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "82a5bfea962cf1606f286ec35e78e088126c3a9c09b4e98014263da79e57a0ed",
                "condition": {
                    "country": "DK",
                    "payment_method": "Wallet"
                },
                "priority": 219,
                "weight": 219,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "32537e08888749c92e5c504b9184ada887e2a6bba46c0af4bbf8e332581610b5",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "DM"
                },
                "priority": 220,
                "weight": 220,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c52def9b2b5a329737d793d2831817affb72b4c1a1330cbae0a78812118a3485",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "DO"
                },
                "priority": 221,
                "weight": 221,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "266012fad01afc90600116ab78af773dfa7d9394b47643cb38d2c00f42e78ec3",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "DZ"
                },
                "priority": 222,
                "weight": 222,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "415dee437dfad25d707bdd2b3007f670716e0f672836c0e12d2c6d7d4a096bff",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "EC"
                },
                "priority": 223,
                "weight": 223,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a8cbc83b004bf04642058adbb9627182184c6ca267c792d02bf64d4e232547aa",
                "condition": {
                    "country": "EE",
                    "payment_method": "Wallet"
                },
                "priority": 224,
                "weight": 224,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "709e4afb7ed609cb0a27b4b1dd9f4d676319eea230982dd0c375a9525c23691a",
                "condition": {
                    "country": "EH",
                    "payment_method": "Wallet"
                },
                "priority": 225,
                "weight": 225,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2ceb25b4422b62d2bd6d7202b0d45b6f7497864d6a90e564c5be22cd03167a7d",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "ER"
                },
                "priority": 226,
                "weight": 226,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1ac5c44e07a95afe9871190a33e02c9d69ae8686d7cb20bc64a3fb8da7d80c97",
                "condition": {
                    "country": "ET",
                    "payment_method": "Wallet"
                },
                "priority": 227,
                "weight": 227,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7c521df24ce83b3aed42d391ea80b40f0214893d430f8e4a7de2b06c352fca61",
                "condition": {
                    "country": "FI",
                    "payment_method": "Wallet"
                },
                "priority": 228,
                "weight": 228,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "738a03334b8288690eeccdafd408c341ba45c25fa7d19c25f709c2ea0071fb30",
                "condition": {
                    "country": "FJ",
                    "payment_method": "Wallet"
                },
                "priority": 229,
                "weight": 229,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "554e303b4124e6442aa3d47a39b54051ee314b1f6ad6bfce53178799554026c2",
                "condition": {
                    "country": "FK",
                    "payment_method": "Wallet"
                },
                "priority": 230,
                "weight": 230,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "edc1687bc208bd54f37c7a32c5f46e2d388d54b9553bd165d5e243320a732e38",
                "condition": {
                    "country": "FO",
                    "payment_method": "Wallet"
                },
                "priority": 231,
                "weight": 231,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a83909009f877565839f10b057d60ecdce6c992336ef0c235bdfac0603e60f56",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "FR"
                },
                "priority": 232,
                "weight": 232,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "000eed347320b1147b5dd28b434773b0ac794c5c503563841b0ba6f0adb1decf",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "GA"
                },
                "priority": 233,
                "weight": 233,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a3335c7639b17444c939325722b385e5b526fb3d14ba29ccd1b8c3f194f63761",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "GD"
                },
                "priority": 234,
                "weight": 234,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "336baa3f3564c0a10251975fce2feea18a7e22d6c6b5d8b3022a3cd691b22d41",
                "condition": {
                    "country": "GE",
                    "payment_method": "Wallet"
                },
                "priority": 235,
                "weight": 235,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0810b95075c4bf2aabd12664e9de2ee86dfc95c35b9059daaa31477f6768f0e4",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "GF"
                },
                "priority": 236,
                "weight": 236,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "32a6d187ff6630d6d3df2064b1f57543fb59d7fa827eb0f0af3e86d7f6b730a6",
                "condition": {
                    "country": "GG",
                    "payment_method": "Wallet"
                },
                "priority": 237,
                "weight": 237,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cf832e1463d671ec3581311e69532929de5c47de1c68ab65fbc0ddc5df7b21b5",
                "condition": {
                    "country": "GH",
                    "payment_method": "Wallet"
                },
                "priority": 238,
                "weight": 238,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7b5d26fad2ec73943471ba0d762103afb74fc30d3ea850c342d072705bdc73b7",
                "condition": {
                    "country": "GI",
                    "payment_method": "Wallet"
                },
                "priority": 239,
                "weight": 239,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ed4e443448d1e57f024c1e6e7bec29c103b33e89c3de58792128c55fc745c0c5",
                "condition": {
                    "country": "GL",
                    "payment_method": "Wallet"
                },
                "priority": 240,
                "weight": 240,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c16c115949e661ec5b12b6b682540ccb14265c3d1a5c8128fc732a6f657728a9",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "GM"
                },
                "priority": 241,
                "weight": 241,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fd43b9485274e30b092d219ec7f3f5414cb1460e5dd451d43a369dd24ac1c27c",
                "condition": {
                    "country": "GN",
                    "payment_method": "Wallet"
                },
                "priority": 242,
                "weight": 242,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "dd617f631a2d612acec2d119323e2d72d10368add97a4808a010dfb8586dc21d",
                "condition": {
                    "country": "GP",
                    "payment_method": "Wallet"
                },
                "priority": 243,
                "weight": 243,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "69da373b13738cc9cbfdf0180579e460656097c89deed24f387996b9e79f7c46",
                "condition": {
                    "country": "GQ",
                    "payment_method": "Wallet"
                },
                "priority": 244,
                "weight": 244,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f422784e7175a0b251a8fc7d97a6545cefb39fdf1ee0aaabec2b46ac866d6357",
                "condition": {
                    "country": "GR",
                    "payment_method": "Wallet"
                },
                "priority": 245,
                "weight": 245,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "be4dbcd4952387f57e295574b312402b7d921b937defe384ae30c20f05d6313a",
                "condition": {
                    "country": "GS",
                    "payment_method": "Wallet"
                },
                "priority": 246,
                "weight": 246,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "eb089b78327fc3001bf437d4551341ea3a0af63d9a82be8b60268a260e5e6cac",
                "condition": {
                    "country": "GT",
                    "payment_method": "Wallet"
                },
                "priority": 247,
                "weight": 247,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3a7e2a0496db8666ba9f9e0b132178e1cfee66890ff5399c09255d2b548840aa",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "GU"
                },
                "priority": 248,
                "weight": 248,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "93c5b4d62d35277471493a79cb5ef9ee080c381fe914f2470927d0f5a282e6ec",
                "condition": {
                    "country": "GW",
                    "payment_method": "Wallet"
                },
                "priority": 249,
                "weight": 249,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4b631e38cc62b677443fc8c2d2bd3e4f072d69480e968109da242a8a1d0d592b",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "GY"
                },
                "priority": 250,
                "weight": 250,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "13118d09f311c86aaf38b736ea5e3c50d674d1d2c47d99e73002143fd392b61a",
                "condition": {
                    "country": "HM",
                    "payment_method": "Wallet"
                },
                "priority": 251,
                "weight": 251,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "07cb377cf772425628f393a45eb64ccb073ed63c88fb0296d27ae772b73330a1",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "HR"
                },
                "priority": 252,
                "weight": 252,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7138babe7d50e2474b70a289ead2f7b0d309e9dfc02a82a62628299842fef057",
                "condition": {
                    "country": "HT",
                    "payment_method": "Wallet"
                },
                "priority": 253,
                "weight": 253,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e21dd1608a18dea014276a877a508d8754769ddd3bf0dbb0b0af3a6ecb19d2d6",
                "condition": {
                    "country": "HU",
                    "payment_method": "Wallet"
                },
                "priority": 254,
                "weight": 254,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "584324f6e229b3dc7a6de8aee5b4212aa64d2307394c1ea5ebe1f2ff78e8bc96",
                "condition": {
                    "country": "IE",
                    "payment_method": "Wallet"
                },
                "priority": 255,
                "weight": 255,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "977f9d5f4da307627c8464599bcea6ea3cd15d1cbd04673a195b941bb246f35c",
                "condition": {
                    "country": "IL",
                    "payment_method": "Wallet"
                },
                "priority": 256,
                "weight": 256,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "029d5206168a3c4c63fdd6c1cb56fc18d1108e7cafedc544de04cc31a1ef8b3c",
                "condition": {
                    "country": "IM",
                    "payment_method": "Wallet"
                },
                "priority": 257,
                "weight": 257,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3452e3dc2f082bbd6c5b35d37aef35d0eda4b5969717ae4cb6773420b759118c",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "IO"
                },
                "priority": 258,
                "weight": 258,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "48eae60d839ffc39205a20f5d0b0f00794d7854f0746748cb72e60246bc38b42",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "IQ"
                },
                "priority": 259,
                "weight": 259,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d812c5a3806c0ade1d94f07d162326284d8ce975382aec2f2c5e1cd7b3495335",
                "condition": {
                    "country": "IR",
                    "payment_method": "Wallet"
                },
                "priority": 260,
                "weight": 260,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0721424ae26f510c2c533c5b148e903b62c75298d4bf915ef1dc307c00d83d6c",
                "condition": {
                    "country": "IS",
                    "payment_method": "Wallet"
                },
                "priority": 261,
                "weight": 261,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a59e8573cbf65a85624ad126842444c0dd3184e26ac27a3f957007317f5a408d",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "JE"
                },
                "priority": 262,
                "weight": 262,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2e08a51c4abf325bdc9f488a711e27ba8e5c955dd415a8b0465e67f816ea5ca1",
                "condition": {
                    "country": "JM",
                    "payment_method": "Wallet"
                },
                "priority": 263,
                "weight": 263,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f0b3fac94434f01c863311f7529810d4f51bc950457999342b85362a62ec4970",
                "condition": {
                    "country": "JO",
                    "payment_method": "Wallet"
                },
                "priority": 264,
                "weight": 264,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "83354d214f57c7f4acf833ea3b5a6cae19368e91af13883fe1ed1b10b20e04f8",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "KE"
                },
                "priority": 265,
                "weight": 265,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1c98262c24c7125d39877b8e54713563253936faf719254e0a1b3c992c586888",
                "condition": {
                    "country": "KG",
                    "payment_method": "Wallet"
                },
                "priority": 266,
                "weight": 266,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0f1b1cbd0a0c4b26834829d758dedff3ab6c0f89290247f302c33e0c9f470d89",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "KH"
                },
                "priority": 267,
                "weight": 267,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "331afe54a1b982f8dc21539cb7187be362d428731aeac87f1db2a9fd10d18d4c",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "KI"
                },
                "priority": 268,
                "weight": 268,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b421a8731715c1d6fe28ee6a058fc9c041b70d5d30dbe5bf441088a0de5f6fcd",
                "condition": {
                    "country": "KM",
                    "payment_method": "Wallet"
                },
                "priority": 269,
                "weight": 269,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4a7521d4bb793feb7578be8cf90dde64c5e8c545e8d02a82bfc2737e737ebbee",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "KN"
                },
                "priority": 270,
                "weight": 270,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "87fa377c93b504bfd0ba1e5e9073023d1abbe9745ca40cc436b0e27994852c11",
                "condition": {
                    "country": "KY",
                    "payment_method": "Wallet"
                },
                "priority": 271,
                "weight": 271,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "873db80193b113af86d0ff6af3df0a9d08c05e473d84411ff878e40770e76c82",
                "condition": {
                    "country": "LA",
                    "payment_method": "Wallet"
                },
                "priority": 272,
                "weight": 272,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9313e64d3bdc848581a1e4589547ce6d08e868a12f0bc76a3a3984a4e828ca6f",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "LB"
                },
                "priority": 273,
                "weight": 273,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6248b7ba9c63a4d9dad5ea09b07a4eeedc8a07365283ac8fc3cd5fe9c7b470eb",
                "condition": {
                    "country": "LC",
                    "payment_method": "Wallet"
                },
                "priority": 274,
                "weight": 274,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "90280cafb3a35dc71706cd4d57b32c6dc37efb55bf843f8a387f9dd0e5aef4db",
                "condition": {
                    "country": "LI",
                    "payment_method": "Wallet"
                },
                "priority": 275,
                "weight": 275,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "83afa6e4c75b81b4ea5bc1209c298be1f5134cb72f73fa578956b68d042e8b58",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "LK"
                },
                "priority": 276,
                "weight": 276,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "369c80c1833f5361dbcac8ecf5a20c1fd6b2246155c55fc665769f273471c77e",
                "condition": {
                    "country": "LR",
                    "payment_method": "Wallet"
                },
                "priority": 277,
                "weight": 277,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5184a186e7dca9fc2e02427ed0a05f9084105f3bf16912758c3745db84335bbc",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "LS"
                },
                "priority": 278,
                "weight": 278,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8de033b953eb4fe9ab1dafad206b166cd8fb52ab517d811aba612254b8ff89c5",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "LT"
                },
                "priority": 279,
                "weight": 279,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cc4570f4c202fd2e913839c664097c0e9ae02caca7b581a4fefe9f037367f2e2",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "LU"
                },
                "priority": 280,
                "weight": 280,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "87d41d34730c7525b537f597e23fac25780db2fb15a557a902bf9dac399fe072",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "LV"
                },
                "priority": 281,
                "weight": 281,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "87c08bfb779fc0e51d670167546459db2b9349e1be8c217782317af1b6af06f5",
                "condition": {
                    "country": "LY",
                    "payment_method": "Wallet"
                },
                "priority": 282,
                "weight": 282,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8c483608d383c640f8dc52c6388189ba651aba53a85a83eb9c25222d05462720",
                "condition": {
                    "country": "MA",
                    "payment_method": "Wallet"
                },
                "priority": 283,
                "weight": 283,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "322cf9fc6cb326fe0d698a5edeb81e3742a937e4aca373c88588456f48945a38",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "MC"
                },
                "priority": 284,
                "weight": 284,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e2fd9bf1914af61232f17dfc5f88d5ac135720a750708f625009c62e136df000",
                "condition": {
                    "country": "MD",
                    "payment_method": "Wallet"
                },
                "priority": 285,
                "weight": 285,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "132f17c012908fa97ab7f144226128be6c92cf4c2f2fe8c3df99b9d5edde3bd4",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "ME"
                },
                "priority": 286,
                "weight": 286,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a14d9d5aeaa99bc77ab9e67c5426918292e357b78b46f763379381e7fc135beb",
                "condition": {
                    "country": "MF",
                    "payment_method": "Wallet"
                },
                "priority": 287,
                "weight": 287,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "71a2adee2b8f4f4e1a7398f619d253bc25138a4afea605d3e817370d50def653",
                "condition": {
                    "country": "MG",
                    "payment_method": "Wallet"
                },
                "priority": 288,
                "weight": 288,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d1a174351a0778a6edecb2d19012aa7b83c738e2feea924f9edccbcc0f8e3d1d",
                "condition": {
                    "country": "MH",
                    "payment_method": "Wallet"
                },
                "priority": 289,
                "weight": 289,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "78bc0f4f12e923cb12a18e7620a2574eb8723ead53ff1e773c40bbc7bb07d4ea",
                "condition": {
                    "country": "MK",
                    "payment_method": "Wallet"
                },
                "priority": 290,
                "weight": 290,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "80c807f426c270e9c0d3b605cd61903d9417af9f29760af4c9e946f0283cf9a4",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "ML"
                },
                "priority": 291,
                "weight": 291,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c5a30870e06ca0adc5b0a70139651b3093c940de417b5dc949f2020deb8ccdd2",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "MM"
                },
                "priority": 292,
                "weight": 292,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "34895464acfc0c99daed213013f74d42e09266f5e55d1ad24a8659dcb59b78d3",
                "condition": {
                    "country": "MN",
                    "payment_method": "Wallet"
                },
                "priority": 293,
                "weight": 293,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0de0f2904aef727cebadf907097821db303c55bed33f4c3d8a590ef59e73a4d1",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "MO"
                },
                "priority": 294,
                "weight": 294,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "bf98d5f37c4d3c5e718efd0a2358f3b895b068dccc39f4b3c3a2b4887d102ab6",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "MP"
                },
                "priority": 295,
                "weight": 295,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3605e7596c5ddc77480d2a37f06419a208f2c4ec36d0916b7ba9ee512fb7ab21",
                "condition": {
                    "country": "MQ",
                    "payment_method": "Wallet"
                },
                "priority": 296,
                "weight": 296,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f9a256c6b57fd78c937b41c887a0ff7873ad2e8a77eecd8b42d3ec0660419cbe",
                "condition": {
                    "country": "MR",
                    "payment_method": "Wallet"
                },
                "priority": 297,
                "weight": 297,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "652c718d489e3a1f95f1b30fe33c83c90423a85f61e45ce2327a5f453e63a833",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "MS"
                },
                "priority": 298,
                "weight": 298,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3e82fb0f0ebdeb349b94fc04ae59e62b1b6d22f4c3dd60d7718cbdf9e444177a",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "MT"
                },
                "priority": 299,
                "weight": 299,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cb0863f7bad29eec3a997a7f70d53d90c625e9ed8d38e619adf0de3b41d526a9",
                "condition": {
                    "country": "MU",
                    "payment_method": "Wallet"
                },
                "priority": 300,
                "weight": 300,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0620dc3ae139ff8fbd5225ec9c48f8dfb50d64e8c14b941fc0572945e4213e78",
                "condition": {
                    "country": "MV",
                    "payment_method": "Wallet"
                },
                "priority": 301,
                "weight": 301,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d25ea8c56390fe7ae8a691dcbbb6a7bb6870d8862001202f7611a3ef5cd691dd",
                "condition": {
                    "country": "MW",
                    "payment_method": "Wallet"
                },
                "priority": 302,
                "weight": 302,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "614a8c4a61780c5633dfaf0e9be9df43d9b291e0bc6eb23c3bf751836e353451",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "NA"
                },
                "priority": 303,
                "weight": 303,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8a26f2387bf451f238c6a02c29a4f2ca83837650ef37b005df447d91fa687972",
                "condition": {
                    "country": "NC",
                    "payment_method": "Wallet"
                },
                "priority": 304,
                "weight": 304,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "14d46b47e904d26aaf025c2ac0c7734af14810601607713dab3ab7c0ce939e0d",
                "condition": {
                    "country": "NE",
                    "payment_method": "Wallet"
                },
                "priority": 305,
                "weight": 305,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "83d943fea8b5d31a081c44043b9667c8211fe4e71279eeff6b3a6db40f746eba",
                "condition": {
                    "country": "NF",
                    "payment_method": "Wallet"
                },
                "priority": 306,
                "weight": 306,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6e1def994235e03918ab99a76d99b00616d6904cc7f913c49a19e1f98e601a13",
                "condition": {
                    "country": "NI",
                    "payment_method": "Wallet"
                },
                "priority": 307,
                "weight": 307,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8ef783e00df10fd540f647eb583881165d3ac5b20e051e34ac2689f34c4418c2",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "NL"
                },
                "priority": 308,
                "weight": 308,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "24ccc8dfd9203a02bd271f8ac6aa7185e4c542554ac084354d6f63c493dc1dce",
                "condition": {
                    "country": "NO",
                    "payment_method": "Wallet"
                },
                "priority": 309,
                "weight": 309,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2cd16ddf5d1fd69c40e8816f9b9bba9e4357071107a2048b44cf8da5e4c059b1",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "NP"
                },
                "priority": 310,
                "weight": 310,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cd030f6bf8fc0431f3021bc365cb686c13ff3f649bbd41eb49a009d647975807",
                "condition": {
                    "country": "NR",
                    "payment_method": "Wallet"
                },
                "priority": 311,
                "weight": 311,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2cae1fc352a769046f04a9f0af0a884cfce5aa30203f7df4b61c427cb4cbcc57",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "NU"
                },
                "priority": 312,
                "weight": 312,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "89510379260860ae2ffebcc101d7db31c14ae343d1703174e316a3b22098b448",
                "condition": {
                    "country": "NZ",
                    "payment_method": "Wallet"
                },
                "priority": 313,
                "weight": 313,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a530aae748f2be0760edc10090570a26345c9644220c026cffdb467b8c0d6831",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "PE"
                },
                "priority": 314,
                "weight": 314,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2b1c39e89d0ddec57ae6cc7717b5fcaa08c6f6a04497e4d249743c1735db9201",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "PF"
                },
                "priority": 315,
                "weight": 315,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7d51bc4c6b881e3ac26ec1e62a7b6e13371761222c4f38e8eef6d61a86fb353f",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "PH"
                },
                "priority": 316,
                "weight": 316,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "feb03e8a273f73b522d5e7703a18cea7efbeaf442c382c1bfc19f02aec89c806",
                "condition": {
                    "country": "PK",
                    "payment_method": "Wallet"
                },
                "priority": 317,
                "weight": 317,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9177975efb3a87b110c064ad042bd0f2d8f7e0f147d0804d002a1f39d98fa1ab",
                "condition": {
                    "country": "PL",
                    "payment_method": "Wallet"
                },
                "priority": 318,
                "weight": 318,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "46e93123995429e44bf7a3bff81b54981d9f5b81a73464a0164a4a4134ba58ed",
                "condition": {
                    "country": "PM",
                    "payment_method": "Wallet"
                },
                "priority": 319,
                "weight": 319,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1e3339d30b60edce29cca769782873423536451a5dbd8095196dcc9dc406f017",
                "condition": {
                    "country": "PN",
                    "payment_method": "Wallet"
                },
                "priority": 320,
                "weight": 320,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c8d97a0e767b09238e3c0d440878127bfaff507bd1a27f09aeebb24908ed7842",
                "condition": {
                    "country": "PS",
                    "payment_method": "Wallet"
                },
                "priority": 321,
                "weight": 321,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c52171f4c0a71df4cc19a5515ac6f65d5b45fc9ebd1d789cfbe788c8a6c31c50",
                "condition": {
                    "country": "PT",
                    "payment_method": "Wallet"
                },
                "priority": 322,
                "weight": 322,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a7f947f2c16bcd9ff960ecf8504246966ba78c1d2b2686ffa184c6e5de12ccc5",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "PY"
                },
                "priority": 323,
                "weight": 323,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ddd48e23c82d52205cac3403b2fbf17f6f708207035ea8531b90155918bb9981",
                "condition": {
                    "country": "QA",
                    "payment_method": "Wallet"
                },
                "priority": 324,
                "weight": 324,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6a73c0d667bd8def7f2de6b74d8d1b02ea9fca0a1e05422aee66b4c776a6d66b",
                "condition": {
                    "country": "RE",
                    "payment_method": "Wallet"
                },
                "priority": 325,
                "weight": 325,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "734da9204e0597c3358c54f008e66c4c0020fe00072ecab90138fc092cd8941a",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "RO"
                },
                "priority": 326,
                "weight": 326,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d82577f5b2899a744f3881aac90191d25ebc5057193a0691b3ffc9adb89b1b4f",
                "condition": {
                    "country": "RS",
                    "payment_method": "Wallet"
                },
                "priority": 327,
                "weight": 327,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c1959ac9d6ac14f983c330e63059efae8524e075c9786d669d6b10e0c8763ecf",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "RW"
                },
                "priority": 328,
                "weight": 328,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d1300d1ef82afe545044dfc7a3634f9b7fe85b63a5e8a320bd9c6c486b3ec407",
                "condition": {
                    "country": "SA",
                    "payment_method": "Wallet"
                },
                "priority": 329,
                "weight": 329,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "efb875fb35864528cc34d30e4548470f4f699880861f92c373d78584f7a32b5d",
                "condition": {
                    "country": "SB",
                    "payment_method": "Wallet"
                },
                "priority": 330,
                "weight": 330,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ad72291140ffc8ce326ca3662cd8b65335bf263eb7358ec38a5bd46edd4d6da4",
                "condition": {
                    "country": "SC",
                    "payment_method": "Wallet"
                },
                "priority": 331,
                "weight": 331,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "af068ce5fc06fd3bd09dbc89d640b0ced786935fa8cfa6bea69a9faddc6e6570",
                "condition": {
                    "country": "SD",
                    "payment_method": "Wallet"
                },
                "priority": 332,
                "weight": 332,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "144173c0387ee508fb5d1db4d23a4fa5f418dc432f681782dffb4530fe89957b",
                "condition": {
                    "country": "SE",
                    "payment_method": "Wallet"
                },
                "priority": 333,
                "weight": 333,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3bad73fa6d0b5227b26b8d9cc07f1075069fbcb46b3d3cb8731bd71da8ff9f64",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "SG"
                },
                "priority": 334,
                "weight": 334,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "67add74768ee4b56a3cd05a44f0df7b5170a176732b006132d9c2b4421388182",
                "condition": {
                    "country": "SH",
                    "payment_method": "Wallet"
                },
                "priority": 335,
                "weight": 335,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e9d20540185a584f4a27f37ab03eb16a29deea03f4cf7949dbc7437e81e345da",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "SI"
                },
                "priority": 336,
                "weight": 336,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "506be1c9bedad278f9fcf64439360c567418159c6a2a991a1212db9595120667",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "SJ"
                },
                "priority": 337,
                "weight": 337,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b8e6f56b54d7dc04ae18612b2f7e8dc8205b3e87bc80349108f68ba414863849",
                "condition": {
                    "country": "SK",
                    "payment_method": "Wallet"
                },
                "priority": 338,
                "weight": 338,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4730d9bff1e3cf21b0391ef02d295d496aa9e761c183afd1f34a8f207d76e53f",
                "condition": {
                    "country": "SL",
                    "payment_method": "Wallet"
                },
                "priority": 339,
                "weight": 339,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "33b6a03cffc893169a386b9092bde7fa23d848b74960a707a0da797f45ae14de",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "SN"
                },
                "priority": 340,
                "weight": 340,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3945a2d03c391d24b04a9d18827ae6ed2589f5a8494561050794e26e90d768a9",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "SO"
                },
                "priority": 341,
                "weight": 341,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6544a03b1ed5dffe970215616c8c76eccbd161dc4fc226e6ec975060e0764a60",
                "condition": {
                    "country": "SS",
                    "payment_method": "Wallet"
                },
                "priority": 342,
                "weight": 342,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "75a7ad74f309b6a6c69c416ffa88d91e7f698d46bc0bea000ae557abeee7a11c",
                "condition": {
                    "country": "ST",
                    "payment_method": "Wallet"
                },
                "priority": 343,
                "weight": 343,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ff3f6a0e734b224ed58ca6471bc5165107123fc741f0e6193da885d53ae34270",
                "condition": {
                    "country": "SX",
                    "payment_method": "Wallet"
                },
                "priority": 344,
                "weight": 344,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3f9755746de113b220b362b69d0e68ed5297abd69bfbc1748dd7c088c50d9c19",
                "condition": {
                    "country": "SY",
                    "payment_method": "Wallet"
                },
                "priority": 345,
                "weight": 345,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1cdb9ff7648c8a283165e5fedc03cdae9649f85becbdec54536cca457ab54a56",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "SZ"
                },
                "priority": 346,
                "weight": 346,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "be64bcc5066abffb853ceb29cff7ee9ac8928cefc568063565d2990aac73cf68",
                "condition": {
                    "country": "TA",
                    "payment_method": "Wallet"
                },
                "priority": 347,
                "weight": 347,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "85d294b4e48effe2a471e16bcbcb3dd0c3eda94bec2fe1986c4d812ebc533cb8",
                "condition": {
                    "country": "TC",
                    "payment_method": "Wallet"
                },
                "priority": 348,
                "weight": 348,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7b01d70f4357c528282f4482463706573e59df6c4972489696de353aab75e6d6",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "TD"
                },
                "priority": 349,
                "weight": 349,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d80fee7eb0a189f4d26e030e039bdd2d0087a00866d0089e9cdbc05ed60526b0",
                "condition": {
                    "country": "TF",
                    "payment_method": "Wallet"
                },
                "priority": 350,
                "weight": 350,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7cb56ba425f2931507e3e2cd0a25cf9d72c2232ba040f248cc29076a1ddc2ac9",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "TG"
                },
                "priority": 351,
                "weight": 351,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c6174c2a42d6e627603badeb21dcffac4062858bb3330a219662978523565b84",
                "condition": {
                    "country": "TJ",
                    "payment_method": "Wallet"
                },
                "priority": 352,
                "weight": 352,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a465b4b00be7d7c827ca763d467496eb66ad45985c9acf2dcf0ad6c1d9be6dc7",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "TK"
                },
                "priority": 353,
                "weight": 353,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ff4999046eda118d200e5a7822c305995369bfc0b01b895150ff36199e96afd6",
                "condition": {
                    "country": "TL",
                    "payment_method": "Wallet"
                },
                "priority": 354,
                "weight": 354,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fca7108283da3658b2aa141640c2a752bb1151d28a6adb2fa9a9c9f6bd3b33ab",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "TM"
                },
                "priority": 355,
                "weight": 355,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a781d038965ebb3ceb13d4f3cdf59febe2c54c8e193e4c1590a4d5e5496654ff",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "TN"
                },
                "priority": 356,
                "weight": 356,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5e8514086444b1bea796ed6b84afcb9c88e8b5c11546f2fb83de4bab2fdcdb1b",
                "condition": {
                    "country": "TO",
                    "payment_method": "Wallet"
                },
                "priority": 357,
                "weight": 357,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b0eb6f8c4d5392df1654f2af491b56ae51904f758cf2408074fd183bbf9f8266",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "TT"
                },
                "priority": 358,
                "weight": 358,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b9c7d51778c6022b78775c93c1fbd31956756ef5430aef6eb458ad0a172269e0",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "TV"
                },
                "priority": 359,
                "weight": 359,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "100c55b39079a79edd0a57be32b5316aedead5b4374ba8a2a7c301a04c1d8b73",
                "condition": {
                    "country": "TZ",
                    "payment_method": "Wallet"
                },
                "priority": 360,
                "weight": 360,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d84172067920abecebf5c3560d308bcb58ed43e17c6836d4fc4b75cd0bdd69df",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "UG"
                },
                "priority": 361,
                "weight": 361,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "28e1f8e9632016566f8fa386c8a1b68d35bdc9e322de86924f2c34053a2e6d6f",
                "condition": {
                    "country": "UM",
                    "payment_method": "Wallet"
                },
                "priority": 362,
                "weight": 362,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "70b264a8087062b1c16c6b07d604da5e9f4805fa0d87808407b6e8544546746b",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "UZ"
                },
                "priority": 363,
                "weight": 363,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "55ebbf010779a9d86f53f90a95c2d046a2f8505aa86296c2c589eacc0d6bc2cf",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "VA"
                },
                "priority": 364,
                "weight": 364,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2fdb1c34867729d4abaaac8e06bfd84b6f3628c46ef41029ad298cf17c3afb5d",
                "condition": {
                    "country": "VC",
                    "payment_method": "Wallet"
                },
                "priority": 365,
                "weight": 365,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1ffe0969a590f96b22967b4b4afe7a7f27f87e1f93de6fb49690c5580cd3e3a2",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "VG"
                },
                "priority": 366,
                "weight": 366,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c3b7f6bb292ad65cadb2da9d137380a72f45d399acee504d1ccf46f2676d8a8d",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "VU"
                },
                "priority": 367,
                "weight": 367,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "070a321e2621eb5b816aa5d75f45105ce9c9112208d4684a90c2445345c8206f",
                "condition": {
                    "country": "WF",
                    "payment_method": "Wallet"
                },
                "priority": 368,
                "weight": 368,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "84e5e67298d711f5949dab55d6b0a0660d31aaad8263c27e4907f5e27d1020b1",
                "condition": {
                    "country": "WS",
                    "payment_method": "Wallet"
                },
                "priority": 369,
                "weight": 369,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f7a8b034daeecb334de20d45d6a07e2d59974d499197e7576a6c4be891febc3b",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "XK"
                },
                "priority": 370,
                "weight": 370,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8763f7d87c5ca91ebb82b8ae86d930c91dd5367d8d902609d613beafedd68ea3",
                "condition": {
                    "country": "YE",
                    "payment_method": "Wallet"
                },
                "priority": 371,
                "weight": 371,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e6fe0c5a2f95762ac140347a02e93a2d6d8ff7af41484dfbaa925ff617b18be3",
                "condition": {
                    "country": "YT",
                    "payment_method": "Wallet"
                },
                "priority": 372,
                "weight": 372,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d413318d77e9dcd98ddafd51ffd2c74286cc524cd92b589bfa22bbe2b4908968",
                "condition": {
                    "payment_method": "Wallet",
                    "country": "ZM"
                },
                "priority": 373,
                "weight": 373,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9a114f568f9c47d3a97829a2f098b543a6d439967843dad501dc03ceb8ee2346",
                "condition": {
                    "country": "ZW",
                    "payment_method": "Wallet"
                },
                "priority": 374,
                "weight": 374,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cbb018b5ac5d14b6225d9a7501464969d374e8ab60ddde23409b101f1ad1a04b",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "AC",
                    "payment_method": "Card"
                },
                "priority": 513,
                "weight": 513,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "50f5ca416e2709bd801971338b82632749dccd107d4e80ffe5a59334f57e6561",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "AC",
                    "payment_method": "Card"
                },
                "priority": 514,
                "weight": 514,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "40ee27460855845c6b66e7287dbe9f50252081dc8ec8f9790be33bd4e273d4fb",
                "condition": {
                    "country": "AD",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 515,
                "weight": 515,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "537ad85107d86c5abecf4daf56502e4d22920462abe1e913ad198f1de553c14a",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "AD"
                },
                "priority": 516,
                "weight": 516,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6a0dfcda5df2c862a6e8cad8ecf4be0630efd8475f84f56bf95ea40c953c44da",
                "condition": {
                    "country": "AE",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 517,
                "weight": 517,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "35a62b8a4e82c6ed056601f6b5bd23f6ff3b95b42c912decb16e3fe6a950a778",
                "condition": {
                    "country": "AE",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 518,
                "weight": 518,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cc012cdf9b626ecc0540a8f9f5b48204bd80cdf8a6c745f130a2df5cf43cac0e",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "AF"
                },
                "priority": 519,
                "weight": 519,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "586bf7974b219edc5c2d45ea1486fe9f681acfdf53b057e3e40e20cd28983ebb",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "AF",
                    "payment_method": "Card"
                },
                "priority": 520,
                "weight": 520,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c2a1410b2b29f37de8e256b550ba5c32e4d53f2500c2e4f649f7ee145675d125",
                "condition": {
                    "country": "AG",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 521,
                "weight": 521,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4f8849c5991016e248b59b26717e1ed5a59460e5b92ce3fd983e1585e9dbcbaf",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "AG"
                },
                "priority": 522,
                "weight": 522,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a34248f8aa9ba4c917e8a2639ab9d6f845126fb545c3e271d0236d4dc348620a",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "AI"
                },
                "priority": 523,
                "weight": 523,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cdeb492df78f2b0749aa2fbc9e552681f8ae3139c3e50cd100bbc6186e138297",
                "condition": {
                    "payment_method": "Card",
                    "country": "AI",
                    "mandate_type": "mandate"
                },
                "priority": 524,
                "weight": 524,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2b4149cb236612bb070300144538cd2ca6840bc3bb49af34c15f6f745b413c86",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "AL"
                },
                "priority": 525,
                "weight": 525,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "faa03c7f9dc316b6d9cef30585557a0cbd343bf4df756d3bd9c3a43d9834ded3",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "AL",
                    "payment_method": "Card"
                },
                "priority": 526,
                "weight": 526,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "473f4267f9fd57f6c950332c759db6bb1e65ef313c0ddb49e23db4545f714df1",
                "condition": {
                    "country": "AM",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 527,
                "weight": 527,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2a16421d17696519ae1248a4d5569c79c7aa8d7178da0d6d50a8159934ad87fa",
                "condition": {
                    "country": "AM",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 528,
                "weight": 528,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0f50ae9d59670df6887dde91d7b5bec5372b2e03018cebe312d51ac644233b66",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "AO"
                },
                "priority": 529,
                "weight": 529,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "82741c97af2a865283cd63e4c63762d003348ccd99f4bc197d75899ad95c094b",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "AO"
                },
                "priority": 530,
                "weight": 530,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6fded00e81478e524bdba72f5839ce8b913183ba6fe7a7904b5f2e0a1fe432a3",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "AQ"
                },
                "priority": 531,
                "weight": 531,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6af1ab30be30267bff8dfd90ed39ccd9c3b1ae6674f9c47741df5314bf2bfc24",
                "condition": {
                    "country": "AQ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 532,
                "weight": 532,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "edbb994f3f721d6302ad0477b8390014da7b19401fcc6af47004b046b6df791d",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "AS",
                    "payment_method": "Card"
                },
                "priority": 533,
                "weight": 533,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e33606f802cfcf4da6a2efc08627e9dd6cc00ab910c6e1f256319c2ed9b3d1c7",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "AS",
                    "payment_method": "Card"
                },
                "priority": 534,
                "weight": 534,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "bce8796f547da0a2002b5305844bc7b61bd36eb15e79e967f7c9852a0260ccdc",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "AT",
                    "payment_method": "Card"
                },
                "priority": 535,
                "weight": 535,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6fe002ea10d128fdde2a84f0456cd44d4e20a2d2c108bf7e5a360518938252ca",
                "condition": {
                    "country": "AT",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 536,
                "weight": 536,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "005326b987c9f5bc67234e27b0b04a05b5da39a73a54210c30b4f61b21bcf344",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "AW"
                },
                "priority": 537,
                "weight": 537,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "60f0b6045bd29122159eff52f9161c5a41fc6647ccb3097773640a494409843f",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "AW",
                    "payment_method": "Card"
                },
                "priority": 538,
                "weight": 538,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "766a2ef2bb0d1d406cc82493237afd42a0ea5c259d4c58d6057bbc50b981fec0",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "AX"
                },
                "priority": 539,
                "weight": 539,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8abe913cbce6e93a12220eb5d5e6374753d89a554c62f43963307e5358f47879",
                "condition": {
                    "country": "AX",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 540,
                "weight": 540,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3cd4a93251965b6f2b9a687e50ac9d7b466b100785b91a7502bdb913c77cefb1",
                "condition": {
                    "payment_method": "Card",
                    "country": "AZ",
                    "mandate_type": "non_mandate"
                },
                "priority": 541,
                "weight": 541,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f37dfdf87307dcb4f6298122dc0bbbfd4d3fa30d2950ca35545e7d02499bb4ab",
                "condition": {
                    "country": "AZ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 542,
                "weight": 542,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "25feb9411af7aa0ed1d5958de8df33dd9529e9732eef39dd4cac1134d4ccaa6c",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "BA"
                },
                "priority": 543,
                "weight": 543,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ae9cb5bf805a42225282f2e083a3c355fac4cb243b330a15abdccf0e63f03c2a",
                "condition": {
                    "country": "BA",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 544,
                "weight": 544,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "88e72100c40c88fbfc5c871153c98a71259fa24a3c6bf89452efa631f49cb852",
                "condition": {
                    "country": "BB",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 545,
                "weight": 545,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d4541ab961f3d26adfdcf91fa23be5693c4194f70259a9de210bd946ff5ca816",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "BB"
                },
                "priority": 546,
                "weight": 546,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9a96422c569723b399317b623b8632bf033f3f2b3246a1a753aec2917cd22716",
                "condition": {
                    "country": "BD",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 547,
                "weight": 547,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ac25608c9e4d999a4db7ee34c0f4d0784c8812e3c3ee2ad991632e0add09caba",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "BD"
                },
                "priority": 548,
                "weight": 548,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "22bc74aef0855f073f4868a418413880b68dfed95d096ed72cc7ec2da7cf4026",
                "condition": {
                    "country": "BE",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 549,
                "weight": 549,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "27c8837d4410d0d4069ee448eaa3115267f1055a4a53209092c7430c76b75909",
                "condition": {
                    "country": "BE",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 550,
                "weight": 550,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cbb575b0d3a83e065d5d0ac2f94519e3a6301cad2e763c2ea9760ca90b7f6b0f",
                "condition": {
                    "country": "BF",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 551,
                "weight": 551,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "525af047741ff6e60851121ab3fdba434058d2bc3bf5e6e34bee60cad8cf197a",
                "condition": {
                    "payment_method": "Card",
                    "country": "BF",
                    "mandate_type": "mandate"
                },
                "priority": 552,
                "weight": 552,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c9a9886b0a49368a255f4bec23ac7ee5044c6ad4ffda43b068ec87424b108bba",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "BG",
                    "payment_method": "Card"
                },
                "priority": 553,
                "weight": 553,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "400b1f698634730ee6c364f137d60cbe487bcb1922d0c068757afbf021127c5f",
                "condition": {
                    "payment_method": "Card",
                    "country": "BG",
                    "mandate_type": "mandate"
                },
                "priority": 554,
                "weight": 554,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3b28c09daf88edac5a5dc606d7c564a5eeae10fe28865877f246ae1af463655c",
                "condition": {
                    "country": "BH",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 555,
                "weight": 555,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1be84d20149f7b439ea5a1c40589c920a2ead0d740d84a446c603b06fdffbc58",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "BH"
                },
                "priority": 556,
                "weight": 556,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fcaaf0ead2d3f37a2b46e0ba0a0041de6047ab03feb1b269aa5670b9483d3481",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "BI"
                },
                "priority": 557,
                "weight": 557,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8768161f051a382608c1a93c85f2629b02b377b1b2dc629b64329b8201ab07e8",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "BI"
                },
                "priority": 558,
                "weight": 558,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "702732b5306a0112ec0b5dd46bbc58fd636923cea9d6d7f981f5181c7f7e624b",
                "condition": {
                    "country": "BJ",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 559,
                "weight": 559,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e165a3d4c16b8202971167c10e68c51b4ad695af9fa23843b543c3678851e91d",
                "condition": {
                    "country": "BJ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 560,
                "weight": 560,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "33a07207f01ea4bfbc378b172ef0dc81c382bb9ae081d3c05b09b1f7598ffdff",
                "condition": {
                    "country": "BL",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 561,
                "weight": 561,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4552d0d29b0fa756abaace250297852af963693ea8c69f408a1bf76ca625c3e1",
                "condition": {
                    "payment_method": "Card",
                    "country": "BL",
                    "mandate_type": "mandate"
                },
                "priority": 562,
                "weight": 562,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b2b0e62f69a0dadf3f0bcf1553a9d90b3fcf7f2f706a23a6d1b9733087cda132",
                "condition": {
                    "payment_method": "Card",
                    "country": "BM",
                    "mandate_type": "non_mandate"
                },
                "priority": 563,
                "weight": 563,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b2bbcc6ebd8d61a4ce53f5960ea35668c73193ae758bb992eea1498e6b0dc325",
                "condition": {
                    "country": "BM",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 564,
                "weight": 564,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ea6f9505c2874e45b38e442cf24a70e2f5dd69011e1fa48c549142af5b940605",
                "condition": {
                    "country": "BN",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 565,
                "weight": 565,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c04a2c2bd0a065835fd1075721e03dc48186037eb4fd84c94533cf1ba56452ab",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "BN"
                },
                "priority": 566,
                "weight": 566,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "038ee4d16513f2bb12f788ab79339745c03bf16450239d258cc2976dbbd3a3f6",
                "condition": {
                    "country": "BO",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 567,
                "weight": 567,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1f067a433b059d146cf0498371bf299112ac696e9955a04d4d67581133637889",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "BO"
                },
                "priority": 568,
                "weight": 568,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6e158fda64f838f69030cf44953b49e81080a0a28eeb26299ea2a3226eb5395a",
                "condition": {
                    "payment_method": "Card",
                    "country": "BQ",
                    "mandate_type": "non_mandate"
                },
                "priority": 569,
                "weight": 569,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3137d1e152b9337ac8cab0bd0f5e15484840b03a80d58d70b39aaef63b1c1593",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "BQ",
                    "payment_method": "Card"
                },
                "priority": 570,
                "weight": 570,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "71e2894c0ed63c269a9ebc71e5f1133df28556c727bb0bc717d91d3f25e932fd",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "BS"
                },
                "priority": 571,
                "weight": 571,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "43831c7017ef6f543946e3803b1e645f624472aee7f3f6b291ce7db02cee9a92",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "BS",
                    "payment_method": "Card"
                },
                "priority": 572,
                "weight": 572,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "025b7ba73a7e784d23ad5d6d2d9a52588144f4afbeac589145bca325079ee55d",
                "condition": {
                    "country": "BT",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 573,
                "weight": 573,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a228647a308fd5cc091c15919def042a856e20781abb2f5401705175facfc01a",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "BT"
                },
                "priority": 574,
                "weight": 574,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "daa1c1c085b529f40757bd1729169e090886473b3604dc9741314bb13e1ee158",
                "condition": {
                    "country": "BV",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 575,
                "weight": 575,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b57c9db62d04f5d5829385dbcb48ebfaec84fe6261d93cf644323a1c2b67b760",
                "condition": {
                    "country": "BV",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 576,
                "weight": 576,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f3659808421ea80100cbb044613bcf7118f189e5f13d575d15ac0c2602bdf1a3",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "BW"
                },
                "priority": 577,
                "weight": 577,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "608ff09241ce7c05c5206f3eea5d0e078e7509fa7138c77f3bae9664f8eb6b42",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "BW",
                    "payment_method": "Card"
                },
                "priority": 578,
                "weight": 578,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8caf62a55df437e41c134ee505f824e690be4337f6c07d4f8592271b9a67085c",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "CC",
                    "payment_method": "Card"
                },
                "priority": 579,
                "weight": 579,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5ef2bbcd75a355283bf68596a6ba657ad65428ac4297e6034aec3b211abc7b73",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "CC"
                },
                "priority": 580,
                "weight": 580,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b8137e72e8baca6a134f303fe34ac3373d1fca15b17cba65383d2bc8903e71e6",
                "condition": {
                    "payment_method": "Card",
                    "country": "CD",
                    "mandate_type": "non_mandate"
                },
                "priority": 581,
                "weight": 581,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "40eb3e7edc574624c938f883beea527c33bd096abb50c525e0b47262ed067658",
                "condition": {
                    "payment_method": "Card",
                    "country": "CD",
                    "mandate_type": "mandate"
                },
                "priority": 582,
                "weight": 582,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "471bccf239209ea4b80e4fb824c6591f79bcb0698fee977972a61f0051d8c283",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "CF"
                },
                "priority": 583,
                "weight": 583,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cd07175379fce4351814f203ff7cdee35ae2cab9775edb4152769f83989dbb19",
                "condition": {
                    "country": "CF",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 584,
                "weight": 584,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "dcf25dcb6a5c3e5183c7a1e5b32025390500c849c2f79e602ebdeba0f6c3df4c",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "CG"
                },
                "priority": 585,
                "weight": 585,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5f31d6fadb861fd5294e9cb4b7529ceb90011b16359b14303babbe4939c81f27",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "CG",
                    "payment_method": "Card"
                },
                "priority": 586,
                "weight": 586,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1f63713a12a5b0fc83dd8a5641a23884df76651fd49e75e74551f3f8f27591ab",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "CH"
                },
                "priority": 587,
                "weight": 587,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "44c6ddb28153950e7bf24f30b993d8db1f89bb021bb469ebc4366f71f15cabf5",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "CH"
                },
                "priority": 588,
                "weight": 588,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c055f5bf59e5ed53629387ad357937feebc8c327118ccec4fe5180f2b3bd128d",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "CI"
                },
                "priority": 589,
                "weight": 589,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "38b87bac6804de5844f280ae9df8ec4f4f5e0bbd5ba27279083de458a2892b6f",
                "condition": {
                    "country": "CI",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 590,
                "weight": 590,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9dcdb07f715a1518a9c903e4c6fa6d805dca72eb86fe9f709fc5198ae9c9fe83",
                "condition": {
                    "country": "CK",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 591,
                "weight": 591,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1d371e2031fc3e2a1273ad22776080485bf12374487f1890d4173f6aff54796a",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "CK",
                    "payment_method": "Card"
                },
                "priority": 592,
                "weight": 592,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "71ade56033a6a785863c4d00832ec0b7e7333df0163972635c01c64672ae9492",
                "condition": {
                    "country": "CM",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 593,
                "weight": 593,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "93ea1ce756dd22ac2bfa54e17023f11aa028eb4dbfee4dc3f476d50f05a5e8ba",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "CM"
                },
                "priority": 594,
                "weight": 594,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2118fd4e7de99b91aa25e7677776a42f33a3ab256771ce40ab1e12a9177eb7cc",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "CR",
                    "payment_method": "Card"
                },
                "priority": 595,
                "weight": 595,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5d47918e47f7f3376cd0912a2970cad1910450010508fe630ccd15ebecfd8de3",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "CR"
                },
                "priority": 596,
                "weight": 596,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5d3e0e102c5c624bf8ed3cfdb1afc2d6302823a9a880f6a302cdef93f881913d",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "CU",
                    "payment_method": "Card"
                },
                "priority": 597,
                "weight": 597,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5e85d9184c3505a48d57023f0141b7bf002ff45a7469babfcd07ee7c1373bc23",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "CU",
                    "payment_method": "Card"
                },
                "priority": 598,
                "weight": 598,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "35c6d23172e6683c2c55faa8a3edf9b8148055418b3a725983dfad4d5b7dbf27",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "CV"
                },
                "priority": 599,
                "weight": 599,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c02dc7884dc26cb2af663af37d3e60f7c67e4dad7d8a7c0c3492cd6dea9c2b73",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "CV"
                },
                "priority": 600,
                "weight": 600,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6a5d7b5c77f2b7bf63b34026078ad1739f04ddd4fa45fcb162054705bde73df4",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "CW",
                    "payment_method": "Card"
                },
                "priority": 601,
                "weight": 601,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "afb27a44e7f35c16f013dce2ef8f1b37bd130bb5023f0395da0cf26c8f2950df",
                "condition": {
                    "payment_method": "Card",
                    "country": "CW",
                    "mandate_type": "mandate"
                },
                "priority": 602,
                "weight": 602,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0450ca3124612f3e35c1ef6e8b6eb7fc734a63912c487e383d8b56b500399f4b",
                "condition": {
                    "country": "CX",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 603,
                "weight": 603,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "28344b9b987636a927f0d9a6d703c05a89125b237b95fed17581c114110127f1",
                "condition": {
                    "payment_method": "Card",
                    "country": "CX",
                    "mandate_type": "mandate"
                },
                "priority": 604,
                "weight": 604,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9e5ece782a37b47438267bb7240a53880eca9f2afdaa5b8110875be6cf65458c",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "CY"
                },
                "priority": 605,
                "weight": 605,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d9587f1446d423e8a45afb7b473535256d901509069db395d473c6a6d19335cf",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "CY"
                },
                "priority": 606,
                "weight": 606,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "58fc1f03cb0686ee35470890d71d764c8c7bea25b81dbcc229a443b4c74eb8f1",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "CZ",
                    "payment_method": "Card"
                },
                "priority": 607,
                "weight": 607,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a8d75ee0f85fa0879a321aa0b01735e5707e53742ac542add2b00285a653deef",
                "condition": {
                    "country": "CZ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 608,
                "weight": 608,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7d616a4e1b41b9e53db9e6c051c585e37fc85fcfac25a46612fe437808496e89",
                "condition": {
                    "country": "DE",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 609,
                "weight": 609,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d166ebf2b28da0b6a58c9af8e6f6b946a680af4a33f3d13dbfc5c6e17e65e54c",
                "condition": {
                    "country": "DE",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 610,
                "weight": 610,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0fc2350c86319d0ad7f7137af5bc38b452b48a9a3d693cfa92c42b85db39965d",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "DJ"
                },
                "priority": 611,
                "weight": 611,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "39da75f82fcba121e9e1f11991908053676f71825eaf5d7663903275969c81e9",
                "condition": {
                    "payment_method": "Card",
                    "country": "DJ",
                    "mandate_type": "mandate"
                },
                "priority": 612,
                "weight": 612,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b16decc7dbd484ce9b2b0202bb7e502825abd6ea4de15763cf02c37d385caade",
                "condition": {
                    "country": "DK",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 613,
                "weight": 613,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2dc056e64a41581d498b6fee7839e57fbf89164abb023c408f09a935b397c82f",
                "condition": {
                    "payment_method": "Card",
                    "country": "DK",
                    "mandate_type": "mandate"
                },
                "priority": 614,
                "weight": 614,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8e028652ab1c893b3a751240a28549d941ea9e83cf6205a9ca0805994a3b90c2",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "DM"
                },
                "priority": 615,
                "weight": 615,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b9602bbb84e53f68d076ecc81c2ec5f0a30a81ec94534e72fcd024bdccf5ae07",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "DM"
                },
                "priority": 616,
                "weight": 616,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ccc741aa82275cda9e14675b057657ef15e8b9e7b02f9f55b9e12de9ac67ca9a",
                "condition": {
                    "country": "DO",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 617,
                "weight": 617,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ad9504768521b39316bda1d85b807be3397a946bf4af2f6dbf4c8bb875283dc0",
                "condition": {
                    "payment_method": "Card",
                    "country": "DO",
                    "mandate_type": "mandate"
                },
                "priority": 618,
                "weight": 618,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a9445385a3851c5d95d596a8cd115eab6f6416da5baeaa6163e29eb4cce73064",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "DZ",
                    "payment_method": "Card"
                },
                "priority": 619,
                "weight": 619,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c65ea4b09027c496df9cd14fe626f6ea3e5e6fef67abf733a20179cf1bd91c4f",
                "condition": {
                    "country": "DZ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 620,
                "weight": 620,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "858b209c097cd8e6d03922fcb4153729922c27d5dcbdabf0029f97f534ae233d",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "EC"
                },
                "priority": 621,
                "weight": 621,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "14eeb3de2a860b4ce90ca52eb095fc49949af415e84cc5995518fe75de92255c",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "EC",
                    "payment_method": "Card"
                },
                "priority": 622,
                "weight": 622,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7199ac6b4007e841533fe751319dcfd19b0fa3392a716d49adb9e7e0525831c4",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "EE",
                    "payment_method": "Card"
                },
                "priority": 623,
                "weight": 623,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7ec5d922b98b44008bb956460229a23851acefb7bc6e49bd2cfe537221df8abd",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "EE"
                },
                "priority": 624,
                "weight": 624,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "30e364df8f30bb6fbc9be5450f64fbdcf192c4e8cb02df1b63002a2b66c74d98",
                "condition": {
                    "country": "EH",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 625,
                "weight": 625,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2607ef390eaab756e93e73b713f4b5f488cb65ad6c38120e73a86d87362e996f",
                "condition": {
                    "payment_method": "Card",
                    "country": "EH",
                    "mandate_type": "mandate"
                },
                "priority": 626,
                "weight": 626,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0463ab61d6336000eb21f03e040365f9719dfa70d311d49ed3c9e3416b49cd08",
                "condition": {
                    "country": "ER",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 627,
                "weight": 627,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9920a452c49a2f961995c01db4b36f1e71cecabecba848877d4923d425e28332",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "ER",
                    "payment_method": "Card"
                },
                "priority": 628,
                "weight": 628,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d80023637f443ca9d48f6c5bbdd2a35eaf091aab6e49aa0e58dab85d932dd1b7",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "ET"
                },
                "priority": 629,
                "weight": 629,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "79ca118b835e4020d7550817c53ce3c125d3580bf91c2f403f0b13f8edaa09ce",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "ET"
                },
                "priority": 630,
                "weight": 630,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e2dc60edad3b1c11a4e954028c57b6a95099ad658915685d07227dfbd105cb4b",
                "condition": {
                    "country": "FI",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 631,
                "weight": 631,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "90524f75fa5e0011ccbbb0c2ef9e5864d833628fa4831791d0e63e9790521518",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "FI",
                    "payment_method": "Card"
                },
                "priority": 632,
                "weight": 632,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5efeaada6f01bd13f930c350670def10e756c2f4db7f2e1db015a91bbf5f883e",
                "condition": {
                    "country": "FJ",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 633,
                "weight": 633,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "711938382e73006886acca8c9eb3d10cc2684a32589953737be6b25c122c894d",
                "condition": {
                    "country": "FJ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 634,
                "weight": 634,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "112799ec266bf8b0ee12618c486c18559afa539966e9a81e314232e2d5e697a7",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "FK"
                },
                "priority": 635,
                "weight": 635,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fb3825b55f42150e5a2e331993c66b448090d33f98e0dbbe0f073d52f68bf414",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "FK"
                },
                "priority": 636,
                "weight": 636,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c3588a87c8afedbe87603b8bb24dfbadceabf7eacbab62a82bc7b7a11c359f49",
                "condition": {
                    "country": "FO",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 637,
                "weight": 637,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4f46b22ebf768eb2721f5eea9d20a0c9cf134fba277dead60d6fdc4d57cde04f",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "FO"
                },
                "priority": 638,
                "weight": 638,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0be050c899a5eae2b2bd0d7905988968f6877e66f8c9330358d7a5766e266863",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "FR",
                    "payment_method": "Card"
                },
                "priority": 639,
                "weight": 639,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "79f077833081f1b971f22d680b67956afa35e01535b7d9732f1d5d65630d117a",
                "condition": {
                    "country": "FR",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 640,
                "weight": 640,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c2db49e85c047f1a95aaed3941d54b9fc2930bcc383a05dc88c595974ae022ec",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "GA",
                    "payment_method": "Card"
                },
                "priority": 641,
                "weight": 641,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7ec2402c362948575dba54ce13cbb7e9600f879ae1aa94a8cea49309319246e9",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "GA"
                },
                "priority": 642,
                "weight": 642,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4000a7923809755c5b5f933b5101f20744fd1cb595ab7d99bd2951b990bbec59",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "GD",
                    "payment_method": "Card"
                },
                "priority": 643,
                "weight": 643,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5336a867f6d7de654e0cb110b7cd54bb30544891f708335f4c8d835fe66133e7",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "GD",
                    "payment_method": "Card"
                },
                "priority": 644,
                "weight": 644,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "48990aca564f035331549d5801af728b979294cb3f10815acb3be23541c5e3e1",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "GE",
                    "payment_method": "Card"
                },
                "priority": 645,
                "weight": 645,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ef520c05281db5615b81b25d5148981bf6f70b7c4d44e8a1fe2f1188230f3abb",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "GE",
                    "payment_method": "Card"
                },
                "priority": 646,
                "weight": 646,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6231f92b654edfc7f4757912232d1172fcf725f82516a76d242553d004a11fbd",
                "condition": {
                    "country": "GF",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 647,
                "weight": 647,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ec3512fa18e93e9d8b8199a6c29d66f9496e8735c69ab53d3a9439af0a34ab97",
                "condition": {
                    "country": "GF",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 648,
                "weight": 648,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3bbead6caeb8407d7ce13459b0489d2c9513b66d185f30aad8d436efddb4988e",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "GG"
                },
                "priority": 649,
                "weight": 649,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c4424f14f99b0a83aeb9a6f4de989734a65882f60152ed5de99bcf7a5b861183",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "GG"
                },
                "priority": 650,
                "weight": 650,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8b82583f93c689712b812cb77021cbe1afe4a83fe2afc48925521e48f52c8959",
                "condition": {
                    "country": "GH",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 651,
                "weight": 651,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8e90091af27b22bb80110f34c61d399469435e2075ba1759b59d29a453b91b4b",
                "condition": {
                    "country": "GH",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 652,
                "weight": 652,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4b970d9d602f30b2d5ff94c58d7a0320e61f4a009ab253ef1bd1aa624ba57718",
                "condition": {
                    "country": "GI",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 653,
                "weight": 653,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "661332d48dd33b616ecd1d95c75ab11ddf29518857e2026fd60eac16f4fe6ffb",
                "condition": {
                    "country": "GI",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 654,
                "weight": 654,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "50b069bbf5a6ef4b8b0686ca38f03af5ef83b2fe5ff0d542909be50e92ee43e6",
                "condition": {
                    "country": "GL",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 655,
                "weight": 655,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "64449da9df868f08393245aeaf9a5b4cc30ee3e015c383ca280fc079406818fd",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "GL"
                },
                "priority": 656,
                "weight": 656,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cd114658b46cccdfcc5ea800a353f4a9afe122da1a72497dcf5b5a0843961695",
                "condition": {
                    "country": "GM",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 657,
                "weight": 657,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f26c5e335351d5723218478618cacd33602bbd71bfd6717a2b6694fe26268e89",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "GM"
                },
                "priority": 658,
                "weight": 658,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5f4e295193bd6ee54936fddda7c0b077ab5f17351184ae43b163e928e7a68cbe",
                "condition": {
                    "country": "GP",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 659,
                "weight": 659,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "26f7d07b1fb93a8fcf71db731f764fe4354edbcc0aeff2893f4ca2e65e3972d6",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "GP",
                    "payment_method": "Card"
                },
                "priority": 660,
                "weight": 660,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "aab69d87bce5b31057576d32e16c2659ff8916834c6cd103db02bf1c534baf2b",
                "condition": {
                    "payment_method": "Card",
                    "country": "GQ",
                    "mandate_type": "non_mandate"
                },
                "priority": 661,
                "weight": 661,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "11d5f0ee2ae084454ccf529537c564ac9cc0737b91b4b10b49060c01e9221811",
                "condition": {
                    "country": "GQ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 662,
                "weight": 662,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9e0375d0d8d6745208a5e52b6ce307e5361224ff80c489f00d608ccdb484ffc2",
                "condition": {
                    "country": "GR",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 663,
                "weight": 663,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "47c16bc427594eaecdd78a406fe5d43be4ac4ad9909e57282a46b30276029ebf",
                "condition": {
                    "country": "GR",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 664,
                "weight": 664,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9e30e8006521a3b0badec1248f09f207a4e5c42d1e92628c4f5563c651ebfd35",
                "condition": {
                    "country": "GS",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 665,
                "weight": 665,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8d34d00bc78abbd7d9960e2d6bd232a97e7415eee6dcbef418fdfebc77e62d03",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "GS",
                    "payment_method": "Card"
                },
                "priority": 666,
                "weight": 666,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ec1b7147070196f3927f07e2965a0c26b802b8e3952b76046f42ee38320b6659",
                "condition": {
                    "country": "GT",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 667,
                "weight": 667,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3c32e31925a1a49049ebd1df38e15c6521acc96623b9efa7edbe79f6f598fe6e",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "GT",
                    "payment_method": "Card"
                },
                "priority": 668,
                "weight": 668,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "260636a27d974651b40f8ec8d2122e7feb1516282de124191f547ccd62f90841",
                "condition": {
                    "country": "GU",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 669,
                "weight": 669,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d37b2a32af68dc4dbd8e96b9332819a2fb177202c750dafebd4c27b59934dc0a",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "GU",
                    "payment_method": "Card"
                },
                "priority": 670,
                "weight": 670,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f7e12bd57465253ca609d89c06e8946a1cea05a77c4d83b6e7e070dbfcbf5a8e",
                "condition": {
                    "country": "GW",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 671,
                "weight": 671,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6b4a1eb9ed6a424e0d249dc81e7362b0a189e38d49df33b1ed5f658fbf19236f",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "GW"
                },
                "priority": 672,
                "weight": 672,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "bef8372ae5b8fb1bbf8b1d1e6647c2be5256cde52f44583cfe05453ed3ffa301",
                "condition": {
                    "payment_method": "Card",
                    "country": "GY",
                    "mandate_type": "non_mandate"
                },
                "priority": 673,
                "weight": 673,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "bc2c2c82d4fd82e2754df190907ee2332756e4d6ad399ded12d38df0967c3a47",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "GY"
                },
                "priority": 674,
                "weight": 674,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "985b5a3dfcfe0e0000f51b0433ec2670ac5ab01f5c64d830215164f97d575900",
                "condition": {
                    "country": "HM",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 675,
                "weight": 675,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e9bee576f0edb3de30156bb551b2547bc2800b7ca0b1295655c0d38c7852d21e",
                "condition": {
                    "country": "HM",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 676,
                "weight": 676,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "564d2bcc8b9a8923a3e703be8424ce88c471596770ee52604fe184194cf34624",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "HR"
                },
                "priority": 677,
                "weight": 677,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8ce4b3440faf4567496ed8e73e42763c63fc0396a6b2c5e87eb11413fff9f3be",
                "condition": {
                    "payment_method": "Card",
                    "country": "HR",
                    "mandate_type": "mandate"
                },
                "priority": 678,
                "weight": 678,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e3057afd15b383c17774c19518f73d3c5e9fbf651c4db9f11456f58c4b4faca1",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "HT"
                },
                "priority": 679,
                "weight": 679,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "785212b8de6ff59abf765b34ebf7ebe7adef385be1acd1c347d2694c637705ef",
                "condition": {
                    "payment_method": "Card",
                    "country": "HT",
                    "mandate_type": "mandate"
                },
                "priority": 680,
                "weight": 680,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "71bbec8b6bae897b7b5de90cb4b2607a1b5f5867ac2fef4f2ba9e57b3745c971",
                "condition": {
                    "country": "HU",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 681,
                "weight": 681,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a2293fd0477c4c905653f7648236ceffc24de8c6d8cc41454684109aad96aefc",
                "condition": {
                    "payment_method": "Card",
                    "country": "HU",
                    "mandate_type": "mandate"
                },
                "priority": 682,
                "weight": 682,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1c72181a06b7814d3c750a2e87a33e5709a47b976c537cb08b521a1a3e6c4092",
                "condition": {
                    "country": "IE",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 683,
                "weight": 683,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0d76ec72442181af9c82b324a146439acf3e7a68d1d58d7d2454a451a0c3870d",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "IE"
                },
                "priority": 684,
                "weight": 684,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "58ce649819bc3a06c94cb80ffce967d8334c4034cd256f7a575ac36310c94248",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "IL"
                },
                "priority": 685,
                "weight": 685,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0a55522e918910174872ca793eee74e6c29e32ca65c4400bb956860f7d67e3c7",
                "condition": {
                    "country": "IL",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 686,
                "weight": 686,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b9e070a13b0c6ccde737ac2b09bd1156d46b31ef46cfe43083425d3eee7f329c",
                "condition": {
                    "country": "IM",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 687,
                "weight": 687,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8792dd6fbcda703cab1b9f8006ac77921b73967934878c7294be71da6e251aa9",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "IM"
                },
                "priority": 688,
                "weight": 688,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "db9973aa27b54a180fa542cf034eb631e6651cdd125859ae0c539d1cb1f33068",
                "condition": {
                    "payment_method": "Card",
                    "country": "IO",
                    "mandate_type": "non_mandate"
                },
                "priority": 689,
                "weight": 689,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "36753ed170068be275c3541f3db9a00bbde52156152a7739bc9e26ee8673f22d",
                "condition": {
                    "country": "IO",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 690,
                "weight": 690,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a234bda307b56266dac3bea077a38f6ccc6cf206720fb8b8c1fcd3b667e947c1",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "IQ"
                },
                "priority": 691,
                "weight": 691,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8e75e78b849ec1c9b3d02108c36a98b049d51778542b1d547dc7701f73ffddf9",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "IQ"
                },
                "priority": 692,
                "weight": 692,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "95d7992af4ba2307e97c63b109275d6924f959d5aab523cb3cdbd04570e39972",
                "condition": {
                    "country": "IR",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 693,
                "weight": 693,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8a5f5b2587d91c60dfa5da505747eb70b8c3549b9b0e3f771526311f35bc5d64",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "IR"
                },
                "priority": 694,
                "weight": 694,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "48d2850b8cb28ec02f4bf647759523a9ee6db58b37358bc359edce1200d52e11",
                "condition": {
                    "country": "IS",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 695,
                "weight": 695,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "922eff9ee12358b9dfbef719ad7093c21da47388099ce76a7f3c8d3ebd6b5c5d",
                "condition": {
                    "country": "IS",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 696,
                "weight": 696,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a8666280444368c2dba132819703feaee60c9e72a703fa59f67124205e6bc4b9",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "JE"
                },
                "priority": 697,
                "weight": 697,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3f0b50124141b415ef02dae316ef4e3d1f7aa67fae64fa1948f55e996f44ce89",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "JE",
                    "payment_method": "Card"
                },
                "priority": 698,
                "weight": 698,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "71c0f289721b32308e2f7fee03bca855de176da90018f2c818b57922ee3b5213",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "JM",
                    "payment_method": "Card"
                },
                "priority": 699,
                "weight": 699,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "bed848dfb85d3af9f16eb8e41d2cc339fead8a83ceb1e4e88fd08b322f4dd08d",
                "condition": {
                    "country": "JM",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 700,
                "weight": 700,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "222b1d17897a2a9d00802a5d137706377724450fe489de9b908af949a7dedaf3",
                "condition": {
                    "country": "JO",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 701,
                "weight": 701,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "44f095a0a48dcadc882e171508618b1aa78a49114851d6b86350d23833ca7cf7",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "JO"
                },
                "priority": 702,
                "weight": 702,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cd7214d02d292c9739da5fa1431c2ca340efd4dd5280f391366d64b9c7f65323",
                "condition": {
                    "country": "KE",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 703,
                "weight": 703,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "dade9a75ad8df89340f8e5cc0315791732a37d9de7d1c4f92d6f92bb7f0dbb44",
                "condition": {
                    "country": "KE",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 704,
                "weight": 704,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9debb19c6d846634f812441df99b10da74cd79b4e4b54b51a2d5a5cc23014b81",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "KG"
                },
                "priority": 705,
                "weight": 705,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b45cadc5de8c6563f8f646e4808b45e37269ccc6f6a8fb0a9b1f8c95177a8767",
                "condition": {
                    "country": "KG",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 706,
                "weight": 706,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "00df59ed57be356d0699667d19ecb30e4ce68679ffc42b35f6fbc5c99e48e5bb",
                "condition": {
                    "payment_method": "Card",
                    "country": "KH",
                    "mandate_type": "non_mandate"
                },
                "priority": 707,
                "weight": 707,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "049bb014ccbcc607414843e84501f86886a9d0cef4a4e32705d3567af5725f34",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "KH",
                    "payment_method": "Card"
                },
                "priority": 708,
                "weight": 708,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f5863d0884be31764070519d6dd2ade6fe7adc26d1b377898f3692fd03df715c",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "KI",
                    "payment_method": "Card"
                },
                "priority": 709,
                "weight": 709,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "548b057956fee833b33f33181defdf7db24916899f9879da76fa4d395a019f60",
                "condition": {
                    "country": "KI",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 710,
                "weight": 710,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b047d40a7adce61936437ed56154a1f2340b27ee32ec3717c6d0e495b8c1bb0c",
                "condition": {
                    "country": "KM",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 711,
                "weight": 711,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d7265c109569d00c181b78af61d2a2c40ca7b4cd51bfed4730a159f90cda884a",
                "condition": {
                    "country": "KM",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 712,
                "weight": 712,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7589a36c8cf03a0dda52b160d91b653cfb3acc8c354bf34e7ed4d36fed1c8056",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "KN"
                },
                "priority": 713,
                "weight": 713,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3a7364965f0290ed089f528454208aa883dd921cca7d5c6e05bf74ec91e9813f",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "KN"
                },
                "priority": 714,
                "weight": 714,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ba4c37adb553890608ad80d14986d55d0c5831c25228ad6fa156c160be190ac4",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "KY"
                },
                "priority": 715,
                "weight": 715,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4935f214abccc41dfc036303ffcc47bcd8d9db61d6ccfe3f1a24c3dd185c5347",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "KY"
                },
                "priority": 716,
                "weight": 716,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9ce35cf43c18ef78f96943cebfadd9b3501d79158f241a7fbcdfdd98619efb37",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "LA"
                },
                "priority": 717,
                "weight": 717,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ddc60ff7efacc488cabb5a45f439f74ed7e814a3e5ffc32ff244e886ddfd2d0c",
                "condition": {
                    "country": "LA",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 718,
                "weight": 718,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "86857229d191304ead50bb3ef460fb748539b3c15b840cb8c7bbec3547fdc0f2",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "LB"
                },
                "priority": 719,
                "weight": 719,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cca6126c94e48d3820ae3acde9b904aa3b24ce5466f6bcd085d168901aa4e740",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "LB",
                    "payment_method": "Card"
                },
                "priority": 720,
                "weight": 720,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "20f602918225d02bcd21a027da0f27566d1b90c558e36badcd8434d3e818895f",
                "condition": {
                    "country": "LC",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 721,
                "weight": 721,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4fa6e8301d4c47aef73b29a022be601b9c60aa4ece3be89ec0473def18441a73",
                "condition": {
                    "country": "LC",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 722,
                "weight": 722,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "dda228cb11ca40805771fb715e9ae15bff5b13ddd7ca1f183885a698275b1153",
                "condition": {
                    "country": "LI",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 723,
                "weight": 723,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6fd8ed8b332f0a47f12f0f66de803d1746187d20bb019f243f128cb86f724d80",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "LI",
                    "payment_method": "Card"
                },
                "priority": 724,
                "weight": 724,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f35faf022969ec5ec1459256cbb30b632914481b6e631e2c92e8ccb1d7c15a67",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "LK",
                    "payment_method": "Card"
                },
                "priority": 725,
                "weight": 725,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8ef8d1e5df896f20b9c43abc60da1066328675d98e722b212f9cac2e973e5a6e",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "LK"
                },
                "priority": 726,
                "weight": 726,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6f35dc0e9900d6486947c1b464d0d62d0c2eb077e3dd566be9e6b1378c017b9f",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "LR"
                },
                "priority": 727,
                "weight": 727,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8494e88c99e32e8987344c1d6bfcedad36ca6a3d8a2bb5161e90ee14117d3eaa",
                "condition": {
                    "country": "LR",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 728,
                "weight": 728,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9857f97618f0f047b02d57641782bc1bb87a9fb5fb1dbecd56e13dc3119aa502",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "LS",
                    "payment_method": "Card"
                },
                "priority": 729,
                "weight": 729,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "79a38d49e5cc9a02662aa0e95c2d789e5b42b90d3a824c537e610c62c8ca8d6c",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "LS"
                },
                "priority": 730,
                "weight": 730,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d76d87f648b8e32d5a557ee1e4d01032d8cc16817bac3176d0d157f0bcc48297",
                "condition": {
                    "payment_method": "Card",
                    "country": "LT",
                    "mandate_type": "non_mandate"
                },
                "priority": 731,
                "weight": 731,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b3843ae2ddf0a0bc27c3c130bc5754ce09a70ce04b7167fad38b0e61a28c2c82",
                "condition": {
                    "country": "LT",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 732,
                "weight": 732,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "39707e745698bebd5aaef8a80932a27843c4ab27436bee7dee45537a2df4609a",
                "condition": {
                    "country": "LU",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 733,
                "weight": 733,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "49c9e3687c18a79a7a4ed588e04bd53c06b8b8865b4982800841b81b2aedf96e",
                "condition": {
                    "payment_method": "Card",
                    "country": "LU",
                    "mandate_type": "mandate"
                },
                "priority": 734,
                "weight": 734,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8e40b215fc59ee4b2f0801e10067a629a94b84075b7134f77d71d8ca46485c5a",
                "condition": {
                    "payment_method": "Card",
                    "country": "LV",
                    "mandate_type": "non_mandate"
                },
                "priority": 735,
                "weight": 735,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "79961aca1264328ad19e4fff9faebd68d4d1eb6983fff2dfbc522706776add77",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "LV"
                },
                "priority": 736,
                "weight": 736,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9e6239a0b6a361e813320b26e3abe072fe5c61884a081071e61155edeeabeccb",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "LY"
                },
                "priority": 737,
                "weight": 737,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "90dda97d0c6f338fba386fd36d5b19db97e9a05eec6a352e6207b9940af6ffca",
                "condition": {
                    "payment_method": "Card",
                    "country": "LY",
                    "mandate_type": "mandate"
                },
                "priority": 738,
                "weight": 738,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "55493093661ee57407a7d64b29bbdfe1eb3c4d8e99e358179637983631c81a16",
                "condition": {
                    "payment_method": "Card",
                    "country": "MA",
                    "mandate_type": "non_mandate"
                },
                "priority": 739,
                "weight": 739,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "aee1f87e473e35e9c30a3d2ebe1d1a22158f9264018557893bf1753e804b6139",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "MA",
                    "payment_method": "Card"
                },
                "priority": 740,
                "weight": 740,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "71b263858aaaebf51d81d3a983218ffba612f172b38b9dca51e82b67ecb3f4ca",
                "condition": {
                    "country": "MC",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 741,
                "weight": 741,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "83390b63c64472126438471491d5150e811b175905f6c16f42ec54bb2bb74501",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "MC"
                },
                "priority": 742,
                "weight": 742,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a59bb98bcb4e86893ea33717d49fe6ff164a56b490dd19ca4c4e21cd0f9df518",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "MD"
                },
                "priority": 743,
                "weight": 743,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "66b42bf040a4a9405543f0feed8d517c2f1cb43a3e878c6d90530b9279649945",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "MD"
                },
                "priority": 744,
                "weight": 744,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "86271e5c92bcf709702decc3be3349c1cfedc97ea557a7e633297bf59c2a57d9",
                "condition": {
                    "payment_method": "Card",
                    "country": "ME",
                    "mandate_type": "non_mandate"
                },
                "priority": 745,
                "weight": 745,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d73d5d06660ff888e8c8fc2232d59796c866d76d7ef70559f40c087e9bcdc4b0",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "ME",
                    "payment_method": "Card"
                },
                "priority": 746,
                "weight": 746,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "10b40910817697d47a8a1d05c523240f5e9e7b07c721de5a70b10ad02cc7db53",
                "condition": {
                    "payment_method": "Card",
                    "country": "MF",
                    "mandate_type": "non_mandate"
                },
                "priority": 747,
                "weight": 747,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "776870b0a635f1ff04e75f5a43412d67c266982268f1467fb50c4b805217e3ff",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "MF"
                },
                "priority": 748,
                "weight": 748,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9f14660a842382a127073f3024a2442a1aa80eaa747acdbb06e765ef0d7ac900",
                "condition": {
                    "payment_method": "Card",
                    "country": "MG",
                    "mandate_type": "non_mandate"
                },
                "priority": 749,
                "weight": 749,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2cc7f3c972ba63b6750c438149ee17747e3a14b2880d609acd6b562f022b4391",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "MG"
                },
                "priority": 750,
                "weight": 750,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1a8166128a90773b2b1bd43d2a5f7f55645ace6b6cf4dda07ed41a8473c52fc8",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "MH",
                    "payment_method": "Card"
                },
                "priority": 751,
                "weight": 751,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7dc52bebcd84583f2358432f9ee59a2c82523143e10814e916bf1c2934f4a60f",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "MH",
                    "payment_method": "Card"
                },
                "priority": 752,
                "weight": 752,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8c44bdb1f2ae7f650bc3b2b22b4fe6901b3fd715bb24b5c558c50e82d98c6c94",
                "condition": {
                    "payment_method": "Card",
                    "country": "MK",
                    "mandate_type": "non_mandate"
                },
                "priority": 753,
                "weight": 753,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4bd820200278c4ba32050b76a2fce4d5f8284fa9a4cdcf008217ba7d36676202",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "MK",
                    "payment_method": "Card"
                },
                "priority": 754,
                "weight": 754,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4e606c000c502a417c4866dbc591192fad32b948ac81ef53f8a965042cf3556e",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "ML",
                    "payment_method": "Card"
                },
                "priority": 755,
                "weight": 755,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "55df93b49e3a930cdfae194ac77d660a72e29c21905e76fb91f1135055c06f64",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "ML",
                    "payment_method": "Card"
                },
                "priority": 756,
                "weight": 756,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1df465658a028a65a7834bd9a6d4e7181b8772d81771d6c65b29669f7947aff9",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "MM",
                    "payment_method": "Card"
                },
                "priority": 757,
                "weight": 757,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d15fd93f3dd135b490dcf3724d90664646c9a24a69f1a0ed50dff03264bb94a7",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "MM"
                },
                "priority": 758,
                "weight": 758,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "faae8e13f76f0b8caaef6409b4b7fe9ba7f4e64392c83575628cba79ced190e5",
                "condition": {
                    "country": "MN",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 759,
                "weight": 759,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4e41adcaffbcce6123a9ab5e1975245f895f39d8f1c825af5ae15a9052940d6f",
                "condition": {
                    "country": "MN",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 760,
                "weight": 760,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4550f2f81f8196672eb618815403a5146d2737442f6aa4c4fb75e4a22bff65b6",
                "condition": {
                    "country": "MO",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 761,
                "weight": 761,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6d3b475e3b180679611f256a668827d382becc4e4d3f8747eb865f014be4cece",
                "condition": {
                    "country": "MO",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 762,
                "weight": 762,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b1054518a480b09cc70c3779a013450733365501506808213832ab0c360d7408",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "MP"
                },
                "priority": 763,
                "weight": 763,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4b74a78a5fc217ac4aaa38bcd748261240cc35392ab9acab74271883f1b22d7e",
                "condition": {
                    "payment_method": "Card",
                    "country": "MP",
                    "mandate_type": "mandate"
                },
                "priority": 764,
                "weight": 764,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "eb2c04fb3b721e08025dead314f96bbc8b5e70676c7dbf2dfdfae48c36b53904",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "MQ",
                    "payment_method": "Card"
                },
                "priority": 765,
                "weight": 765,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c938d69bd7c552469b96245a978780196cbc712d8d9e06d445eccc7c043a1ebd",
                "condition": {
                    "country": "MQ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 766,
                "weight": 766,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b886f7ec053d261508e43c7d8650b72c1e5d16a4603741bbd62320dd2499fe45",
                "condition": {
                    "payment_method": "Card",
                    "country": "MR",
                    "mandate_type": "non_mandate"
                },
                "priority": 767,
                "weight": 767,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b102f7813cdd08c285455df2679072d2693d4e90cfd9cce0ad8e9adc6f3b17ba",
                "condition": {
                    "country": "MR",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 768,
                "weight": 768,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7dd0ce81d218006fa223da679f30f8cf7f71b2c83261c6e8cfdc1bd2824cc331",
                "condition": {
                    "country": "MS",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 769,
                "weight": 769,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3377a84fec1c6ee0db13e06b2e40ae81829ee234da54138f23fd2b3726378704",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "MS",
                    "payment_method": "Card"
                },
                "priority": 770,
                "weight": 770,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c28a7057d9bae473edd3588b95e98355ec45d4baef4c39c633a3e6850663d756",
                "condition": {
                    "country": "MT",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 771,
                "weight": 771,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6e308d474dd747d606b0751b01824cccf3a72df8691fc3e9b42075afb97e73a0",
                "condition": {
                    "country": "MT",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 772,
                "weight": 772,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "736dce3cc9b2854609046d046e2284d4ce243595807f892473f12559197ac6d0",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "MU",
                    "payment_method": "Card"
                },
                "priority": 773,
                "weight": 773,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b4b5ac3b9cba0757d082ea99a56bc0e1745578e7777d3ad0d730813320faabf7",
                "condition": {
                    "country": "MU",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 774,
                "weight": 774,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "dfad21cf4dd24f43e55bd98caef31ee55fe4489f8b90a3b028910de4ab58e928",
                "condition": {
                    "country": "MV",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 775,
                "weight": 775,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "be1144d31475dc4ddc85fd5b04a338faa500494cdbb47e3f50915fbad49101ce",
                "condition": {
                    "country": "MV",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 776,
                "weight": 776,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e1b0b3ab217e464cf3097a8ce867123be671f8581f82429bc0cc58228066a88e",
                "condition": {
                    "country": "MW",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 777,
                "weight": 777,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c39c5bf6237d9d424441bacaca328e1f40ad61a08b05dd1471222fb58cb0cf8e",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "MW"
                },
                "priority": 778,
                "weight": 778,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e9fbe6adbee5376c3979aa8d28b338ce53c842b627b1f2d27902b3493674028e",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "NA",
                    "payment_method": "Card"
                },
                "priority": 779,
                "weight": 779,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5fdc73abad7a84221363477361805ea1d7abc0b08042179a416c52860cd571ec",
                "condition": {
                    "country": "NA",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 780,
                "weight": 780,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "353a0395bf00013903accaacbf639459dd31c70d20872e176a2a955eec7dc84c",
                "condition": {
                    "country": "NC",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 781,
                "weight": 781,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0f90cdcebcb502cbda67488e37689ab137c3946bc3795d9c5a90755271a98425",
                "condition": {
                    "country": "NC",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 782,
                "weight": 782,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4894406ca04e28b3069fee3dc8ae7a81b1fec9e9c5765b5122f36953d09d6e1c",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "NE"
                },
                "priority": 783,
                "weight": 783,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "4dc6a9f71caabf972ea9b5fc1b16cb0ac985f042c4f661b8568f0f3f0fc51823",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "NE"
                },
                "priority": 784,
                "weight": 784,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "75a14eee8e49d2bd25d6c3ed21f91708e1fbad54b071caf954db51645633c6f1",
                "condition": {
                    "payment_method": "Card",
                    "country": "NF",
                    "mandate_type": "non_mandate"
                },
                "priority": 785,
                "weight": 785,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "90dab5af717de8cb1fb9b2f42ee68bf6f0eb5fe08813754d7554afaa32270b2f",
                "condition": {
                    "country": "NF",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 786,
                "weight": 786,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6700f3a7d04f5da0e3afa870555a5cc7b499b26b866b64309451dc9ee7a30398",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "NI",
                    "payment_method": "Card"
                },
                "priority": 787,
                "weight": 787,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2164d00ea77dd8721f725c16cd0098cc61d9d121ac54716408c2c787a819699c",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "NI"
                },
                "priority": 788,
                "weight": 788,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7a5e4b076e47b944aca65c65a70a0a471d46676e0e69aef3ea69110c3702cc01",
                "condition": {
                    "payment_method": "Card",
                    "country": "NL",
                    "mandate_type": "non_mandate"
                },
                "priority": 789,
                "weight": 789,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cfa755d78ebf1e803ac13edb222646d3c3b41f3d192599c49323c04921ab5103",
                "condition": {
                    "country": "NL",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 790,
                "weight": 790,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "22c59e1284495f870d126edcca0e2798643d329a9da694a755271c2fba3a427b",
                "condition": {
                    "country": "NO",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 791,
                "weight": 791,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d53f6a3d7ec988868443aaac514434c42ffeba4bde4e9a414bcaffdc5c2fc256",
                "condition": {
                    "country": "NO",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 792,
                "weight": 792,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6f9be8fd46163665b44a8c449740532be0c65783e3e70ad31c08daa6cab4ce4c",
                "condition": {
                    "payment_method": "Card",
                    "country": "NP",
                    "mandate_type": "non_mandate"
                },
                "priority": 793,
                "weight": 793,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c1d6047dc1de82d6e78a0d33a4e29e06b9fbbcadf3177649f7ff61e14c9b1caf",
                "condition": {
                    "country": "NP",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 794,
                "weight": 794,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c4acc2bc5313d6d9258b4bf43bb8c0b1147ed27b9df30f4479f1209ccd6b5007",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "NR"
                },
                "priority": 795,
                "weight": 795,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "545faad4f1a0443c263d7422f16b2256d7c6e63921260d94dd0a3b0108077a84",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "NR",
                    "payment_method": "Card"
                },
                "priority": 796,
                "weight": 796,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ec22053d312b5066c51856474833df00f12a885422f6ac7967beb4dd7998dbc6",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "NU"
                },
                "priority": 797,
                "weight": 797,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "eb1dc0a409e533504aa1c361aa9859677bae758ab7112f170c2d0c6f8f62b4e7",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "NU"
                },
                "priority": 798,
                "weight": 798,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "50cd5cc56732b6a32a1fe2863b64e2b4e361816773bf7d2b8065e9ae9dda0307",
                "condition": {
                    "country": "NZ",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 799,
                "weight": 799,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "659f312d133dbe5c5523767b153558c7f562c72aa35789997d07f736885e6cde",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "NZ",
                    "payment_method": "Card"
                },
                "priority": 800,
                "weight": 800,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f881a7f19d4c66e255b9d831dd8e16476f56774595a0e24b8664c979099c252a",
                "condition": {
                    "payment_method": "Card",
                    "country": "PE",
                    "mandate_type": "non_mandate"
                },
                "priority": 801,
                "weight": 801,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e71bce2934be801b3216ec7a6cb71d35467cf0fb6206e931a6c16eddecd17970",
                "condition": {
                    "country": "PE",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 802,
                "weight": 802,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "190ab2c76133b1c700b4ef9e3a33cdc8c8cec5a0df6fdfbfd3dcc30bbd40b221",
                "condition": {
                    "country": "PF",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 803,
                "weight": 803,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "472d49c5f33aff336b085555cbfbb1c0a4018005032005dfb59f149dce6a74f3",
                "condition": {
                    "country": "PF",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 804,
                "weight": 804,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "db079b94b95040843b5cabf38881154344a76b545932a0c05e4ec7bb692e6937",
                "condition": {
                    "country": "PH",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 805,
                "weight": 805,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f89c2881f84c53f7165615ae0f88ae773ab61e5293756561d5c82c1f1f95b199",
                "condition": {
                    "country": "PH",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 806,
                "weight": 806,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c493d7407d4c59b9ac23d1009f2662a9c4e5f42073316fc7e407d79c580d6813",
                "condition": {
                    "country": "PK",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 807,
                "weight": 807,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3667d988e7b1184a797c65c0b0d898ef01fdc3cbcb1730154d3b1869a2403d6d",
                "condition": {
                    "country": "PK",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 808,
                "weight": 808,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b33b9e698983958d93fdbfd544b63432c0fbd8cccabb2131747143fa846c267e",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "PL",
                    "payment_method": "Card"
                },
                "priority": 809,
                "weight": 809,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "10561d77ef695d890cf88cee017993bc51964b24459fc0e8c28acb3369fab734",
                "condition": {
                    "country": "PL",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 810,
                "weight": 810,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2fde8973b20859f5959fc0cecc5b1bf72fffa70b4cf1dc9f4e556f407658f397",
                "condition": {
                    "country": "PM",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 811,
                "weight": 811,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e35bdd0d2112d358369be12bd283b1c242f085a50f08daa3ab05f93d7522b458",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "PM"
                },
                "priority": 812,
                "weight": 812,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3658da8466ef656c03ecca1e3802c35a6d00b1c07bea064d8d70e0b5a4b9ecba",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "PN",
                    "payment_method": "Card"
                },
                "priority": 813,
                "weight": 813,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e82bfece2de564471ad5f88e82aff14a5dd0558b1f3f8aaee8f10b88c1fc9fbe",
                "condition": {
                    "country": "PN",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 814,
                "weight": 814,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0e410517c094ac0a9427d349a2886948bd33f3ed18a16c17349502395659ff8a",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "PS",
                    "payment_method": "Card"
                },
                "priority": 815,
                "weight": 815,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f27591e08d732168b5a1c5f25f6482741daf447046b9e3649557036a56e957cf",
                "condition": {
                    "country": "PS",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 816,
                "weight": 816,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8fec2f1009973afedf1b8b965daf912afd063f56d2b9a97684d3161f2c2fdd4a",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "PT"
                },
                "priority": 817,
                "weight": 817,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b4871cb9d463035b331a1fb946b7d650956830d5d9e87a34fa4278eebce17303",
                "condition": {
                    "country": "PT",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 818,
                "weight": 818,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "24b94415a1bfb8f0f71d801f3d439b28ca42b9850ed2dc9774e83cc9270fde1f",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "PY"
                },
                "priority": 819,
                "weight": 819,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1dac7982369036706e107b14e00de4f4374987f78f1c1e960e648f782636754a",
                "condition": {
                    "country": "PY",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 820,
                "weight": 820,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fbe3d65fecb75a71e5d5576a4118b08d26988cf4cbdb848e6fe212bc6bf9c47b",
                "condition": {
                    "country": "QA",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 821,
                "weight": 821,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a32e2d0a683f038fafc619022f9fea1f38650be77dd60d3b53b441cb7caf0ff6",
                "condition": {
                    "country": "QA",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 822,
                "weight": 822,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3e3f517c04bdab676c239481eeec0235f8b51d2df6a1c270d232f3b76b1dda0f",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "RE"
                },
                "priority": 823,
                "weight": 823,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ee7a299dd7a2ceedf22e0e9a13aa7ef49e1757c264e226591d4bc0d5704ba392",
                "condition": {
                    "country": "RE",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 824,
                "weight": 824,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "05cd955d90e3aa5d0e2ae4e486bf318302148dbcf6ac1cb080ec507b05e18438",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "RO",
                    "payment_method": "Card"
                },
                "priority": 825,
                "weight": 825,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2eccb6b0d11f322e8ed68f390442624021038970de3b2aa0a61b9f3386439234",
                "condition": {
                    "payment_method": "Card",
                    "country": "RO",
                    "mandate_type": "mandate"
                },
                "priority": 826,
                "weight": 826,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9de6ef54ce029faf1b7dff204ba84da68f8fe434269cf2dce63a11da1c2d22d0",
                "condition": {
                    "country": "RS",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 827,
                "weight": 827,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "96ac79b806aff1daf6e69d743eb3c5c0d9c5d8d73f21e02e701aca769a108eb2",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "RS",
                    "payment_method": "Card"
                },
                "priority": 828,
                "weight": 828,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8e97962a6d361e1d4ed18f5408ce9f4b9e961bc635e2e3d000a1e579ad6a8e2b",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "RW"
                },
                "priority": 829,
                "weight": 829,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7cd4d9f5f1a185ff11a80421198f6570079a8f2afa6f94d01d18b113982d1dd4",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "RW",
                    "payment_method": "Card"
                },
                "priority": 830,
                "weight": 830,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8cba0d7653427ce03ed5f0819064bcf8552f318c89555588c7413519682af9b5",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "SA"
                },
                "priority": 831,
                "weight": 831,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "58f13f6bbb392d730d72c1c3e48fae2ddddfb237a21f4418ba64556d71f00b99",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "SA",
                    "payment_method": "Card"
                },
                "priority": 832,
                "weight": 832,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0c4e0548801aa9eccb293c34824de2c92cbbf110c955617fc1a8f3cd33e1d996",
                "condition": {
                    "payment_method": "Card",
                    "country": "SB",
                    "mandate_type": "non_mandate"
                },
                "priority": 833,
                "weight": 833,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "55639f1b83c7602c5aa6d40d5e9ac4a4ab1aa043ee3e2f4855b2e3552d27bd58",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "SB"
                },
                "priority": 834,
                "weight": 834,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "93ae710e4679981d7cf7f70be72b755c1b1ec167865b67021b78bd48e7aa8982",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "SC"
                },
                "priority": 835,
                "weight": 835,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "dbf1943d8304d559479c9f72ed8fdb78ed7183e2e7aac743f7c92b20762ebce2",
                "condition": {
                    "country": "SC",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 836,
                "weight": 836,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "536e99d8fb7247bafecd694025af4e4ece7776787a4a4b434e0b787ac051d21a",
                "condition": {
                    "country": "SD",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 837,
                "weight": 837,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "94c66813bb256bbe55ae756dd8d6c287f9b01567ac039f068e0a53554071f3c3",
                "condition": {
                    "payment_method": "Card",
                    "country": "SD",
                    "mandate_type": "mandate"
                },
                "priority": 838,
                "weight": 838,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8f403eaf85c1a5b17fe856ed16091b1ea69fcca535e773420a8b751446a75c52",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "SE",
                    "payment_method": "Card"
                },
                "priority": 839,
                "weight": 839,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c8315d15037c859044d599eac980c68f7ad4a54802375e5bec7c8818eb6321f9",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "SE"
                },
                "priority": 840,
                "weight": 840,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ed8c2556b1339a117866c1fabaa5b7f893ad0a2599ceacfc08cd8da116596b83",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "SG"
                },
                "priority": 841,
                "weight": 841,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0202bcf3c4857b1d5562b026882403fd262b579b7c227d4026ad2c2eaa59c02c",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "SG"
                },
                "priority": 842,
                "weight": 842,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "94220c87152d59f10f4dfe6892548ec3a5d70cd06eefb5f53945be6f953cae98",
                "condition": {
                    "country": "SH",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 843,
                "weight": 843,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "164509a6d2761c0181b20a677d77db4811f38041880f6867f8503fb5ab66628d",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "SH"
                },
                "priority": 844,
                "weight": 844,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a74997eeaa2d1a2f7964daae44a298daaa50cdb0af193f81c1b849608449c65d",
                "condition": {
                    "country": "SI",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 845,
                "weight": 845,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6973203ae23ad6620ffbbb2d9784b284dd699916e0b23088c7e369e2218c0578",
                "condition": {
                    "payment_method": "Card",
                    "country": "SI",
                    "mandate_type": "mandate"
                },
                "priority": 846,
                "weight": 846,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ca0d29107512f7a037a8866f3ab1e99b1f774444c5a19e5ced27274e12f9ae8c",
                "condition": {
                    "payment_method": "Card",
                    "country": "SJ",
                    "mandate_type": "non_mandate"
                },
                "priority": 847,
                "weight": 847,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5099e133fd25be6e6b4e8ffb511b37afdd4785f04be837767a26a3e497c98abc",
                "condition": {
                    "country": "SJ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 848,
                "weight": 848,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a67792b84961fe3b047e3a54595a75fd1b08809bc2f3c3b7d5c894812ed094a0",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "SK"
                },
                "priority": 849,
                "weight": 849,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "19e09831a6521c761648b6406bfe62a0a79aa70c5be9b6d7dcca8843bbc7a4ee",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "SK"
                },
                "priority": 850,
                "weight": 850,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "985d2dd94b533d6e70adcaaee516911a1163bad3faab850d6ee51c77816fd3bd",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "SL"
                },
                "priority": 851,
                "weight": 851,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "a61ebdef0c3a50aa2d5a9c661e8158c06488ab40f9570459d11c1540336842b1",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "SL"
                },
                "priority": 852,
                "weight": 852,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b6e02c2d8e2b2c07d0486f71406b7ba808ac2b9c7786b0f6db53daac9a6231da",
                "condition": {
                    "country": "SN",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 853,
                "weight": 853,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "18a96089c7044a86ebbd7f471638a5d3c188f3ec4e4e26a91da404f0b495cbc0",
                "condition": {
                    "payment_method": "Card",
                    "country": "SN",
                    "mandate_type": "mandate"
                },
                "priority": 854,
                "weight": 854,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "33fbf7c881d85bc07e133db95e8fbfa5ca4f2fe3961b0e7ad98a52bd7b1d0290",
                "condition": {
                    "payment_method": "Card",
                    "country": "SO",
                    "mandate_type": "non_mandate"
                },
                "priority": 855,
                "weight": 855,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "695a27973e8d8bdaea4b949bf9fd57f7fe626e8d60d6aa77c1a9ae2553021fa2",
                "condition": {
                    "payment_method": "Card",
                    "country": "SO",
                    "mandate_type": "mandate"
                },
                "priority": 856,
                "weight": 856,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "579af369b403ef8db371dcf5247d49c09e08808a1a233425d731653705d01d1a",
                "condition": {
                    "country": "SS",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 857,
                "weight": 857,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f5b8e0152a18106ffa9da1802d7f92afc05debd9c94bc2d41bd412601a26792a",
                "condition": {
                    "payment_method": "Card",
                    "country": "SS",
                    "mandate_type": "mandate"
                },
                "priority": 858,
                "weight": 858,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "18ba4824317c92c226be85d1988f5ec3b2da85bf33d6097ba2b61b5db7fb0cd8",
                "condition": {
                    "country": "ST",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 859,
                "weight": 859,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2b18d998eaccb64ca3a6d9cbed4dedc9274fe57e42c133c8845b7b4c27cdd852",
                "condition": {
                    "country": "ST",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 860,
                "weight": 860,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "736e66095335cedcd4eeffc8588b6aa59445b1770b660353183f1f3540c9e457",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "SX"
                },
                "priority": 861,
                "weight": 861,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "07b91e21534b6d854f102425b329ce3a9ba8dcfe7b576803cd5f66a29ea1924d",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "SX"
                },
                "priority": 862,
                "weight": 862,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "208053f4b63969be2d375eec4c930c0be86788d714a4c1ed4f55d9cc0842e019",
                "condition": {
                    "country": "SY",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 863,
                "weight": 863,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1e65ea8044abff1b6aae6da169755386dbdc9e0258c5cc59e0c5fabeb1e1b32a",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "SY",
                    "payment_method": "Card"
                },
                "priority": 864,
                "weight": 864,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "8d0fa214f429b599e948fc58197fffcd0898d392acf89a2548613cbf9cebf817",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "SZ"
                },
                "priority": 865,
                "weight": 865,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "92604bfb06cd255fc8ffdcec5e97d31f5db0db6e7a3251b732b4e83192c4ab87",
                "condition": {
                    "country": "SZ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 866,
                "weight": 866,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9185198d40a755dafaa0f15769f609c7ad6274c40d8202796e2b62ddf162e265",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "TA"
                },
                "priority": 867,
                "weight": 867,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "baaea23657f9acb7a6b495c9477d3be039c98142f0b21c4a2dd7cb371e5c945b",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "TA"
                },
                "priority": 868,
                "weight": 868,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f0df712f51e33757b46e9eedcf94e56caf14c937993c2c9fbffb3b444d923511",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "TC",
                    "payment_method": "Card"
                },
                "priority": 869,
                "weight": 869,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e063bc7978adb5fd666a3f6a57b54fcb2594ee83037c8c6fc65d63ce82591bd9",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "TC"
                },
                "priority": 870,
                "weight": 870,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "c5b360d7b71d1c573387589503b7823c81b69471dd1823fb99fb213598ddf36e",
                "condition": {
                    "country": "TD",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 871,
                "weight": 871,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "34acdb93eb02dc17bce52178a5a463a4eb1b3ecde670f0520114324c6693b8c1",
                "condition": {
                    "country": "TD",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 872,
                "weight": 872,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "bfc9a408b6ade7a2a308180b655969a66a6d0c18c7750b9ff073c98016da9bcf",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "TF"
                },
                "priority": 873,
                "weight": 873,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "f9f60b8ac26141157bd3bd2b81ee16a5f14ac0a877e9068d81a19bb1db4c8ee6",
                "condition": {
                    "country": "TF",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 874,
                "weight": 874,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9f57b13b1fab4ca14adb1aced59e0a268b824cb6618cbe1ae626a161a7488350",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "TG",
                    "payment_method": "Card"
                },
                "priority": 875,
                "weight": 875,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "12432efb5ae430c39fd414c0f28d1401eea5676e2c947038d3e001820f7712bd",
                "condition": {
                    "country": "TG",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 876,
                "weight": 876,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3a2a491aeb0d7232c500d3127b85e0b91c26f2cfb22678d5ba26162b045fbfe9",
                "condition": {
                    "country": "TJ",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 877,
                "weight": 877,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ebdd49c698dc1edc2ed4177de52376cb52c2347abd3d9be5453381f71dcc240e",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "TJ"
                },
                "priority": 878,
                "weight": 878,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "b291c40bd06e492589b06b448ab21211474f09aad94cb269de47b9de0592c270",
                "condition": {
                    "country": "TK",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 879,
                "weight": 879,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "781ebdadec59437b5cb3318e96a68eb51509a8b0b87ac4d3eb588f5015c571d0",
                "condition": {
                    "country": "TK",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 880,
                "weight": 880,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cc10808207ef0820b8d08e0a8247fcd041a4de028eeb07fc723007144ca0c4a1",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "TL",
                    "payment_method": "Card"
                },
                "priority": 881,
                "weight": 881,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "cb4bfb427b863e36447d0ae25a2a2b3196fd991a263ed2388686c2c56c86892f",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "TL",
                    "payment_method": "Card"
                },
                "priority": 882,
                "weight": 882,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9388850f4d2b0918216de53f421b29ad2ec0033720f7765986d3f334c4ecca5a",
                "condition": {
                    "country": "TM",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 883,
                "weight": 883,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "03929466fbcbeb63a44793fbd3c3762e6310b3453c8f528153ed9bc40a6c5be1",
                "condition": {
                    "country": "TM",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 884,
                "weight": 884,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "ac63526bc9c8621a0874ca2dbc186f088190a04eeaa50bdf5d17174eca359d04",
                "condition": {
                    "country": "TN",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 885,
                "weight": 885,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e5376fa691d5d1b25e6ea0e5848da486d6ddf5c2338116695c89d267f025a026",
                "condition": {
                    "country": "TN",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 886,
                "weight": 886,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2ae21a6955bfbabb2ef75cc5515f6e8263e76b59c17562aa8b8fa16daf06c5f5",
                "condition": {
                    "country": "TO",
                    "mandate_type": "non_mandate",
                    "payment_method": "Card"
                },
                "priority": 887,
                "weight": 887,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "1c40a1685e5f77122bf1102ccf5c5e0e93afde322a24451a6dde9fb9cd65f671",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "TO",
                    "payment_method": "Card"
                },
                "priority": 888,
                "weight": 888,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "299b7787db773412f1adc5900f5d26581439355eedc50d9dad2f13f049ef336d",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "TT",
                    "payment_method": "Card"
                },
                "priority": 889,
                "weight": 889,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "e29b93aeea804ab5127434029697c42304feaba75202db63f623e134448175e4",
                "condition": {
                    "country": "TT",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 890,
                "weight": 890,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5cfa689cc6f164426bdc749809699ac5e3cd072e0f07a087d36a1413a6ac74e6",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "TV",
                    "payment_method": "Card"
                },
                "priority": 891,
                "weight": 891,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "bdc61b0a19a8b535f56d20cc21a60fc689a27cd5ebe1e8b34fde006cd2559459",
                "condition": {
                    "country": "TV",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 892,
                "weight": 892,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fbb596f1890c4a260d0763527c914e73751fa56d3146c7809818f7bd5c87da78",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "TZ"
                },
                "priority": 893,
                "weight": 893,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "6b8eda5ddfd8c3e6e0fa9aa87a5655482cf3502b95316484f319a17e40cacb82",
                "condition": {
                    "country": "TZ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 894,
                "weight": 894,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0b40f310c28acc3264e245d837887f3c4ec5f8d1f1423e2c2babf333955d6d74",
                "condition": {
                    "country": "UG",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 895,
                "weight": 895,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2e0b3c900886156f298c6aeb7abc3dc77a5741fba23e158910c0ce56f18cbbad",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "UG"
                },
                "priority": 896,
                "weight": 896,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "621b65b020c216f7d7e23e819d361d2a0e26ce49c6d31964c6c2cde22565c234",
                "condition": {
                    "country": "UM",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 897,
                "weight": 897,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "88f63b55e4a57cb3033b9f80f40d565f8345af8b4cdbb0841047221e362a5d4d",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "UM",
                    "payment_method": "Card"
                },
                "priority": 898,
                "weight": 898,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2c5bf21008ea731278b4f8fbf9b8a05dc33aa62e234350b3b3dd51846bfa94ce",
                "condition": {
                    "payment_method": "Card",
                    "country": "UZ",
                    "mandate_type": "non_mandate"
                },
                "priority": 899,
                "weight": 899,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7df3a4b289811d7c7ad3998b8c304fbb14b57fe14997730e432c413ef858ef60",
                "condition": {
                    "country": "UZ",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 900,
                "weight": 900,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2d8f3c5b05f19426e18f7d46de19ff6cc5e80e5e022833772f886bef4fedd97c",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "VA",
                    "payment_method": "Card"
                },
                "priority": 901,
                "weight": 901,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d9151ed66ffe7683c92135a83a2f0e4d011fb9b85aff0c0eed9d98f230bb3a26",
                "condition": {
                    "country": "VA",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 902,
                "weight": 902,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "3f54ff2fc2c08fbc935f6e00210b1e7c48a81dbe2a79b02002708ea800419ceb",
                "condition": {
                    "country": "VC",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 903,
                "weight": 903,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7cbe946875a4111a6b071eef31d2c488634ad6327f9a3662f6eda2a4ac6965d2",
                "condition": {
                    "payment_method": "Card",
                    "country": "VC",
                    "mandate_type": "mandate"
                },
                "priority": 904,
                "weight": 904,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "59af01b4e86d3ae11519422d8cd3d628bb1d550fcec62aada1983e54f03c8f7f",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "non_mandate",
                    "country": "VG"
                },
                "priority": 905,
                "weight": 905,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "15a222b34ef5167b8f79218b94c6c44d914df58780a6d59f5e443f543d94dbb3",
                "condition": {
                    "country": "VG",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 906,
                "weight": 906,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5bfb78c8a65d2f37af7e6ccf1a994f3655a74ff79095ad1d590f088b5ae76282",
                "condition": {
                    "country": "VU",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 907,
                "weight": 907,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "7bf1061d76ff6874adec4158ca103e8b6ec20f76f5b1ffce82ed2aa99a75c50e",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "VU"
                },
                "priority": 908,
                "weight": 908,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9c74b1ebb5b01df889ce8e365eeb511fb2ed9b1e1df38fae7244820e764ca907",
                "condition": {
                    "country": "WF",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 909,
                "weight": 909,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "401df1b48c319ca669da72a4875c8488cfe9a7b55bd8a24660cb908ebe47d647",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "WF"
                },
                "priority": 910,
                "weight": 910,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "9d049216487229a9b7989887c6fc6da9701c78f9efa6658d7a6be99632068b8b",
                "condition": {
                    "mandate_type": "non_mandate",
                    "payment_method": "Card",
                    "country": "WS"
                },
                "priority": 911,
                "weight": 911,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0918091fecf703b6a45b137c7add35d1cb1151d6bd8193fc59feb1d44fa7c309",
                "condition": {
                    "mandate_type": "mandate",
                    "payment_method": "Card",
                    "country": "WS"
                },
                "priority": 912,
                "weight": 912,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "2e648931ccd28adeac8e9081e0af8f0fc413094ecdf99abf4b1e3ad696b83865",
                "condition": {
                    "country": "XK",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 913,
                "weight": 913,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "58bcef546392216be661f2968259eba60d00824160cf677fdb4c7742e40a8bb8",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "XK",
                    "payment_method": "Card"
                },
                "priority": 914,
                "weight": 914,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "391c098ec4b0fe5d4e7fe9bda599cce1b29d806ffaf260e33e3e478cdec7a8bd",
                "condition": {
                    "country": "YE",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 915,
                "weight": 915,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5c6154d47ee69f92b3f449c244d4f67860322f29b9a97ed0516aad037984bd93",
                "condition": {
                    "country": "YE",
                    "payment_method": "Card",
                    "mandate_type": "mandate"
                },
                "priority": 916,
                "weight": 916,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "12e487aadf049bb52c859644ffed92b1ee4952f1678144d5108c417ef6e17936",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "YT",
                    "payment_method": "Card"
                },
                "priority": 917,
                "weight": 917,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fe6668b44238c310a49478b6b07eb1cf5bf5eeff479638ac1492012cd17ff5cb",
                "condition": {
                    "payment_method": "Card",
                    "country": "YT",
                    "mandate_type": "mandate"
                },
                "priority": 918,
                "weight": 918,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "5aa82e008451b5a894a4239de81ad4444f42d85b077bd1c046c90d835ff02d6c",
                "condition": {
                    "country": "ZM",
                    "payment_method": "Card",
                    "mandate_type": "non_mandate"
                },
                "priority": 919,
                "weight": 919,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "14145bf293f3af31a66aa2c7db26d9b6a5250f07259b946e665e505f488b9ff8",
                "condition": {
                    "country": "ZM",
                    "mandate_type": "mandate",
                    "payment_method": "Card"
                },
                "priority": 920,
                "weight": 920,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "16b7bd177169091192edaace79b58a201b3a63835829fe981b017724725844a5",
                "condition": {
                    "mandate_type": "non_mandate",
                    "country": "ZW",
                    "payment_method": "Card"
                },
                "priority": 921,
                "weight": 921,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "45f8a1396b3f0c6e246a01ce30e05b068a82bccd4e672721c34a2f564b639127",
                "condition": {
                    "mandate_type": "mandate",
                    "country": "ZW",
                    "payment_method": "Card"
                },
                "priority": 922,
                "weight": 922,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "0112f1270f7736ad1e1cae4db8f6747035c6b036c2e3968585147fc98a401823",
                "condition": {
                    "payment_method": "Card",
                    "country": "GN",
                    "mandate_type": "non_mandate"
                },
                "priority": 923,
                "weight": 923,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "d7bad820e2bbe5379d4d523bab3a735e2c84a270c55c2add9823a340e31c1ad8",
                "condition": {
                    "payment_method": "Card",
                    "mandate_type": "mandate",
                    "country": "GN"
                },
                "priority": 924,
                "weight": 924,
                "override_with_keys": [
                    "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33"
                ]
            },
            {
                "id": "fefd1be2e9fb4b3f13c3d2e8c693f72aed20f72b55841643a4f4f6683f9dfff5",
                "condition": {
                    "always_collect_billing_details_from_wallet_connector": true,
                    "payment_method": "Wallet"
                },
                "priority": 33293,
                "weight": 33293,
                "override_with_keys": [
                    "c76206a69f3f1c34c6d8b43656987623b6d3edc22ce85fbf5043f9180b0419c9"
                ]
            },
            {
                "id": "0cceec3700832e53a226eb56f8224a26d879a3b78fc2f6b4787f2f2d025f8445",
                "condition": {
                    "always_collect_shipping_details_from_wallet_connector": true,
                    "payment_method": "Wallet"
                },
                "priority": 33294,
                "weight": 33294,
                "override_with_keys": [
                    "f2ba1e7144aeed1a38f977ad1afcd97007f614bb27c2e8a2a3a146724be31f6a"
                ]
            }
        ],
        "overrides": {
            "650435d35b38cee342dc34f566214545d0b603ae0f5bb49992afbd1d0b83177f": {
                "dynamic_fields.card.card_number._is_required": true,
                "dynamic_fields.card.card_exp_year._is_required": true,
                "dynamic_fields.card.card_exp_month._is_required": true,
                "dynamic_fields.card.card_cvc._is_required": true
            },
            "f2ba1e7144aeed1a38f977ad1afcd97007f614bb27c2e8a2a3a146724be31f6a": {
                "dynamic_fields.shipping.address.last_name._is_required": true,
                "dynamic_fields.shipping.address.line1._is_required": true,
                "dynamic_fields.shipping.address.state._is_required": true,
                "dynamic_fields.shipping.email._is_required": true,
                "dynamic_fields.shipping.address.line2._is_required": true,
                "dynamic_fields.shipping.address.country._is_required": true,
                "dynamic_fields.shipping.phone.number._is_required": true,
                "dynamic_fields.shipping.address.city._is_required": true,
                "dynamic_fields.shipping.address.zip._is_required": true,
                "dynamic_fields.shipping.phone.country_code._is_required": true,
                "dynamic_fields.shipping.address.first_name._is_required": true
            },
            "c76206a69f3f1c34c6d8b43656987623b6d3edc22ce85fbf5043f9180b0419c9": {
                "dynamic_fields.billing.email._is_required": true,
                "dynamic_fields.billing.address.state._is_required": true,
                "dynamic_fields.billing.address.city._is_required": true,
                "dynamic_fields.billing.address.last_name._is_required": true,
                "dynamic_fields.billing.address.country._is_required": true,
                "dynamic_fields.billing.address.line1._is_required": true,
                "dynamic_fields.billing.address.zip._is_required": true,
                "dynamic_fields.billing.address.line2._is_required": true,
                "dynamic_fields.billing.phone.country_code._is_required": true,
                "dynamic_fields.billing.phone.number._is_required": true,
                "dynamic_fields.billing.address.first_name._is_required": true
            },
            "3e47df162984309d28b80807b3c0e88a0b7de3ff5a12a87e7179cdcb508f7d33": {
                "dynamic_fields.billing.address.state._is_required": false
            },
            "8a3edf7d6247e71698a13c17f47c69d08c6ad4428d35752adff149dffe50f110": {
                "dynamic_fields.billing.address.first_name._default_placeholder_text": "Card Holder Name",
                "dynamic_fields.card.card_cvc._is_required": true,
                "dynamic_fields.billing.address.last_name._validation_rule_type": "last_name",
                "dynamic_fields.card.card_number._is_required": true,
                "dynamic_fields.billing.address.first_name._label_localization_key": "cardHolderName",
                "dynamic_fields.billing.address.first_name._validation_rule_type": "first_name",
                "dynamic_fields.card.card_exp_month._is_required": true,
                "dynamic_fields.card.card_exp_year._is_required": true,
                "dynamic_fields.billing.address.first_name._placeholder_localization_key": "cardHolderName",
                "dynamic_fields.billing.address.first_name._default_label_text": "Card Holder Name"
            }
        },
        "default_configs": {
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._keyboard_type": "numeric",
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.state._label_localization_key": "stateLabel",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._label_localization_key": "sortCodeText",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._placeholder_localization_key": "bsbNumberPlaceholder",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._max_input_length": 17,
            "dynamic_fields.billing.address.line1._extended_dropdown_options": [],
            "dynamic_fields.card.card_cvc._html_autocomplete_attribute": "cc-csc",
            "dynamic_fields.gift_card.number._placeholder_localization_key": "giftCardNumberPlaceholder",
            "dynamic_fields.billing.address.state._dropdown_options": [],
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._layout_row_id": "bank_debit_becs_bank_debit_account_number_row",
            "dynamic_fields.shipping.address.line1._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._render_when_prefilled": false,
            "dynamic_fields.gift_card.givex.number._max_input_length": 255,
            "dynamic_fields.crypto.pay_currency._confirm_request_write_path": "payment_method_data.crypto.pay_currency",
            "dynamic_fields.customer.document_details.document_number._layout_width_ratio": 1,
            "dynamic_fields.billing.address.country._is_required": false,
            "dynamic_fields.gift_card.number._render_when_prefilled": false,
            "dynamic_fields.shipping.address.state._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.first_name._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._confirm_request_write_path": "payment_method_data.bank_redirect.online_banking_poland.issuer",
            "dynamic_fields.card.card_exp_year._confirm_request_write_path": "payment_method_data.card.card_exp_year",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._field_display_order": 310,
            "dynamic_fields.gift_card.givex.cvc._render_when_prefilled": false,
            "dynamic_fields.shipping.address.city._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.eps.bank_name._field_display_order": 160,
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._layout_width_ratio": 1,
            "dynamic_fields.shipping.address.country._render_when_prefilled": false,
            "dynamic_fields.gift_card.cvc._intent_data_read_path": "gift_card.givex.cvc",
            "dynamic_fields.billing.address.city._validation_rule_type": "no_validation",
            "dynamic_fields.billing.phone.country_code._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.last_name._dropdown_options": [],
            "dynamic_fields.billing.address.line1._validation_regex_pattern": ".*",
            "dynamic_fields.card.card_network._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._is_required": false,
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._default_label_text": "Bank Issuer",
            "dynamic_fields.card.card_exp_month._field_render_type": "CardExpiryMonth",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._placeholder_localization_key": "branchCodePlaceholder",
            "dynamic_fields.email._input_format_pattern": "no_format_pattern",
            "dynamic_fields.voucher.boleto.social_security_number._max_input_length": 14,
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._is_required": false,
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._render_when_prefilled": false,
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.address.state._validation_rule_type": "no_validation",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._confirm_request_write_path": "payment_method_data.bank_redirect.open_banking_fpx.issuer",
            "dynamic_fields.billing.address.zip._field_display_order": 590,
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._max_input_length": 8,
            "dynamic_fields.shipping.address.line1._max_input_length": 255,
            "dynamic_fields.crypto.network._dropdown_options": [],
            "dynamic_fields.bank_redirect.ideal.bank_name._label_localization_key": "formFieldBankNameLabel",
            "dynamic_fields.wallet.mifinity.language_preference._field_display_order": 190,
            "dynamic_fields.bank_redirect.blik.blik_code._input_format_pattern": "***-***",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._label_localization_key": "formFieldACHRoutingNumberLabel",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._field_display_order": 340,
            "dynamic_fields.shipping.address.state._layout_width_ratio": 1,
            "dynamic_fields.shipping.phone.country_code._validation_regex_pattern": ".*",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._label_localization_key": "clientUidLabel",
            "dynamic_fields.billing.address.state._placeholder_localization_key": "statePlaceholder",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._field_render_type": "Phone",
            "dynamic_fields.shipping.address.country._html_autocomplete_attribute": "shipping country",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._intent_data_read_path": "bank_debit.ach_bank_debit.bank_type",
            "dynamic_fields.description._field_display_order": 710,
            "dynamic_fields.gift_card.number._layout_width_ratio": 1,
            "dynamic_fields.shipping.address.country._field_render_type": "Country",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._dropdown_options": [
                "bangkok_bank",
                "krungsri_bank",
                "krung_thai_bank",
                "the_siam_commercial_bank",
                "kasikorn_bank"
            ],
            "dynamic_fields.upi.upi_collect.vpa_id._layout_width_ratio": 1,
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.customer.document_details.document_type._layout_row_id": "customer_document_details_document_type_row",
            "dynamic_fields.shipping.address.zip._intent_data_read_path": "shipping.address.zip",
            "dynamic_fields.billing.address.line2._max_input_length": 255,
            "dynamic_fields.card.card_network._default_label_text": "Card Network",
            "dynamic_fields.billing.address.country._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.line2._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._layout_width_ratio": 1,
            "dynamic_fields.shipping.phone.number._layout_row_id": "shipping_phone_number_row",
            "dynamic_fields.billing.address.first_name._layout_width_ratio": 1,
            "dynamic_fields.billing.phone.country_code._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._default_label_text": "Branch Code",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._default_placeholder_text": "Enter Pix key.",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._keyboard_type": "phone-pad",
            "dynamic_fields.shipping.address.state._extended_dropdown_options": [],
            "dynamic_fields.description._default_placeholder_text": "Description",
            "dynamic_fields.card.card_cvc._layout_width_ratio": 1,
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._default_label_text": "Phone Number",
            "dynamic_fields.bank_redirect.ideal.bank_name._validation_regex_pattern": ".*",
            "dynamic_fields.card.card_exp_year._html_autocomplete_attribute": "cc-exp-year",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._dropdown_options": [],
            "dynamic_fields.customer.document_details.document_type._extended_dropdown_options": [],
            "dynamic_fields.email._dropdown_options": [],
            "dynamic_fields.shipping.address.city._label_localization_key": "cityLabel",
            "dynamic_fields.shipping.address.country._intent_data_read_path": "shipping.address.country",
            "dynamic_fields.billing.phone.number._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.first_name._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.city._input_format_pattern": "no_format_pattern",
            "dynamic_fields.shipping.address.line1._render_when_prefilled": false,
            "dynamic_fields.upi.upi_collect.vpa_id._field_render_type": "Generic",
            "dynamic_fields.gift_card.number._confirm_request_write_path": "payment_method_data.gift_card.givex.number",
            "dynamic_fields.crypto.pay_currency._field_render_type": "CryptoCurrency",
            "dynamic_fields.voucher.boleto.social_security_number._default_label_text": "Social Security Number",
            "dynamic_fields.gift_card.givex.cvc._field_display_order": 420,
            "dynamic_fields.card.card_number._render_when_prefilled": false,
            "dynamic_fields.card.card_number._html_autocomplete_attribute": "cc-number",
            "dynamic_fields.customer.document_details.document_number._extended_dropdown_options": [],
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._max_input_length": 9,
            "dynamic_fields.shipping.address.line1._is_required": false,
            "dynamic_fields.upi.upi_collect.vpa_id._layout_row_id": "upi_upi_collect_vpa_id_row",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._intent_data_read_path": "bank_debit.becs_bank_debit.bsb_number",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._is_required": false,
            "dynamic_fields.shipping.address.city._keyboard_type": "default",
            "dynamic_fields.wallet.mifinity.date_of_birth._default_placeholder_text": "Enter Date of Birth.",
            "dynamic_fields.shipping.address.city._confirm_request_write_path": "shipping.address.city",
            "dynamic_fields.shipping.address.last_name._confirm_request_write_path": "shipping.address.last_name",
            "dynamic_fields.billing.address.zip._keyboard_type": "default",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._field_display_order": 60,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._placeholder_localization_key": "expiryYearPlaceholder",
            "dynamic_fields.shipping.address.zip._layout_row_id": "shipping_address_zip_row",
            "dynamic_fields.gift_card.cvc._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.line1._placeholder_localization_key": "line1Placeholder",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._confirm_request_write_path": "payment_method_data.bank_debit.ach_bank_debit.bank_type",
            "dynamic_fields.bank_redirect.ideal.bank_name._max_input_length": 255,
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._is_required": false,
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._label_localization_key": "formFieldBankAccountNumberLabel",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._max_input_length": 7,
            "dynamic_fields.bank_transfer.pix_emv.pix_key._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.line2._is_required": false,
            "dynamic_fields.billing.email._validation_regex_pattern": ".*",
            "dynamic_fields.card.card_cvc._label_localization_key": "cvcTextLabel",
            "dynamic_fields.gift_card.givex.number._dropdown_options": [],
            "dynamic_fields.upi.upi_collect.vpa_id._input_format_pattern": "no_format_pattern",
            "dynamic_fields.shipping.address.country._extended_dropdown_options": [],
            "dynamic_fields.card.card_number._intent_data_read_path": "card.card_number",
            "dynamic_fields.shipping.address.last_name._default_label_text": "Last Name",
            "dynamic_fields.billing.address.country._confirm_request_write_path": "payment_method_data.billing.address.country",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._confirm_request_write_path": "payment_method_data.bank_redirect.online_banking_slovakia.issuer",
            "dynamic_fields.crypto.pay_currency._layout_row_id": "crypto_pay_currency_row",
            "dynamic_fields.shipping.phone.country_code._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.line2._extended_dropdown_options": [],
            "dynamic_fields.billing.email._dropdown_options": [],
            "dynamic_fields.shipping.phone.number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.crypto.pay_currency._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.first_name._label_localization_key": "billingNameLabel",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._field_display_order": 300,
            "dynamic_fields.crypto.pay_currency._default_placeholder_text": "Select Currency",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._html_autocomplete_attribute": "cc-exp-year",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._intent_data_read_path": "bank_transfer.pix_emv.pix_key",
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._dropdown_options": [],
            "dynamic_fields.bank_redirect.bancontact_card.card_number._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.blik.blik_code._render_when_prefilled": false,
            "dynamic_fields.billing.phone.country_code._confirm_request_write_path": "payment_method_data.billing.phone.country_code",
            "dynamic_fields.card.card_number._dropdown_options": [],
            "dynamic_fields.shipping.address.line2._validation_rule_type": "no_validation",
            "dynamic_fields.shipping.address.last_name._dropdown_options": [],
            "dynamic_fields.bank_redirect.bancontact_card.card_number._render_when_prefilled": false,
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._default_placeholder_text": "eg: DE00 0000 0000 0000 0000 00",
            "dynamic_fields.shipping.address.line2._validation_regex_pattern": ".*",
            "dynamic_fields.bank_transfer.pix.pix_key._default_label_text": "PIX Key",
            "dynamic_fields.billing.address.zip._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._placeholder_localization_key": "expiryMonthPlaceholder",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._dropdown_options": [],
            "dynamic_fields.billing.email._confirm_request_write_path": "payment_method_data.billing.email",
            "dynamic_fields.card.card_number._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._max_input_length": 255,
            "dynamic_fields.billing.address.country._field_display_order": 580,
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._layout_row_id": "bank_redirect_online_banking_poland_issuer_row",
            "dynamic_fields.billing.address.zip._render_when_prefilled": false,
            "dynamic_fields.shipping.email._validation_regex_pattern": ".*",
            "dynamic_fields.gift_card.number._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.city._max_input_length": 255,
            "dynamic_fields.card.card_exp_month._is_required": false,
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._placeholder_localization_key": "bankIssuerPlaceholder",
            "dynamic_fields.customer.document_details.document_type._intent_data_read_path": "customer.document_details.document_type",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._label_localization_key": "expiryYearLabel",
            "dynamic_fields.billing.address.country._default_label_text": "Country",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._default_label_text": "Expiry Month",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._max_input_length": 255,
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._default_placeholder_text": "Select Bank Issuer",
            "dynamic_fields.shipping.phone.country_code._max_input_length": 255,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._placeholder_localization_key": "accountHolderNamePlaceholder",
            "dynamic_fields.wallet.mifinity.language_preference._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.city._html_autocomplete_attribute": "billing address-level2",
            "dynamic_fields.bank_redirect.eps.bank_name._layout_row_id": "bank_redirect_eps_bank_name_row",
            "dynamic_fields.billing.address.line1._intent_data_read_path": "billing.address.line1",
            "dynamic_fields.billing.address.line1._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.blik.blik_code._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._label_localization_key": "bankLabel",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._label_localization_key": "bankLabel",
            "dynamic_fields.shipping.address.last_name._layout_width_ratio": 1,
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._render_when_prefilled": false,
            "dynamic_fields.billing.address.last_name._layout_row_id": "billing_address_last_name_row",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._label_localization_key": "branchCodeLabel",
            "dynamic_fields.card.card_number._keyboard_type": "numeric",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._default_placeholder_text": "Your Phone",
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._extended_dropdown_options": [],
            "dynamic_fields.card.card_exp_year._extended_dropdown_options": [],
            "dynamic_fields.customer.document_details.document_number._confirm_request_write_path": "customer.document_details.document_number",
            "dynamic_fields.bank_redirect.blik.blik_code._placeholder_localization_key": "blikCodePlaceholder",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._field_display_order": 80,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.address.line1._keyboard_type": "default",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._validation_rule_type": "no_validation",
            "dynamic_fields.gift_card.cvc._placeholder_localization_key": "giftCardPinPlaceholder",
            "dynamic_fields.billing.address.state._validation_rule_type": "no_validation",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._label_localization_key": "formFieldBankAccountNumberLabel",
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._html_autocomplete_attribute": "on",
            "dynamic_fields.billing.address.state._is_required": false,
            "dynamic_fields.shipping.email._is_required": false,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._dropdown_options": [
                "Checking",
                "Savings"
            ],
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._placeholder_localization_key": "accountNumberPlaceholder",
            "dynamic_fields.wallet.mifinity.date_of_birth._label_localization_key": "dateOfBirth",
            "dynamic_fields.shipping.address.country._default_label_text": "Country",
            "dynamic_fields.shipping.address.city._validation_regex_pattern": ".*",
            "dynamic_fields.wallet.mifinity.language_preference._validation_rule_type": "no_validation",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._placeholder_localization_key": "bankTypePlaceholder",
            "dynamic_fields.billing.address.line2._placeholder_localization_key": "line2Placeholder",
            "dynamic_fields.customer.document_details.document_type._placeholder_localization_key": "documentTypePlaceholder",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._dropdown_options": [
                "affin_bank",
                "agro_bank",
                "alliance_bank",
                "am_bank",
                "bank_of_china",
                "bank_islam",
                "bank_muamalat",
                "bank_rakyat",
                "bank_simpanan_nasional",
                "cimb_bank",
                "hong_leong_bank",
                "hsbc_bank",
                "kuwait_finance_house",
                "maybank",
                "ocbc_bank",
                "public_bank",
                "rhb_bank",
                "standard_chartered_bank",
                "uob_bank"
            ],
            "dynamic_fields.gift_card.givex.number._label_localization_key": "giftCardNumberLabel",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._confirm_request_write_path": "payment_method_data.bank_redirect.open_banking_uk.issuer",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.eps.bank_name._confirm_request_write_path": "payment_method_data.bank_redirect.eps.bank_name",
            "dynamic_fields.gift_card.number._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.line1._layout_width_ratio": 1,
            "dynamic_fields.billing.email._layout_width_ratio": 1,
            "dynamic_fields.billing.address.first_name._field_render_type": "CardHolderName",
            "dynamic_fields.billing.phone.country_code._default_label_text": "Dialing Code",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._label_localization_key": "bankTypeLabel",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._intent_data_read_path": "mobile_payment.direct_carrier_billing.client_uid",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.state._max_input_length": 255,
            "dynamic_fields.description._layout_width_ratio": 1,
            "dynamic_fields.customer.document_details.document_type._default_placeholder_text": "Select Document Type",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._is_required": false,
            "dynamic_fields.billing.address.zip._default_placeholder_text": "Postal Code",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._layout_row_id": "mobile_payment_direct_carrier_billing_client_uid_row",
            "dynamic_fields.customer.document_details.document_number._field_display_order": 230,
            "dynamic_fields.wallet.mifinity.language_preference._confirm_request_write_path": "payment_method_data.wallet.mifinity.language_preference",
            "dynamic_fields.billing.address.line1._html_autocomplete_attribute": "billing address-line1",
            "dynamic_fields.gift_card.givex.number._field_render_type": "Generic",
            "dynamic_fields.billing.email._label_localization_key": "emailLabel",
            "dynamic_fields.card.card_exp_month._default_label_text": "Expiry Month",
            "dynamic_fields.shipping.address.last_name._default_placeholder_text": "Last Name",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._placeholder_localization_key": "bankIssuerPlaceholder",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._intent_data_read_path": "bank_redirect.open_banking_fpx.issuer",
            "dynamic_fields.shipping.address.line1._field_display_order": 630,
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._layout_row_id": "bank_debit_ach_bank_debit_account_number_row",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._input_format_pattern": "no_format_pattern",
            "dynamic_fields.gift_card.cvc._validation_regex_pattern": ".*",
            "dynamic_fields.gift_card.cvc._layout_row_id": "gift_card_cvc_row",
            "dynamic_fields.email._max_input_length": 254,
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._extended_dropdown_options": [],
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.last_name._render_when_prefilled": false,
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._render_when_prefilled": false,
            "dynamic_fields.customer.document_details.document_type._default_label_text": "Document Type",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._input_format_pattern": "no_format_pattern",
            "dynamic_fields.shipping.phone.number._label_localization_key": "formFieldPhoneNumberLabel",
            "dynamic_fields.card.card_network._is_required": false,
            "dynamic_fields.order_details.0.product_name._max_input_length": 255,
            "dynamic_fields.shipping.address.first_name._input_format_pattern": "no_format_pattern",
            "dynamic_fields.shipping.address.state._confirm_request_write_path": "shipping.address.state",
            "dynamic_fields.shipping.phone.country_code._confirm_request_write_path": "shipping.phone.country_code",
            "dynamic_fields.shipping.address.country._placeholder_localization_key": "countryPlaceholder",
            "dynamic_fields.order_details.0.product_name._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.eps.bank_name._max_input_length": 255,
            "dynamic_fields.card.card_exp_year._is_required": false,
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._field_display_order": 110,
            "dynamic_fields.crypto.network._html_autocomplete_attribute": "on",
            "dynamic_fields.billing.address.line2._intent_data_read_path": "billing.address.line2",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._layout_row_id": "bank_transfer_pix_emv_pix_key_row",
            "dynamic_fields.description._max_input_length": 255,
            "dynamic_fields.shipping.address.last_name._intent_data_read_path": "shipping.address.last_name",
            "dynamic_fields.shipping.address.line2._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.line2._label_localization_key": "line2Label",
            "dynamic_fields.shipping.address.state._max_input_length": 255,
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._confirm_request_write_path": "payment_method_data.bank_debit.becs_bank_debit.account_number",
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._field_render_type": "Generic",
            "dynamic_fields.shipping.address.line2._keyboard_type": "default",
            "dynamic_fields.shipping.address.first_name._label_localization_key": "firstName",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._render_when_prefilled": false,
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._extended_dropdown_options": [],
            "dynamic_fields.billing.email._placeholder_localization_key": "emailLabel",
            "dynamic_fields.billing.address.city._max_input_length": 255,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._validation_regex_pattern": ".*",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._render_when_prefilled": false,
            "dynamic_fields.billing.address.zip._max_input_length": 255,
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._dropdown_options": [],
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._field_display_order": 75,
            "dynamic_fields.billing.phone.number._intent_data_read_path": "billing.phone.number",
            "dynamic_fields.upi.upi_collect.vpa_id._field_display_order": 250,
            "dynamic_fields.gift_card.number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._dropdown_options": [],
            "dynamic_fields.voucher.boleto.social_security_number._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.address.first_name._field_display_order": 600,
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._field_render_type": "Generic",
            "dynamic_fields.crypto.network._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._validation_rule_type": "no_validation",
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.eps.bank_name._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_transfer.pix.pix_key._max_input_length": 255,
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._html_autocomplete_attribute": "tel",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._confirm_request_write_path": "payment_method_data.bank_redirect.online_banking_thailand.issuer",
            "dynamic_fields.gift_card.givex.cvc._dropdown_options": [],
            "dynamic_fields.billing.address.line1._confirm_request_write_path": "payment_method_data.billing.address.line1",
            "dynamic_fields.voucher.boleto.social_security_number._field_display_order": 240,
            "dynamic_fields.shipping.address.zip._is_required": false,
            "dynamic_fields.shipping.email._html_autocomplete_attribute": "shipping email",
            "dynamic_fields.bank_redirect.blik.blik_code._max_input_length": 7,
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._render_when_prefilled": false,
            "dynamic_fields.crypto.network._input_format_pattern": "no_format_pattern",
            "dynamic_fields.customer.document_details.document_number._default_placeholder_text": "Document Number",
            "dynamic_fields.customer.document_details.document_number._is_required": false,
            "dynamic_fields.upi.upi_collect.vpa_id._confirm_request_write_path": "payment_method_data.upi.upi_collect.vpa_id",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._html_autocomplete_attribute": "on",
            "dynamic_fields.shipping.address.state._default_label_text": "State/Province",
            "dynamic_fields.billing.address.last_name._extended_dropdown_options": [],
            "dynamic_fields.customer.document_details.document_number._default_label_text": "Document Number",
            "dynamic_fields.wallet.mifinity.language_preference._dropdown_options": [
                "BR",
                "PT_BR",
                "CN",
                "ZH_CN",
                "DE",
                "DK",
                "DA",
                "DA_DK",
                "EN",
                "ES",
                "FI",
                "FR",
                "GR",
                "EL",
                "EL_GR",
                "HR",
                "IT",
                "JP",
                "JA",
                "JA_JP",
                "LA",
                "ES_LA",
                "NL",
                "NO",
                "PL",
                "PT",
                "RU",
                "SV",
                "SE",
                "SV_SE",
                "ZH",
                "TW",
                "ZH_TW"
            ],
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._field_render_type": "BankNamesSelect",
            "dynamic_fields.shipping.phone.country_code._extended_dropdown_options": [],
            "dynamic_fields.wallet.mifinity.language_preference._default_label_text": "Language Preference",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._confirm_request_write_path": "payment_method_data.bank_debit.becs_bank_debit.bsb_number",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._field_render_type": "Generic",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._dropdown_options": [
                "affin_bank",
                "agro_bank",
                "alliance_bank",
                "am_bank",
                "bank_of_china",
                "bank_islam",
                "bank_muamalat",
                "bank_rakyat",
                "bank_simpanan_nasional",
                "cimb_bank",
                "hong_leong_bank",
                "hsbc_bank",
                "kuwait_finance_house",
                "maybank",
                "ocbc_bank",
                "public_bank",
                "rhb_bank",
                "standard_chartered_bank",
                "uob_bank"
            ],
            "dynamic_fields.email._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._layout_row_id": "bank_redirect_open_banking_czech_republic_issuer_row",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._html_autocomplete_attribute": "on",
            "dynamic_fields.card.card_exp_year._default_placeholder_text": "Select Year",
            "dynamic_fields.billing.address.line1._default_label_text": "Address Line 1",
            "dynamic_fields.billing.phone.number._dropdown_options": [],
            "dynamic_fields.card.card_exp_month._html_autocomplete_attribute": "cc-exp-month",
            "dynamic_fields.shipping.email._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.ideal.bank_name._confirm_request_write_path": "payment_method_data.bank_redirect.ideal.bank_name",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._default_label_text": "Sort Code",
            "dynamic_fields.email._layout_row_id": "email_row",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._extended_dropdown_options": [],
            "dynamic_fields.gift_card.cvc._label_localization_key": "giftCardPinLabel",
            "dynamic_fields.billing.address.state._field_display_order": 570,
            "dynamic_fields.shipping.address.first_name._dropdown_options": [],
            "dynamic_fields.bank_transfer.pix.pix_key._confirm_request_write_path": "payment_method_data.bank_transfer.pix.pix_key",
            "dynamic_fields.billing.address.line2._confirm_request_write_path": "payment_method_data.billing.address.line2",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._render_when_prefilled": false,
            "dynamic_fields.gift_card.givex.number._default_label_text": "Gift Card Number",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._layout_width_ratio": 1,
            "dynamic_fields.billing.address.line1._label_localization_key": "line1Label",
            "dynamic_fields.gift_card.givex.cvc._default_placeholder_text": "123456",
            "dynamic_fields.bank_transfer.pix.pix_key._validation_rule_type": "no_validation",
            "dynamic_fields.customer.document_details.document_number._validation_regex_pattern": ".*",
            "dynamic_fields.gift_card.givex.cvc._extended_dropdown_options": [],
            "dynamic_fields.gift_card.givex.cvc._field_render_type": "Generic",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._render_when_prefilled": false,
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._extended_dropdown_options": [],
            "dynamic_fields.gift_card.number._html_autocomplete_attribute": "on",
            "dynamic_fields.voucher.boleto.social_security_number._input_format_pattern": "***.***.***-**",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._render_when_prefilled": false,
            "dynamic_fields.shipping.phone.country_code._label_localization_key": "formFieldCountryCodeLabel",
            "dynamic_fields.shipping.phone.number._intent_data_read_path": "shipping.phone.number",
            "dynamic_fields.email._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._default_label_text": "Bank Issuer",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._default_label_text": "Account Number",
            "dynamic_fields.billing.phone.country_code._field_render_type": "PhoneCountryCode",
            "dynamic_fields.shipping.phone.number._confirm_request_write_path": "shipping.phone.number",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._default_placeholder_text": "Branch Code",
            "dynamic_fields.description._dropdown_options": [],
            "dynamic_fields.voucher.boleto.social_security_number._placeholder_localization_key": "pixCPFPlaceholder",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._layout_row_id": "bank_transfer_pix_automatico_push_account_number_row",
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._layout_row_id": "bank_redirect_open_banking_slovakia_issuer_row",
            "dynamic_fields.gift_card.givex.number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.shipping.address.first_name._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._field_render_type": "BankNamesSelect",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._default_placeholder_text": "Source Bank Account ID",
            "dynamic_fields.billing.phone.number._extended_dropdown_options": [],
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._placeholder_localization_key": "accountNumberPlaceholder",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._layout_width_ratio": 1,
            "dynamic_fields.crypto.network._max_input_length": 255,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._html_autocomplete_attribute": "cc-exp-month",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.address.zip._extended_dropdown_options": [],
            "dynamic_fields.crypto.network._default_label_text": "Currency Networks",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._intent_data_read_path": "bank_redirect.online_banking_poland.issuer",
            "dynamic_fields.billing.email._intent_data_read_path": "billing.email",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._is_required": false,
            "dynamic_fields.billing.email._keyboard_type": "email-address",
            "dynamic_fields.card.card_exp_month._render_when_prefilled": false,
            "dynamic_fields.shipping.address.last_name._validation_rule_type": "no_validation",
            "dynamic_fields.billing.phone.country_code._default_placeholder_text": "Select Dialing Code",
            "dynamic_fields.description._field_render_type": "Generic",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._validation_rule_type": "no_validation",
            "dynamic_fields.card.card_exp_year._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._confirm_request_write_path": "payment_method_data.bank_transfer.pix_automatico_push.branch_code",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._default_placeholder_text": "123456789",
            "dynamic_fields.email._validation_rule_type": "regex",
            "dynamic_fields.order_details.0.product_name._layout_row_id": "order_details_0_product_name_row",
            "dynamic_fields.wallet.mifinity.language_preference._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._label_localization_key": "bankLabel",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._field_render_type": "Dropdown",
            "dynamic_fields.shipping.address.line1._default_placeholder_text": "Street address",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.address.line2._layout_width_ratio": 1,
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._field_render_type": "Generic",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._layout_row_id": "bank_transfer_pix_automatico_push_branch_code_row",
            "dynamic_fields.billing.phone.country_code._placeholder_localization_key": "dialingCodePlaceholder",
            "dynamic_fields.upi.upi_collect.vpa_id._default_label_text": "UPI ID",
            "dynamic_fields.shipping.phone.country_code._field_render_type": "PhoneCountryCode",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._placeholder_localization_key": "bankIssuerPlaceholder",
            "dynamic_fields.card.card_number._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._default_placeholder_text": "Select Bank Issuer",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._extended_dropdown_options": [],
            "dynamic_fields.gift_card.cvc._field_display_order": 440,
            "dynamic_fields.upi.upi_collect.vpa_id._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._layout_width_ratio": 1,
            "dynamic_fields.billing.phone.number._default_label_text": "Phone Number",
            "dynamic_fields.billing.address.zip._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._dropdown_options": [],
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._render_when_prefilled": false,
            "dynamic_fields.billing.address.line2._dropdown_options": [],
            "dynamic_fields.bank_transfer.pix_emv.pix_key._layout_width_ratio": 1,
            "dynamic_fields.card.card_exp_month._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.line2._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._layout_row_id": "bank_debit_sepa_bank_debit_iban_row",
            "dynamic_fields.billing.address.line2._field_display_order": 550,
            "dynamic_fields.email._field_display_order": 500,
            "dynamic_fields.shipping.address.city._html_autocomplete_attribute": "shipping address-level2",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._intent_data_read_path": "bank_redirect.online_banking_slovakia.issuer",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._field_display_order": 450,
            "dynamic_fields.shipping.address.last_name._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.eps.bank_name._intent_data_read_path": "bank_redirect.eps.bank_name",
            "dynamic_fields.shipping.address.zip._html_autocomplete_attribute": "shipping postal-code",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._validation_rule_type": "no_validation",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._layout_width_ratio": 1,
            "dynamic_fields.billing.address.line1._field_render_type": "Generic",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._field_render_type": "CardHolderName",
            "dynamic_fields.shipping.address.zip._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._field_render_type": "Generic",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.address.line1._layout_row_id": "shipping_address_line1_row",
            "dynamic_fields.customer.document_details.document_number._field_render_type": "Generic",
            "dynamic_fields.card.card_number._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._confirm_request_write_path": "payment_method_data.bank_redirect.bancontact_card.card_exp_year",
            "dynamic_fields.billing.phone.country_code._html_autocomplete_attribute": "billing tel-country-code",
            "dynamic_fields.billing.address.city._placeholder_localization_key": "cityPlaceholder",
            "dynamic_fields.upi.upi_collect.vpa_id._html_autocomplete_attribute": "on",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._placeholder_localization_key": "clientUidPlaceholder",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._max_input_length": 255,
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._max_input_length": 255,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._layout_row_id": "bank_redirect_bancontact_card_card_exp_month_row",
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._intent_data_read_path": "bank_transfer.pix_automatico_push.bank_identifier",
            "dynamic_fields.billing.address.line1._validation_rule_type": "no_validation",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._keyboard_type": "numeric",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._intent_data_read_path": "bank_debit.sepa_bank_debit.iban",
            "dynamic_fields.billing.address.last_name._max_input_length": 255,
            "dynamic_fields.customer.document_details.document_type._validation_rule_type": "no_validation",
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._validation_regex_pattern": ".*",
            "dynamic_fields.bank_transfer.pix.pix_key._dropdown_options": [],
            "dynamic_fields.billing.email._input_format_pattern": "no_format_pattern",
            "dynamic_fields.wallet.mifinity.date_of_birth._html_autocomplete_attribute": "bday",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._field_display_order": 90,
            "dynamic_fields.billing.address.country._max_input_length": 255,
            "dynamic_fields.shipping.phone.country_code._input_format_pattern": "no_format_pattern",
            "dynamic_fields.gift_card.number._dropdown_options": [],
            "dynamic_fields.upi.upi_collect.vpa_id._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.city._dropdown_options": [],
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._field_render_type": "BankNamesSelect",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._default_placeholder_text": "000123456789",
            "dynamic_fields.bank_redirect.ideal.bank_name._render_when_prefilled": false,
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._field_display_order": 330,
            "dynamic_fields.card.card_exp_month._max_input_length": 255,
            "dynamic_fields.order_details.0.product_name._extended_dropdown_options": [],
            "dynamic_fields.card.card_exp_month._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.zip._label_localization_key": "postalCodeLabel",
            "dynamic_fields.voucher.boleto.social_security_number._layout_row_id": "voucher_boleto_social_security_number_row",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._layout_row_id": "bank_transfer_pix_source_bank_account_id_row",
            "dynamic_fields.shipping.address.zip._render_when_prefilled": false,
            "dynamic_fields.billing.address.last_name._confirm_request_write_path": "payment_method_data.billing.address.last_name",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._layout_width_ratio": 1,
            "dynamic_fields.shipping.phone.number._html_autocomplete_attribute": "shipping tel-national",
            "dynamic_fields.description._html_autocomplete_attribute": "on",
            "dynamic_fields.shipping.address.city._extended_dropdown_options": [],
            "dynamic_fields.crypto.network._placeholder_localization_key": "cryptoNetworkPlaceholder",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._is_required": false,
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._confirm_request_write_path": "payment_method_data.mobile_payment.direct_carrier_billing.client_uid",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._default_label_text": "Source Bank Account ID",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._confirm_request_write_path": "payment_method_data.mobile_payment.direct_carrier_billing.msisdn",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._html_autocomplete_attribute": "on",
            "dynamic_fields.card.card_exp_month._placeholder_localization_key": "expiryMonthPlaceholder",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._intent_data_read_path": "mobile_payment.direct_carrier_billing.msisdn",
            "dynamic_fields.bank_redirect.eps.bank_name._label_localization_key": "formFieldBankNameLabel",
            "dynamic_fields.shipping.email._keyboard_type": "email-address",
            "dynamic_fields.voucher.boleto.social_security_number._field_render_type": "Generic",
            "dynamic_fields.gift_card.givex.cvc._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._label_localization_key": "formFieldSepaIbanLabel",
            "dynamic_fields.shipping.email._default_label_text": "Email Address",
            "dynamic_fields.gift_card.givex.cvc._label_localization_key": "giftCardPinLabel",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._field_render_type": "CardNumber",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._field_render_type": "BankNamesSelect",
            "dynamic_fields.shipping.address.zip._layout_width_ratio": 1,
            "dynamic_fields.card.card_exp_month._extended_dropdown_options": [],
            "dynamic_fields.shipping.phone.country_code._placeholder_localization_key": "dialingCodePlaceholder",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._extended_dropdown_options": [],
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._intent_data_read_path": "bank_debit.becs_bank_debit.sort_code",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._validation_rule_type": "no_validation",
            "dynamic_fields.gift_card.givex.cvc._confirm_request_write_path": "payment_method_data.gift_card.givex.cvc",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._field_display_order": 390,
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.blik.blik_code._default_label_text": "BLIK Code",
            "dynamic_fields.voucher.boleto.social_security_number._label_localization_key": "socialSecurityNumberLabel",
            "dynamic_fields.billing.address.state._default_label_text": "State/Province",
            "dynamic_fields.shipping.address.zip._placeholder_localization_key": "postalCodePlaceholder",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._intent_data_read_path": "bank_redirect.online_banking_czech_republic.issuer",
            "dynamic_fields.crypto.network._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._default_placeholder_text": "Select Bank Issuer",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._layout_width_ratio": 1,
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._confirm_request_write_path": "payment_method_data.bank_debit.bacs_bank_debit.account_number",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._max_input_length": 255,
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._intent_data_read_path": "bank_transfer.pix_automatico_push.account_number",
            "dynamic_fields.shipping.address.last_name._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.eps.bank_name._layout_width_ratio": 1,
            "dynamic_fields.bank_transfer.pix.pix_key._is_required": false,
            "dynamic_fields.billing.phone.number._layout_row_id": "billing_phone_row",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._default_label_text": "Account Holder Name",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._keyboard_type": "numeric",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._default_label_text": "Client UID",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._default_label_text": "BSB Number",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._dropdown_options": [],
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._label_localization_key": "formFieldSepaBicLabel",
            "dynamic_fields.bank_redirect.blik.blik_code._layout_row_id": "bank_redirect_blik_blik_code_row",
            "dynamic_fields.bank_redirect.eps.bank_name._default_label_text": "Bank Name",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._validation_rule_type": "no_validation",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._is_required": false,
            "dynamic_fields.card.card_exp_month._confirm_request_write_path": "payment_method_data.card.card_exp_month",
            "dynamic_fields.card.card_exp_year._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.line1._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._field_render_type": "Generic",
            "dynamic_fields.shipping.address.zip._default_label_text": "ZIP/Postal Code",
            "dynamic_fields.billing.address.last_name._label_localization_key": "lastName",
            "dynamic_fields.shipping.address.zip._keyboard_type": "default",
            "dynamic_fields.card.card_cvc._extended_dropdown_options": [],
            "dynamic_fields.card.card_network._placeholder_localization_key": "cardNetworkPlaceholder",
            "dynamic_fields.voucher.boleto.social_security_number._layout_width_ratio": 1,
            "dynamic_fields.wallet.mifinity.language_preference._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.first_name._confirm_request_write_path": "shipping.address.first_name",
            "dynamic_fields.bank_redirect.blik.blik_code._is_required": false,
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._field_render_type": "BankNamesSelect",
            "dynamic_fields.card.card_network._max_input_length": 255,
            "dynamic_fields.billing.phone.number._validation_regex_pattern": ".*",
            "dynamic_fields.billing.email._extended_dropdown_options": [],
            "dynamic_fields.gift_card.givex.number._confirm_request_write_path": "payment_method_data.gift_card.givex.number",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._max_input_length": 255,
            "dynamic_fields.bank_transfer.pix_emv.pix_key._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._layout_width_ratio": 1,
            "dynamic_fields.shipping.address.zip._field_render_type": "Generic",
            "dynamic_fields.card.card_exp_month._layout_width_ratio": 1,
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._layout_width_ratio": 1,
            "dynamic_fields.shipping.address.last_name._max_input_length": 255,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._layout_row_id": "bank_redirect_open_banking_fpx_issuer_row",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._field_display_order": 100,
            "dynamic_fields.gift_card.givex.number._extended_dropdown_options": [],
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.card.card_exp_year._render_when_prefilled": false,
            "dynamic_fields.shipping.address.country._default_placeholder_text": "Select Country",
            "dynamic_fields.billing.address.first_name._max_input_length": 255,
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._field_display_order": 370,
            "dynamic_fields.upi.upi_collect.vpa_id._placeholder_localization_key": "upiIdPlaceholder",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._html_autocomplete_attribute": "on",
            "dynamic_fields.billing.address.country._placeholder_localization_key": "countryPlaceholder",
            "dynamic_fields.bank_redirect.blik.blik_code._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._render_when_prefilled": false,
            "dynamic_fields.wallet.mifinity.language_preference._layout_width_ratio": 1,
            "dynamic_fields.gift_card.givex.cvc._is_required": false,
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._default_label_text": "Bank Identifier",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.wallet.mifinity.date_of_birth._layout_width_ratio": 1,
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._keyboard_type": "numeric",
            "dynamic_fields.bank_redirect.blik.blik_code._dropdown_options": [],
            "dynamic_fields.card.card_network._render_when_prefilled": false,
            "dynamic_fields.gift_card.cvc._field_render_type": "Generic",
            "dynamic_fields.gift_card.givex.number._placeholder_localization_key": "giftCardNumberPlaceholder",
            "dynamic_fields.billing.address.first_name._extended_dropdown_options": [],
            "dynamic_fields.wallet.mifinity.date_of_birth._placeholder_localization_key": "dateOfBirthPlaceholderText",
            "dynamic_fields.shipping.address.line2._default_placeholder_text": "Apt., unit number, etc (optional)",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._input_format_pattern": "no_format_pattern",
            "dynamic_fields.card.card_exp_month._layout_row_id": "card_card_exp_month_row",
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._field_display_order": 140,
            "dynamic_fields.description._validation_regex_pattern": ".*",
            "dynamic_fields.gift_card.cvc._max_input_length": 255,
            "dynamic_fields.order_details.0.product_name._is_required": false,
            "dynamic_fields.shipping.address.first_name._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._default_placeholder_text": "Select Bank Issuer",
            "dynamic_fields.billing.address.last_name._field_render_type": "CardHolderName",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._dropdown_options": [
                "aib",
                "bank_of_scotland",
                "barclays",
                "danske_bank",
                "first_direct",
                "first_trust",
                "halifax",
                "hsbc_bank",
                "lloyds",
                "monzo",
                "nat_west",
                "nationwide_bank",
                "revolut",
                "royal_bank_of_scotland",
                "santander_przelew24",
                "starling",
                "tesco_bank",
                "tsb_bank",
                "ulster_bank",
                "open_bank_success",
                "open_bank_failure",
                "open_bank_cancelled"
            ],
            "dynamic_fields.shipping.address.country._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.address.line2._field_display_order": 640,
            "dynamic_fields.shipping.address.first_name._validation_rule_type": "no_validation",
            "dynamic_fields.billing.email._default_placeholder_text": "Email",
            "dynamic_fields.billing.address.first_name._layout_row_id": "billing_address_first_name_row",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._render_when_prefilled": false,
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._keyboard_type": "default",
            "dynamic_fields.gift_card.givex.cvc._validation_rule_type": "no_validation",
            "dynamic_fields.card.card_exp_year._layout_width_ratio": 1,
            "dynamic_fields.billing.address.city._label_localization_key": "cityLabel",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._validation_regex_pattern": ".*",
            "dynamic_fields.wallet.mifinity.language_preference._field_render_type": "LanguagePreference",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._keyboard_type": "numeric",
            "dynamic_fields.billing.email._max_input_length": 254,
            "dynamic_fields.card.card_cvc._confirm_request_write_path": "payment_method_data.card.card_cvc",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._extended_dropdown_options": [],
            "dynamic_fields.billing.address.last_name._layout_width_ratio": 1,
            "dynamic_fields.billing.email._default_label_text": "Email Address",
            "dynamic_fields.crypto.network._validation_rule_type": "no_validation",
            "dynamic_fields.shipping.phone.number._placeholder_localization_key": "formFieldPhoneNumberPlaceholder",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._placeholder_localization_key": "bankIssuerPlaceholder",
            "dynamic_fields.billing.address.first_name._default_label_text": "Full Name",
            "dynamic_fields.billing.address.state._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._is_required": false,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._dropdown_options": [],
            "dynamic_fields.shipping.address.last_name._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.phone.number._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._keyboard_type": "numeric",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._layout_width_ratio": 1,
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._extended_dropdown_options": [],
            "dynamic_fields.billing.address.line2._layout_row_id": "billing_address_line2_row",
            "dynamic_fields.billing.address.line2._label_localization_key": "line2Label",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._validation_rule_type": "no_validation",
            "dynamic_fields.card.card_number._default_placeholder_text": "1234 1234 1234 1234",
            "dynamic_fields.billing.address.last_name._default_placeholder_text": "Last Name",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._render_when_prefilled": false,
            "dynamic_fields.card.card_exp_month._dropdown_options": [],
            "dynamic_fields.card.card_network._keyboard_type": "default",
            "dynamic_fields.card.card_number._max_input_length": 23,
            "dynamic_fields.bank_transfer.pix.pix_key._intent_data_read_path": "bank_transfer.pix.pix_key",
            "dynamic_fields.bank_redirect.blik.blik_code._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.city._layout_width_ratio": 1,
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._validation_rule_type": "no_validation",
            "dynamic_fields.bank_transfer.pix.pix_key._layout_row_id": "bank_transfer_pix_pix_key_row",
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._dropdown_options": [],
            "dynamic_fields.shipping.address.city._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.blik.blik_code._intent_data_read_path": "bank_redirect.blik.blik_code",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._html_autocomplete_attribute": "on",
            "dynamic_fields.billing.address.first_name._confirm_request_write_path": "payment_method_data.billing.address.first_name",
            "dynamic_fields.card.card_exp_year._dropdown_options": [],
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._html_autocomplete_attribute": "on",
            "dynamic_fields.card.card_exp_year._label_localization_key": "expiryYearLabel",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.address.zip._placeholder_localization_key": "postalCodePlaceholder",
            "dynamic_fields.billing.phone.country_code._is_required": false,
            "dynamic_fields.billing.address.line2._default_label_text": "Address Line 2",
            "dynamic_fields.billing.phone.country_code._dropdown_options": [],
            "dynamic_fields.billing.address.city._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._layout_width_ratio": 1,
            "dynamic_fields.billing.address.last_name._placeholder_localization_key": "lastNamePlaceholder",
            "dynamic_fields.shipping.phone.country_code._default_label_text": "Dialing Code",
            "dynamic_fields.wallet.mifinity.date_of_birth._confirm_request_write_path": "payment_method_data.wallet.mifinity.date_of_birth",
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._confirm_request_write_path": "payment_method_data.bank_redirect.open_banking_czech_republic.issuer",
            "dynamic_fields.bank_transfer.pix.pix_key._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.address.zip._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._intent_data_read_path": "bank_debit.ach_bank_debit.routing_number",
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._validation_rule_type": "no_validation",
            "dynamic_fields.billing.phone.number._default_placeholder_text": "000 000 000",
            "dynamic_fields.card.card_exp_month._keyboard_type": "numeric",
            "dynamic_fields.gift_card.cvc._render_when_prefilled": false,
            "dynamic_fields.gift_card.number._intent_data_read_path": "gift_card.givex.number",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._keyboard_type": "numeric",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._max_input_length": 255,
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._is_required": false,
            "dynamic_fields.shipping.address.first_name._layout_row_id": "shipping_address_first_name_row",
            "dynamic_fields.billing.address.zip._validation_rule_type": "no_validation",
            "dynamic_fields.customer.document_details.document_number._max_input_length": 255,
            "dynamic_fields.card.card_exp_month._label_localization_key": "expiryMonthLabel",
            "dynamic_fields.customer.document_details.document_type._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._extended_dropdown_options": [],
            "dynamic_fields.billing.address.country._extended_dropdown_options": [],
            "dynamic_fields.email._confirm_request_write_path": "email",
            "dynamic_fields.card.card_exp_year._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.ideal.bank_name._field_render_type": "BankNamesSelect",
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._dropdown_options": [
                "bangkok_bank",
                "krungsri_bank",
                "krung_thai_bank",
                "the_siam_commercial_bank",
                "kasikorn_bank"
            ],
            "dynamic_fields.shipping.phone.number._max_input_length": 14,
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._label_localization_key": "bankLabel",
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._is_required": false,
            "dynamic_fields.bank_redirect.ideal.bank_name._html_autocomplete_attribute": "on",
            "dynamic_fields.order_details.0.product_name._render_when_prefilled": false,
            "dynamic_fields.card.card_cvc._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._field_render_type": "Generic",
            "dynamic_fields.shipping.address.line2._field_render_type": "Generic",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._field_display_order": 370,
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._field_display_order": 460,
            "dynamic_fields.billing.phone.country_code._intent_data_read_path": "billing.phone.country_code",
            "dynamic_fields.billing.phone.number._max_input_length": 14,
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._layout_row_id": "bank_debit_bacs_bank_debit_account_number_row",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._default_placeholder_text": "000123456789",
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._confirm_request_write_path": "payment_method_data.bank_transfer.pix_automatico_push.bank_identifier",
            "dynamic_fields.billing.address.country._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._default_label_text": "Bank Issuer",
            "dynamic_fields.shipping.email._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._field_render_type": "BankNamesSelect",
            "dynamic_fields.wallet.mifinity.date_of_birth._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.country._dropdown_options": [
                "AC",
                "AD",
                "AE",
                "AF",
                "AG",
                "AI",
                "AL",
                "AM",
                "AO",
                "AQ",
                "AR",
                "AS",
                "AT",
                "AU",
                "AW",
                "AX",
                "AZ",
                "BA",
                "BB",
                "BD",
                "BE",
                "BF",
                "BG",
                "BH",
                "BI",
                "BJ",
                "BL",
                "BM",
                "BN",
                "BO",
                "BQ",
                "BR",
                "BS",
                "BT",
                "BV",
                "BW",
                "BY",
                "BZ",
                "CA",
                "CC",
                "CD",
                "CF",
                "CG",
                "CH",
                "CI",
                "CK",
                "CL",
                "CM",
                "CN",
                "CO",
                "CR",
                "CU",
                "CV",
                "CW",
                "CX",
                "CY",
                "CZ",
                "DE",
                "DJ",
                "DK",
                "DM",
                "DO",
                "DZ",
                "EC",
                "EE",
                "EG",
                "EH",
                "ER",
                "ES",
                "ET",
                "FI",
                "FJ",
                "FK",
                "FM",
                "FO",
                "FR",
                "GA",
                "GB",
                "GD",
                "GE",
                "GF",
                "GG",
                "GH",
                "GI",
                "GL",
                "GM",
                "GN",
                "GP",
                "GQ",
                "GR",
                "GS",
                "GT",
                "GU",
                "GW",
                "GY",
                "HK",
                "HM",
                "HN",
                "HR",
                "HT",
                "HU",
                "ID",
                "IE",
                "IL",
                "IM",
                "IN",
                "IO",
                "IQ",
                "IR",
                "IS",
                "IT",
                "JE",
                "JM",
                "JO",
                "JP",
                "KE",
                "KG",
                "KH",
                "KI",
                "KM",
                "KN",
                "KP",
                "KR",
                "KW",
                "KY",
                "KZ",
                "LA",
                "LB",
                "LC",
                "LI",
                "LK",
                "LR",
                "LS",
                "LT",
                "LU",
                "LV",
                "LY",
                "MA",
                "MC",
                "MD",
                "ME",
                "MF",
                "MG",
                "MH",
                "MK",
                "ML",
                "MM",
                "MN",
                "MO",
                "MP",
                "MQ",
                "MR",
                "MS",
                "MT",
                "MU",
                "MV",
                "MW",
                "MX",
                "MY",
                "MZ",
                "NA",
                "NC",
                "NE",
                "NF",
                "NG",
                "NI",
                "NL",
                "NO",
                "NP",
                "NR",
                "NU",
                "NZ",
                "OM",
                "PA",
                "PE",
                "PF",
                "PG",
                "PH",
                "PK",
                "PL",
                "PM",
                "PN",
                "PR",
                "PS",
                "PT",
                "PW",
                "PY",
                "QA",
                "RE",
                "RO",
                "RS",
                "RU",
                "RW",
                "SA",
                "SB",
                "SC",
                "SD",
                "SE",
                "SG",
                "SH",
                "SI",
                "SJ",
                "SK",
                "SL",
                "SM",
                "SN",
                "SO",
                "SR",
                "SS",
                "ST",
                "SV",
                "SX",
                "SY",
                "SZ",
                "TA",
                "TC",
                "TD",
                "TF",
                "TG",
                "TH",
                "TJ",
                "TK",
                "TL",
                "TM",
                "TN",
                "TO",
                "TR",
                "TT",
                "TV",
                "TW",
                "TZ",
                "UA",
                "UG",
                "UM",
                "US",
                "UY",
                "UZ",
                "VA",
                "VC",
                "VE",
                "VG",
                "VI",
                "VN",
                "VU",
                "WF",
                "WS",
                "XK",
                "YE",
                "YT",
                "ZA",
                "ZM",
                "ZW"
            ],
            "dynamic_fields.shipping.email._default_placeholder_text": "Email Address",
            "dynamic_fields.wallet.mifinity.date_of_birth._layout_row_id": "wallet_mifinity_date_of_birth_row",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.address.last_name._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.eps.bank_name._placeholder_localization_key": "formFieldBankNamePlaceholder",
            "dynamic_fields.card.card_network._html_autocomplete_attribute": "cc-type",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._field_render_type": "BankNamesSelect",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._default_label_text": "Bank Issuer",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._dropdown_options": [],
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._field_render_type": "BankNamesSelect",
            "dynamic_fields.customer.document_details.document_type._field_render_type": "Dropdown",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._extended_dropdown_options": [],
            "dynamic_fields.customer.document_details.document_number._intent_data_read_path": "customer.document_details.document_number",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._intent_data_read_path": "bank_transfer.pix_emv.source_bank_account_id",
            "dynamic_fields.crypto.network._confirm_request_write_path": "payment_method_data.crypto.network",
            "dynamic_fields.bank_redirect.blik.blik_code._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.email._label_localization_key": "emailLabel",
            "dynamic_fields.wallet.mifinity.date_of_birth._is_required": false,
            "dynamic_fields.customer.document_details.document_number._dropdown_options": [],
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._extended_dropdown_options": [],
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._placeholder_localization_key": "sortCodePlaceholder",
            "dynamic_fields.shipping.address.state._default_placeholder_text": "Select State",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._default_placeholder_text": "Select Bank Issuer",
            "dynamic_fields.description._layout_row_id": "description_row",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._max_input_length": 255,
            "dynamic_fields.wallet.mifinity.date_of_birth._extended_dropdown_options": [],
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._intent_data_read_path": "bank_debit.ach_bank_debit.account_number",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._label_localization_key": "formFieldBankAccountNumberLabel",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._field_display_order": 270,
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._keyboard_type": "numeric",
            "dynamic_fields.billing.address.line1._field_display_order": 540,
            "dynamic_fields.card.card_network._dropdown_options": [],
            "dynamic_fields.billing.phone.country_code._layout_width_ratio": 1,
            "dynamic_fields.order_details.0.product_name._keyboard_type": "default",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._intent_data_read_path": "bank_debit.becs_bank_debit.account_number",
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._field_display_order": 73,
            "dynamic_fields.shipping.address.zip._default_placeholder_text": "Postal Code",
            "dynamic_fields.shipping.address.city._intent_data_read_path": "shipping.address.city",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._label_localization_key": "bankLabel",
            "dynamic_fields.shipping.address.last_name._placeholder_localization_key": "lastNamePlaceholder",
            "dynamic_fields.billing.email._validation_rule_type": "regex",
            "dynamic_fields.bank_redirect.ideal.bank_name._input_format_pattern": "no_format_pattern",
            "dynamic_fields.card.card_number._field_render_type": "CardNumber",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._placeholder_localization_key": "formFieldPhoneNumberPlaceholder",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._validation_regex_pattern": ".*",
            "dynamic_fields.wallet.mifinity.language_preference._default_placeholder_text": "Select Language",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._is_required": false,
            "dynamic_fields.bank_redirect.ideal.bank_name._field_display_order": 150,
            "dynamic_fields.shipping.address.city._is_required": false,
            "dynamic_fields.gift_card.givex.number._layout_row_id": "gift_card_givex_number_row",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._label_localization_key": "pixKeyLabel",
            "dynamic_fields.card.card_exp_year._field_display_order": 30,
            "dynamic_fields.billing.email._is_required": false,
            "dynamic_fields.card.card_network._label_localization_key": "cardNetworkLabel",
            "dynamic_fields.email._field_render_type": "Email",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._default_label_text": "Account Number",
            "dynamic_fields.shipping.address.country._dropdown_options": [
                "AC",
                "AD",
                "AE",
                "AF",
                "AG",
                "AI",
                "AL",
                "AM",
                "AO",
                "AQ",
                "AR",
                "AS",
                "AT",
                "AU",
                "AW",
                "AX",
                "AZ",
                "BA",
                "BB",
                "BD",
                "BE",
                "BF",
                "BG",
                "BH",
                "BI",
                "BJ",
                "BL",
                "BM",
                "BN",
                "BO",
                "BQ",
                "BR",
                "BS",
                "BT",
                "BV",
                "BW",
                "BY",
                "BZ",
                "CA",
                "CC",
                "CD",
                "CF",
                "CG",
                "CH",
                "CI",
                "CK",
                "CL",
                "CM",
                "CN",
                "CO",
                "CR",
                "CU",
                "CV",
                "CW",
                "CX",
                "CY",
                "CZ",
                "DE",
                "DJ",
                "DK",
                "DM",
                "DO",
                "DZ",
                "EC",
                "EE",
                "EG",
                "EH",
                "ER",
                "ES",
                "ET",
                "FI",
                "FJ",
                "FK",
                "FM",
                "FO",
                "FR",
                "GA",
                "GB",
                "GD",
                "GE",
                "GF",
                "GG",
                "GH",
                "GI",
                "GL",
                "GM",
                "GN",
                "GP",
                "GQ",
                "GR",
                "GS",
                "GT",
                "GU",
                "GW",
                "GY",
                "HK",
                "HM",
                "HN",
                "HR",
                "HT",
                "HU",
                "ID",
                "IE",
                "IL",
                "IM",
                "IN",
                "IO",
                "IQ",
                "IR",
                "IS",
                "IT",
                "JE",
                "JM",
                "JO",
                "JP",
                "KE",
                "KG",
                "KH",
                "KI",
                "KM",
                "KN",
                "KP",
                "KR",
                "KW",
                "KY",
                "KZ",
                "LA",
                "LB",
                "LC",
                "LI",
                "LK",
                "LR",
                "LS",
                "LT",
                "LU",
                "LV",
                "LY",
                "MA",
                "MC",
                "MD",
                "ME",
                "MF",
                "MG",
                "MH",
                "MK",
                "ML",
                "MM",
                "MN",
                "MO",
                "MP",
                "MQ",
                "MR",
                "MS",
                "MT",
                "MU",
                "MV",
                "MW",
                "MX",
                "MY",
                "MZ",
                "NA",
                "NC",
                "NE",
                "NF",
                "NG",
                "NI",
                "NL",
                "NO",
                "NP",
                "NR",
                "NU",
                "NZ",
                "OM",
                "PA",
                "PE",
                "PF",
                "PG",
                "PH",
                "PK",
                "PL",
                "PM",
                "PN",
                "PR",
                "PS",
                "PT",
                "PW",
                "PY",
                "QA",
                "RE",
                "RO",
                "RS",
                "RU",
                "RW",
                "SA",
                "SB",
                "SC",
                "SD",
                "SE",
                "SG",
                "SH",
                "SI",
                "SJ",
                "SK",
                "SL",
                "SM",
                "SN",
                "SO",
                "SR",
                "SS",
                "ST",
                "SV",
                "SX",
                "SY",
                "SZ",
                "TA",
                "TC",
                "TD",
                "TF",
                "TG",
                "TH",
                "TJ",
                "TK",
                "TL",
                "TM",
                "TN",
                "TO",
                "TR",
                "TT",
                "TV",
                "TW",
                "TZ",
                "UA",
                "UG",
                "UM",
                "US",
                "UY",
                "UZ",
                "VA",
                "VC",
                "VE",
                "VG",
                "VI",
                "VN",
                "VU",
                "WF",
                "WS",
                "XK",
                "YE",
                "YT",
                "ZA",
                "ZM",
                "ZW"
            ],
            "dynamic_fields.shipping.address.zip._label_localization_key": "postalCodeLabel",
            "dynamic_fields.shipping.phone.country_code._html_autocomplete_attribute": "shipping tel-country-code",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._input_format_pattern": "no_format_pattern",
            "dynamic_fields.shipping.address.city._field_display_order": 650,
            "dynamic_fields.card.card_cvc._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._default_placeholder_text": "1234 1234 1234 1234",
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._placeholder_localization_key": "bankIssuerPlaceholder",
            "dynamic_fields.gift_card.cvc._layout_width_ratio": 1,
            "dynamic_fields.shipping.address.line1._dropdown_options": [],
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._layout_row_id": "bank_redirect_online_banking_czech_republic_issuer_row",
            "dynamic_fields.description._intent_data_read_path": "description",
            "dynamic_fields.crypto.network._intent_data_read_path": "crypto.network",
            "dynamic_fields.billing.address.state._confirm_request_write_path": "payment_method_data.billing.address.state",
            "dynamic_fields.gift_card.givex.number._keyboard_type": "numeric",
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._default_label_text": "Sort Code",
            "dynamic_fields.customer.document_details.document_type._layout_width_ratio": 1,
            "dynamic_fields.card.card_network._default_placeholder_text": "Select Card Network",
            "dynamic_fields.billing.address.zip._is_required": false,
            "dynamic_fields.shipping.address.line2._dropdown_options": [],
            "dynamic_fields.wallet.mifinity.language_preference._layout_row_id": "wallet_mifinity_language_preference_row",
            "dynamic_fields.description._validation_rule_type": "no_validation",
            "dynamic_fields.billing.phone.country_code._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.city._intent_data_read_path": "billing.address.city",
            "dynamic_fields.billing.address.state._layout_row_id": "billing_city_state_row",
            "dynamic_fields.billing.address.country._label_localization_key": "countryLabel",
            "dynamic_fields.card.card_exp_year._default_label_text": "Expiry Year",
            "dynamic_fields.voucher.boleto.social_security_number._render_when_prefilled": false,
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._placeholder_localization_key": "sourceBankAccountIdPlaceholder",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._is_required": false,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._keyboard_type": "default",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._confirm_request_write_path": "payment_method_data.bank_debit.bacs_bank_debit.sort_code",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._keyboard_type": "numeric",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._default_label_text": "IBAN",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._default_placeholder_text": "Select Bank Issuer",
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._intent_data_read_path": "bank_redirect.open_banking_czech_republic.issuer",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._is_required": false,
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._field_render_type": "BankNamesSelect",
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.phone.country_code._layout_row_id": "billing_phone_row",
            "dynamic_fields.billing.address.state._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.phone.number._default_label_text": "Phone Number",
            "dynamic_fields.customer.document_details.document_type._label_localization_key": "documentTypeLabel",
            "dynamic_fields.gift_card.givex.cvc._default_label_text": "Gift Card PIN",
            "dynamic_fields.shipping.address.first_name._default_label_text": "First Name",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._default_label_text": "Bank Issuer",
            "dynamic_fields.billing.phone.number._field_render_type": "Phone",
            "dynamic_fields.shipping.address.state._placeholder_localization_key": "statePlaceholder",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._default_placeholder_text": "Select Bank Issuer",
            "dynamic_fields.shipping.phone.number._field_display_order": 690,
            "dynamic_fields.crypto.pay_currency._field_display_order": 200,
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._html_autocomplete_attribute": "on",
            "dynamic_fields.shipping.address.line1._field_render_type": "Generic",
            "dynamic_fields.customer.document_details.document_number._label_localization_key": "documentNumberLabel",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._default_placeholder_text": "Source Bank Account ID",
            "dynamic_fields.bank_redirect.ideal.bank_name._layout_row_id": "bank_redirect_ideal_bank_name_row",
            "dynamic_fields.billing.address.state._default_placeholder_text": "Select State",
            "dynamic_fields.customer.document_details.document_type._field_display_order": 220,
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._confirm_request_write_path": "payment_method_data.bank_redirect.online_banking_fpx.issuer",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._placeholder_localization_key": "ibanPlaceholder",
            "dynamic_fields.wallet.mifinity.language_preference._label_localization_key": "languagePreferenceLabel",
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._default_placeholder_text": "Select Bank Issuer",
            "dynamic_fields.wallet.mifinity.language_preference._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._intent_data_read_path": "bank_redirect.open_banking_uk.issuer",
            "dynamic_fields.shipping.address.state._field_display_order": 660,
            "dynamic_fields.bank_transfer.pix.pix_key._label_localization_key": "pixKeyLabel",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._max_input_length": 255,
            "dynamic_fields.billing.phone.number._field_display_order": 530,
            "dynamic_fields.bank_transfer.pix_emv.pix_key._dropdown_options": [],
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._default_label_text": "Bank Issuer",
            "dynamic_fields.bank_transfer.pix.pix_key._default_placeholder_text": "Enter Pix key.",
            "dynamic_fields.billing.phone.country_code._render_when_prefilled": false,
            "dynamic_fields.shipping.phone.number._is_required": false,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._max_input_length": 255,
            "dynamic_fields.shipping.email._layout_width_ratio": 1,
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._field_render_type": "Generic",
            "dynamic_fields.upi.upi_collect.vpa_id._label_localization_key": "vpaIdLabel",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._intent_data_read_path": "bank_redirect.online_banking_fpx.issuer",
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._max_input_length": 6,
            "dynamic_fields.billing.phone.number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._input_format_pattern": "no_format_pattern",
            "dynamic_fields.shipping.address.line2._confirm_request_write_path": "shipping.address.line2",
            "dynamic_fields.billing.email._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._render_when_prefilled": false,
            "dynamic_fields.description._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.phone.number._confirm_request_write_path": "payment_method_data.billing.phone.number",
            "dynamic_fields.gift_card.number._max_input_length": 255,
            "dynamic_fields.crypto.pay_currency._max_input_length": 255,
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._confirm_request_write_path": "payment_method_data.bank_redirect.online_banking_czech_republic.issuer",
            "dynamic_fields.shipping.email._layout_row_id": "shipping_email_row",
            "dynamic_fields.billing.phone.country_code._max_input_length": 255,
            "dynamic_fields.gift_card.givex.number._is_required": false,
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._extended_dropdown_options": [],
            "dynamic_fields.gift_card.givex.cvc._html_autocomplete_attribute": "on",
            "dynamic_fields.shipping.address.first_name._html_autocomplete_attribute": "shipping given-name",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._keyboard_type": "numeric",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._extended_dropdown_options": [],
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._field_display_order": 380,
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._is_required": false,
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._default_placeholder_text": "Select Bank Issuer",
            "dynamic_fields.card.card_network._layout_width_ratio": 1,
            "dynamic_fields.crypto.pay_currency._label_localization_key": "currencyLabel",
            "dynamic_fields.shipping.address.last_name._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.state._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._validation_rule_type": "no_validation",
            "dynamic_fields.customer.document_details.document_type._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._render_when_prefilled": false,
            "dynamic_fields.billing.phone.number._placeholder_localization_key": "",
            "dynamic_fields.email._keyboard_type": "email-address",
            "dynamic_fields.customer.document_details.document_number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._dropdown_options": [
                "e_platby_v_u_b",
                "postova_banka",
                "sporo_pay",
                "tatra_pay",
                "viamo",
                "volksbank_gruppe",
                "volkskreditbank_ag",
                "vr_bank_braunau"
            ],
            "dynamic_fields.gift_card.cvc._is_required": false,
            "dynamic_fields.shipping.phone.number._keyboard_type": "phone-pad",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._intent_data_read_path": "bank_transfer.pix.source_bank_account_id",
            "dynamic_fields.card.card_cvc._placeholder_localization_key": "cvcPlaceholder",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._is_required": false,
            "dynamic_fields.bank_redirect.blik.blik_code._label_localization_key": "blikCodeLabel",
            "dynamic_fields.crypto.network._field_render_type": "CryptoNetwork",
            "dynamic_fields.billing.address.last_name._html_autocomplete_attribute": "billing family-name",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._html_autocomplete_attribute": "on",
            "dynamic_fields.gift_card.givex.number._field_display_order": 410,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._default_placeholder_text": "Select Month",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._is_required": false,
            "dynamic_fields.wallet.mifinity.language_preference._intent_data_read_path": "wallet.mifinity.language_preference",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._placeholder_localization_key": "bankIssuerPlaceholder",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._extended_dropdown_options": [],
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._field_display_order": 400,
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._intent_data_read_path": "bank_debit.bacs_bank_debit.account_number",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._layout_row_id": "bank_redirect_online_banking_slovakia_issuer_row",
            "dynamic_fields.card.card_exp_year._placeholder_localization_key": "expiryYearPlaceholder",
            "dynamic_fields.card.card_cvc._dropdown_options": [],
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._dropdown_options": [
                "ceska_sporitelna",
                "komercni_banka",
                "platnosc_online_karta_platnicza"
            ],
            "dynamic_fields.customer.document_details.document_type._max_input_length": 255,
            "dynamic_fields.email._is_required": false,
            "dynamic_fields.bank_redirect.ideal.bank_name._is_required": false,
            "dynamic_fields.bank_redirect.ideal.bank_name._placeholder_localization_key": "formFieldBankNamePlaceholder",
            "dynamic_fields.email._default_placeholder_text": "Email",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._label_localization_key": "formFieldPhoneNumberLabel",
            "dynamic_fields.gift_card.number._label_localization_key": "giftCardNumberLabel",
            "dynamic_fields.order_details.0.product_name._dropdown_options": [],
            "dynamic_fields.wallet.mifinity.language_preference._placeholder_localization_key": "languagePreferencePlaceholder",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._render_when_prefilled": false,
            "dynamic_fields.upi.upi_collect.vpa_id._intent_data_read_path": "upi.upi_collect.vpa_id",
            "dynamic_fields.description._keyboard_type": "default",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._render_when_prefilled": false,
            "dynamic_fields.shipping.address.country._label_localization_key": "countryLabel",
            "dynamic_fields.billing.address.first_name._keyboard_type": "default",
            "dynamic_fields.gift_card.givex.cvc._placeholder_localization_key": "giftCardPinPlaceholder",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._max_input_length": 8,
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._render_when_prefilled": false,
            "dynamic_fields.shipping.address.line2._render_when_prefilled": false,
            "dynamic_fields.order_details.0.product_name._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.eps.bank_name._dropdown_options": [
                "AbnAmro",
                "ArzteUndApothekerBank",
                "AsnBank",
                "AustrianAnadiBankAg",
                "BankAustria",
                "BankhausCarlSpangler",
                "BankhausSchelhammerUndSchatteraAg",
                "BawagPskAg",
                "BksBankAg",
                "BrullKallmusBankAg",
                "BtvVierLanderBank",
                "Bunq",
                "CapitalBankGraweGruppeAg",
                "Citi",
                "Dolomitenbank",
                "EasybankAg",
                "ErsteBankUndSparkassen",
                "Handelsbanken",
                "HypoAlpeadriabankInternationalAg",
                "HypoNoeLbFurNiederosterreichUWien",
                "HypoOberosterreichSalzburgSteiermark",
                "HypoTirolBankAg",
                "HypoVorarlbergBankAg",
                "HypoBankBurgenlandAktiengesellschaft",
                "Ing",
                "Knab",
                "MarchfelderBank",
                "OberbankAg",
                "RaiffeisenBankengruppeOsterreich",
                "Rabobank",
                "Regiobank",
                "Revolut",
                "SnsBank",
                "TriodosBank",
                "VanLanschot",
                "Moneyou",
                "SchoellerbankAg",
                "SpardaBankWien",
                "VolksbankGruppe",
                "VolkskreditbankAg",
                "VrBankBraunau",
                "PlusBank"
            ],
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._confirm_request_write_path": "payment_method_data.bank_transfer.pix.source_bank_account_id",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._extended_dropdown_options": [],
            "dynamic_fields.billing.address.zip._dropdown_options": [],
            "dynamic_fields.billing.address.first_name._html_autocomplete_attribute": "billing given-name",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._placeholder_localization_key": "cardNumberPlaceholder",
            "dynamic_fields.billing.email._html_autocomplete_attribute": "billing email",
            "dynamic_fields.customer.document_details.document_type._confirm_request_write_path": "customer.document_details.document_type",
            "dynamic_fields.order_details.0.product_name._validation_regex_pattern": ".*",
            "dynamic_fields.upi.upi_collect.vpa_id._keyboard_type": "default",
            "dynamic_fields.billing.address.state._intent_data_read_path": "billing.address.state",
            "dynamic_fields.order_details.0.product_name._label_localization_key": "productNameLabel",
            "dynamic_fields.shipping.address.city._default_label_text": "City",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._placeholder_localization_key": "bankIssuerPlaceholder",
            "dynamic_fields.bank_transfer.pix.pix_key._field_display_order": 360,
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._validation_rule_type": "no_validation",
            "dynamic_fields.crypto.pay_currency._dropdown_options": [
                "BTC",
                "LTC",
                "ETH",
                "XRP",
                "XLM",
                "BCH",
                "ADA",
                "SOL",
                "SHIB",
                "TRX",
                "DOGE",
                "BNB",
                "USDT",
                "USDC",
                "DAI"
            ],
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._html_autocomplete_attribute": "on",
            "dynamic_fields.wallet.mifinity.date_of_birth._field_display_order": 180,
            "dynamic_fields.voucher.boleto.social_security_number._confirm_request_write_path": "payment_method_data.voucher.boleto.social_security_number",
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._intent_data_read_path": "bank_redirect.open_banking_slovakia.issuer",
            "dynamic_fields.crypto.network._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.eps.bank_name._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.state._html_autocomplete_attribute": "shipping address-level1",
            "dynamic_fields.shipping.address.state._intent_data_read_path": "shipping.address.state",
            "dynamic_fields.card.card_number._default_label_text": "Card Number",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._render_when_prefilled": false,
            "dynamic_fields.gift_card.givex.cvc._max_input_length": 255,
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._html_autocomplete_attribute": "on",
            "dynamic_fields.shipping.email._max_input_length": 254,
            "dynamic_fields.bank_transfer.pix_emv.pix_key._placeholder_localization_key": "pixKeyPlaceholder",
            "dynamic_fields.billing.address.first_name._placeholder_localization_key": "fullNamePlaceholder",
            "dynamic_fields.shipping.address.country._max_input_length": 255,
            "dynamic_fields.billing.address.first_name._default_placeholder_text": "First Name",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._layout_row_id": "bank_debit_ach_bank_debit_bank_account_holder_name_row",
            "dynamic_fields.bank_transfer.pix.pix_key._layout_width_ratio": 1,
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.zip._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.line1._dropdown_options": [],
            "dynamic_fields.bank_transfer.pix_emv.pix_key._default_label_text": "PIX Key",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._layout_row_id": "bank_redirect_open_banking_thailand_issuer_row",
            "dynamic_fields.billing.address.city._layout_row_id": "billing_city_state_row",
            "dynamic_fields.card.card_network._field_display_order": 50,
            "dynamic_fields.shipping.address.state._is_required": false,
            "dynamic_fields.upi.upi_collect.vpa_id._default_placeholder_text": "Eg: johndoe@upi",
            "dynamic_fields.billing.address.zip._confirm_request_write_path": "payment_method_data.billing.address.zip",
            "dynamic_fields.wallet.mifinity.date_of_birth._max_input_length": 255,
            "dynamic_fields.bank_redirect.blik.blik_code._field_display_order": 170,
            "dynamic_fields.order_details.0.product_name._html_autocomplete_attribute": "on",
            "dynamic_fields.order_details.0.product_name._field_display_order": 470,
            "dynamic_fields.card.card_number._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._field_render_type": "Generic",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._confirm_request_write_path": "payment_method_data.bank_redirect.bancontact_card.card_exp_month",
            "dynamic_fields.shipping.address.first_name._is_required": false,
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._field_display_order": 70,
            "dynamic_fields.customer.document_details.document_type._html_autocomplete_attribute": "on",
            "dynamic_fields.shipping.address.line1._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._extended_dropdown_options": [],
            "dynamic_fields.crypto.pay_currency._extended_dropdown_options": [],
            "dynamic_fields.billing.address.first_name._dropdown_options": [],
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._intent_data_read_path": "bank_redirect.bancontact_card.card_exp_year",
            "dynamic_fields.bank_redirect.blik.blik_code._keyboard_type": "numeric",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._validation_rule_type": "no_validation",
            "dynamic_fields.billing.phone.number._html_autocomplete_attribute": "billing tel-national",
            "dynamic_fields.card.card_number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.customer.document_details.document_number._placeholder_localization_key": "documentNumberPlaceholder",
            "dynamic_fields.billing.address.last_name._field_display_order": 490,
            "dynamic_fields.email._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._default_label_text": "Bank Issuer",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._layout_width_ratio": 1,
            "dynamic_fields.crypto.pay_currency._is_required": false,
            "dynamic_fields.email._intent_data_read_path": "email",
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._dropdown_options": [
                "e_platby_v_u_b",
                "postova_banka",
                "sporo_pay",
                "tatra_pay",
                "viamo",
                "volksbank_gruppe",
                "volkskreditbank_ag",
                "vr_bank_braunau"
            ],
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._is_required": false,
            "dynamic_fields.billing.address.line1._placeholder_localization_key": "line1Placeholder",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._is_required": false,
            "dynamic_fields.shipping.address.city._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.address.zip._default_label_text": "ZIP/Postal Code",
            "dynamic_fields.upi.upi_collect.vpa_id._dropdown_options": [],
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._dropdown_options": [
                "ceska_sporitelna",
                "komercni_banka",
                "platnosc_online_karta_platnicza"
            ],
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._extended_dropdown_options": [],
            "dynamic_fields.voucher.boleto.social_security_number._default_placeholder_text": "Enter Pix CPF.",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._is_required": false,
            "dynamic_fields.shipping.address.first_name._intent_data_read_path": "shipping.address.first_name",
            "dynamic_fields.shipping.address.country._field_display_order": 680,
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.ideal.bank_name._dropdown_options": [
                "abn_amro",
                "asn_bank",
                "bunq",
                "handelsbanken",
                "ing",
                "knab",
                "moneyou",
                "n26",
                "nationale_nederlanden",
                "rabobank",
                "regiobank",
                "revolut",
                "sns_bank",
                "triodos_bank",
                "van_lanschot",
                "yoursafe"
            ],
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._validation_regex_pattern": ".*",
            "dynamic_fields.gift_card.givex.cvc._layout_row_id": "gift_card_givex_cvc_row",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._max_input_length": 255,
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._confirm_request_write_path": "payment_method_data.bank_debit.becs_bank_debit.sort_code",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._placeholder_localization_key": "routingNumberPlaceholder",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._placeholder_localization_key": "sourceBankAccountIdPlaceholder",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._validation_rule_type": "no_validation",
            "dynamic_fields.gift_card.number._validation_rule_type": "no_validation",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._keyboard_type": "default",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._keyboard_type": "default",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._placeholder_localization_key": "bankIssuerPlaceholder",
            "dynamic_fields.billing.phone.country_code._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._default_label_text": "Bank Issuer",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._layout_width_ratio": 1,
            "dynamic_fields.billing.address.last_name._keyboard_type": "default",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.address.city._field_display_order": 560,
            "dynamic_fields.card.card_cvc._intent_data_read_path": "card.card_cvc",
            "dynamic_fields.shipping.address.first_name._field_render_type": "FirstName",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._validation_rule_type": "no_validation",
            "dynamic_fields.customer.document_details.document_number._validation_rule_type": "no_validation",
            "dynamic_fields.bank_transfer.pix.pix_key._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._confirm_request_write_path": "payment_method_data.bank_debit.ach_bank_debit.bank_account_holder_name",
            "dynamic_fields.shipping.address.state._field_render_type": "State",
            "dynamic_fields.billing.address.country._layout_row_id": "billing_country_postal_row",
            "dynamic_fields.billing.phone.number._keyboard_type": "phone-pad",
            "dynamic_fields.billing.address.country._intent_data_read_path": "billing.address.country",
            "dynamic_fields.bank_transfer.pix.pix_key._validation_regex_pattern": ".*",
            "dynamic_fields.order_details.0.product_name._layout_width_ratio": 1,
            "dynamic_fields.billing.address.city._keyboard_type": "default",
            "dynamic_fields.billing.address.line2._default_placeholder_text": "Apt., unit number, etc (optional)",
            "dynamic_fields.billing.address.state._field_render_type": "State",
            "dynamic_fields.billing.address.last_name._intent_data_read_path": "billing.address.last_name",
            "dynamic_fields.customer.document_details.document_type._render_when_prefilled": false,
            "dynamic_fields.description._placeholder_localization_key": "descriptionPlaceholder",
            "dynamic_fields.gift_card.givex.number._validation_rule_type": "no_validation",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._confirm_request_write_path": "payment_method_data.bank_transfer.pix_emv.pix_key",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._keyboard_type": "default",
            "dynamic_fields.bank_redirect.eps.bank_name._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._layout_row_id": "bank_transfer_pix_emv_source_bank_account_id_row",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._dropdown_options": [],
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._default_label_text": "Bank Issuer",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._dropdown_options": [],
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._max_input_length": 15,
            "dynamic_fields.order_details.0.product_name._default_label_text": "Product Name",
            "dynamic_fields.wallet.mifinity.date_of_birth._dropdown_options": [],
            "dynamic_fields.shipping.phone.country_code._is_required": false,
            "dynamic_fields.billing.address.last_name._is_required": false,
            "dynamic_fields.billing.address.zip._html_autocomplete_attribute": "billing postal-code",
            "dynamic_fields.crypto.pay_currency._placeholder_localization_key": "currencyPlaceholder",
            "dynamic_fields.billing.address.line2._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._layout_width_ratio": 1,
            "dynamic_fields.description._render_when_prefilled": false,
            "dynamic_fields.billing.address.last_name._default_label_text": "Last Name",
            "dynamic_fields.crypto.network._is_required": false,
            "dynamic_fields.upi.upi_collect.vpa_id._max_input_length": 255,
            "dynamic_fields.shipping.address.line1._label_localization_key": "line1Label",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._is_required": false,
            "dynamic_fields.card.card_exp_year._keyboard_type": "numeric",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._max_input_length": 255,
            "dynamic_fields.shipping.address.first_name._keyboard_type": "default",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._field_display_order": 290,
            "dynamic_fields.gift_card.cvc._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.city._is_required": false,
            "dynamic_fields.shipping.phone.country_code._intent_data_read_path": "shipping.phone.country_code",
            "dynamic_fields.shipping.phone.country_code._dropdown_options": [],
            "dynamic_fields.billing.address.line1._layout_row_id": "billing_address_line1_row",
            "dynamic_fields.card.card_exp_month._field_display_order": 20,
            "dynamic_fields.bank_redirect.eps.bank_name._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._placeholder_localization_key": "sortCodePlaceholder",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.line1._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._is_required": false,
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.email._validation_rule_type": "regex",
            "dynamic_fields.shipping.address.zip._confirm_request_write_path": "shipping.address.zip",
            "dynamic_fields.gift_card.cvc._default_placeholder_text": "123456",
            "dynamic_fields.card.card_number._field_display_order": 10,
            "dynamic_fields.billing.address.first_name._validation_rule_type": "no_validation",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._label_localization_key": "sortCodeText",
            "dynamic_fields.wallet.mifinity.date_of_birth._default_label_text": "Date of Birth",
            "dynamic_fields.email._default_label_text": "Email",
            "dynamic_fields.billing.address.country._input_format_pattern": "no_format_pattern",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._keyboard_type": "default",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._layout_row_id": "bank_debit_becs_bank_debit_bsb_number_row",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._confirm_request_write_path": "payment_method_data.bank_debit.sepa_bank_debit.iban",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._label_localization_key": "expiryMonthLabel",
            "dynamic_fields.billing.address.last_name._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._label_localization_key": "bankLabel",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._render_when_prefilled": false,
            "dynamic_fields.card.card_network._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._layout_row_id": "bank_redirect_open_banking_uk_issuer_row",
            "dynamic_fields.billing.address.country._render_when_prefilled": false,
            "dynamic_fields.gift_card.givex.number._default_placeholder_text": "ABCD1234EFGH5678",
            "dynamic_fields.gift_card.cvc._confirm_request_write_path": "payment_method_data.gift_card.givex.cvc",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._layout_width_ratio": 1,
            "dynamic_fields.crypto.network._default_placeholder_text": "Network",
            "dynamic_fields.shipping.address.first_name._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._input_format_pattern": "no_format_pattern",
            "dynamic_fields.customer.document_details.document_number._keyboard_type": "default",
            "dynamic_fields.billing.address.zip._field_render_type": "Generic",
            "dynamic_fields.billing.address.country._default_placeholder_text": "Select Country",
            "dynamic_fields.email._html_autocomplete_attribute": "email",
            "dynamic_fields.shipping.address.line2._layout_row_id": "shipping_address_line2_row",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._field_display_order": 74,
            "dynamic_fields.card.card_cvc._default_placeholder_text": "123",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._max_input_length": 255,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._extended_dropdown_options": [],
            "dynamic_fields.billing.address.state._render_when_prefilled": false,
            "dynamic_fields.gift_card.givex.cvc._layout_width_ratio": 1,
            "dynamic_fields.card.card_exp_year._layout_row_id": "card_card_exp_year_row",
            "dynamic_fields.shipping.address.country._layout_row_id": "shipping_address_country_row",
            "dynamic_fields.billing.address.state._html_autocomplete_attribute": "billing address-level1",
            "dynamic_fields.shipping.phone.number._dropdown_options": [],
            "dynamic_fields.bank_redirect.bancontact_card.card_number._extended_dropdown_options": [],
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._extended_dropdown_options": [],
            "dynamic_fields.crypto.pay_currency._default_label_text": "Currency",
            "dynamic_fields.bank_redirect.ideal.bank_name._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.first_name._intent_data_read_path": "billing.address.first_name",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._intent_data_read_path": "bank_redirect.open_banking_thailand.issuer",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.eps.bank_name._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._dropdown_options": [
                "blik_p_s_p",
                "place_z_i_p_k_o",
                "m_bank",
                "pay_with_i_n_g",
                "santander_przelew24",
                "bank_p_e_k_a_o_s_a",
                "bank_millennium",
                "pay_with_alior_bank",
                "banki_spoldzielcze",
                "pay_with_inteligo",
                "b_n_p_paribas_poland",
                "bank_nowy_s_a",
                "credit_agricole",
                "pay_with_b_o_s",
                "pay_with_citi_handlowy",
                "pay_with_plus_bank",
                "toyota_bank",
                "velo_bank",
                "e_transfer_pocztowy24"
            ],
            "dynamic_fields.shipping.address.line2._intent_data_read_path": "shipping.address.line2",
            "dynamic_fields.shipping.address.line1._html_autocomplete_attribute": "shipping address-line1",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._input_format_pattern": "***-***",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._is_required": false,
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.first_name._is_required": false,
            "dynamic_fields.crypto.network._field_display_order": 210,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._field_display_order": 280,
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._field_display_order": 350,
            "dynamic_fields.customer.document_details.document_number._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._field_display_order": 130,
            "dynamic_fields.voucher.boleto.social_security_number._keyboard_type": "numeric",
            "dynamic_fields.shipping.address.last_name._label_localization_key": "lastName",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._field_display_order": 71,
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._layout_row_id": "bank_redirect_online_banking_thailand_issuer_row",
            "dynamic_fields.gift_card.cvc._keyboard_type": "numeric",
            "dynamic_fields.bank_redirect.ideal.bank_name._default_placeholder_text": "Bank Name",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._dropdown_options": [],
            "dynamic_fields.card.card_exp_month._intent_data_read_path": "card.card_exp_month",
            "dynamic_fields.bank_redirect.blik.blik_code._confirm_request_write_path": "payment_method_data.bank_redirect.blik.blik_code",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._label_localization_key": "cardNumberLabel",
            "dynamic_fields.order_details.0.product_name._intent_data_read_path": "order_details.0.product_name",
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._label_localization_key": "sortCodeText",
            "dynamic_fields.billing.address.line2._keyboard_type": "default",
            "dynamic_fields.bank_redirect.eps.bank_name._is_required": false,
            "dynamic_fields.billing.address.line1._max_input_length": 255,
            "dynamic_fields.shipping.phone.country_code._default_placeholder_text": "Select Dialing Code",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._confirm_request_write_path": "payment_method_data.bank_debit.ach_bank_debit.account_number",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._max_input_length": 42,
            "dynamic_fields.card.card_exp_month._default_placeholder_text": "Select Month",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._is_required": false,
            "dynamic_fields.billing.address.city._default_placeholder_text": "City",
            "dynamic_fields.wallet.mifinity.language_preference._html_autocomplete_attribute": "on",
            "dynamic_fields.shipping.email._dropdown_options": [],
            "dynamic_fields.card.card_number._is_required": false,
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._is_required": false,
            "dynamic_fields.card.card_number._placeholder_localization_key": "cardNumberPlaceholder",
            "dynamic_fields.shipping.address.zip._dropdown_options": [],
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._field_render_type": "BankNamesSelect",
            "dynamic_fields.bank_transfer.pix.pix_key._field_render_type": "Generic",
            "dynamic_fields.bank_transfer.pix.pix_key._placeholder_localization_key": "pixKeyPlaceholder",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._validation_rule_type": "no_validation",
            "dynamic_fields.crypto.pay_currency._html_autocomplete_attribute": "on",
            "dynamic_fields.customer.document_details.document_number._layout_row_id": "customer_document_details_document_number_row",
            "dynamic_fields.shipping.address.last_name._html_autocomplete_attribute": "shipping family-name",
            "dynamic_fields.billing.phone.country_code._label_localization_key": "",
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._intent_data_read_path": "bank_redirect.online_banking_thailand.issuer",
            "dynamic_fields.wallet.mifinity.language_preference._is_required": false,
            "dynamic_fields.shipping.email._confirm_request_write_path": "shipping.email",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._label_localization_key": "bankLabel",
            "dynamic_fields.shipping.address.last_name._field_display_order": 610,
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._validation_rule_type": "no_validation",
            "dynamic_fields.upi.upi_collect.vpa_id._render_when_prefilled": false,
            "dynamic_fields.shipping.address.country._validation_rule_type": "no_validation",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._dropdown_options": [],
            "dynamic_fields.billing.address.city._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._label_localization_key": "bankLabel",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._intent_data_read_path": "bank_transfer.pix_automatico_push.branch_code",
            "dynamic_fields.billing.email._field_display_order": 510,
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._intent_data_read_path": "bank_debit.bacs_bank_debit.sort_code",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._validation_rule_type": "no_validation",
            "dynamic_fields.shipping.address.city._default_placeholder_text": "City",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._validation_rule_type": "no_validation",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._confirm_request_write_path": "payment_method_data.bank_transfer.pix_emv.source_bank_account_id",
            "dynamic_fields.shipping.email._placeholder_localization_key": "emailLabel",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._render_when_prefilled": false,
            "dynamic_fields.billing.address.last_name._input_format_pattern": "no_format_pattern",
            "dynamic_fields.wallet.mifinity.date_of_birth._field_render_type": "DateOfBirth",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._layout_row_id": "bank_redirect_online_banking_fpx_issuer_row",
            "dynamic_fields.shipping.address.last_name._keyboard_type": "default",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._layout_width_ratio": 1,
            "dynamic_fields.gift_card.number._keyboard_type": "numeric",
            "dynamic_fields.voucher.boleto.social_security_number._extended_dropdown_options": [],
            "dynamic_fields.order_details.0.product_name._field_render_type": "Generic",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._layout_width_ratio": 1,
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.customer.document_details.document_number._render_when_prefilled": false,
            "dynamic_fields.shipping.address.line2._html_autocomplete_attribute": "shipping address-line2",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._validation_regex_pattern": ".*",
            "dynamic_fields.gift_card.givex.cvc._keyboard_type": "numeric",
            "dynamic_fields.shipping.phone.country_code._layout_row_id": "shipping_phone_country_code_row",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._render_when_prefilled": false,
            "dynamic_fields.shipping.address.line1._confirm_request_write_path": "shipping.address.line1",
            "dynamic_fields.shipping.address.line1._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._extended_dropdown_options": [],
            "dynamic_fields.billing.address.zip._layout_width_ratio": 1,
            "dynamic_fields.customer.document_details.document_type._dropdown_options": [],
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._render_when_prefilled": false,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._html_autocomplete_attribute": "on",
            "dynamic_fields.billing.address.country._html_autocomplete_attribute": "billing country",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._field_display_order": 260,
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.address.city._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.ideal.bank_name._intent_data_read_path": "bank_redirect.ideal.bank_name",
            "dynamic_fields.bank_redirect.ideal.bank_name._default_label_text": "Bank Name",
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._default_placeholder_text": "Bank Identifier",
            "dynamic_fields.shipping.email._field_render_type": "Email",
            "dynamic_fields.bank_debit.sepa_bank_debit.iban._render_when_prefilled": false,
            "dynamic_fields.card.card_network._intent_data_read_path": "card.card_network",
            "dynamic_fields.crypto.pay_currency._intent_data_read_path": "crypto.pay_currency",
            "dynamic_fields.upi.upi_collect.vpa_id._is_required": false,
            "dynamic_fields.shipping.phone.number._validation_rule_type": "no_validation",
            "dynamic_fields.order_details.0.product_name._confirm_request_write_path": "order_details.0.product_name",
            "dynamic_fields.voucher.boleto.social_security_number._intent_data_read_path": "voucher.boleto.social_security_number",
            "dynamic_fields.billing.address.state._input_format_pattern": "no_format_pattern",
            "dynamic_fields.card.card_exp_year._max_input_length": 255,
            "dynamic_fields.gift_card.givex.number._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.blik.blik_code._html_autocomplete_attribute": "on",
            "dynamic_fields.shipping.address.state._render_when_prefilled": false,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._default_placeholder_text": "eg: John Doe",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._default_placeholder_text": "00012345",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._layout_row_id": "bank_debit_ach_bank_debit_routing_number_row",
            "dynamic_fields.shipping.address.line1._layout_width_ratio": 1,
            "dynamic_fields.card.card_cvc._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._default_placeholder_text": "Select Year",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._placeholder_localization_key": "accountNumberPlaceholder",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._layout_row_id": "bank_redirect_bancontact_card_card_exp_year_row",
            "dynamic_fields.bank_redirect.eps.bank_name._field_render_type": "BankNamesSelect",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._max_input_length": 255,
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._field_render_type": "Generic",
            "dynamic_fields.card.card_number._label_localization_key": "cardNumberLabel",
            "dynamic_fields.card.card_exp_year._field_render_type": "CardExpiryYear",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._layout_row_id": "bank_debit_bacs_bank_debit_sort_code_row",
            "dynamic_fields.wallet.mifinity.date_of_birth._render_when_prefilled": false,
            "dynamic_fields.billing.address.city._default_label_text": "City",
            "dynamic_fields.billing.address.line2._html_autocomplete_attribute": "billing address-line2",
            "dynamic_fields.bank_redirect.online_banking_slovakia.issuer._validation_regex_pattern": ".*",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._default_label_text": "Source Bank Account ID",
            "dynamic_fields.card.card_exp_year._intent_data_read_path": "card.card_exp_year",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._layout_width_ratio": 1,
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._field_render_type": "Generic",
            "dynamic_fields.crypto.network._layout_row_id": "crypto_network_row",
            "dynamic_fields.shipping.address.country._confirm_request_write_path": "shipping.address.country",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._default_placeholder_text": "10-80-00",
            "dynamic_fields.shipping.address.last_name._is_required": false,
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._dropdown_options": [],
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._is_required": false,
            "dynamic_fields.customer.document_details.document_type._is_required": false,
            "dynamic_fields.shipping.address.line1._default_label_text": "Address Line 1",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._max_input_length": 9,
            "dynamic_fields.card.card_cvc._is_required": false,
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._label_localization_key": "formFieldBankAccountNumberLabel",
            "dynamic_fields.voucher.boleto.social_security_number._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._validation_regex_pattern": ".*",
            "dynamic_fields.crypto.pay_currency._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._keyboard_type": "default",
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._layout_row_id": "bank_transfer_pix_automatico_push_bank_identifier_row",
            "dynamic_fields.billing.address.city._dropdown_options": [],
            "dynamic_fields.card.card_number._confirm_request_write_path": "payment_method_data.card.card_number",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._html_autocomplete_attribute": "cc-number",
            "dynamic_fields.bank_redirect.ideal.bank_name._extended_dropdown_options": [],
            "dynamic_fields.shipping.address.line2._default_label_text": "Address Line 2",
            "dynamic_fields.bank_redirect.ideal.bank_name._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.eps.bank_name._default_placeholder_text": "Bank Name",
            "dynamic_fields.bank_redirect.online_banking_czech_republic.issuer._validation_regex_pattern": ".*",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_month._intent_data_read_path": "bank_redirect.bancontact_card.card_exp_month",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._default_label_text": "Card Number",
            "dynamic_fields.gift_card.cvc._dropdown_options": [],
            "dynamic_fields.gift_card.givex.number._intent_data_read_path": "gift_card.givex.number",
            "dynamic_fields.gift_card.number._is_required": false,
            "dynamic_fields.shipping.address.zip._field_display_order": 670,
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._layout_row_id": "mobile_payment_direct_carrier_billing_msisdn_row",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._validation_regex_pattern": ".*",
            "dynamic_fields.gift_card.number._layout_row_id": "gift_card_number_row",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._keyboard_type": "numeric",
            "dynamic_fields.shipping.address.line2._max_input_length": 255,
            "dynamic_fields.card.card_cvc._validation_rule_type": "no_validation",
            "dynamic_fields.wallet.mifinity.date_of_birth._intent_data_read_path": "wallet.mifinity.date_of_birth",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._validation_rule_type": "no_validation",
            "dynamic_fields.shipping.phone.number._render_when_prefilled": false,
            "dynamic_fields.email._placeholder_localization_key": "emailLabel",
            "dynamic_fields.shipping.address.state._layout_row_id": "shipping_address_state_row",
            "dynamic_fields.billing.address.zip._intent_data_read_path": "billing.address.zip",
            "dynamic_fields.order_details.0.product_name._placeholder_localization_key": "productNamePlaceholder",
            "dynamic_fields.card.card_cvc._default_label_text": "CVV",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._default_label_text": "Account Number",
            "dynamic_fields.shipping.address.country._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._render_when_prefilled": false,
            "dynamic_fields.bank_transfer.pix.pix_key._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_debit.ach_bank_debit.account_number._is_required": false,
            "dynamic_fields.shipping.address.first_name._max_input_length": 255,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._is_required": false,
            "dynamic_fields.email._render_when_prefilled": false,
            "dynamic_fields.bank_transfer.pix.pix_key._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._default_label_text": "Expiry Year",
            "dynamic_fields.crypto.network._label_localization_key": "cryptoNetworkLabel",
            "dynamic_fields.wallet.mifinity.date_of_birth._validation_rule_type": "date_of_birth",
            "dynamic_fields.gift_card.givex.cvc._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._default_placeholder_text": "Select Bank Type",
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._validation_regex_pattern": ".*",
            "dynamic_fields.card.card_cvc._field_render_type": "Cvc",
            "dynamic_fields.shipping.address.line1._intent_data_read_path": "shipping.address.line1",
            "dynamic_fields.description._default_label_text": "Description",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._placeholder_localization_key": "bankIssuerPlaceholder",
            "dynamic_fields.billing.address.first_name._field_display_order": 480,
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._placeholder_localization_key": "bankIdentifierPlaceholder",
            "dynamic_fields.card.card_network._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_transfer.pix_automatico_push.branch_code._max_input_length": 255,
            "dynamic_fields.shipping.email._field_display_order": 620,
            "dynamic_fields.card.card_network._layout_row_id": "card_card_network_row",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._field_display_order": 120,
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._max_input_length": 255,
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._max_input_length": 255,
            "dynamic_fields.bank_redirect.open_banking_czech_republic.issuer._label_localization_key": "bankLabel",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._extended_dropdown_options": [],
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._field_render_type": "Generic",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._validation_regex_pattern": ".*",
            "dynamic_fields.billing.address.zip._layout_row_id": "billing_country_postal_row",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._label_localization_key": "bankLabel",
            "dynamic_fields.billing.address.line2._field_render_type": "Generic",
            "dynamic_fields.billing.phone.number._is_required": false,
            "dynamic_fields.gift_card.cvc._input_format_pattern": "no_format_pattern",
            "dynamic_fields.shipping.address.zip._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_transfer.pix.pix_key._keyboard_type": "default",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._field_render_type": "Generic",
            "dynamic_fields.billing.phone.country_code._field_display_order": 520,
            "dynamic_fields.shipping.address.line2._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.address.line2._render_when_prefilled": false,
            "dynamic_fields.shipping.email._render_when_prefilled": false,
            "dynamic_fields.shipping.address.zip._max_input_length": 255,
            "dynamic_fields.card.card_network._field_render_type": "CardNetwork",
            "dynamic_fields.description._extended_dropdown_options": [],
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._is_required": false,
            "dynamic_fields.crypto.network._render_when_prefilled": false,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._layout_width_ratio": 1,
            "dynamic_fields.email._label_localization_key": "emailLabel",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._intent_data_read_path": "bank_redirect.bancontact_card.card_number",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._render_when_prefilled": false,
            "dynamic_fields.bank_redirect.eps.bank_name._validation_rule_type": "no_validation",
            "dynamic_fields.shipping.address.city._placeholder_localization_key": "cityPlaceholder",
            "dynamic_fields.shipping.address.state._label_localization_key": "stateLabel",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._label_localization_key": "sourceBankAccountIdLabel",
            "dynamic_fields.card.card_exp_month._input_format_pattern": "no_format_pattern",
            "dynamic_fields.shipping.email._intent_data_read_path": "shipping.email",
            "dynamic_fields.shipping.address.country._layout_width_ratio": 1,
            "dynamic_fields.card.card_number._layout_row_id": "card_card_number_row",
            "dynamic_fields.billing.address.city._confirm_request_write_path": "payment_method_data.billing.address.city",
            "dynamic_fields.description._confirm_request_write_path": "description",
            "dynamic_fields.shipping.address.line2._is_required": false,
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.phone.number._label_localization_key": "formFieldPhoneNumberLabel",
            "dynamic_fields.wallet.mifinity.language_preference._max_input_length": 255,
            "dynamic_fields.card.card_cvc._field_display_order": 40,
            "dynamic_fields.shipping.phone.country_code._render_when_prefilled": false,
            "dynamic_fields.shipping.address.line2._placeholder_localization_key": "line2Placeholder",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._html_autocomplete_attribute": "name",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._render_when_prefilled": false,
            "dynamic_fields.card.card_network._validation_rule_type": "no_validation",
            "dynamic_fields.card.card_cvc._max_input_length": 4,
            "dynamic_fields.card.card_cvc._layout_row_id": "card_card_cvc_row",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._default_placeholder_text": "eg: 000-000",
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._dropdown_options": [],
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._default_label_text": "Account Number",
            "dynamic_fields.gift_card.number._default_label_text": "Gift Card Number",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._input_format_pattern": "**-**-**",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._dropdown_options": [],
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._layout_row_id": "bank_debit_becs_bank_debit_sort_code_row",
            "dynamic_fields.bank_redirect.bancontact_card.card_exp_year._max_input_length": 255,
            "dynamic_fields.shipping.phone.country_code._field_display_order": 700,
            "dynamic_fields.billing.phone.number._render_when_prefilled": false,
            "dynamic_fields.shipping.address.first_name._default_placeholder_text": "First Name",
            "dynamic_fields.shipping.address.last_name._layout_row_id": "shipping_address_last_name_row",
            "dynamic_fields.mobile_payment.direct_carrier_billing.client_uid._default_placeholder_text": "Client UID",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._label_localization_key": "accountHolderNameLabel",
            "dynamic_fields.gift_card.cvc._default_label_text": "Gift Card PIN",
            "dynamic_fields.shipping.address.line1._keyboard_type": "default",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._validation_regex_pattern": ".*",
            "dynamic_fields.shipping.address.first_name._placeholder_localization_key": "firstNamePlaceholder",
            "dynamic_fields.shipping.phone.number._extended_dropdown_options": [],
            "dynamic_fields.mobile_payment.direct_carrier_billing.msisdn._extended_dropdown_options": [],
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._validation_regex_pattern": ".*",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._layout_width_ratio": 1,
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._validation_rule_type": "no_validation",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._layout_width_ratio": 1,
            "dynamic_fields.shipping.phone.country_code._layout_width_ratio": 1,
            "dynamic_fields.shipping.address.state._dropdown_options": [],
            "dynamic_fields.voucher.boleto.social_security_number._validation_rule_type": "no_validation",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._input_format_pattern": "no_format_pattern",
            "dynamic_fields.billing.address.line1._is_required": false,
            "dynamic_fields.shipping.phone.number._layout_width_ratio": 1,
            "dynamic_fields.billing.address.line2._layout_width_ratio": 1,
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._is_required": false,
            "dynamic_fields.order_details.0.product_name._default_placeholder_text": "Product Name",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._default_label_text": "Bank Type",
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._dropdown_options": [],
            "dynamic_fields.billing.phone.number._layout_width_ratio": 2,
            "dynamic_fields.bank_debit.ach_bank_debit.bank_account_holder_name._intent_data_read_path": "bank_debit.ach_bank_debit.bank_account_holder_name",
            "dynamic_fields.bank_debit.becs_bank_debit.account_number._field_render_type": "Generic",
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.online_banking_poland.issuer._default_label_text": "Bank Issuer",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._confirm_request_write_path": "payment_method_data.bank_redirect.bancontact_card.card_number",
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._confirm_request_write_path": "payment_method_data.bank_redirect.open_banking_slovakia.issuer",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._layout_width_ratio": 1,
            "dynamic_fields.crypto.pay_currency._validation_regex_pattern": ".*",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._confirm_request_write_path": "payment_method_data.bank_debit.ach_bank_debit.routing_number",
            "dynamic_fields.shipping.address.city._layout_row_id": "shipping_address_city_row",
            "dynamic_fields.wallet.mifinity.date_of_birth._input_format_pattern": "dd-MM-yyyy",
            "dynamic_fields.bank_redirect.bancontact_card.card_number._max_input_length": 23,
            "dynamic_fields.bank_redirect.open_banking_thailand.issuer._confirm_request_write_path": "payment_method_data.bank_redirect.open_banking_thailand.issuer",
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._field_render_type": "Generic",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._validation_rule_type": "no_validation",
            "dynamic_fields.bank_debit.becs_bank_debit.bsb_number._extended_dropdown_options": [],
            "dynamic_fields.billing.address.line1._default_placeholder_text": "Street address",
            "dynamic_fields.crypto.pay_currency._render_when_prefilled": false,
            "dynamic_fields.shipping.address.first_name._render_when_prefilled": false,
            "dynamic_fields.gift_card.number._field_display_order": 430,
            "dynamic_fields.bank_redirect.bancontact_card.card_number._layout_row_id": "bank_redirect_bancontact_card_card_number_row",
            "dynamic_fields.card.card_network._confirm_request_write_path": "payment_method_data.card.card_network",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._placeholder_localization_key": "accountNumberPlaceholder",
            "dynamic_fields.gift_card.givex.cvc._intent_data_read_path": "gift_card.givex.cvc",
            "dynamic_fields.gift_card.number._field_render_type": "Generic",
            "dynamic_fields.bank_redirect.open_banking_uk.issuer._max_input_length": 255,
            "dynamic_fields.gift_card.givex.number._html_autocomplete_attribute": "on",
            "dynamic_fields.voucher.boleto.social_security_number._dropdown_options": [],
            "dynamic_fields.billing.address.state._extended_dropdown_options": [],
            "dynamic_fields.gift_card.number._default_placeholder_text": "ABCD1234EFGH5678",
            "dynamic_fields.crypto.pay_currency._layout_width_ratio": 1,
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._default_placeholder_text": "Account Number",
            "dynamic_fields.shipping.address.last_name._field_render_type": "LastName",
            "dynamic_fields.bank_transfer.pix_automatico_push.account_number._confirm_request_write_path": "payment_method_data.bank_transfer.pix_automatico_push.account_number",
            "dynamic_fields.bank_transfer.pix_emv.source_bank_account_id._max_input_length": 255,
            "dynamic_fields.bank_debit.bacs_bank_debit.sort_code._field_display_order": 320,
            "dynamic_fields.billing.email._field_render_type": "Email",
            "dynamic_fields.bank_debit.ach_bank_debit.bank_type._layout_row_id": "bank_debit_ach_bank_debit_bank_type_row",
            "dynamic_fields.billing.email._layout_row_id": "billing_email_row",
            "dynamic_fields.gift_card.cvc._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.open_banking_fpx.issuer._placeholder_localization_key": "bankIssuerPlaceholder",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._field_display_order": 360,
            "dynamic_fields.shipping.address.country._is_required": false,
            "dynamic_fields.billing.address.city._extended_dropdown_options": [],
            "dynamic_fields.bank_redirect.blik.blik_code._field_render_type": "Generic",
            "dynamic_fields.billing.address.country._field_render_type": "Country",
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._dropdown_options": [],
            "dynamic_fields.bank_transfer.pix.source_bank_account_id._label_localization_key": "sourceBankAccountIdLabel",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._field_render_type": "Generic",
            "dynamic_fields.shipping.address.city._field_render_type": "Generic",
            "dynamic_fields.description._label_localization_key": "descriptionLabel",
            "dynamic_fields.bank_redirect.online_banking_fpx.issuer._is_required": false,
            "dynamic_fields.billing.address.country._layout_width_ratio": 1,
            "dynamic_fields.bank_redirect.bancontact_card.card_number._keyboard_type": "numeric",
            "dynamic_fields.card.card_cvc._keyboard_type": "numeric",
            "dynamic_fields.description._is_required": false,
            "dynamic_fields.bank_redirect.open_banking_slovakia.issuer._default_placeholder_text": "Select Bank Issuer",
            "dynamic_fields.shipping.phone.number._field_render_type": "Phone",
            "dynamic_fields.upi.upi_collect.vpa_id._validation_rule_type": "no_validation",
            "dynamic_fields.billing.address.first_name._input_format_pattern": "no_format_pattern",
            "dynamic_fields.bank_debit.bacs_bank_debit.account_number._html_autocomplete_attribute": "on",
            "dynamic_fields.shipping.phone.number._default_placeholder_text": "Your Phone",
            "dynamic_fields.gift_card.givex.number._layout_width_ratio": 1,
            "dynamic_fields.voucher.boleto.social_security_number._is_required": false,
            "dynamic_fields.billing.address.city._field_render_type": "Generic",
            "dynamic_fields.bank_debit.ach_bank_debit.routing_number._default_label_text": "Routing Number",
            "dynamic_fields.bank_redirect.online_banking_thailand.issuer._html_autocomplete_attribute": "on",
            "dynamic_fields.bank_redirect.blik.blik_code._default_placeholder_text": "000 000",
            "dynamic_fields.gift_card.givex.number._render_when_prefilled": false,
            "dynamic_fields.bank_transfer.pix_automatico_push.bank_identifier._max_input_length": 11,
            "dynamic_fields.bank_debit.becs_bank_debit.sort_code._default_placeholder_text": "Sort Code",
            "dynamic_fields.bank_transfer.pix_emv.pix_key._field_render_type": "Generic"
        },
        "dimensions": {
            "enforced_profile_id": {
                "schema": {
                    "type": "string",
                    "pattern": ".*"
                },
                "position": 16,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "provider_merchant_id": {
                "schema": {
                    "type": "string",
                    "pattern": ".*"
                },
                "position": 12,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "enforced_provider_merchant_id": {
                "schema": {
                    "type": "string",
                    "pattern": ".*"
                },
                "position": 18,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "enforced_organization_id": {
                "schema": {
                    "pattern": ".*",
                    "type": "string"
                },
                "position": 19,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "profile_id": {
                "schema": {
                    "pattern": ".*",
                    "type": "string"
                },
                "position": 15,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "country": {
                "schema": {
                    "enum": [
                        "AC",
                        "AD",
                        "AE",
                        "AF",
                        "AG",
                        "AI",
                        "AL",
                        "AM",
                        "AO",
                        "AQ",
                        "AR",
                        "AS",
                        "AT",
                        "AU",
                        "AW",
                        "AX",
                        "AZ",
                        "BA",
                        "BB",
                        "BD",
                        "BE",
                        "BF",
                        "BG",
                        "BH",
                        "BI",
                        "BJ",
                        "BL",
                        "BM",
                        "BN",
                        "BO",
                        "BQ",
                        "BR",
                        "BS",
                        "BT",
                        "BV",
                        "BW",
                        "BY",
                        "BZ",
                        "CA",
                        "CC",
                        "CD",
                        "CF",
                        "CG",
                        "CH",
                        "CI",
                        "CK",
                        "CL",
                        "CM",
                        "CN",
                        "CO",
                        "CR",
                        "CU",
                        "CV",
                        "CW",
                        "CX",
                        "CY",
                        "CZ",
                        "DE",
                        "DJ",
                        "DK",
                        "DM",
                        "DO",
                        "DZ",
                        "EC",
                        "EE",
                        "EG",
                        "EH",
                        "ER",
                        "ES",
                        "ET",
                        "FI",
                        "FJ",
                        "FK",
                        "FM",
                        "FO",
                        "FR",
                        "GA",
                        "GB",
                        "GD",
                        "GE",
                        "GF",
                        "GG",
                        "GH",
                        "GI",
                        "GL",
                        "GM",
                        "GN",
                        "GP",
                        "GQ",
                        "GR",
                        "GS",
                        "GT",
                        "GU",
                        "GW",
                        "GY",
                        "HK",
                        "HM",
                        "HN",
                        "HR",
                        "HT",
                        "HU",
                        "ID",
                        "IE",
                        "IL",
                        "IM",
                        "IN",
                        "IO",
                        "IQ",
                        "IR",
                        "IS",
                        "IT",
                        "JE",
                        "JM",
                        "JO",
                        "JP",
                        "KE",
                        "KG",
                        "KH",
                        "KI",
                        "KM",
                        "KN",
                        "KP",
                        "KR",
                        "KW",
                        "KY",
                        "KZ",
                        "LA",
                        "LB",
                        "LC",
                        "LI",
                        "LK",
                        "LR",
                        "LS",
                        "LT",
                        "LU",
                        "LV",
                        "LY",
                        "MA",
                        "MC",
                        "MD",
                        "ME",
                        "MF",
                        "MG",
                        "MH",
                        "MK",
                        "ML",
                        "MM",
                        "MN",
                        "MO",
                        "MP",
                        "MQ",
                        "MR",
                        "MS",
                        "MT",
                        "MU",
                        "MV",
                        "MW",
                        "MX",
                        "MY",
                        "MZ",
                        "NA",
                        "NC",
                        "NE",
                        "NF",
                        "NG",
                        "NI",
                        "NL",
                        "NO",
                        "NP",
                        "NR",
                        "NU",
                        "NZ",
                        "OM",
                        "PA",
                        "PE",
                        "PF",
                        "PG",
                        "PH",
                        "PK",
                        "PL",
                        "PM",
                        "PN",
                        "PR",
                        "PS",
                        "PT",
                        "PW",
                        "PY",
                        "QA",
                        "RE",
                        "RO",
                        "RS",
                        "RU",
                        "RW",
                        "SA",
                        "SB",
                        "SC",
                        "SD",
                        "SE",
                        "SG",
                        "SH",
                        "SI",
                        "SJ",
                        "SK",
                        "SL",
                        "SM",
                        "SN",
                        "SO",
                        "SR",
                        "SS",
                        "ST",
                        "SV",
                        "SX",
                        "SY",
                        "SZ",
                        "TA",
                        "TC",
                        "TD",
                        "TF",
                        "TG",
                        "TH",
                        "TJ",
                        "TK",
                        "TL",
                        "TM",
                        "TN",
                        "TO",
                        "TR",
                        "TT",
                        "TV",
                        "TW",
                        "TZ",
                        "UA",
                        "UG",
                        "UM",
                        "US",
                        "UY",
                        "UZ",
                        "VA",
                        "VC",
                        "VE",
                        "VG",
                        "VI",
                        "VN",
                        "VU",
                        "WF",
                        "WS",
                        "XK",
                        "YE",
                        "YT",
                        "ZA",
                        "ZM",
                        "ZW"
                    ],
                    "type": "string"
                },
                "position": 4,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "payment_method": {
                "schema": {
                    "type": "string",
                    "enum": [
                        "BankDebit",
                        "BankRedirect",
                        "BankTransfer",
                        "Card",
                        "CardRedirect",
                        "Crypto",
                        "GiftCard",
                        "MobilePayment",
                        "PayLater",
                        "Upi",
                        "Voucher",
                        "Wallet"
                    ]
                },
                "position": 2,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "organization_id": {
                "schema": {
                    "type": "string",
                    "pattern": ".*"
                },
                "position": 11,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "incoming_webhook_events": {
                "schema": {
                    "pattern": ".*",
                    "type": "string"
                },
                "position": 10,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "payout_retry_type": {
                "schema": {
                    "enum": [
                        "single_connector",
                        "multi_connector"
                    ],
                    "type": "string"
                },
                "position": 9,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "always_collect_shipping_details_from_wallet_connector": {
                "schema": {
                    "type": "boolean"
                },
                "position": 8,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "always_collect_billing_details_from_wallet_connector": {
                "schema": {
                    "type": "boolean"
                },
                "position": 7,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "merchant_id": {
                "schema": {
                    "pattern": ".*",
                    "type": "string"
                },
                "position": 14,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "payment_method_type": {
                "schema": {
                    "enum": [
                        "Ach",
                        "Affirm",
                        "AfterpayClearpay",
                        "Alfamart",
                        "Alma",
                        "AmazonPay",
                        "ApplePay",
                        "Atome",
                        "Bacs",
                        "BancontactCard",
                        "BcaBankTransfer",
                        "Becs",
                        "Benefit",
                        "Blik",
                        "BniVa",
                        "Boleto",
                        "BriVa",
                        "CimbVa",
                        "Credit",
                        "CryptoCurrency",
                        "DanamonVa",
                        "Debit",
                        "DirectCarrierBilling",
                        "Eps",
                        "FamilyMart",
                        "Flexiti",
                        "Giropay",
                        "Givex",
                        "GooglePay",
                        "Ideal",
                        "Indomaret",
                        "InstantBankTransfer",
                        "InstantBankTransferFinland",
                        "InstantBankTransferPoland",
                        "Interac",
                        "Klarna",
                        "Knet",
                        "Lawson",
                        "LocalBankTransfer",
                        "MandiriVa",
                        "MbWay",
                        "Mifinity",
                        "MiniStop",
                        "MomoAtm",
                        "Multibanco",
                        "OnlineBankingCzechRepublic",
                        "OnlineBankingFinland",
                        "OnlineBankingFpx",
                        "OnlineBankingPoland",
                        "OnlineBankingSlovakia",
                        "OnlineBankingThailand",
                        "OpenBanking",
                        "OpenBankingUk",
                        "PayBright",
                        "PayEasy",
                        "Paypal",
                        "PermataBankTransfer",
                        "Pix",
                        "PixAutomaticoPush",
                        "PixAutomaticoQr",
                        "Przelewy24",
                        "SamsungPay",
                        "Seicomart",
                        "Sepa",
                        "SepaBankTransfer",
                        "SevenEleven",
                        "Skrill",
                        "Sofort",
                        "Trustly",
                        "UpiCollect",
                        "Walley"
                    ],
                    "type": "string"
                },
                "position": 3,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "enforced_processor_merchant_id": {
                "schema": {
                    "type": "string",
                    "pattern": ".*"
                },
                "position": 17,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "variantIds": {
                "schema": {
                    "type": "string",
                    "pattern": ".*"
                },
                "position": 0,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "connector": {
                "schema": {
                    "type": "string",
                    "enum": [
                        "authipay",
                        "adyenplatform",
                        "stripe_billing_test",
                        "phonypay",
                        "fauxpay",
                        "fiservcommercehub",
                        "pretendpay",
                        "stripe_test",
                        "dummyconnector1",
                        "dummyconnector2",
                        "dummyconnector3",
                        "dummyconnector4",
                        "dummyconnector5",
                        "dummyconnector6",
                        "dummyconnector7",
                        "adyen_test",
                        "checkout_test",
                        "paypal_test",
                        "aci",
                        "adyen",
                        "affirm",
                        "airwallex",
                        "amazonpay",
                        "archipel",
                        "authorizedotnet",
                        "bambora",
                        "bamboraapac",
                        "bankofamerica",
                        "barclaycard",
                        "billwerk",
                        "bitpay",
                        "bluesnap",
                        "blackhawknetwork",
                        "calida",
                        "boku",
                        "braintree",
                        "breadpay",
                        "cardinal",
                        "cashtocode",
                        "celero",
                        "chargebee",
                        "checkbook",
                        "checkout",
                        "coinbase",
                        "coingate",
                        "custombilling",
                        "cryptopay",
                        "ctp_mastercard",
                        "ctp_visa",
                        "cybersource",
                        "cybersourcedecisionmanager",
                        "datatrans",
                        "deutschebank",
                        "digitalvirgo",
                        "dlocal",
                        "dwolla",
                        "ebanx",
                        "elavon",
                        "facilitapay",
                        "finix",
                        "fiserv",
                        "fiservemea",
                        "fiuu",
                        "flexiti",
                        "forte",
                        "getnet",
                        "gigadat",
                        "globalpay",
                        "globepay",
                        "gocardless",
                        "gpayments",
                        "hipay",
                        "helcim",
                        "hyperpg",
                        "hyperswitch_vault",
                        "inespay",
                        "iatapay",
                        "itaubank",
                        "jpmorgan",
                        "juspaythreedsserver",
                        "klarna",
                        "loonio",
                        "mifinity",
                        "mollie",
                        "moneris",
                        "multisafepay",
                        "netcetera",
                        "nexinets",
                        "nexixpay",
                        "nmi",
                        "nomupay",
                        "noon",
                        "nordea",
                        "novalnet",
                        "nuvei",
                        "opennode",
                        "paybox",
                        "payload",
                        "payme",
                        "payone",
                        "paypal",
                        "paysafe",
                        "paystack",
                        "paytm",
                        "payu",
                        "peachpayments",
                        "payjustnow",
                        "payjustnowinstore",
                        "phonepe",
                        "placetopay",
                        "powertranz",
                        "prophetpay",
                        "rapyd",
                        "razorpay",
                        "recurly",
                        "redsys",
                        "revolv3",
                        "santander",
                        "shift4",
                        "silverflow",
                        "square",
                        "stax",
                        "stripe",
                        "stripebilling",
                        "taxjar",
                        "threedsecureio",
                        "tesouro",
                        "tokenex",
                        "tokenio",
                        "trustpay",
                        "trustpayments",
                        "tsys",
                        "vgs",
                        "volt",
                        "wellsfargo",
                        "wise",
                        "worldline",
                        "worldpay",
                        "worldpayvantiv",
                        "worldpayxml",
                        "worldpaymodular",
                        "signifyd",
                        "plaid",
                        "riskified",
                        "xendit",
                        "zen",
                        "zift",
                        "zsl"
                    ]
                },
                "position": 1,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "processor_merchant_id": {
                "schema": {
                    "pattern": ".*",
                    "type": "string"
                },
                "position": 13,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "mandate_type": {
                "schema": {
                    "type": "string",
                    "enum": [
                        "mandate",
                        "non_mandate"
                    ]
                },
                "position": 6,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            },
            "currency": {
                "schema": {
                    "enum": [
                        "AED",
                        "AFN",
                        "ALL",
                        "AMD",
                        "ANG",
                        "AOA",
                        "ARS",
                        "AUD",
                        "AWG",
                        "AZN",
                        "BAM",
                        "BBD",
                        "BDT",
                        "BGN",
                        "BHD",
                        "BIF",
                        "BMD",
                        "BND",
                        "BOB",
                        "BRL",
                        "BSD",
                        "BTN",
                        "BWP",
                        "BYN",
                        "BZD",
                        "CAD",
                        "CDF",
                        "CHF",
                        "CLF",
                        "CLP",
                        "CNY",
                        "COP",
                        "CRC",
                        "CUC",
                        "CUP",
                        "CVE",
                        "CZK",
                        "DJF",
                        "DKK",
                        "DOP",
                        "DZD",
                        "EGP",
                        "ERN",
                        "ETB",
                        "EUR",
                        "FJD",
                        "FKP",
                        "GBP",
                        "GEL",
                        "GHS",
                        "GIP",
                        "GMD",
                        "GNF",
                        "GTQ",
                        "GYD",
                        "HKD",
                        "HNL",
                        "HRK",
                        "HTG",
                        "HUF",
                        "IDR",
                        "ILS",
                        "INR",
                        "IQD",
                        "IRR",
                        "ISK",
                        "JMD",
                        "JOD",
                        "JPY",
                        "KES",
                        "KGS",
                        "KHR",
                        "KMF",
                        "KPW",
                        "KRW",
                        "KWD",
                        "KYD",
                        "KZT",
                        "LAK",
                        "LBP",
                        "LKR",
                        "LRD",
                        "LSL",
                        "LYD",
                        "MAD",
                        "MDL",
                        "MGA",
                        "MKD",
                        "MMK",
                        "MNT",
                        "MOP",
                        "MRU",
                        "MUR",
                        "MVR",
                        "MWK",
                        "MXN",
                        "MYR",
                        "MZN",
                        "NAD",
                        "NGN",
                        "NIO",
                        "NOK",
                        "NPR",
                        "NZD",
                        "OMR",
                        "PAB",
                        "PEN",
                        "PGK",
                        "PHP",
                        "PKR",
                        "PLN",
                        "PYG",
                        "QAR",
                        "RON",
                        "RSD",
                        "RUB",
                        "RWF",
                        "SAR",
                        "SBD",
                        "SCR",
                        "SDG",
                        "SEK",
                        "SGD",
                        "SHP",
                        "SLE",
                        "SLL",
                        "SOS",
                        "SRD",
                        "SSP",
                        "STD",
                        "STN",
                        "SVC",
                        "SYP",
                        "SZL",
                        "THB",
                        "TJS",
                        "TMT",
                        "TND",
                        "TOP",
                        "TRY",
                        "TTD",
                        "TWD",
                        "TZS",
                        "UAH",
                        "UGX",
                        "USD",
                        "UYU",
                        "UZS",
                        "VES",
                        "VND",
                        "VUV",
                        "WST",
                        "XAF",
                        "XCD",
                        "XOF",
                        "XPF",
                        "YER",
                        "ZAR",
                        "ZMW",
                        "ZWL"
                    ],
                    "type": "string"
                },
                "position": 5,
                "dimension_type": {
                    "REGULAR": {}
                },
                "dependency_graph": {}
            }
        }
    },
    "resolved_configs": null,
    "context_used": {
        "profile_id": "pro_FxjrOPwhKA7t7lMMQFZX",
        "processor_merchant_id": "merchant_1747129093",
        "organization_id": "org_wzjYn9BcRQmcpkUtWgJz",
        "connector": [
            "authorizedotnet"
        ]
    },
    "payment_methods": [
        {
            "payment_method": "card",
            "payment_method_types": [
                {
                    "payment_method_type": "credit",
                    "payment_method_criteria": "card_network",
                    "criteria_rules": [
                        {
                            "criteria_value": "CartesBancaires",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "AmericanExpress",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "Visa",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "DinersClub",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "Mastercard",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "UnionPay",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "Interac",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "Discover",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "JCB",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        }
                    ]
                },
                {
                    "payment_method_type": "debit",
                    "payment_method_criteria": "card_network",
                    "criteria_rules": [
                        {
                            "criteria_value": "DinersClub",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "Discover",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "UnionPay",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "CartesBancaires",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "Mastercard",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "Visa",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "AmericanExpress",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "Interac",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        },
                        {
                            "criteria_value": "JCB",
                            "eligible_connectors": [
                                "authorizedotnet"
                            ]
                        }
                    ]
                }
            ]
        }
    ],
    "account_config": {
        "profile": {
            "collect_shipping_details_from_wallet_connector": false,
            "collect_billing_details_from_wallet_connector": false,
            "always_collect_billing_details_from_wallet_connector": false,
            "always_collect_shipping_details_from_wallet_connector": false,
            "vaulting_action": "skip"
        }
    }
}`->JSON.parseExn

    // val
    data
  }

  let onFailure = _ => JSON.Encode.null

  await fetchApiWithLogging(
    uri,
    ~eventName=SDK_CONFIGS_CALL,
    ~logger,
    ~method=#GET,
    ~customPodUri=Some(customPodUri),
    ~publishableKey=Some(publishableKey),
    ~onSuccess,
    ~onFailure,
    ~sdkAuthorization,
  )
}
