open Utils
open LoggerUtils
open Identity
open Promise
open PaymentConfirmTypes
open IntentCallTypes
open URLModule

let getPaymentMethodFromParams = params => {
  switch params.paymentType {
  | Card => "CARD"
  | Gpay => "GOOGLE_PAY"
  | Applepay => "APPLE_PAY"
  | Paypal => "PAYPAL"
  | _ => "OTHER"
  }
}

let parseNextAction = intent => {
  switch intent.nextAction.type_ {
  | "redirect_to_url" => RedirectToUrl(intent.nextAction.redirectToUrl)
  | "redirect_inside_popup" =>
    RedirectInsidePopup(intent.nextAction.popupUrl, intent.nextAction.redirectResponseUrl)
  | "display_bank_transfer_information" =>
    DisplayBankTransferInfo(intent.nextAction.bank_transfer_steps_and_charges_details)
  | "qr_code_information" => {
      let qrData = intent.nextAction.image_data_url->Option.getOr("")
      let displayText = intent.nextAction.display_text->Option.getOr("")
      let borderColor = intent.nextAction.border_color->Option.getOr("")
      let expiryTime = intent.nextAction.display_to_timestamp->Option.getOr(0.0)
      QrCodeInformation(qrData, displayText, borderColor, expiryTime)
    }
  | "three_ds_invoke" => {
      let threeDsData =
        intent.nextAction.three_ds_data
        ->Option.flatMap(JSON.Decode.object)
        ->Option.getOr(Dict.make())
      ThreeDsInvoke(threeDsData)
    }
  | "invoke_hidden_iframe" => {
      let iframeData =
        intent.nextAction.iframe_data
        ->Option.flatMap(JSON.Decode.object)
        ->Option.getOr(Dict.make())
      InvokeHiddenIframe(iframeData)
    }
  | "display_voucher_information" => {
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
      DisplayVoucherInfo(voucherData)
    }
  | "third_party_sdk_session_token" => {
      let sessionToken = switch intent.nextAction.session_token {
      | Some(token) => token->getDictFromJson
      | None => Dict.make()
      }
      ThirdPartySdkSessionToken(sessionToken)
    }
  | "invoke_sdk_client" => {
      let nextActionData = intent.nextAction.next_action_data->Option.getOr(JSON.Encode.null)
      InvokeSdkClient(nextActionData)
    }
  | actionType => Unknown(actionType)
  }
}

let handleRedirectToUrl = (url, params) => {
  let paymentMethod = switch params.paymentType {
  | Card => "CARD"
  | _ => ""
  }

  handleLogging(~optLogger=params.optLogger, ~value="", ~eventName=REDIRECTING_USER, ~paymentMethod)

  let handleOpenUrl = url => {
    if params.isPaymentSession {
      replaceRootHref(url, params.redirectionFlags)
    } else {
      openUrl(url)
    }
  }

  handleOpenUrl(url)
  resolve(JSON.Encode.null)
}

let handleRedirectInsidePopup = (popupUrl, redirectResponseUrl, params) => {
  let paymentMethod = switch params.paymentType {
  | Card => "CARD"
  | _ => ""
  }

  handleLogging(
    ~optLogger=params.optLogger,
    ~value="",
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
    ("iframeId", params.iframeId->JSON.Encode.string),
    ("metadata", metaData->getJsonFromArrayOfJson),
  ])

  resolve(JSON.Encode.null)
}

let handleDisplayBankTransferInfo = (bankTransferDetails, params, data, url) => {
  let paymentMethod = switch params.paymentType {
  | Card => "CARD"
  | _ => ""
  }

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

let handleQrCodeInformation = (qrData, displayText, borderColor, expiryTime, params, data, url) => {
  let paymentMethod = switch params.paymentType {
  | Card => "CARD"
  | _ => ""
  }

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

let handleThreeDsInvoke = (threeDsData, params, url) => {
  let paymentMethod = switch params.paymentType {
  | Card => "CARD"
  | _ => ""
  }

  let do3dsMethodCall =
    threeDsData
    ->Dict.get("three_ds_method_details")
    ->Option.flatMap(JSON.Decode.object)
    ->Option.flatMap(x => x->Dict.get("three_ds_method_data_submission"))
    ->Option.getOr(Dict.make()->JSON.Encode.object)
    ->JSON.Decode.bool
    ->getBoolValue

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

let handleInvokeHiddenIframe = (iframeData, params, url) => {
  let headerObj = Dict.make()
  mergeHeadersIntoDict(~dict=headerObj, ~headers=params.headers)

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

let handleDisplayVoucherInfo = (voucherData, params, data, url) => {
  let paymentMethod = switch params.paymentType {
  | Card => "CARD"
  | _ => ""
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

let handleThirdPartySdkSessionToken = (sessionToken, params, data) => {
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

let handleInvokeSdkClient = (nextActionData, intent) => {
  let response =
    [
      ("orderId", intent.connectorTransactionId->JSON.Encode.string),
      ("nextActionData", nextActionData),
    ]->getJsonFromArrayOfJson

  resolve(response)
}

let handleNextAction = (intent, params, data, url) => {
  let nextAction = parseNextAction(intent)

  switch nextAction {
  | RedirectToUrl(redirectUrl) => handleRedirectToUrl(redirectUrl, params)
  | RedirectInsidePopup(popupUrl, redirectResponseUrl) =>
    handleRedirectInsidePopup(popupUrl, redirectResponseUrl, params)
  | DisplayBankTransferInfo(details) => handleDisplayBankTransferInfo(details, params, data, url)
  | QrCodeInformation(qrData, displayText, borderColor, expiryTime) =>
    handleQrCodeInformation(qrData, displayText, borderColor, expiryTime, params, data, url)
  | ThreeDsInvoke(threeDsData) => handleThreeDsInvoke(threeDsData, params, url)
  | InvokeHiddenIframe(iframeData) => handleInvokeHiddenIframe(iframeData, params, url)
  | DisplayVoucherInfo(voucherData) => handleDisplayVoucherInfo(voucherData, params, data, url)
  | ThirdPartySdkSessionToken(sessionToken) =>
    handleThirdPartySdkSessionToken(sessionToken, params, data)
  | InvokeSdkClient(nextActionData) => handleInvokeSdkClient(nextActionData, intent)
  | Unknown(actionType) => {
      if !params.isPaymentSession {
        postFailedSubmitResponse(
          ~errortype="confirm_payment_failed",
          ~message="Payment failed. Try again!",
        )
      }

      if params.uri->String.includes("force_sync=true") {
        let paymentMethod = getPaymentMethodFromParams(params)
        handleLogging(
          ~optLogger=params.optLogger,
          ~value=actionType,
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
  }
}
