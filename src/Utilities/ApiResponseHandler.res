open Utils
open PaymentHelpersTypes
open LoggerUtils
open IntentCallTypes
open URLModule
open PaymentConfirmTypes
open Promise
open HyperLoggerTypes

let createApiCallContext = uri => {
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

let getPaymentMethodFromParams = params => {
  switch params.paymentType {
  | Card => "CARD"
  | Gpay => "GOOGLE_PAY"
  | Applepay => "APPLE_PAY"
  | Paypal => "PAYPAL"
  | _ => "OTHER"
  }
}

let handleOpenUrl = (url, isPaymentSession, redirectionFlags) => {
  if isPaymentSession {
    replaceRootHref(url, redirectionFlags)
  } else {
    openUrl(url)
  }
}

let closePaymentLoaderIfAny = () => messageParentWindow([("fullscreen", false->JSON.Encode.bool)])

let handleProcessingStatusDefault = (intent, params, data) => {
  let url = makeUrl(params.confirmParam.return_url)
  url.searchParams.set("payment_intent_client_secret", params.clientSecret)
  url.searchParams.set("payment_id", params.clientSecret->getPaymentId)
  url.searchParams.set("status", intent.status)

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
      resolve(data)
    } else if params.confirmParam.redirect === Some("always") {
      if params.isCallbackUsedVal->Option.getOr(false) {
        handleOnCompleteDoThisMessage()
      } else {
        handleOpenUrl(url.href, params.isPaymentSession, params.redirectionFlags)
      }
      resolve(data)
    } else {
      resolve(data)
    }
  | _ =>
    if params.isCallbackUsedVal->Option.getOr(false) {
      closePaymentLoaderIfAny()
      handleOnCompleteDoThisMessage()
    } else {
      handleOpenUrl(url.href, params.isPaymentSession, params.redirectionFlags)
    }
    resolve(data)
  }
}

let handleFinalStatus = (intent, params, data, paymentMethod) => {
  let {optLogger, setIsManualRetryEnabled} = params

  switch intent.status {
  | "succeeded" =>
    handleLogging(~optLogger, ~value=intent.status, ~eventName=PAYMENT_SUCCESS, ~paymentMethod)
  | "failed" =>
    handleLogging(~optLogger, ~value=intent.status, ~eventName=PAYMENT_FAILED, ~paymentMethod)
    setIsManualRetryEnabled(_ => intent.manualRetryAllowed)
  | _ => ()
  }

  handleProcessingStatusDefault(intent, params, data)
}

let handleProcessingStatus = (intent, params, data, _paymentMethod) => {
  if intent.nextAction.type_ == "third_party_sdk_session_token" {
    let sessionToken = switch intent.nextAction.session_token {
    | Some(token) => token->getDictFromJson
    | None => Dict.make()
    }
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
    handleProcessingStatusDefault(intent, params, data)
  }
}

let processSuccessResponse = (data, context: apiCallContext, params, statusCode) => {
  let {eventName} = context
  let {optLogger, isPaymentSession, clientSecret} = params
  logApi(
    ~optLogger,
    ~url=params.uri,
    ~statusCode,
    ~apiLogType=Response,
    ~eventName,
    ~isPaymentSession,
  )

  let intent = itemToObjMapper(data->getDictFromJson)
  let paymentMethod = getPaymentMethodFromParams(params)

  let url = makeUrl(params.confirmParam.return_url)
  url.searchParams.set("payment_intent_client_secret", clientSecret)
  url.searchParams.set("payment_id", clientSecret->getPaymentId)
  url.searchParams.set("status", intent.status)

  if intent.status == "requires_customer_action" {
    NextActionHandler.handleNextAction(intent, params, data, url)
  } else if intent.status == "requires_payment_method" {
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
  } else if intent.status == "processing" {
    handleProcessingStatus(intent, params, data, paymentMethod)
  } else if intent.status != "" {
    handleFinalStatus(intent, params, data, paymentMethod)
  } else if !isPaymentSession {
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

let handleApiError = (errorData, context: apiCallContext, params, statusCode) => {
  let {isConfirm, eventName} = context
  let {
    paymentType,
    optLogger,
    isPaymentSession,
    bodyStr,
    uri,
    handleUserError,
    confirmParam,
    clientSecret,
    redirectionFlags,
  } = params

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
      ~value=errorData->JSON.stringify,
      ~eventName=PAYMENT_FAILED,
      ~paymentMethod,
    )
  }

  logApi(
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

  if handleUserError {
    let url = makeUrl(confirmParam.return_url)
    url.searchParams.set("payment_intent_client_secret", clientSecret)
    url.searchParams.set("status", "failed")
    url.searchParams.set("payment_id", clientSecret->getPaymentId)

    handleOpenUrl(url.href, isPaymentSession, redirectionFlags)
    resolve(JSON.Encode.null)
  } else {
    let failedSubmitResponse = getFailedSubmitResponse(
      ~errorType=errorObj.error.type_,
      ~message=errorObj.error.message,
    )
    resolve(failedSubmitResponse)
  }
}

let handleNetworkError = (error, context: apiCallContext, params) => {
  let exceptionMessage = error->formatException
  logApi(
    ~optLogger=params.optLogger,
    ~url=params.uri,
    ~statusCode=0,
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

    if params.handleUserError {
      let url = makeUrl(params.confirmParam.return_url)
      url.searchParams.set("payment_intent_client_secret", params.clientSecret)
      url.searchParams.set("status", "failed")
      url.searchParams.set("payment_id", params.clientSecret->getPaymentId)

      handleOpenUrl(url.href, params.isPaymentSession, params.redirectionFlags)
      resolve(JSON.Encode.null)
    } else {
      let failedSubmitResponse = getFailedSubmitResponse(
        ~errorType="server_error",
        ~message="Something went wrong",
      )
      resolve(failedSubmitResponse)
    }
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
