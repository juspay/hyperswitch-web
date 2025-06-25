open Utils
open Identity
open PaymentConfirmTypes
open ConfirmType
open LoggerUtils
open URLModule

let handleRedirectToUrl = (
  intent: PaymentConfirmTypes.intent,
  optLogger,
  paymentMethod,
  handleOpenUrl,
) => {
  handleLogging(~optLogger, ~value="", ~eventName=REDIRECTING_USER, ~paymentMethod)
  handleOpenUrl(intent.nextAction.redirectToUrl)
}

let handleRedirectInsidePopup = (
  intent: PaymentConfirmTypes.intent,
  iframeId,
  paymentMethod,
  optLogger,
) => {
  let popupUrl = intent.nextAction.popupUrl
  let redirectResponseUrl = intent.nextAction.redirectResponseUrl
  handleLogging(~optLogger, ~value="", ~eventName=THREE_DS_POPUP_REDIRECTION, ~paymentMethod)
  let metaData = [
    ("popupUrl", popupUrl->JSON.Encode.string),
    ("redirectResponseUrl", redirectResponseUrl->JSON.Encode.string),
  ]
  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", `3dsRedirectionPopup`->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
    ("metadata", metaData->getJsonFromArrayOfJson),
  ])
}

let handleDisplayBankTransferInformation = (
  intent: PaymentConfirmTypes.intent,
  iframeId,
  paymentMethod,
  optLogger,
  data,
  url,
) => {
  let metadata = switch intent.nextAction.bank_transfer_steps_and_charges_details {
  | Some(obj) => obj->getDictFromJson
  | None => Dict.make()
  }
  let dict = deepCopyDict(metadata)
  dict->Dict.set("data", data)
  dict->Dict.set("url", url.href->JSON.Encode.string)
  handleLogging(~optLogger, ~value="", ~eventName=DISPLAY_BANK_TRANSFER_INFO_PAGE, ~paymentMethod)
  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", `${intent.payment_method_type}BankTransfer`->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
    ("metadata", dict->JSON.Encode.object),
  ])
}

let handleQrCodeInformation = (
  intent: PaymentConfirmTypes.intent,
  clientSecret,
  confirmParam: ConfirmType.confirmParams,
  headers,
  url,
  paymentMethod,
  optLogger,
  iframeId,
) => {
  let qrData = intent.nextAction.image_data_url->Option.getOr("")
  let displayText = intent.nextAction.display_text->Option.getOr("")
  let borderColor = intent.nextAction.border_color->Option.getOr("")
  let expiryTime = intent.nextAction.display_to_timestamp->Option.getOr(0.0)
  let headerObj = Dict.make()
  mergeHeadersIntoDict(~dict=headerObj, ~headers)
  let metaData =
    [
      ("qrData", qrData->JSON.Encode.string),
      ("paymentIntentId", clientSecret->JSON.Encode.string),
      ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
      ("headers", headerObj->JSON.Encode.object),
      ("expiryTime", expiryTime->Float.toString->JSON.Encode.string),
      ("url", url.href->JSON.Encode.string),
      ("paymentMethod", paymentMethod->JSON.Encode.string),
      ("display_text", displayText->JSON.Encode.string),
      ("border_color", borderColor->JSON.Encode.string),
    ]->getJsonFromArrayOfJson
  handleLogging(~optLogger, ~value="", ~eventName=DISPLAY_QR_CODE_INFO_PAGE, ~paymentMethod)
  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", `qrData`->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
    ("metadata", metaData),
  ])
}

let handleThreeDsInvoke = (
  intent: PaymentConfirmTypes.intent,
  clientSecret,
  confirmParam: ConfirmType.confirmParams,
  headers,
  url,
  iframeId,
  paymentMethod,
  optLogger,
) => {
  let threeDsData =
    intent.nextAction.three_ds_data
    ->Option.flatMap(JSON.Decode.object)
    ->Option.getOr(Dict.make())
  let do3dsMethodCall =
    threeDsData
    ->Dict.get("three_ds_method_details")
    ->Option.flatMap(JSON.Decode.object)
    ->Option.flatMap(x => x->Dict.get("three_ds_method_data_submission"))
    ->Option.getOr(Dict.make()->JSON.Encode.object)
    ->JSON.Decode.bool
    ->getBoolValue

  let headerObj = Dict.make()
  mergeHeadersIntoDict(~dict=headerObj, ~headers)

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
  )

  if do3dsMethodCall {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", `3ds`->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
      ("metadata", metaData->JSON.Encode.object),
    ])
  } else {
    metaData->Dict.set("3dsMethodComp", "U"->JSON.Encode.string)
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", `3dsAuth`->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
      ("metadata", metaData->JSON.Encode.object),
    ])
  }
}

let handleInvokeHiddenIframe = (
  intent: PaymentConfirmTypes.intent,
  clientSecret,
  confirmParam: ConfirmType.confirmParams,
  headers,
  url,
  iframeId,
) => {
  let iframeData =
    intent.nextAction.iframe_data
    ->Option.flatMap(JSON.Decode.object)
    ->Option.getOr(Dict.make())

  let headerObj = Dict.make()
  mergeHeadersIntoDict(~dict=headerObj, ~headers)
  let metaData =
    [
      ("iframeData", iframeData->JSON.Encode.object),
      ("paymentIntentId", clientSecret->JSON.Encode.string),
      ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
      ("headers", headerObj->JSON.Encode.object),
      ("url", url.href->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
      ("confirmParams", confirmParam->anyTypeToJson),
    ]->Dict.fromArray

  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", `redsys3ds`->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
    ("metadata", metaData->JSON.Encode.object),
  ])
}

let handleDisplayVoucherInformation = (
  intent: PaymentConfirmTypes.intent,
  url,
  paymentMethod,
  optLogger,
  iframeId,
  data,
) => {
  let voucherData = intent.nextAction.voucher_details->Option.getOr({
    download_url: "",
    reference: "",
  })

  let metaData =
    [
      ("voucherUrl", voucherData.download_url->JSON.Encode.string),
      ("reference", voucherData.reference->JSON.Encode.string),
      ("returnUrl", url.href->JSON.Encode.string),
      ("paymentMethod", paymentMethod->JSON.Encode.string),
      ("payment_intent_data", data),
    ]->Dict.fromArray
  handleLogging(~optLogger, ~value="", ~eventName=DISPLAY_VOUCHER, ~paymentMethod)
  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", `voucherData`->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
    ("metadata", metaData->JSON.Encode.object),
  ])
}

let handleThirdPartySdkSessionToken = (
  intent: PaymentConfirmTypes.intent,
  componentName,
  confirmParam: ConfirmType.confirmParams,
  clientSecret,
  iframeId,
) => {
  let session_token = switch intent.nextAction.session_token {
  | Some(token) => token->getDictFromJson
  | None => Dict.make()
  }
  let walletName = session_token->getString("wallet_name", "")

  let message = switch walletName {
  | "apple_pay" => [
      ("applePayButtonClicked", true->JSON.Encode.bool),
      ("applePayPresent", session_token->anyTypeToJson),
      ("componentName", componentName->JSON.Encode.string),
    ]
  | "google_pay" => [("googlePayThirdPartyFlow", session_token->anyTypeToJson)]
  | "open_banking" => {
      let metaData = [
        (
          "linkToken",
          session_token
          ->getString("open_banking_session_token", "")
          ->JSON.Encode.string,
        ),
        ("pmAuthConnectorArray", ["plaid"]->anyTypeToJson),
        ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
        ("clientSecret", clientSecret->JSON.Encode.string),
        ("isForceSync", true->JSON.Encode.bool),
      ]->getJsonFromArrayOfJson
      [
        ("fullscreen", true->JSON.Encode.bool),
        ("param", "plaidSDK"->JSON.Encode.string),
        ("iframeId", iframeId->JSON.Encode.string),
        ("metadata", metaData),
      ]
    }
  | _ => []
  }
  messageParentWindow(message)
}

let handleInvokeSdkClient = (intent: PaymentConfirmTypes.intent) => {
  let nextActionData = intent.nextAction.next_action_data->Option.getOr(JSON.Encode.null)
  let response =
    [
      ("orderId", intent.connectorTransactionId->JSON.Encode.string),
      ("nextActionData", nextActionData),
    ]->getJsonFromArrayOfJson
  response
}

let handle = (
  intent: PaymentConfirmTypes.intent,
  ~optLogger,
  ~paymentMethod,
  ~handleOpenUrl,
  ~iframeId,
  ~data,
  ~url,
  ~clientSecret,
  ~confirmParam: ConfirmType.confirmParams,
  ~headers,
  ~componentName,
  ~resolve,
) => {
  switch intent.nextAction.type_ {
  | "redirect_to_url" =>
    handleRedirectToUrl(intent, optLogger, paymentMethod, handleOpenUrl)->ignore
  | "redirect_inside_popup" =>
    handleRedirectInsidePopup(intent, iframeId, paymentMethod, optLogger)->ignore
  | "display_bank_transfer_information" =>
    handleDisplayBankTransferInformation(
      intent,
      iframeId,
      paymentMethod,
      optLogger,
      data,
      url,
    )->ignore
  | "qr_code_information" =>
    handleQrCodeInformation(
      intent,
      clientSecret,
      confirmParam,
      headers,
      url,
      paymentMethod,
      optLogger,
      iframeId,
    )->ignore
  | "three_ds_invoke" =>
    handleThreeDsInvoke(
      intent,
      clientSecret,
      confirmParam,
      headers,
      url,
      iframeId,
      paymentMethod,
      optLogger,
    )->ignore
  | "invoke_hidden_iframe" =>
    handleInvokeHiddenIframe(intent, clientSecret, confirmParam, headers, url, iframeId)->ignore
  | "display_voucher_information" =>
    handleDisplayVoucherInformation(intent, url, paymentMethod, optLogger, iframeId, data)->ignore
  | "third_party_sdk_session_token" =>
    handleThirdPartySdkSessionToken(
      intent,
      componentName,
      confirmParam,
      clientSecret,
      iframeId,
    )->ignore
  | "invoke_sdk_client" => resolve(handleInvokeSdkClient(intent))->ignore
  | _ => ()
  }
}
