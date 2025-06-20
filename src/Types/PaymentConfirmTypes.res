type achCreditTransfer = {
  account_number: string,
  bank_name: string,
  routing_number: string,
  swift_code: string,
}
let defaultACHCreditTransfer = {
  account_number: "",
  bank_name: "",
  routing_number: "",
  swift_code: "",
}

type bacsBankInstruction = {
  sort_code: string,
  account_number: string,
  account_holder_name: string,
}
let defaultBacsBankInstruction = {
  sort_code: "",
  account_number: "",
  account_holder_name: "",
}

type bankTransfer = {ach_credit_transfer: achCreditTransfer}
type redirectToUrl = {
  returnUrl: string,
  url: string,
}

type voucherDetails = {
  download_url: string,
  reference: string,
}

type nextAction = {
  redirectToUrl: string,
  popupUrl: string,
  redirectResponseUrl: string,
  type_: string,
  bank_transfer_steps_and_charges_details: option<JSON.t>,
  session_token: option<JSON.t>,
  image_data_url: option<string>,
  three_ds_data: option<JSON.t>,
  voucher_details: option<voucherDetails>,
  display_to_timestamp: option<float>,
  next_action_data: option<JSON.t>,
  display_text: option<string>,
  border_color: option<string>,
  iframe_data: option<JSON.t>,
}
type intent = {
  nextAction: nextAction,
  status: string,
  paymentId: string,
  clientSecret: string,
  error_message: string,
  payment_method_type: string,
  manualRetryAllowed: bool,
  connectorTransactionId: string,
}
open Utils

let defaultRedirectTourl = {
  returnUrl: "",
  url: "",
}
let defaultNextAction = {
  redirectToUrl: "",
  popupUrl: "",
  redirectResponseUrl: "",
  type_: "",
  bank_transfer_steps_and_charges_details: None,
  session_token: None,
  image_data_url: None,
  three_ds_data: None,
  voucher_details: None,
  display_to_timestamp: None,
  next_action_data: None,
  display_text: None,
  border_color: None,
  iframe_data: None,
}
let defaultIntent = {
  nextAction: defaultNextAction,
  status: "",
  clientSecret: "",
  paymentId: "",
  error_message: "",
  payment_method_type: "",
  manualRetryAllowed: false,
  connectorTransactionId: "",
}

let getAchCreditTransfer = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      account_number: getString(json, "account_number", ""),
      bank_name: getString(json, "bank_name", ""),
      routing_number: getString(json, "routing_number", ""),
      swift_code: getString(json, "swift_code", ""),
    }
  })
  ->Option.getOr(defaultACHCreditTransfer)
}
let getBacsBankInstructions = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      account_holder_name: getString(json, "account_holder_name", ""),
      account_number: getString(json, "account_number", ""),
      sort_code: getString(json, "sort_code", ""),
    }
  })
  ->Option.getOr(defaultBacsBankInstruction)
}
let getBankTransferDetails = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      ach_credit_transfer: getAchCreditTransfer(json, "ach_credit_transfer"),
    }
  })
}

let getVoucherDetails = json => {
  {
    download_url: getString(json, "download_url", ""),
    reference: getString(json, "reference", ""),
  }
}

let getNextAction = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      redirectToUrl: getString(json, "redirect_to_url", ""),
      popupUrl: getString(json, "popup_url", ""),
      redirectResponseUrl: getString(json, "redirect_response_url", ""),
      type_: getString(json, "type", ""),
      bank_transfer_steps_and_charges_details: Some(
        getJsonObjFromDict(
          json,
          "bank_transfer_steps_and_charges_details",
          Dict.make(),
        )->JSON.Encode.object,
      ),
      session_token: Some(
        getJsonObjFromDict(json, "session_token", Dict.make())->JSON.Encode.object,
      ),
      image_data_url: Some(json->getString("image_data_url", "")),
      three_ds_data: Some(
        json
        ->Dict.get("three_ds_data")
        ->Option.getOr(Dict.make()->JSON.Encode.object),
      ),
      display_to_timestamp: Some(
        json
        ->Dict.get("display_to_timestamp")
        ->Option.flatMap(JSON.Decode.float)
        ->Option.getOr(0.0),
      ),
      voucher_details: {
        json
        ->Dict.get("voucher_details")
        ->Option.flatMap(JSON.Decode.object)
        ->Option.map(json => json->getVoucherDetails)
      },
      next_action_data: Some(json->getDictFromDict("next_action_data")->JSON.Encode.object),
      display_text: json->getOptionString("display_text"),
      border_color: json->getOptionString("border_color"),
      iframe_data: Some(json->Utils.getJsonObjectFromDict("iframe_data")),
    }
  })
  ->Option.getOr(defaultNextAction)
}
let itemToObjMapper = dict => {
  {
    nextAction: getNextAction(dict, "next_action"),
    status: getString(dict, "status", ""),
    clientSecret: getString(dict, "client_secret", ""),
    paymentId: getString(dict, "payment_id", ""),
    error_message: getString(dict, "error_message", ""),
    payment_method_type: getString(dict, "payment_method_type", ""),
    manualRetryAllowed: getBool(dict, "manual_retry_allowed", false),
    connectorTransactionId: getString(dict, "connector_transaction_id", ""),
  }
}
