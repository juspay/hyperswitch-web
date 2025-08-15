open Utils
open LoggerUtils
open Identity
open Promise
open PaymentConfirmTypes
open IntentCallTypes
open URLModule

let getPaymentMethod = params =>
  switch params.paymentType {
  | Card => "CARD"
  | _ => ""
  }

let handleRedirectToUrl = (params, intent, paymentMethod) => {
  handleLogging(~optLogger=params.optLogger, ~value="", ~eventName=REDIRECTING_USER, ~paymentMethod)

  let handleOpenUrl = url => {
    if params.isPaymentSession {
      replaceRootHref(url, params.redirectionFlags)
    } else {
      openUrl(url)
    }
  }

  let redirectUrl = intent.nextAction.redirectToUrl
  handleOpenUrl(redirectUrl)
  resolve(JSON.Encode.null)
}

let handleRedirectInsidePopup = (params, intent, paymentMethod) => {
  handleLogging(
    ~optLogger=params.optLogger,
    ~value="",
    ~eventName=THREE_DS_POPUP_REDIRECTION,
    ~paymentMethod,
  )

  let popupUrl = intent.nextAction.popupUrl
  let redirectResponseUrl = intent.nextAction.redirectResponseUrl

  let metaData = [
    ("popupUrl", popupUrl->JSON.Encode.string),
    ("redirectResponseUrl", redirectResponseUrl->JSON.Encode.string),
  ]

  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", `3dsRedirectionPopup`->JSON.Encode.string),
    ("iframeId", params.iframeId->JSON.Encode.string),
    ("metadata", metaData->getJsonFromArrayOfJson),
  ])

  resolve(JSON.Encode.null)
}

let handleDisplayBankTransferInfo = (params, data, url, intent, paymentMethod) => {
  let bankTransferDetails = intent.nextAction.bank_transfer_steps_and_charges_details
  let metadata = switch bankTransferDetails {
  | Some(obj) => obj->getDictFromJson
  | None => Dict.make()
  }
  let dict = deepCopyDict(metadata)
  dict->Dict.set("data", data)
  dict->Dict.set("url", url.href->JSON.Encode.string)

  handleLogging(
    ~optLogger=params.optLogger,
    ~value="",
    ~eventName=DISPLAY_BANK_TRANSFER_INFO_PAGE,
    ~paymentMethod,
  )

  if !params.isPaymentSession {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      (
        "param",
        `${switch params.paymentType {
          | Card => "card"
          | Gpay => "google_pay"
          | Applepay => "apple_pay"
          | Paypal => "paypal"
          | _ => "other"
          }}BankTransfer`->JSON.Encode.string,
      ),
      ("iframeId", params.iframeId->JSON.Encode.string),
      ("metadata", dict->JSON.Encode.object),
    ])
  }

  resolve(data)
}

let handleQrCodeInformation = (params, data, url, intent, paymentMethod) => {
  let qrData = intent.nextAction.image_data_url->Option.getOr("")
  let displayText = intent.nextAction.display_text->Option.getOr("")
  let borderColor = intent.nextAction.border_color->Option.getOr("")
  let expiryTime = intent.nextAction.display_to_timestamp->Option.getOr(0.0)

  let headerObj = Dict.make()
  mergeHeadersIntoDict(~dict=headerObj, ~headers=params.headers)

  let metaData =
    [
      ("qrData", qrData->JSON.Encode.string),
      ("paymentIntentId", params.clientSecret->JSON.Encode.string),
      ("publishableKey", params.confirmParam.publishableKey->JSON.Encode.string),
      ("headers", headerObj->JSON.Encode.object),
      ("expiryTime", expiryTime->Float.toString->JSON.Encode.string),
      ("url", url.href->JSON.Encode.string),
      ("paymentMethod", paymentMethod->JSON.Encode.string),
      ("display_text", displayText->JSON.Encode.string),
      ("border_color", borderColor->JSON.Encode.string),
    ]->getJsonFromArrayOfJson

  handleLogging(
    ~optLogger=params.optLogger,
    ~value="",
    ~eventName=DISPLAY_QR_CODE_INFO_PAGE,
    ~paymentMethod,
  )

  if !params.isPaymentSession {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", `qrData`->JSON.Encode.string),
      ("iframeId", params.iframeId->JSON.Encode.string),
      ("metadata", metaData),
    ])
  }

  resolve(data)
}

let handleThreeDsInvoke = (params, url, intent, paymentMethod) => {
  let threeDsData = intent.nextAction.three_ds_data->decodeJsonToDict

  let do3dsMethodCall =
    threeDsData
    ->getDictFromObj("three_ds_method_details")
    ->getBool("three_ds_method_data_submission", false)

  let headerObj = Dict.make()
  mergeHeadersIntoDict(~dict=headerObj, ~headers=params.headers)

  let metaData =
    [
      ("threeDSData", threeDsData->JSON.Encode.object),
      ("paymentIntentId", params.clientSecret->JSON.Encode.string),
      ("publishableKey", params.confirmParam.publishableKey->JSON.Encode.string),
      ("headers", headerObj->JSON.Encode.object),
      ("url", url.href->JSON.Encode.string),
      ("iframeId", params.iframeId->JSON.Encode.string),
    ]->Dict.fromArray

  handleLogging(
    ~optLogger=params.optLogger,
    ~value=do3dsMethodCall ? "Y" : "N",
    ~eventName=THREE_DS_METHOD,
    ~paymentMethod,
  )

  if do3dsMethodCall {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", `3ds`->JSON.Encode.string),
      ("iframeId", params.iframeId->JSON.Encode.string),
      ("metadata", metaData->JSON.Encode.object),
    ])
  } else {
    metaData->Dict.set("3dsMethodComp", "U"->JSON.Encode.string)
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", `3dsAuth`->JSON.Encode.string),
      ("iframeId", params.iframeId->JSON.Encode.string),
      ("metadata", metaData->JSON.Encode.object),
    ])
  }

  resolve(JSON.Encode.null)
}

let handleInvokeHiddenIframe = (params, url, intent) => {
  let headerObj = Dict.make()
  mergeHeadersIntoDict(~dict=headerObj, ~headers=params.headers)

  let iframeData = intent.nextAction.iframe_data->decodeJsonToDict

  let metaData =
    [
      ("iframeData", iframeData->JSON.Encode.object),
      ("paymentIntentId", params.clientSecret->JSON.Encode.string),
      ("publishableKey", params.confirmParam.publishableKey->JSON.Encode.string),
      ("headers", headerObj->JSON.Encode.object),
      ("url", url.href->JSON.Encode.string),
      ("iframeId", params.iframeId->JSON.Encode.string),
      ("confirmParams", params.confirmParam->anyTypeToJson),
    ]->Dict.fromArray

  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", `redsys3ds`->JSON.Encode.string),
    ("iframeId", params.iframeId->JSON.Encode.string),
    ("metadata", metaData->JSON.Encode.object),
  ])

  resolve(JSON.Encode.null)
}

let handleDisplayVoucherInfo = (params, data, url, intent, paymentMethod) => {
  let voucherData = switch intent.nextAction.voucher_details {
  | Some(details) => {
      download_url: details.download_url,
      reference: details.reference,
    }
  | None => {
      download_url: "",
      reference: "",
    }
  }

  let headerObj = Dict.make()
  mergeHeadersIntoDict(~dict=headerObj, ~headers=params.headers)

  let metaData =
    [
      ("voucherUrl", voucherData.download_url->JSON.Encode.string),
      ("reference", voucherData.reference->JSON.Encode.string),
      ("returnUrl", url.href->JSON.Encode.string),
      ("paymentMethod", paymentMethod->JSON.Encode.string),
      ("payment_intent_data", data),
    ]->Dict.fromArray

  handleLogging(~optLogger=params.optLogger, ~value="", ~eventName=DISPLAY_VOUCHER, ~paymentMethod)

  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", `voucherData`->JSON.Encode.string),
    ("iframeId", params.iframeId->JSON.Encode.string),
    ("metadata", metaData->JSON.Encode.object),
  ])

  resolve(JSON.Encode.null)
}

let handleThirdPartySdkSessionToken = (params, data, intent) => {
  let sessionToken = intent.nextAction.session_token->Option.mapOr(Dict.make(), getDictFromJson)
  let walletName = sessionToken->getString("wallet_name", "")

  let message = switch walletName {
  | "apple_pay" => [
      ("applePayButtonClicked", true->JSON.Encode.bool),
      ("applePayPresent", sessionToken->anyTypeToJson),
      ("componentName", params.componentName->JSON.Encode.string),
    ]
  | "google_pay" => [("googlePayThirdPartyFlow", sessionToken->anyTypeToJson)]
  | "open_banking" => {
      let metaData =
        [
          (
            "linkToken",
            sessionToken->getString("open_banking_session_token", "")->JSON.Encode.string,
          ),
          ("pmAuthConnectorArray", ["plaid"]->anyTypeToJson),
          ("publishableKey", params.confirmParam.publishableKey->JSON.Encode.string),
          ("clientSecret", params.clientSecret->JSON.Encode.string),
          ("isForceSync", true->JSON.Encode.bool),
        ]->getJsonFromArrayOfJson
      [
        ("fullscreen", true->JSON.Encode.bool),
        ("param", "plaidSDK"->JSON.Encode.string),
        ("iframeId", params.iframeId->JSON.Encode.string),
        ("metadata", metaData),
      ]
    }
  | _ => []
  }

  if !params.isPaymentSession {
    messageParentWindow(message)
  }

  resolve(data)
}

let handleInvokeSdkClient = intent => {
  let nextActionData = intent.nextAction.next_action_data->Option.getOr(JSON.Encode.null)
  let response =
    [
      ("orderId", intent.connectorTransactionId->JSON.Encode.string),
      ("nextActionData", nextActionData),
    ]->getJsonFromArrayOfJson

  resolve(response)
}

let handleUnknownNextAction = (unknownNextAction, params, url, paymentMethod) => {
  if !params.isPaymentSession {
    postFailedSubmitResponse(
      ~errortype="confirm_payment_failed",
      ~message="Payment failed. Try again!",
    )
  }

  if params.uri->String.includes("force_sync=true") {
    handleLogging(
      ~optLogger=params.optLogger,
      ~value=unknownNextAction,
      ~eventName=REDIRECTING_USER,
      ~paymentMethod,
      ~logType=ERROR,
    )

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
      ~errorType="confirm_payment_failed",
      ~message="Payment failed. Try again!",
    )
    resolve(failedSubmitResponse)
  }
}

let handleNextAction = (intent, params, data, url) => {
  let paymentMethod = switch params.paymentType {
  | Card => "CARD"
  | _ => intent.payment_method_type
  }
  switch intent.nextAction.type_ {
  | "redirect_to_url" => handleRedirectToUrl(params, intent, paymentMethod)
  | "redirect_inside_popup" => handleRedirectInsidePopup(params, intent, paymentMethod)
  | "display_bank_transfer_information" =>
    handleDisplayBankTransferInfo(params, data, url, intent, paymentMethod)
  | "qr_code_information" => handleQrCodeInformation(params, data, url, intent, paymentMethod)
  | "three_ds_invoke" => handleThreeDsInvoke(params, url, intent, paymentMethod)
  | "invoke_hidden_iframe" => handleInvokeHiddenIframe(params, url, intent)
  | "display_voucher_information" =>
    handleDisplayVoucherInfo(params, data, url, intent, paymentMethod)
  | "third_party_sdk_session_token" => handleThirdPartySdkSessionToken(params, data, intent)
  | "invoke_sdk_client" => handleInvokeSdkClient(intent)
  | unknownNextAction => handleUnknownNextAction(unknownNextAction, params, url, paymentMethod)
  }
}
