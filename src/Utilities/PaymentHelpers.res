open Utils
open Identity

@val @scope(("window", "parent", "location")) external href: string = "href"

type searchParams = {set: (string, string) => unit}
type url = {searchParams: searchParams, href: string}
@new external urlSearch: string => url = "URL"

open LoggerUtils
type payment = Card | BankTransfer | BankDebits | KlarnaRedirect | Gpay | Applepay | Paypal | Other

let closePaymentLoaderIfAny = () => handlePostMessage([("fullscreen", false->JSON.Encode.bool)])

let retrievePaymentIntent = (
  clientSecret,
  headers,
  ~optLogger,
  ~switchToCustomPod,
  ~isForceSync=false,
) => {
  open Promise
  let paymentIntentID = String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")
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
    (),
  )
  fetchApi(
    uri,
    ~method=#GET,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    (),
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
          ~eventName=RETRIEVE_CALL,
          ~logType=ERROR,
          ~logCategory=API,
          (),
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
        (),
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
    ->Dict.fromArray
    ->JSON.Encode.object

  open Promise
  logApi(
    ~optLogger,
    ~url,
    ~apiLogType=Request,
    ~eventName=AUTHENTICATION_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
    (),
  )
  fetchApi(url, ~method=#POST, ~bodyStr=body->JSON.stringify, ~headers=headers->Dict.fromArray, ())
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
          (),
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=AUTHENTICATION_CALL,
        (),
      )
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
      (),
    )
    reject(err)
  })
}

let rec pollRetrievePaymentIntent = (
  clientSecret,
  headers,
  ~optLogger,
  ~switchToCustomPod,
  ~isForceSync=false,
) => {
  open Promise
  retrievePaymentIntent(clientSecret, headers, ~optLogger, ~switchToCustomPod, ~isForceSync)
  ->then(json => {
    let dict = json->JSON.Decode.object->Option.getOr(Dict.make())
    let status = dict->getString("status", "")

    if status === "succeeded" || status === "failed" {
      resolve(json)
    } else {
      delay(2000)->then(_val => {
        pollRetrievePaymentIntent(
          clientSecret,
          headers,
          ~optLogger,
          ~switchToCustomPod,
          ~isForceSync,
        )
      })
    }
  })
  ->catch(e => {
    Console.log2("Unable to retrieve payment due to following error", e)
    pollRetrievePaymentIntent(clientSecret, headers, ~optLogger, ~switchToCustomPod, ~isForceSync)
  })
}

let retrieveStatus = (~headers, ~switchToCustomPod, pollID, logger) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let uri = `${endpoint}/poll/status/${pollID}`
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=POLL_STATUS_INIT,
    ~logType=INFO,
    ~logCategory=API,
    (),
  )
  fetchApi(
    uri,
    ~method=#GET,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    (),
  )
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
          (),
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
        (),
      )
      res->Fetch.Response.json
    }
  })
  ->catch(e => {
    Console.log2("Unable to Poll status details because of ", e)
    JSON.Encode.null->resolve
  })
}

let rec pollStatus = (
  ~headers,
  ~switchToCustomPod,
  ~pollId,
  ~interval,
  ~count,
  ~returnUrl,
  ~logger,
) => {
  open Promise
  retrieveStatus(~headers, ~switchToCustomPod, pollId, logger)
  ->then(json => {
    let dict = json->JSON.Decode.object->Option.getOr(Dict.make())
    let status = dict->getString("status", "")
    Promise.make((resolve, _) => {
      if status === "completed" {
        resolve(json)
      } else if count === 0 {
        handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
        openUrl(returnUrl)
      } else {
        delay(interval)
        ->then(
          _ => {
            pollStatus(
              ~headers,
              ~switchToCustomPod,
              ~pollId,
              ~interval,
              ~count=count - 1,
              ~returnUrl,
              ~logger,
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
      ~switchToCustomPod,
      ~pollId,
      ~interval,
      ~count=count - 1,
      ~returnUrl,
      ~logger,
    )
  })
}

let rec intentCall = (
  ~fetchApi: (
    string,
    ~bodyStr: string=?,
    ~headers: Dict.t<string>=?,
    ~method: Fetch.method,
    unit,
  ) => Promise.t<Fetch.Response.t>,
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
  ~switchToCustomPod,
  ~sdkHandleOneClickConfirmPayment,
  ~counter,
  ~isPaymentSession=false,
  ~paymentSessionRedirect="if_redirect",
  (),
) => {
  open Promise
  let isConfirm = uri->String.includes("/confirm")
  let (eventName: OrcaLogger.eventName, initEventName: OrcaLogger.eventName) = isConfirm
    ? (CONFIRM_CALL, CONFIRM_CALL_INIT)
    : (RETRIEVE_CALL, RETRIEVE_CALL_INIT)
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=initEventName,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession,
    (),
  )
  let handleOpenUrl = url => {
    if isPaymentSession {
      Window.Location.replace(url)
    } else {
      openUrl(url)
    }
  }
  fetchApi(
    uri,
    ~method=fetchMethod,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    ~bodyStr,
    (),
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status->Int.toString
    let url = urlSearch(confirmParam.return_url)
    url.searchParams.set("payment_intent_client_secret", clientSecret)
    url.searchParams.set("status", "failed")

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
                ->JSON.parseExn
                ->getDictFromJson
                ->getString("payment_method_type", "")
              }
              handleLogging(
                ~optLogger,
                ~value=data->JSON.stringify,
                ~eventName=PAYMENT_FAILED,
                ~paymentMethod,
                (),
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
              (),
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
              (),
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
              let paymentIntentID =
                String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")
              let endpoint = ApiEndpoint.getApiEndPoint(
                ~publishableKey=confirmParam.publishableKey,
                ~isConfirmCall=isConfirm,
                (),
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
                ~switchToCustomPod,
                ~sdkHandleOneClickConfirmPayment,
                ~counter=counter + 1,
                (),
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
              (),
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
                  postSubmitResponse(~jsonData=data, ~url=url.href)
                } else if paymentSessionRedirect === "always" {
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
                  (),
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
                  (),
                )
                if !isPaymentSession {
                  handlePostMessage([
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
                    ("expiryTime", expiryTime->Belt.Float.toString->JSON.Encode.string),
                    ("url", url.href->JSON.Encode.string),
                  ]->Dict.fromArray
                handleLogging(
                  ~optLogger,
                  ~value="",
                  ~internalMetadata=metaData->JSON.Encode.object->JSON.stringify,
                  ~eventName=DISPLAY_QR_CODE_INFO_PAGE,
                  ~paymentMethod,
                  (),
                )
                if !isPaymentSession {
                  handlePostMessage([
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
                  ->Belt.Option.flatMap(JSON.Decode.object)
                  ->Option.getOr(Dict.make())
                let do3dsMethodCall =
                  threeDsData
                  ->Dict.get("three_ds_method_details")
                  ->Belt.Option.flatMap(JSON.Decode.object)
                  ->Belt.Option.flatMap(x => x->Dict.get("three_ds_method_data_submission"))
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
                  (),
                )

                if do3dsMethodCall {
                  handlePostMessage([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `3ds`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", metaData->JSON.Encode.object),
                  ])
                } else {
                  metaData->Dict.set("3dsMethodComp", "U"->JSON.Encode.string)
                  handlePostMessage([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `3dsAuth`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", metaData->JSON.Encode.object),
                  ])
                }
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
                | _ => []
                }

                if !isPaymentSession {
                  handlePostMessage(message)
                }
                resolve(data)
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
                    (),
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
                  handlePostMessage(message)
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
                  (),
                )
              } else if intent.status === "failed" {
                handleLogging(
                  ~optLogger,
                  ~value=intent.status,
                  ~eventName=PAYMENT_FAILED,
                  ~paymentMethod,
                  (),
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
          (),
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
          let paymentIntentID =
            String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")
          let endpoint = ApiEndpoint.getApiEndPoint(
            ~publishableKey=confirmParam.publishableKey,
            ~isConfirmCall=isConfirm,
            (),
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
            ~switchToCustomPod,
            ~sdkHandleOneClickConfirmPayment,
            ~counter=counter + 1,
            ~isPaymentSession,
            (),
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
  let list = Recoil.useRecoilValueFromAtom(list)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let switchToCustomPod = Recoil.useRecoilValueFromAtom(switchToCustomPod)
  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  (~handleUserError=false, ~confirmParam: ConfirmType.confirmParams, ~iframeId="", ()) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")
      let headers = [("Content-Type", "application/json"), ("api-key", confirmParam.publishableKey)]
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey, ())
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
          ~switchToCustomPod,
          ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
          ~counter=0,
          (),
        )->ignore
      }
      switch list {
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
    ->Dict.fromArray
    ->JSON.Encode.object

  | Array(arr) => arr->Array.map(maskPayload)->JSON.Encode.array
  | String(valueStr) => valueStr->maskStr->JSON.Encode.string
  | Number(float) => Float.toString(float)->maskStr->JSON.Encode.string
  | Bool(bool) => (bool ? "true" : "false")->JSON.Encode.string
  | Null => JSON.Encode.string("null")
  }
}

let usePaymentIntent = (optLogger, paymentType) => {
  open RecoilAtoms
  let blockConfirm = Recoil.useRecoilValueFromAtom(isConfirmBlocked)
  let switchToCustomPod = Recoil.useRecoilValueFromAtom(switchToCustomPod)
  let list = Recoil.useRecoilValueFromAtom(list)
  let keys = Recoil.useRecoilValueFromAtom(keys)

  let (isManualRetryEnabled, setIsManualRetryEnabled) = Recoil.useRecoilState(isManualRetryEnabled)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId=keys.iframeId,
    ~isThirdPartyFlow=false,
    (),
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")
      let headers = [("Content-Type", "application/json"), ("api-key", confirmParam.publishableKey)]
      let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]
      let manual_retry = isManualRetryEnabled
        ? [("retry_action", "manual_retry"->JSON.Encode.string)]
        : []
      let body =
        [("client_secret", clientSecret->JSON.Encode.string)]->Array.concatMany([
          returnUrlArr,
          manual_retry,
        ])
      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=!isThirdPartyFlow,
        (),
      )
      let uri = `${endpoint}/payments/${paymentIntentID}/confirm`

      let callIntent = body => {
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
              ->Dict.fromArray
              ->JSON.Encode.object,
            ),
          ]
          ->Dict.fromArray
          ->JSON.Encode.object
          ->JSON.stringify
        switch paymentType {
        | Card =>
          handleLogging(
            ~optLogger,
            ~internalMetadata=loggerPayload,
            ~value="",
            ~eventName=PAYMENT_ATTEMPT,
            ~paymentMethod="CARD",
            (),
          )
        | _ =>
          let _ = bodyArr->Array.map(((str, json)) => {
            if str === "payment_method_type" {
              handleLogging(
                ~optLogger,
                ~value="",
                ~internalMetadata=loggerPayload,
                ~eventName=PAYMENT_ATTEMPT,
                ~paymentMethod=json->getStringFromJson(""),
                (),
              )
            }
            ()
          })
        }
        if blockConfirm && Window.isInteg {
          Console.log3("CONFIRM IS BLOCKED", body->JSON.parseExn, headers)
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
            ~switchToCustomPod,
            ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
            ~counter=0,
            (),
          )->ignore
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
          ->Dict.fromArray
          ->JSON.Encode.object
          ->JSON.stringify
        callIntent(bodyStr)
      }

      let intentWithMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concat(
            bodyArr->Array.concatMany([PaymentBody.mandateBody(mandatePaymentType), broswerInfo()]),
          )
          ->Dict.fromArray
          ->JSON.Encode.object
          ->JSON.stringify
        callIntent(bodyStr)
      }

      switch list {
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
  ~switchToCustomPod,
  ~endpoint,
  (),
) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
  let paymentIntentID = String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")
  let body =
    [
      ("payment_id", paymentIntentID->JSON.Encode.string),
      ("client_secret", clientSecret->JSON.Encode.string),
      ("wallets", wallets->JSON.Encode.array),
      ("delayed_session_token", isDelayedSessionToken->JSON.Encode.bool),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object
  let uri = `${endpoint}/payments/session_tokens`
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=SESSIONS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
    (),
  )
  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=body->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    (),
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
          (),
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
        (),
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
      (),
    )
    JSON.Encode.null->resolve
  })
}

let fetchPaymentMethodList = (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~switchToCustomPod,
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
    (),
  )
  fetchApi(
    uri,
    ~method=#GET,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    (),
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
          ~eventName=PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
          (),
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
        (),
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
      (),
    )
    JSON.Encode.null->resolve
  })
}

let fetchCustomerPaymentMethodList = (
  ~clientSecret,
  ~publishableKey,
  ~endpoint,
  ~optLogger,
  ~switchToCustomPod,
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
    (),
  )
  fetchApi(
    uri,
    ~method=#GET,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    (),
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
          ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
          ~isPaymentSession,
          (),
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
        (),
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
      (),
    )
    JSON.Encode.null->resolve
  })
}
