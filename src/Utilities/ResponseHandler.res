open Utils
open Identity
open PaymentHelpersTypes
open PaymentConfirmTypes
open ConfirmType
open LoggerUtils
open URLModule

let handleProcessingStatus = (
  paymentType,
  sdkHandleOneClickConfirmPayment,
  isPaymentSession,
  isCallbackUsedVal,
  handleOpenUrl,
  url,
  resolve,
  data,
  confirmParam,
) => {
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

let handleRequiresPaymentMethod = (intent, resolve) => {
  if intent.nextAction.type_ === "invoke_sdk_client" {
    let nextActionData = intent.nextAction.next_action_data->Option.getOr(JSON.Encode.null)
    let response =
      [
        ("orderId", intent.connectorTransactionId->JSON.Encode.string),
        ("nextActionData", nextActionData),
      ]->getJsonFromArrayOfJson
    resolve(response)
  }
}

let handleProcessing = (
  intent,
  paymentType,
  sdkHandleOneClickConfirmPayment,
  isPaymentSession,
  isCallbackUsedVal,
  handleOpenUrl,
  url,
  resolve,
  data,
  confirmParam,
) => {
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
    handleProcessingStatus(
      paymentType,
      sdkHandleOneClickConfirmPayment,
      isPaymentSession,
      isCallbackUsedVal,
      handleOpenUrl,
      url,
      resolve,
      data,
      confirmParam,
    )
  }
  resolve(data)
}

let handleSucceeded = (
  intent,
  optLogger,
  paymentMethod,
  paymentType,
  sdkHandleOneClickConfirmPayment,
  isPaymentSession,
  isCallbackUsedVal,
  handleOpenUrl,
  url,
  resolve,
  data,
  confirmParam,
) => {
  handleLogging(~optLogger, ~value=intent.status, ~eventName=PAYMENT_SUCCESS, ~paymentMethod)
  handleProcessingStatus(
    paymentType,
    sdkHandleOneClickConfirmPayment,
    isPaymentSession,
    isCallbackUsedVal,
    handleOpenUrl,
    url,
    resolve,
    data,
    confirmParam,
  )
}

let handleFailed = (
  intent,
  optLogger,
  paymentMethod,
  setIsManualRetryEnabled,
  paymentType,
  sdkHandleOneClickConfirmPayment,
  isPaymentSession,
  isCallbackUsedVal,
  handleOpenUrl,
  url,
  resolve,
  data,
  confirmParam,
) => {
  handleLogging(~optLogger, ~value=intent.status, ~eventName=PAYMENT_FAILED, ~paymentMethod)
  if intent.status === "failed" {
    setIsManualRetryEnabled(_ => intent.manualRetryAllowed)
  }
  handleProcessingStatus(
    paymentType,
    sdkHandleOneClickConfirmPayment,
    isPaymentSession,
    isCallbackUsedVal,
    handleOpenUrl,
    url,
    resolve,
    data,
    confirmParam,
  )
}

let handleDefault = (isPaymentSession, resolve) => {
  if !isPaymentSession {
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
}

let handle = (
  intent,
  ~optLogger,
  ~paymentMethod,
  ~handleOpenUrl,
  ~iframeId,
  ~data,
  ~url,
  ~clientSecret,
  ~confirmParam,
  ~headers,
  ~componentName,
  ~resolve,
  ~paymentType,
  ~sdkHandleOneClickConfirmPayment,
  ~isPaymentSession,
  ~isCallbackUsedVal,
  ~setIsManualRetryEnabled,
) => {
  switch intent.status {
  | "requires_customer_action" =>
    NextActionHandler.handle(
      intent,
      ~optLogger,
      ~paymentMethod,
      ~handleOpenUrl,
      ~iframeId,
      ~data,
      ~url,
      ~clientSecret,
      ~confirmParam,
      ~headers,
      ~componentName,
      ~resolve,
    )
  | "requires_payment_method" => handleRequiresPaymentMethod(intent, resolve)->ignore
  | "processing" =>
    handleProcessing(
      intent,
      paymentType,
      sdkHandleOneClickConfirmPayment,
      isPaymentSession,
      isCallbackUsedVal,
      handleOpenUrl,
      url,
      resolve,
      data,
      confirmParam,
    )->ignore
  | "succeeded" =>
    handleSucceeded(
      intent,
      optLogger,
      paymentMethod,
      paymentType,
      sdkHandleOneClickConfirmPayment,
      isPaymentSession,
      isCallbackUsedVal,
      handleOpenUrl,
      url,
      resolve,
      data,
      confirmParam,
    )->ignore
  | "failed" =>
    handleFailed(
      intent,
      optLogger,
      paymentMethod,
      setIsManualRetryEnabled,
      paymentType,
      sdkHandleOneClickConfirmPayment,
      isPaymentSession,
      isCallbackUsedVal,
      handleOpenUrl,
      url,
      resolve,
      data,
      confirmParam,
    )->ignore
  | _ => handleDefault(isPaymentSession, resolve)->ignore
  }
}
