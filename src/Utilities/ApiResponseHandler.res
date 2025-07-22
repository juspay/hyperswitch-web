open Utils
open PaymentHelpersTypes
open IntentCallTypes
open URLModule
open PaymentConfirmTypes
open Promise

let closePaymentLoaderIfAny = () => messageParentWindow([("fullscreen", false->JSON.Encode.bool)])

let handleOpenUrl = (url, isPaymentSession, redirectionFlags) => {
  if isPaymentSession {
    replaceRootHref(url, redirectionFlags)
  } else {
    openUrl(url)
  }
}

let createApiCallContext = uri => {
  open HyperLoggerTypes
  let isConfirm = uri->String.includes("/confirm")
  let isCompleteAuthorize = uri->String.includes("/complete_authorize")
  let isPostSessionTokens = uri->String.includes("/post_session_tokens")

  let (eventName, initEventName) = switch (isConfirm, isCompleteAuthorize, isPostSessionTokens) {
  | (true, _, _) => (CONFIRM_CALL, CONFIRM_CALL_INIT)
  | (_, true, _) => (COMPLETE_AUTHORIZE_CALL, COMPLETE_AUTHORIZE_CALL_INIT)
  | (_, _, true) => (POST_SESSION_TOKENS_CALL, POST_SESSION_TOKENS_CALL_INIT)
  | _ => (RETRIEVE_CALL, RETRIEVE_CALL_INIT)
  }

  {
    eventName,
    initEventName,
    isConfirm,
    isCompleteAuthorize,
    isPostSessionTokens,
  }
}

let handleFailureRedirection = (params, errorType, message) => {
  let {handleUserError, confirmParam, clientSecret, isPaymentSession, redirectionFlags} = params

  if handleUserError {
    let url = makeUrl(confirmParam.return_url)
    url.searchParams.set("payment_intent_client_secret", clientSecret)
    url.searchParams.set("status", "failed")
    url.searchParams.set("payment_id", clientSecret->getPaymentId)

    handleOpenUrl(url.href, isPaymentSession, redirectionFlags)
    resolve(JSON.Encode.null)
  } else {
    let failedSubmitResponse = getFailedSubmitResponse(~errorType, ~message)
    resolve(failedSubmitResponse)
  }
}

let handleStatusDefault = (params, data, url) => {
  switch (params.paymentType, params.sdkHandleOneClickConfirmPayment) {
  | (Card, _)
  | (Gpay, false)
  | (Applepay, false)
  | (Paypal, false) =>
    if !params.isPaymentSession {
      if params.isCallbackUsedVal->Option.getOr(false) {
        handleOnCompleteDoThisMessage()
      } else {
        closePaymentLoaderIfAny()
      }
      postSubmitResponse(~jsonData=data, ~url=url.href)
    } else if params.confirmParam.redirect === Some("always") {
      if params.isCallbackUsedVal->Option.getOr(false) {
        handleOnCompleteDoThisMessage()
      } else {
        handleOpenUrl(url.href, params.isPaymentSession, params.redirectionFlags)
      }
    }
  | _ =>
    if params.isCallbackUsedVal->Option.getOr(false) {
      closePaymentLoaderIfAny()
      handleOnCompleteDoThisMessage()
    } else {
      handleOpenUrl(url.href, params.isPaymentSession, params.redirectionFlags)
    }
  }
  resolve(data)
}

let handleProcessingStatus = (intent, params, data, _paymentMethod, url) => {
  if intent.nextAction.type_ == "third_party_sdk_session_token" {
    let sessionToken = intent.nextAction.session_token->Option.mapOr(Dict.make(), getDictFromJson)
    let walletName = sessionToken->getString("wallet_name", "")
    let message = switch walletName {
    | "apple_pay" => [
        ("applePayButtonClicked", true->JSON.Encode.bool),
        ("applePayPresent", sessionToken->Identity.anyTypeToJson),
      ]
    | "google_pay" => [("googlePayThirdPartyFlow", sessionToken->Identity.anyTypeToJson)]
    | _ => []
    }

    if !params.isPaymentSession {
      messageParentWindow(message)
    }
    resolve(data)
  } else {
    handleStatusDefault(params, data, url)
  }
}

let handleSucceededStatus = (intent, params, paymentMethod, data, url) => {
  let {optLogger} = params
  LoggerUtils.handleLogging(
    ~optLogger,
    ~value=intent.status,
    ~eventName=PAYMENT_SUCCESS,
    ~paymentMethod,
  )
  handleStatusDefault(params, data, url)
}

let handleFailedStatus = (intent, params, paymentMethod, data, url) => {
  let {optLogger, setIsManualRetryEnabled} = params
  LoggerUtils.handleLogging(
    ~optLogger,
    ~value=intent.status,
    ~eventName=PAYMENT_FAILED,
    ~paymentMethod,
  )
  setIsManualRetryEnabled(_ => intent.manualRetryAllowed)
  handleStatusDefault(params, data, url)
}

let handleEmptyStatus = (params, data) => {
  let {isPaymentSession} = params
  if !isPaymentSession {
    postFailedSubmitResponse(
      ~errortype="confirm_payment_failed",
      ~message="Payment failed. Try again!",
    )
    resolve(data)
  } else {
    let failedSubmitResponse = getFailedSubmitResponse(
      ~errorType="confirm_payment_failed",
      ~message="Payment failed. Try again!",
    )
    resolve(failedSubmitResponse)
  }
}

let handleRequiresPaymentMethod = (intent, data) => {
  if intent.nextAction.type_ === "invoke_sdk_client" {
    let nextActionData = intent.nextAction.next_action_data->Option.getOr(JSON.Encode.null)
    let response =
      [
        ("orderId", intent.connectorTransactionId->JSON.Encode.string),
        ("nextActionData", nextActionData),
      ]->getJsonFromArrayOfJson
    resolve(response)
  } else {
    resolve(data)
  }
}

let processSuccessResponse = (data, context: apiCallContext, params, statusCode) => {
  let {eventName} = context
  let {optLogger, isPaymentSession, clientSecret, paymentType} = params
  LoggerUtils.logApi(
    ~optLogger,
    ~url=params.uri,
    ~statusCode,
    ~apiLogType=Response,
    ~eventName,
    ~isPaymentSession,
  )

  let intent = itemToObjMapper(data->getDictFromJson)
  let paymentMethod = switch paymentType {
  | Card => "CARD"
  | _ => intent.payment_method_type
  }

  let url = makeUrl(params.confirmParam.return_url)
  url.searchParams.set("payment_intent_client_secret", clientSecret)
  url.searchParams.set("payment_id", clientSecret->getPaymentId)
  url.searchParams.set("status", intent.status)

  switch intent.status {
  | "requires_customer_action" => NextActionHandler.handleNextAction(intent, params, data, url)
  | "requires_payment_method" => handleRequiresPaymentMethod(intent, data)
  | "processing" => handleProcessingStatus(intent, params, data, paymentMethod, url)
  | "succeeded" => handleSucceededStatus(intent, params, paymentMethod, data, url)
  | "failed" => handleFailedStatus(intent, params, paymentMethod, data, url)
  | "" => handleEmptyStatus(params, data)
  | _ => handleStatusDefault(params, data, url)
  }
}

let handleApiError = (errorData, context: apiCallContext, params, statusCode) => {
  let {isConfirm, eventName} = context
  let {paymentType, optLogger, isPaymentSession, bodyStr, uri} = params

  if isConfirm {
    let paymentMethod = switch paymentType {
    | Card => "CARD"
    | _ =>
      bodyStr
      ->safeParse
      ->getDictFromJson
      ->getString("payment_method_type", "")
    }
    LoggerUtils.handleLogging(
      ~optLogger,
      ~value=errorData->JSON.stringify,
      ~eventName=PAYMENT_FAILED,
      ~paymentMethod,
    )
  }

  LoggerUtils.logApi(
    ~optLogger,
    ~url=uri,
    ~data=errorData,
    ~statusCode,
    ~apiLogType=Err,
    ~eventName,
    ~logType=ERROR,
    ~logCategory=API,
    ~isPaymentSession,
  )

  let dict = errorData->getDictFromJson
  let errorObj = PaymentError.itemToObjMapper(dict)

  if !isPaymentSession {
    closePaymentLoaderIfAny()
    postFailedSubmitResponse(~errortype=errorObj.error.type_, ~message=errorObj.error.message)
  }

  handleFailureRedirection(params, errorObj.error.type_, errorObj.error.message)
}

let handleNetworkError = (error, context: apiCallContext, params) => {
  let exceptionMessage = error->formatException
  let {optLogger, uri} = params
  LoggerUtils.logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=NoResponse,
    ~data=exceptionMessage,
    ~eventName=context.eventName,
    ~logType=ERROR,
    ~logCategory=API,
    ~isPaymentSession=params.isPaymentSession,
  )

  if params.counter >= 5 {
    if !params.isPaymentSession {
      closePaymentLoaderIfAny()
      postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
    }

    handleFailureRedirection(params, "server_error", "Something went wrong")
  } else {
    // Retry with retrieve call
    // This would need to call the main intentCall function recursively
    // For now, we'll return a retry indicator
    let failedSubmitResponse = getFailedSubmitResponse(
      ~errorType="retry_needed",
      ~message="Retry needed",
    )
    resolve(failedSubmitResponse)
  }
}
