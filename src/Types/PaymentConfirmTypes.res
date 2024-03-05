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
  type_: string,
  bank_transfer_steps_and_charges_details: option<Js.Json.t>,
  session_token: option<Js.Json.t>,
  image_data_url: option<string>,
  voucher_details: option<voucherDetails>,
  display_to_timestamp: option<float>,
}
type intent = {
  nextAction: nextAction,
  status: string,
  paymentId: string,
  clientSecret: string,
  error_message: string,
  payment_method_type: string,
  manualRetryAllowed: bool,
}
open Utils

let defaultRedirectTourl = {
  returnUrl: "",
  url: "",
}
let defaultNextAction = {
  redirectToUrl: "",
  type_: "",
  bank_transfer_steps_and_charges_details: None,
  session_token: None,
  image_data_url: None,
  voucher_details: None,
  display_to_timestamp: None,
}
let defaultIntent = {
  nextAction: defaultNextAction,
  status: "",
  clientSecret: "",
  paymentId: "",
  error_message: "",
  payment_method_type: "",
  manualRetryAllowed: false,
}

let getAchCreditTransfer = (dict, str) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      account_number: getString(json, "account_number", ""),
      bank_name: getString(json, "bank_name", ""),
      routing_number: getString(json, "routing_number", ""),
      swift_code: getString(json, "swift_code", ""),
    }
  })
  ->Belt.Option.getWithDefault(defaultACHCreditTransfer)
}
let getBacsBankInstructions = (dict, str) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      account_holder_name: getString(json, "account_holder_name", ""),
      account_number: getString(json, "account_number", ""),
      sort_code: getString(json, "sort_code", ""),
    }
  })
  ->Belt.Option.getWithDefault(defaultBacsBankInstruction)
}
let getBankTransferDetails = (dict, str) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
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
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      redirectToUrl: getString(json, "redirect_to_url", ""),
      type_: getString(json, "type", ""),
      bank_transfer_steps_and_charges_details: Some(
        getJsonObjFromDict(
          json,
          "bank_transfer_steps_and_charges_details",
          Js.Dict.empty(),
        )->Js.Json.object_,
      ),
      session_token: Some(
        getJsonObjFromDict(json, "session_token", Js.Dict.empty())->Js.Json.object_,
      ),
      image_data_url: Some(json->getString("image_data_url", "")),
      display_to_timestamp: Some(
        json
        ->Js.Dict.get("display_to_timestamp")
        ->Belt.Option.flatMap(Js.Json.decodeNumber)
        ->Belt.Option.getWithDefault(0.0),
      ),
      voucher_details: {
        json
        ->Js.Dict.get("voucher_details")
        ->Belt.Option.flatMap(Js.Json.decodeObject)
        ->Belt.Option.map(json => json->getVoucherDetails)
      },
    }
  })
  ->Belt.Option.getWithDefault(defaultNextAction)
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
  }
}
