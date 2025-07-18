open Utils
open PaymentHelpersTypes
open LoggerUtils
open Identity
open IntentCallTypes
open ApiContextHelper

// Parse next action from intent
let parseNextAction = (intent: PaymentConfirmTypes.intent): nextActionType => {
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
      let voucherData: voucherDetails = switch intent.nextAction.voucher_details {
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

// Handle redirect to URL
let handleRedirectToUrl = (url: string, params: intentCallParams): promise<JSON.t> => {
  open Promise
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

// Handle redirect inside popup
let handleRedirectInsidePopup = (
  popupUrl: string,
  redirectResponseUrl: string,
  params: intentCallParams,
): promise<JSON.t> => {
  open Promise
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

// Handle display bank transfer information
let handleDisplayBankTransferInfo = (
  bankTransferDetails: option<JSON.t>,
  params: intentCallParams,
  data: JSON.t,
  url: URLModule.url,
): promise<JSON.t> => {
  open Promise
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

// Handle QR code information
let handleQrCodeInformation = (
  qrData: string,
  displayText: string,
  borderColor: string,
  expiryTime: float,
  params: intentCallParams,
  data: JSON.t,
  url: URLModule.url,
): promise<JSON.t> => {
  open Promise
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

// Handle 3DS invocation
let handleThreeDsInvoke = (
  threeDsData: Dict.t<JSON.t>,
  params: intentCallParams,
  url: URLModule.url,
): promise<JSON.t> => {
  open Promise
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

// Handle hidden iframe invocation
let handleInvokeHiddenIframe = (
  iframeData: Dict.t<JSON.t>,
  params: intentCallParams,
  url: URLModule.url,
): promise<JSON.t> => {
  open Promise
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

// Handle voucher information display
let handleDisplayVoucherInfo = (
  voucherData: voucherDetails,
  params: intentCallParams,
  data: JSON.t,
  url: URLModule.url,
): promise<JSON.t> => {
  open Promise
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

// Handle third party SDK session token
let handleThirdPartySdkSessionToken = (
  sessionToken: Dict.t<JSON.t>,
  params: intentCallParams,
  data: JSON.t,
): promise<JSON.t> => {
  open Promise
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

// Handle SDK client invocation
let handleInvokeSdkClient = (nextActionData: JSON.t, intent: PaymentConfirmTypes.intent): promise<
  JSON.t,
> => {
  open Promise
  let response =
    [
      ("orderId", intent.connectorTransactionId->JSON.Encode.string),
      ("nextActionData", nextActionData),
    ]->getJsonFromArrayOfJson

  resolve(response)
}

// Main next action dispatcher
let handleNextAction = (
  intent: PaymentConfirmTypes.intent,
  params: intentCallParams,
  data: JSON.t,
  url: URLModule.url,
): promise<JSON.t> => {
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
      // Handle unknown action types
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
        Promise.resolve(JSON.Encode.null)
      } else {
        let failedSubmitResponse = getFailedSubmitResponse(
          ~errorType="confirm_payment_failed",
          ~message="Payment failed. Try again!",
        )
        Promise.resolve(failedSubmitResponse)
      }
    }
  }
}
