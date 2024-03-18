open Utils

@val @scope(("window", "parent", "location")) external href: string = "href"

type searchParams = {set: (string, string) => unit}
type url = {searchParams: searchParams, href: string}
@new external urlSearch: string => url = "URL"

open LoggerUtils
type payment = Card | BankTransfer | BankDebits | KlarnaRedirect | Gpay | Applepay | Paypal | Other

let closePaymentLoaderIfAny = () =>
  Utils.handlePostMessage([("fullscreen", false->JSON.Encode.bool)])

let retrievePaymentIntent = (clientSecret, headers, ~optLogger, ~switchToCustomPod) => {
  open Promise
  let paymentIntentID = String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")
  let endpoint = ApiEndpoint.getApiEndPoint()
  let uri = `${endpoint}/payments/${paymentIntentID}?client_secret=${clientSecret}`

  logApi(
    ~optLogger,
    ~url=uri,
    ~type_="request",
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
          ~type_="err",
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
        ~type_="response",
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

let rec pollRetrievePaymentIntent = (clientSecret, headers, ~optLogger, ~switchToCustomPod) => {
  open Promise
  retrievePaymentIntent(clientSecret, headers, ~optLogger, ~switchToCustomPod)
  ->then(json => {
    let dict = json->JSON.Decode.object->Option.getOr(Dict.make())
    let status = dict->getString("status", "")

    if status === "succeeded" || status === "failed" {
      resolve(json)
    } else {
      delay(2000)->then(_val => {
        pollRetrievePaymentIntent(clientSecret, headers, ~optLogger, ~switchToCustomPod)
      })
    }
  })
  ->catch(e => {
    Console.log2("Unable to retrieve payment due to following error", e)
    pollRetrievePaymentIntent(clientSecret, headers, ~optLogger, ~switchToCustomPod)
  })
}

let rec intentCall = (
  ~fetchApi: (
    string,
    ~bodyStr: string=?,
    ~headers: Dict.t<string>=?,
    ~method: Fetch.method,
    unit,
  ) => OrcaPaymentPage.Promise.t<Fetch.Response.t>,
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
    ~type_="request",
    ~eventName=initEventName,
    ~logType=INFO,
    ~logCategory=API,
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
        Js.Promise.make(
          (~resolve, ~reject as _) => {
            if isConfirm {
              let paymentMethod = switch paymentType {
              | Card => "CARD"
              | _ =>
                bodyStr
                ->JSON.parseExn
                ->Utils.getDictFromJson
                ->Utils.getString("payment_method_type", "")
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
              ~type_="err",
              ~eventName,
              ~logType=ERROR,
              ~logCategory=API,
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
        Js.Promise.make(
          (~resolve, ~reject as _) => {
            let exceptionMessage = err->Utils.formatException
            logApi(
              ~optLogger,
              ~url=uri,
              ~statusCode,
              ~type_="no_response",
              ~data=exceptionMessage,
              ~eventName,
              ~logType=ERROR,
              ~logCategory=API,
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
        Js.Promise.make(
          (~resolve, ~reject as _) => {
            logApi(~optLogger, ~url=uri, ~statusCode, ~type_="response", ~eventName, ())
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
                | Some(obj) => obj->Utils.getDictFromJson
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
              } else if intent.nextAction.type_ == "third_party_sdk_session_token" {
                let session_token = switch intent.nextAction.session_token {
                | Some(token) => token->Utils.getDictFromJson
                | None => Dict.make()
                }
                let walletName = session_token->Utils.getString("wallet_name", "")
                let message = switch walletName {
                | "apple_pay" => [
                    ("applePayButtonClicked", true->JSON.Encode.bool),
                    ("applePayPresent", session_token->toJson),
                  ]
                | "google_pay" => [("googlePayThirdPartyFlow", session_token->toJson)]
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
                | Some(token) => token->Utils.getDictFromJson
                | None => Dict.make()
                }
                let walletName = session_token->Utils.getString("wallet_name", "")
                let message = switch walletName {
                | "apple_pay" => [
                    ("applePayButtonClicked", true->JSON.Encode.bool),
                    ("applePayPresent", session_token->toJson),
                  ]
                | "google_pay" => [("googlePayThirdPartyFlow", session_token->toJson)]
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
    Js.Promise.make((~resolve, ~reject as _) => {
      let url = urlSearch(confirmParam.return_url)
      url.searchParams.set("payment_intent_client_secret", clientSecret)
      url.searchParams.set("status", "failed")
      let exceptionMessage = err->Utils.formatException
      logApi(
        ~optLogger,
        ~url=uri,
        ~eventName,
        ~type_="no_response",
        ~data=exceptionMessage,
        ~logType=ERROR,
        ~logCategory=API,
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
        let paymentIntentID = String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")
        let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey, ())
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
    })->then(resolve)
  })
}

let usePaymentSync = (optLogger: option<OrcaLogger.loggerMake>, paymentType: payment) => {
  let list = Recoil.useRecoilValueFromAtom(RecoilAtoms.list)
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let switchToCustomPod = Recoil.useRecoilValueFromAtom(RecoilAtoms.switchToCustomPod)
  let setIsManualRetryEnabled = Recoil.useSetRecoilState(RecoilAtoms.isManualRetryEnabled)
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

let usePaymentIntent = (optLogger: option<OrcaLogger.loggerMake>, paymentType: payment) => {
  let blockConfirm = Recoil.useRecoilValueFromAtom(RecoilAtoms.isConfirmBlocked)
  let switchToCustomPod = Recoil.useRecoilValueFromAtom(RecoilAtoms.switchToCustomPod)
  let list = Recoil.useRecoilValueFromAtom(RecoilAtoms.list)
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let (isManualRetryEnabled, setIsManualRetryEnabled) = Recoil.useRecoilState(
    RecoilAtoms.isManualRetryEnabled,
  )
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId="",
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
        ~isConfirmCall=true,
        (),
      )
      let uri = `${endpoint}/payments/${paymentIntentID}/confirm`

      let callIntent = body => {
        let maskedPayload =
          body->OrcaUtils.safeParseOpt->Option.getOr(JSON.Encode.null)->maskPayload->JSON.stringify
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
                ~paymentMethod=json->JSON.Decode.string->Option.getOr(""),
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
      | Loaded(data) =>
        let paymentList = data->getDictFromJson->PaymentMethodsRecord.itemToObjMapper
        let mandatePaymentType =
          paymentList.payment_type->PaymentMethodsRecord.paymentTypeToStringMapper
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
      | SemiLoaded => intentWithoutMandate("")
      | _ => ()
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
    ~type_="request",
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
          ~type_="err",
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
        ~type_="response",
        ~eventName=SESSIONS_CALL,
        ~logType=INFO,
        ~logCategory=API,
        (),
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->Utils.formatException
    logApi(
      ~optLogger,
      ~url=uri,
      ~type_="no_response",
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
    ~type_="request",
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
          ~type_="err",
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
        ~type_="response",
        ~eventName=PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
        (),
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->Utils.formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~type_="no_response",
      ~eventName=PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
      (),
    )
    JSON.Encode.null->resolve
  })
}

let fetchCustomerDetails = (
  ~clientSecret,
  ~publishableKey,
  ~endpoint,
  ~optLogger,
  ~switchToCustomPod,
) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
  let uri = `${endpoint}/customers/payment_methods?client_secret=${clientSecret}`
  logApi(
    ~optLogger,
    ~url=uri,
    ~type_="request",
    ~eventName=CUSTOMER_PAYMENT_METHODS_CALL_INIT,
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
          ~type_="err",
          ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
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
        ~type_="response",
        ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
        (),
      )
      res->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->Utils.formatException
    logApi(
      ~optLogger,
      ~url=uri,
      ~type_="no_response",
      ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
      (),
    )
    JSON.Encode.null->resolve
  })
}
