open Utils
open PaymentHelpersTypes
open LoggerUtils
open IntentCallTypes
open URLModule
open ApiContextHelper

// Import functions from PaymentHelpers
let closePaymentLoaderIfAny = () => messageParentWindow([("fullscreen", false->JSON.Encode.bool)])

// Handle default processing status behavior
let rec handleProcessingStatusDefault = (params: intentCallParams, data: JSON.t): promise<
  JSON.t,
> => {
  open Promise

  let url = makeUrl(params.confirmParam.return_url)
  url.searchParams.set("payment_intent_client_secret", params.clientSecret)
  url.searchParams.set("payment_id", params.clientSecret->Utils.getPaymentId)

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
        let handleOpenUrl = url => {
          if params.isPaymentSession {
            replaceRootHref(url, params.redirectionFlags)
          } else {
            openUrl(url)
          }
        }
        handleOpenUrl(url.href)
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
      let handleOpenUrl = url => {
        if params.isPaymentSession {
          replaceRootHref(url, params.redirectionFlags)
        } else {
          openUrl(url)
        }
      }
      handleOpenUrl(url.href)
    }
    resolve(data)
  }
}

// Handle final payment statuses
and handleFinalStatus = (
  intent: PaymentConfirmTypes.intent,
  params: intentCallParams,
  data: JSON.t,
  paymentMethod: string,
  _url: URLModule.url,
): promise<JSON.t> => {
  if intent.status === "succeeded" {
    handleLogging(
      ~optLogger=params.optLogger,
      ~value=intent.status,
      ~eventName=PAYMENT_SUCCESS,
      ~paymentMethod,
    )
  } else if intent.status === "failed" {
    handleLogging(
      ~optLogger=params.optLogger,
      ~value=intent.status,
      ~eventName=PAYMENT_FAILED,
      ~paymentMethod,
    )
  }

  if intent.status === "failed" {
    params.setIsManualRetryEnabled(_ => intent.manualRetryAllowed)
  }

  handleProcessingStatusDefault(params, data)
}

// Handle processing status
and handleProcessingStatus = (
  intent: PaymentConfirmTypes.intent,
  params: intentCallParams,
  data: JSON.t,
  _paymentMethod: string,
): promise<JSON.t> => {
  open Promise

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
    handleProcessingStatusDefault(params, data)
  }
}

// Process successful API response
let processSuccessResponse = (
  data: JSON.t,
  context: apiCallContext,
  params: intentCallParams,
): promise<JSON.t> => {
  open Promise

  logApi(
    ~optLogger=params.optLogger,
    ~url=params.uri,
    ~statusCode=200,
    ~apiLogType=Response,
    ~eventName=context.eventName,
    ~isPaymentSession=params.isPaymentSession,
  )

  let intent = PaymentConfirmTypes.itemToObjMapper(data->getDictFromJson)
  let paymentMethod = getPaymentMethodFromParams(params)

  let url = makeUrl(params.confirmParam.return_url)
  url.searchParams.set("payment_intent_client_secret", params.clientSecret)
  url.searchParams.set("payment_id", params.clientSecret->Utils.getPaymentId)
  url.searchParams.set("status", intent.status)

  // Handle different payment statuses
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
    // Handle final statuses (succeeded, failed, etc.)
    handleFinalStatus(intent, params, data, paymentMethod, url)
  } else {
    // Handle empty status
    if !params.isPaymentSession {
      postFailedSubmitResponse(
        ~errortype="confirm_payment_failed",
        ~message="Payment failed. Try again!",
      )
    }
    let failedSubmitResponse = getFailedSubmitResponse(
      ~errorType="confirm_payment_failed",
      ~message="Payment failed. Try again!",
    )
    resolve(failedSubmitResponse)
  }
}

// Handle API error response
let handleApiError = (
  errorData: JSON.t,
  context: apiCallContext,
  params: intentCallParams,
  statusCode: int,
): promise<JSON.t> => {
  open Promise

  if context.isConfirm {
    let paymentMethod = switch params.paymentType {
    | Card => "CARD"
    | _ =>
      params.bodyStr
      ->safeParse
      ->getDictFromJson
      ->getString("payment_method_type", "")
    }
    handleLogging(
      ~optLogger=params.optLogger,
      ~value=errorData->JSON.stringify,
      ~eventName=PAYMENT_FAILED,
      ~paymentMethod,
    )
  }

  logApi(
    ~optLogger=params.optLogger,
    ~url=params.uri,
    ~data=errorData,
    ~statusCode,
    ~apiLogType=Err,
    ~eventName=context.eventName,
    ~logType=ERROR,
    ~logCategory=API,
    ~isPaymentSession=params.isPaymentSession,
  )

  let dict = errorData->getDictFromJson
  let errorObj = PaymentError.itemToObjMapper(dict)

  if !params.isPaymentSession {
    closePaymentLoaderIfAny()
    postFailedSubmitResponse(~errortype=errorObj.error.type_, ~message=errorObj.error.message)
  }

  if params.handleUserError {
    let url = makeUrl(params.confirmParam.return_url)
    url.searchParams.set("payment_intent_client_secret", params.clientSecret)
    url.searchParams.set("status", "failed")
    url.searchParams.set("payment_id", params.clientSecret->Utils.getPaymentId)

    let handleOpenUrl = url => {
      if params.isPaymentSession {
        replaceRootHref(url, params.redirectionFlags)
      } else {
        openUrl(url)
      }
    }
    handleOpenUrl(url.href)
    resolve(JSON.Encode.null)
  } else {
    let failedSubmitResponse = getFailedSubmitResponse(
      ~errorType=errorObj.error.type_,
      ~message=errorObj.error.message,
    )
    resolve(failedSubmitResponse)
  }
}

// Handle network errors and determine retry strategy
let handleNetworkError = (error: exn, context: apiCallContext, params: intentCallParams): promise<
  JSON.t,
> => {
  open Promise

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
    // Max retries reached
    if !params.isPaymentSession {
      closePaymentLoaderIfAny()
      postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
    }

    if params.handleUserError {
      let url = makeUrl(params.confirmParam.return_url)
      url.searchParams.set("payment_intent_client_secret", params.clientSecret)
      url.searchParams.set("payment_id", params.clientSecret->Utils.getPaymentId)
      url.searchParams.set("status", "failed")

      let handleOpenUrl = url => {
        if params.isPaymentSession {
          replaceRootHref(url, params.redirectionFlags)
        } else {
          openUrl(url)
        }
      }
      handleOpenUrl(url.href)
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
