open Utils
open Identity

@val @scope(("window", "parent", "location")) external href: string = "href"

type searchParams = {set: (string, string) => unit}
type url = {searchParams: searchParams, href: string}
@new external urlSearch: string => url = "URL"

open LoggerUtils
type payment = Card | BankTransfer | BankDebits | KlarnaRedirect | Gpay | Applepay | Paypal | Other

let getPaymentType = paymentMethodType =>
  switch paymentMethodType {
  | "apple_pay" => Applepay
  | "google_pay" => Gpay
  | "debit"
  | "credit"
  | "" =>
    Card
  | _ => Other
  }

let closePaymentLoaderIfAny = () => messageParentWindow([("fullscreen", false->JSON.Encode.bool)])

type paymentIntent = (
  ~handleUserError: bool=?,
  ~bodyArr: array<(string, JSON.t)>,
  ~confirmParam: ConfirmType.confirmParams,
  ~iframeId: string=?,
  ~isThirdPartyFlow: bool=?,
  ~intentCallback: Core__JSON.t => unit=?,
  ~manualRetry: bool=?,
) => unit

type completeAuthorize = (
  ~handleUserError: bool=?,
  ~bodyArr: array<(string, JSON.t)>,
  ~confirmParam: ConfirmType.confirmParams,
  ~iframeId: string=?,
) => unit

let retrievePaymentIntent = (
  clientSecret,
  headers,
  ~optLogger,
  ~customPodUri,
  ~isForceSync=false,
) => {
  open Promise
  let paymentIntentID = clientSecret->getPaymentId
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
    let statusCode = res->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    Console.log2("Unable to retrieve payment details because of ", e)
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
    let statusCode = res->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    Console.log2("Unable to call 3ds auth ", exceptionMessage)
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
      delay(2000)->then(_val => {
        pollRetrievePaymentIntent(clientSecret, headers, ~optLogger, ~customPodUri, ~isForceSync)
      })
    }
  })
  ->catch(e => {
    Console.log2("Unable to retrieve payment due to following error", e)
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
    let statusCode = res->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    Console.log2("Unable to Poll status details because of ", e)
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
        ->ignore
      }
    })
  })
  ->catch(e => {
    Console.log2("Unable to retrieve payment due to following error", e)
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
) => {
  open Promise
  let isConfirm = uri->String.includes("/confirm")
  let isCompleteAuthorize = uri->String.includes("/complete_authorize")
  let (eventName: OrcaLogger.eventName, initEventName: OrcaLogger.eventName) = switch (
    isConfirm,
    isCompleteAuthorize,
  ) {
  | (true, _) => (CONFIRM_CALL, CONFIRM_CALL_INIT)
  | (_, true) => (COMPLETE_AUTHORIZE_CALL, COMPLETE_AUTHORIZE_CALL_INIT)
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
      Window.replaceRootHref(url)
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
    let statusCode = res->Fetch.Response.status->Int.toString
    let url = urlSearch(confirmParam.return_url)
    url.searchParams.set("payment_intent_client_secret", clientSecret)
    url.searchParams.set("status", "failed")
    messageParentWindow([("confirmParams", confirmParam->Identity.anyTypeToJson)])

    if statusCode->String.charAt(0) !== "2" {
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
              let paymentIntentID = clientSecret->getPaymentId
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
              )
              ->then(
                res => {
                  resolve(res)
                  Promise.resolve()
                },
              )
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

            let url = urlSearch(confirmParam.return_url)
            url.searchParams.set("payment_intent_client_secret", clientSecret)
            url.searchParams.set("status", intent.status)

            let handleProcessingStatus = (paymentType, sdkHandleOneClickConfirmPayment) => {
              switch (paymentType, sdkHandleOneClickConfirmPayment) {
              | (Card, _)
              | (Gpay, false)
              | (Applepay, false)
              | (Paypal, false) =>
                if !isPaymentSession {
                  closePaymentLoaderIfAny()
                  postSubmitResponse(~jsonData=data, ~url=url.href)
                } else if confirmParam.redirect === Some("always") {
                  handleOpenUrl(url.href)
                } else {
                  resolve(data)
                }
              | _ => handleOpenUrl(url.href)
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
                let expiryTime = intent.nextAction.display_to_timestamp->Option.getOr(0.0)
                let headerObj = Dict.make()
                headers->Array.forEach(
                  entries => {
                    let (x, val) = entries
                    Dict.set(headerObj, x, val->JSON.Encode.string)
                  },
                )
                let metaData =
                  [
                    ("qrData", qrData->JSON.Encode.string),
                    ("paymentIntentId", clientSecret->JSON.Encode.string),
                    ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
                    ("headers", headerObj->JSON.Encode.object),
                    ("expiryTime", expiryTime->Float.toString->JSON.Encode.string),
                    ("url", url.href->JSON.Encode.string),
                  ]->Dict.fromArray
                handleLogging(
                  ~optLogger,
                  ~value="",
                  ~internalMetadata=metaData->JSON.Encode.object->JSON.stringify,
                  ~eventName=DISPLAY_QR_CODE_INFO_PAGE,
                  ~paymentMethod,
                )
                if !isPaymentSession {
                  messageParentWindow([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `qrData`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", metaData->JSON.Encode.object),
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
                headers->Array.forEach(
                  entries => {
                    let (x, val) = entries
                    Dict.set(headerObj, x, val->JSON.Encode.string)
                  },
                )
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
              } else if intent.nextAction.type_ === "display_voucher_information" {
                let voucherData = intent.nextAction.voucher_details->Option.getOr({
                  download_url: "",
                  reference: "",
                })
                let headerObj = Dict.make()
                headers->Array.forEach(
                  entries => {
                    let (x, val) = entries
                    Dict.set(headerObj, x, val->JSON.Encode.string)
                  },
                )
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
                      ("pmAuthConnectorArray", ["plaid"]->Identity.anyTypeToJson),
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
        let url = urlSearch(confirmParam.return_url)
        url.searchParams.set("payment_intent_client_secret", clientSecret)
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
          let paymentIntentID = clientSecret->getPaymentId
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
          )
          ->then(
            res => {
              resolve(res)
              Promise.resolve()
            },
          )
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

let usePaymentSync = (optLogger: option<OrcaLogger.loggerMake>, paymentType: payment) => {
  open RecoilAtoms
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  (~handleUserError=false, ~confirmParam: ConfirmType.confirmParams, ~iframeId="") => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = clientSecret->getPaymentId
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
    ->Utils.getJsonFromArrayOfJson

  | Array(arr) => arr->Array.map(maskPayload)->JSON.Encode.array
  | String(valueStr) => valueStr->maskStr->JSON.Encode.string
  | Number(float) => Float.toString(float)->maskStr->JSON.Encode.string
  | Bool(bool) => (bool ? "true" : "false")->JSON.Encode.string
  | Null => JSON.Encode.string("null")
  }
}

let usePaymentIntent = (optLogger, paymentType) => {
  open RecoilAtoms
  open Promise
  let url = RescriptReactRouter.useUrl()
  let paymentTypeFromUrl =
    CardUtils.getQueryParamsDictforKey(url.search, "componentName")->CardThemeType.getPaymentMode
  let blockConfirm = Recoil.useRecoilValueFromAtom(isConfirmBlocked)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let keys = Recoil.useRecoilValueFromAtom(keys)

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
      let paymentIntentID = clientSecret->getPaymentId
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
              ->Utils.getJsonFromArrayOfJson,
            ),
          ]
          ->Utils.getJsonFromArrayOfJson
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
        if blockConfirm && Window.isInteg {
          Console.log3("CONFIRM IS BLOCKED", body->safeParse, headers)
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
          )
          ->then(val => {
            intentCallback(val)
            resolve()
          })
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
          ->Utils.getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      let intentWithMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concat(
            bodyArr->Array.concatMany([PaymentBody.mandateBody(mandatePaymentType), broswerInfo()]),
          )
          ->Utils.getJsonFromArrayOfJson
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

let useCompleteAuthorize = (optLogger: option<OrcaLogger.loggerMake>, paymentType: payment) => {
  open RecoilAtoms
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  let url = RescriptReactRouter.useUrl()
  let paymentTypeFromUrl =
    CardUtils.getQueryParamsDictforKey(url.search, "componentName")->CardThemeType.getPaymentMode
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId=keys.iframeId,
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = clientSecret->getPaymentId
      let headers = [
        ("Content-Type", "application/json"),
        ("api-key", confirmParam.publishableKey),
        ("X-Client-Source", paymentTypeFromUrl->CardThemeType.getPaymentModeToStrMapper),
      ]
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)
      let uri = `${endpoint}/payments/${paymentIntentID}/complete_authorize`

      let browserInfo = BrowserSpec.broswerInfo
      let bodyStr =
        [("client_secret", clientSecret->JSON.Encode.string)]
        ->Array.concatMany([bodyArr, browserInfo()])
        ->Utils.getJsonFromArrayOfJson
        ->JSON.stringify

      let completeAuthorize = () => {
        intentCall(
          ~fetchApi,
          ~uri,
          ~headers,
          ~bodyStr,
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
        )->ignore
      }
      switch paymentMethodList {
      | Loaded(_) => completeAuthorize()
      | _ => ()
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="complete_authorize_failed",
        ~message="Complete Authorize Failed. Try Again!",
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
  let paymentIntentID = clientSecret->getPaymentId
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
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    let statusCode = resp->Fetch.Response.status->Int.toString

    resp
    ->Fetch.Response.json
    ->then(data => {
      if statusCode->String.charAt(0) !== "2" {
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
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
      // Fetch.Response.json(resp)
      let val = {
        "redirect_url": "https://google.com/",
        "currency": "EUR",
        "payment_methods": [
          {
            "payment_method": "crypto",
            "payment_method_types": [
              {
                "payment_method_type": "crypto_currency",
                "payment_experience": [
                  {
                    "payment_experience_type": "redirect_to_url",
                    "eligible_connectors": ["cryptopay", "bitpay"],
                  },
                ],
                "card_networks": null,
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": {
                  "payment_method_data.crypto.pay_currency": {
                    "required_field": "payment_method_data.crypto.pay_currency",
                    "display_name": "currency",
                    "field_type": {
                      "user_currency": {
                        "options": [
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
                          "DAI",
                        ],
                      },
                    },
                    "value": null,
                  },
                  "payment_method_data.crypto.network": {
                    "required_field": "payment_method_data.crypto.network",
                    "display_name": "network",
                    "field_type": "user_crypto_currency_network",
                    "value": null,
                  },
                },
                "surcharge_details": null,
                "pm_auth_connector": null,
              },
            ],
          }->Identity.anyTypeToJson,
          {
            "payment_method": "wallet",
            "payment_method_types": [
              {
                "payment_method_type": "ali_pay",
                "payment_experience": [
                  {
                    "payment_experience_type": "redirect_to_url",
                    "eligible_connectors": ["adyen", "stripe"],
                  },
                ],
                "card_networks": null,
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": null,
                "surcharge_details": null,
                "pm_auth_connector": null,
              },
              {
                "payment_method_type": "we_chat_pay",
                "payment_experience": [
                  {
                    "payment_experience_type": "display_qr_code",
                    "eligible_connectors": ["stripe"],
                  },
                  {
                    "payment_experience_type": "redirect_to_url",
                    "eligible_connectors": ["adyen"],
                  },
                ],
                "card_networks": null,
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": null,
                "surcharge_details": null,
                "pm_auth_connector": null,
              },
            ],
          }->Identity.anyTypeToJson,
          {
            "payment_method": "bank_debit",
            "payment_method_types": [
              {
                "payment_method_type": "becs",
                "payment_experience": [
                  {
                    "payment_experience_type": "redirect_to_url",
                    "eligible_connectors": ["stripe"],
                  },
                ],
                "card_networks": null,
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": {
                  "billing.address.first_name": {
                    "required_field": "payment_method_data.billing.address.first_name",
                    "display_name": "billing_first_name",
                    "field_type": "user_billing_name",
                    "value": null,
                  },
                  "billing.address.last_name": {
                    "required_field": "payment_method_data.billing.address.last_name",
                    "display_name": "owner_name",
                    "field_type": "user_billing_name",
                    "value": null,
                  },
                  "payment_method_data.bank_debit.becs.account_number": {
                    "required_field": "payment_method_data.bank_debit.becs.account_number",
                    "display_name": "bank_account_number",
                    "field_type": "user_bank_account_number",
                    "value": null,
                  },
                  "billing.email": {
                    "required_field": "payment_method_data.billing.email",
                    "display_name": "email",
                    "field_type": "user_email_address",
                    "value": "hyperswitch_sdk_demo_id@gmail.com",
                  },
                  "payment_method_data.bank_debit.becs.bsb_number": {
                    "required_field": "payment_method_data.bank_debit.becs.bsb_number",
                    "display_name": "bsb_number",
                    "field_type": "text",
                    "value": null,
                  },
                },
                "surcharge_details": null,
                "pm_auth_connector": null,
              }->Identity.anyTypeToJson,
              {
                "payment_method_type": "sepa",
                "payment_experience": [
                  {
                    "payment_experience_type": "redirect_to_url",
                    "eligible_connectors": ["adyen"],
                  },
                ],
                "card_networks": null,
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": {
                  "billing.address.first_name": {
                    "required_field": "payment_method_data.billing.address.first_name",
                    "display_name": "owner_name",
                    "field_type": "user_billing_name",
                    "value": null,
                  },
                  "payment_method_data.bank_debit.sepa.iban": {
                    "required_field": "payment_method_data.bank_debit.sepa.iban",
                    "display_name": "iban",
                    "field_type": "user_iban",
                    "value": null,
                  },
                  "billing.address.last_name": {
                    "required_field": "payment_method_data.billing.address.last_name",
                    "display_name": "owner_name",
                    "field_type": "user_billing_name",
                    "value": null,
                  },
                  // "billing.address.city": {
                  //   "required_field": "payment_method_data.billing.address.city",
                  //   "display_name": "owner_name",
                  //   "field_type": "user_address_city",
                  //   "value": null,
                  // },
                  // "billing.address.state": {
                  //   "required_field": "payment_method_data.billing.address.state",
                  //   "display_name": "owner_name",
                  //   "field_type": "user_address_state",
                  //   "value": null,
                  // },
                },
                "surcharge_details": null,
                "pm_auth_connector": null,
              }->Identity.anyTypeToJson,
            ],
          }->Identity.anyTypeToJson,
          {
            "payment_method": "gift_card",
            "payment_method_types": [
              {
                "payment_method_type": "pay_safe_card",
                "payment_experience": [
                  {
                    "payment_experience_type": "redirect_to_url",
                    "eligible_connectors": ["adyen"],
                  },
                ],
                "card_networks": null,
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": null,
                "surcharge_details": null,
                "pm_auth_connector": null,
              }->Identity.anyTypeToJson,
              {
                "payment_method_type": "givex",
                "payment_experience": [
                  {
                    "payment_experience_type": "redirect_to_url",
                    "eligible_connectors": ["adyen"],
                  },
                ],
                "card_networks": null,
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": {
                  "payment_method_data.gift_card.cvc": {
                    "required_field": "payment_method_data.gift_card.cvc",
                    "display_name": "gift_card_cvc",
                    "field_type": "user_card_cvc",
                    "value": null,
                  },
                  "payment_method_data.gift_card.number": {
                    "required_field": "payment_method_data.gift_card.number",
                    "display_name": "gift_card_number",
                    "field_type": "user_card_number",
                    "value": null,
                  },
                },
                "surcharge_details": null,
                "pm_auth_connector": null,
              }->Identity.anyTypeToJson,
            ],
          }->Identity.anyTypeToJson,
          {
            "payment_method": "bank_transfer",
            "payment_method_types": [
              {
                "payment_method_type": "multibanco",
                "payment_experience": [
                  {
                    "payment_experience_type": "redirect_to_url",
                    "eligible_connectors": ["stripe"],
                  },
                ],
                "card_networks": null,
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": {
                  "billing.email": {
                    "required_field": "payment_method_data.billing.email",
                    "display_name": "email",
                    "field_type": "user_email_address",
                    "value": "hyperswitch_sdk_demo_id@gmail.com",
                  },
                },
                "surcharge_details": null,
                "pm_auth_connector": null,
              }->Identity.anyTypeToJson,
              {
                "payment_method_type": "pix",
                "payment_experience": [
                  {
                    "payment_experience_type": "redirect_to_url",
                    "eligible_connectors": ["itaubank"],
                  },
                ],
                "card_networks": null,
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": {
                  "billing.address.first_name": {
                    "required_field": "payment_method_data.billing.address.first_name",
                    "display_name": "card_holder_name",
                    "field_type": "user_full_name",
                    "value": null,
                  },
                  "payment_method_data.bank_transfer.pix.cpf": {
                    "required_field": "payment_method_data.bank_transfer.pix.cpf",
                    "display_name": "cpf",
                    "field_type": "user_cpf",
                    "value": null,
                  },
                  "payment_method_data.bank_transfer.pix.pix_key": {
                    "required_field": "payment_method_data.bank_transfer.pix.pix_key",
                    "display_name": "pix_key",
                    "field_type": "user_pix_key",
                    "value": null,
                  },
                  "payment_method_data.bank_transfer.pix.cnpj": {
                    "required_field": "payment_method_data.bank_transfer.pix.cnpj",
                    "display_name": "cnpj",
                    "field_type": "user_cnpj",
                    "value": null,
                  },
                  "billing.address.last_name": {
                    "required_field": "payment_method_data.billing.address.last_name",
                    "display_name": "card_holder_name",
                    "field_type": "user_full_name",
                    "value": null,
                  },
                },
                "surcharge_details": null,
                "pm_auth_connector": null,
              }->Identity.anyTypeToJson,
            ],
          }->Identity.anyTypeToJson,
          {
            "payment_method": "card",
            "payment_method_types": [
              {
                "payment_method_type": "debit",
                "payment_experience": null,
                "card_networks": [
                  {
                    "card_network": "JCB",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "Visa",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "DinersClub",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "UnionPay",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "Discover",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "CartesBancaires",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "AmericanExpress",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "Interac",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "Mastercard",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                ],
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": {
                  "payment_method_data.card.card_exp_year": {
                    "required_field": "payment_method_data.card.card_exp_year",
                    "display_name": "card_exp_year",
                    "field_type": "user_card_expiry_year",
                    "value": null,
                  },
                  "payment_method_data.card.card_exp_month": {
                    "required_field": "payment_method_data.card.card_exp_month",
                    "display_name": "card_exp_month",
                    "field_type": "user_card_expiry_month",
                    "value": null,
                  },
                  "billing.address.city": {
                    "required_field": "payment_method_data.billing.address.city",
                    "display_name": "city",
                    "field_type": "user_address_city",
                    "value": "San Fransico",
                  },
                  "billing.address.first_name": {
                    "required_field": "payment_method_data.billing.address.first_name",
                    "display_name": "card_holder_name",
                    "field_type": "user_full_name",
                    "value": null,
                  },
                  "billing.address.country": {
                    "required_field": "payment_method_data.billing.address.country",
                    "display_name": "country",
                    "field_type": {
                      "user_address_country": {
                        "options": ["ALL"],
                      },
                    },
                    "value": "NL",
                  },
                  "billing.address.state": {
                    "required_field": "payment_method_data.billing.address.state",
                    "display_name": "state",
                    "field_type": "user_address_state",
                    "value": "California",
                  },
                  "payment_method_data.card.card_cvc": {
                    "required_field": "payment_method_data.card.card_cvc",
                    "display_name": "card_cvc",
                    "field_type": "user_card_cvc",
                    "value": null,
                  },
                  "email": {
                    "required_field": "email",
                    "display_name": "email",
                    "field_type": "user_email_address",
                    "value": "hyperswitch_sdk_demo_id@gmail.com",
                  },
                  "billing.address.line1": {
                    "required_field": "payment_method_data.billing.address.line1",
                    "display_name": "line1",
                    "field_type": "user_address_line1",
                    "value": null,
                  },
                  "billing.address.zip": {
                    "required_field": "payment_method_data.billing.address.zip",
                    "display_name": "zip",
                    "field_type": "user_address_pincode",
                    "value": "94122",
                  },
                  "billing.address.last_name": {
                    "required_field": "payment_method_data.billing.address.last_name",
                    "display_name": "card_holder_name",
                    "field_type": "user_full_name",
                    "value": null,
                  },
                  "payment_method_data.card.card_number": {
                    "required_field": "payment_method_data.card.card_number",
                    "display_name": "card_number",
                    "field_type": "user_card_number",
                    "value": null,
                  },
                  "billing.email": {
                    "required_field": "payment_method_data.billing.email",
                    "display_name": "email",
                    "field_type": "user_email_address",
                    "value": "hyperswitch_sdk_demo_id@gmail.com",
                  },
                },
                "surcharge_details": null,
                "pm_auth_connector": null,
              }->Identity.anyTypeToJson,
              {
                "payment_method_type": "credit",
                "payment_experience": null,
                "card_networks": [
                  {
                    "card_network": "CartesBancaires",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "Visa",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "UnionPay",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "JCB",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "Interac",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "DinersClub",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "Mastercard",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "Discover",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                  {
                    "card_network": "AmericanExpress",
                    "surcharge_details": null,
                    "eligible_connectors": [
                      "placetopay",
                      "aci",
                      "nmi",
                      "noon",
                      "trustpay",
                      "checkout",
                      "bluesnap",
                      "adyen",
                      "cybersource",
                      "paypal",
                      "bambora",
                      "stripe",
                    ],
                  },
                ],
                "bank_names": null,
                "bank_debits": null,
                "bank_transfers": null,
                "required_fields": {
                  "billing.address.line1": {
                    "required_field": "payment_method_data.billing.address.line1",
                    "display_name": "line1",
                    "field_type": "user_address_line1",
                    "value": null,
                  },
                  "billing.address.zip": {
                    "required_field": "payment_method_data.billing.address.zip",
                    "display_name": "zip",
                    "field_type": "user_address_pincode",
                    "value": "94122",
                  },
                  "billing.address.country": {
                    "required_field": "payment_method_data.billing.address.country",
                    "display_name": "country",
                    "field_type": {
                      "user_address_country": {
                        "options": ["ALL"],
                      },
                    },
                    "value": "NL",
                  },
                  "payment_method_data.card.card_exp_month": {
                    "required_field": "payment_method_data.card.card_exp_month",
                    "display_name": "card_exp_month",
                    "field_type": "user_card_expiry_month",
                    "value": null,
                  },
                  "email": {
                    "required_field": "email",
                    "display_name": "email",
                    "field_type": "user_email_address",
                    "value": "hyperswitch_sdk_demo_id@gmail.com",
                  },
                  "billing.address.first_name": {
                    "required_field": "payment_method_data.billing.address.first_name",
                    "display_name": "card_holder_name",
                    "field_type": "user_full_name",
                    "value": null,
                  },
                  "billing.address.state": {
                    "required_field": "payment_method_data.billing.address.state",
                    "display_name": "state",
                    "field_type": "user_address_state",
                    "value": "California",
                  },
                  "billing.address.city": {
                    "required_field": "payment_method_data.billing.address.city",
                    "display_name": "city",
                    "field_type": "user_address_city",
                    "value": "San Fransico",
                  },
                  "billing.email": {
                    "required_field": "payment_method_data.billing.email",
                    "display_name": "email",
                    "field_type": "user_email_address",
                    "value": "hyperswitch_sdk_demo_id@gmail.com",
                  },
                  "payment_method_data.card.card_number": {
                    "required_field": "payment_method_data.card.card_number",
                    "display_name": "card_number",
                    "field_type": "user_card_number",
                    "value": null,
                  },
                  "billing.address.last_name": {
                    "required_field": "payment_method_data.billing.address.last_name",
                    "display_name": "card_holder_name",
                    "field_type": "user_full_name",
                    "value": null,
                  },
                  "payment_method_data.card.card_exp_year": {
                    "required_field": "payment_method_data.card.card_exp_year",
                    "display_name": "card_exp_year",
                    "field_type": "user_card_expiry_year",
                    "value": null,
                  },
                  "payment_method_data.card.card_cvc": {
                    "required_field": "payment_method_data.card.card_cvc",
                    "display_name": "card_cvc",
                    "field_type": "user_card_cvc",
                    "value": null,
                  },
                },
                "surcharge_details": null,
                "pm_auth_connector": null,
              }->Identity.anyTypeToJson,
            ],
          }->Identity.anyTypeToJson,
          {
            "payment_method": "bank_debit",
            "payment_method_types": [
              {
                "payment_method_type": "becs",
                "payment_experience": null,
                "card_networks": null,
                "bank_names": null,
                "bank_debits": {
                  "eligible_connectors": ["stripe"],
                },
                "bank_transfers": null,
                "required_fields": {
                  "billing.address.first_name": {
                    "required_field": "payment_method_data.billing.address.first_name",
                    "display_name": "billing_first_name",
                    "field_type": "user_billing_name",
                    "value": null,
                  },
                  "billing.address.last_name": {
                    "required_field": "payment_method_data.billing.address.last_name",
                    "display_name": "owner_name",
                    "field_type": "user_billing_name",
                    "value": null,
                  },
                  "payment_method_data.bank_debit.becs.account_number": {
                    "required_field": "payment_method_data.bank_debit.becs.account_number",
                    "display_name": "bank_account_number",
                    "field_type": "user_bank_account_number",
                    "value": null,
                  },
                  "billing.email": {
                    "required_field": "payment_method_data.billing.email",
                    "display_name": "email",
                    "field_type": "user_email_address",
                    "value": "hyperswitch_sdk_demo_id@gmail.com",
                  },
                  "payment_method_data.bank_debit.becs.bsb_number": {
                    "required_field": "payment_method_data.bank_debit.becs.bsb_number",
                    "display_name": "bsb_number",
                    "field_type": "text",
                    "value": null,
                  },
                },
                "surcharge_details": null,
                "pm_auth_connector": null,
              }->Identity.anyTypeToJson,
              {
                "payment_method_type": "sepa",
                "payment_experience": null,
                "card_networks": null,
                "bank_names": null,
                "bank_debits": {
                  "eligible_connectors": ["adyen"],
                },
                "bank_transfers": null,
                "required_fields": {
                  "billing.address.first_name": {
                    "required_field": "payment_method_data.billing.address.first_name",
                    "display_name": "owner_name",
                    "field_type": "user_billing_name",
                    "value": null,
                  },
                  "payment_method_data.bank_debit.sepa.iban": {
                    "required_field": "payment_method_data.bank_debit.sepa.iban",
                    "display_name": "iban",
                    "field_type": "user_iban",
                    "value": null,
                  },
                  "billing.address.last_name": {
                    "required_field": "payment_method_data.billing.address.last_name",
                    "display_name": "owner_name",
                    "field_type": "user_billing_name",
                    "value": null,
                  },
                },
                "surcharge_details": null,
                "pm_auth_connector": null,
              }->Identity.anyTypeToJson,
            ],
          }->Identity.anyTypeToJson,
        ],
        "mandate_payment": null,
        "merchant_name": "sandboxtesterjp",
        "show_surcharge_breakup_screen": true,
        "payment_type": "normal",
        "request_external_three_ds_authentication": false,
        "collect_shipping_details_from_wallets": true,
        "collect_billing_details_from_wallets": true,
        "is_tax_calculation_enabled": false,
      }->Identity.anyTypeToJson

      val->resolve
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
    let statusCode = res->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
      ("payment_id", clientSecret->Option.getOr("")->getPaymentId->JSON.Encode.string),
      ("payment_method", "bank_debit"->JSON.Encode.string),
      ("payment_method_type", paymentMethodType->JSON.Encode.string),
    ]
    ->getJsonFromArrayOfJson
    ->JSON.stringify,
    ~headers,
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
            ("pmAuthConnectorArray", pmAuthConnectorsArr->Identity.anyTypeToJson),
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
    Console.log2("Unable to retrieve payment_methods auth/link because of ", e)
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
  let logger = OrcaLogger.make(~source=Elements(Payment))
  let uri = `${endpoint}/payment_methods/auth/exchange`
  let updatedBody = [
    ("client_secret", clientSecret->Option.getOr("")->JSON.Encode.string),
    ("payment_id", clientSecret->Option.getOr("")->getPaymentId->JSON.Encode.string),
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
    let statusCode = res->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
        Console.log2(
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
    Console.log2("Unable to retrieve payment_methods auth/exchange because of ", e)
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
    let statusCode = res->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
