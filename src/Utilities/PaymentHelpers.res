open Utils

@val @scope(("window", "parent", "location")) external href: string = "href"

type searchParams = {set: (. string, string) => unit}
type url = {searchParams: searchParams, href: string}
@new external urlSearch: string => url = "URL"

open LoggerUtils
type payment = Card | BankTransfer | BankDebits | KlarnaRedirect | Gpay | Applepay | Paypal | Other

let closePaymentLoaderIfAny = () =>
  Utils.handlePostMessage([("fullscreen", false->Js.Json.boolean)])

let retrievePaymentIntent = (clientSecret, headers, ~optLogger, ~switchToCustomPod) => {
  open Promise
  let paymentIntentID = Js.String2.split(clientSecret, "_secret_")[0]
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
    ~method_=Fetch.Get,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    (),
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status->string_of_int
    if statusCode->Js.String2.charAt(0) !== "2" {
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
        Js.Json.null->resolve
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
    Js.log2("Unable to retrieve payment details because of ", e)
    Js.Json.null->resolve
  })
}

let rec pollRetrievePaymentIntent = (clientSecret, headers, ~optLogger, ~switchToCustomPod) => {
  open Promise
  retrievePaymentIntent(clientSecret, headers, ~optLogger, ~switchToCustomPod)
  ->then(json => {
    let dict = json->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
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
    Js.log2("Unable to retrieve payment due to following error", e)
    pollRetrievePaymentIntent(clientSecret, headers, ~optLogger, ~switchToCustomPod)
  })
}

let intentCall = (
  ~fetchApi: (
    string,
    ~bodyStr: string=?,
    ~headers: Js.Dict.t<string>=?,
    ~method_: Fetch.requestMethod,
    unit,
  ) => OrcaPaymentPage.Promise.t<Fetch.response>,
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
) => {
  open Promise
  let isConfirm = uri->Js.String2.includes("/confirm")
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
  fetchApi(
    uri,
    ~method_=fetchMethod,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    ~bodyStr,
    (),
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status->string_of_int
    let url = urlSearch(confirmParam.return_url)
    url.searchParams.set(. "payment_intent_client_secret", clientSecret)
    url.searchParams.set(. "status", "failed")

    if statusCode->Js.String2.charAt(0) !== "2" {
      res
      ->Fetch.Response.json
      ->then(data => {
        if isConfirm {
          let paymentMethod = switch paymentType {
          | Card => "CARD"
          | _ =>
            bodyStr
            ->Js.Json.parseExn
            ->Utils.getDictFromJson
            ->Utils.getString("payment_method_type", "")
          }
          handleLogging(
            ~optLogger,
            ~value=data->Js.Json.stringify,
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
        closePaymentLoaderIfAny()
        postFailedSubmitResponse(~errortype=errorObj.error.type_, ~message=errorObj.error.message)
        if handleUserError {
          openUrl(url.href)
        }
        resolve()
      })
      ->catch(err => {
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
        closePaymentLoaderIfAny()
        postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
        if handleUserError {
          openUrl(url.href)
        }
        resolve()
      })
      ->ignore
    } else {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(~optLogger, ~url=uri, ~statusCode, ~type_="response", ~eventName, ())
        let intent = PaymentConfirmTypes.itemToObjMapper(data->getDictFromJson)
        let paymentMethod = switch paymentType {
        | Card => "CARD"
        | _ => intent.payment_method_type
        }

        let url = urlSearch(confirmParam.return_url)
        url.searchParams.set(. "payment_intent_client_secret", clientSecret)
        url.searchParams.set(. "status", intent.status)
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
            openUrl(intent.nextAction.redirectToUrl)
          } else if intent.nextAction.type_ == "display_bank_transfer_information" {
            let metadata = switch intent.nextAction.bank_transfer_steps_and_charges_details {
            | Some(obj) => obj->Utils.getDictFromJson
            | None => Js.Dict.empty()
            }
            let dict = deepCopyDict(metadata)
            dict->Js.Dict.set("data", data)
            dict->Js.Dict.set("url", url.href->Js.Json.string)
            handleLogging(
              ~optLogger,
              ~value="",
              ~internalMetadata=dict->Js.Json.object_->Js.Json.stringify,
              ~eventName=DISPLAY_BANK_TRANSFER_INFO_PAGE,
              ~paymentMethod,
              (),
            )
            handlePostMessage([
              ("fullscreen", true->Js.Json.boolean),
              ("param", `${intent.payment_method_type}BankTransfer`->Js.Json.string),
              ("iframeId", iframeId->Js.Json.string),
              ("metadata", dict->Js.Json.object_),
            ])
          } else if intent.nextAction.type_ === "qr_code_information" {
            let qrData = intent.nextAction.image_data_url->Belt.Option.getWithDefault("")
            let headerObj = Js.Dict.empty()
            headers->Js.Array2.forEach(entries => {
              let (x, val) = entries
              Js.Dict.set(headerObj, x, val->Js.Json.string)
            })
            let metaData =
              [
                ("qrData", qrData->Js.Json.string),
                ("paymentIntentId", clientSecret->Js.Json.string),
                ("headers", headerObj->Js.Json.object_),
                ("expiryTime", Js.Json.null),
                ("url", url.href->Js.Json.string),
              ]->Js.Dict.fromArray
            handleLogging(
              ~optLogger,
              ~value="",
              ~internalMetadata=metaData->Js.Json.object_->Js.Json.stringify,
              ~eventName=DISPLAY_QR_CODE_INFO_PAGE,
              ~paymentMethod,
              (),
            )
            handlePostMessage([
              ("fullscreen", true->Js.Json.boolean),
              ("param", `qrData`->Js.Json.string),
              ("iframeId", iframeId->Js.Json.string),
              ("metadata", metaData->Js.Json.object_),
            ])
          } else if intent.nextAction.type_ == "third_party_sdk_session_token" {
            let session_token = switch intent.nextAction.session_token {
            | Some(token) => token->Utils.getDictFromJson
            | None => Js.Dict.empty()
            }
            let walletName = session_token->Utils.getString("wallet_name", "")
            let message = switch walletName {
            | "apple_pay" => [
                ("applePayButtonClicked", true->Js.Json.boolean),
                ("applePayPresent", session_token->toJson),
              ]
            | "google_pay" => [("googlePayThirdPartyFlow", session_token->toJson)]
            | _ => []
            }

            handlePostMessage(message)
          } else {
            postFailedSubmitResponse(
              ~errortype="confirm_payment_failed",
              ~message="Payment failed. Try again!",
            )
            if uri->Js.String2.includes("force_sync=true") {
              openUrl(url.href)
            }
          }
        } else if intent.status == "processing" {
          if intent.nextAction.type_ == "third_party_sdk_session_token" {
            let session_token = switch intent.nextAction.session_token {
            | Some(token) => token->Utils.getDictFromJson
            | None => Js.Dict.empty()
            }
            let walletName = session_token->Utils.getString("wallet_name", "")
            let message = switch walletName {
            | "apple_pay" => [
                ("applePayButtonClicked", true->Js.Json.boolean),
                ("applePayPresent", session_token->toJson),
              ]
            | "google_pay" => [("googlePayThirdPartyFlow", session_token->toJson)]
            | _ => []
            }

            handlePostMessage(message)
          } else {
            switch paymentType {
            | Card => postSubmitResponse(~jsonData=data, ~url=url.href)
            | _ => openUrl(url.href)
            }
          }
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
            setIsManualRetryEnabled(._ => intent.manualRetryAllowed)
          }
          switch paymentType {
          | Card => postSubmitResponse(~jsonData=data, ~url=url.href)
          | _ => openUrl(url.href)
          }
        } else {
          postFailedSubmitResponse(
            ~errortype="confirm_payment_failed",
            ~message="Payment failed. Try again!",
          )
        }
        resolve()
      })
      ->ignore
    }
    resolve()
  })
  ->catch(err => {
    let url = urlSearch(confirmParam.return_url)
    url.searchParams.set(. "payment_intent_client_secret", clientSecret)
    url.searchParams.set(. "status", "failed")
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
    closePaymentLoaderIfAny()
    postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
    if handleUserError {
      openUrl(url.href)
    }
    resolve()
  })
  ->ignore
}

let usePaymentSync = (optLogger: option<OrcaLogger.loggerMake>, paymentType: payment) => {
  let list = Recoil.useRecoilValueFromAtom(RecoilAtoms.list)
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let switchToCustomPod = Recoil.useRecoilValueFromAtom(RecoilAtoms.switchToCustomPod)
  let setIsManualRetryEnabled = Recoil.useSetRecoilState(RecoilAtoms.isManualRetryEnabled)
  (~handleUserError=false, ~confirmParam: ConfirmType.confirmParams, ~iframeId="", ()) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = Js.String2.split(clientSecret, "_secret_")[0]
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
          ~fetchMethod=Fetch.Get,
          ~setIsManualRetryEnabled,
          ~switchToCustomPod,
        )
      }
      switch list {
      | Loaded(_) => paymentSync()
      | SemiLoaded
      | Loading
      | LoadError(_) => ()
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="SYNC_PAYMENT_FAILED",
        ~message="Sync Payment Failed. Try Again!",
      )
    }
  }
}

let rec maskPayload = payloadDict => {
  let keys = payloadDict->Js.Dict.keys
  let maskedPayload = Js.Dict.empty()
  keys
  ->Js.Array2.map(key => {
    let value = payloadDict->Js.Dict.get(key)->Belt.Option.getWithDefault(Js.Json.null)
    if value->Js.Json.decodeObject->Belt.Option.isSome {
      let valueDict = value->Utils.getDictFromJson
      maskedPayload->Js.Dict.set(key, valueDict->maskPayload->Js.Json.string)
    } else {
      maskedPayload->Js.Dict.set(
        key,
        value
        ->Js.Json.decodeString
        ->Belt.Option.getWithDefault("")
        ->Js.String2.replaceByRe(%re(`/\S/g`), "x")
        ->Js.Json.string,
      )
    }
  })
  ->ignore
  maskedPayload->Js.Json.object_->Js.Json.stringify
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
    ~bodyArr: array<(string, Js.Json.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId="",
    (),
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = Js.String2.split(clientSecret, "_secret_")[0]
      let headers = [("Content-Type", "application/json"), ("api-key", confirmParam.publishableKey)]
      let returnUrlArr = [("return_url", confirmParam.return_url->Js.Json.string)]
      let manual_retry = isManualRetryEnabled
        ? [("retry_action", "manual_retry"->Js.Json.string)]
        : []
      let body =
        [("client_secret", clientSecret->Js.Json.string)]->Js.Array2.concatMany([
          returnUrlArr,
          manual_retry,
        ])
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey, ())
      let uri = `${endpoint}/payments/${paymentIntentID}/confirm`
      let fetchMethod = Fetch.Post
      let loggerPayload = body->Js.Dict.fromArray->maskPayload

      let callIntent = body => {
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
          let _ = bodyArr->Js.Array2.map(((str, json)) => {
            if str === "payment_method_type" {
              handleLogging(
                ~optLogger,
                ~value="",
                ~internalMetadata=loggerPayload,
                ~eventName=PAYMENT_ATTEMPT,
                ~paymentMethod=json->Js.Json.decodeString->Belt.Option.getWithDefault(""),
                (),
              )
            }
            ()
          })
        }
        if blockConfirm && Window.isInteg {
          Js.log3("CONFIRM IS BLOCKED", body->Js.Json.parseExn, headers)
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
            ~fetchMethod,
            ~setIsManualRetryEnabled,
            ~switchToCustomPod,
          )
        }
      }

      let broswerInfo = BrowserSpec.broswerInfo
      let intentWithoutMandate = () => {
        let bodyStr =
          body
          ->Js.Array2.concat(bodyArr->Js.Array2.concat(broswerInfo()))
          ->Js.Dict.fromArray
          ->Js.Json.object_
          ->Js.Json.stringify
        callIntent(bodyStr)
      }
      let intentWithMandate = () => {
        let bodyStr =
          body
          ->Js.Array2.concat(
            bodyArr->Js.Array2.concatMany([PaymentBody.mandateBody(), broswerInfo()]),
          )
          ->Js.Dict.fromArray
          ->Js.Json.object_
          ->Js.Json.stringify
        callIntent(bodyStr)
      }

      switch list {
      | Loaded(data) =>
        let paymentList = data->getDictFromJson->PaymentMethodsRecord.itemToObjMapper
        switch paymentList.mandate_payment {
        | Some(_) =>
          switch paymentType {
          | Card
          | Gpay
          | Applepay
          | KlarnaRedirect
          | Paypal
          | BankDebits =>
            intentWithMandate()
          | _ => intentWithoutMandate()
          }
        | None => intentWithoutMandate()
        }
      | SemiLoaded => intentWithoutMandate()
      | Loading
      | LoadError(_) => ()
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="confirm_payment_failed",
        ~message="Payment failed. Try again!",
      )
    }
  }
}

let useSessions = (
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
  let paymentIntentID =
    Js.String2.split(clientSecret, "_secret_")->Belt.Array.get(0)->Belt.Option.getWithDefault("")
  let body =
    [
      ("payment_id", paymentIntentID->Js.Json.string),
      ("client_secret", clientSecret->Js.Json.string),
      ("wallets", wallets->Js.Json.array),
      ("delayed_session_token", isDelayedSessionToken->Js.Json.boolean),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_
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
    ~method_=Fetch.Post,
    ~bodyStr=body->Js.Json.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    (),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status->string_of_int
    if statusCode->Js.String2.charAt(0) !== "2" {
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
        Js.Json.null->resolve
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
    Js.Json.null->resolve
  })
}

let usePaymentMethodList = (
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
    ~method_=Fetch.Get,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    (),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status->string_of_int
    if statusCode->Js.String2.charAt(0) !== "2" {
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
        Js.Json.null->resolve
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
    Js.Json.null->resolve
  })
}

let useCustomerDetails = (
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
    ~method_=Fetch.Get,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~switchToCustomPod, ()),
    (),
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status->string_of_int
    if statusCode->Js.String2.charAt(0) !== "2" {
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
        Js.Json.null->resolve
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
    Js.Json.null->resolve
  })
}
