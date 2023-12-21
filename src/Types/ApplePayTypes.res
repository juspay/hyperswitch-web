type token = {paymentData: Js.Json.t}
type paymentResult = {token: Js.Json.t}
type event = {validationURL: string, payment: paymentResult}
type innerSession
type session = {
  begin: (. unit) => unit,
  abort: (. unit) => unit,
  mutable oncancel: unit => unit,
  canMakePayments: (. unit) => bool,
  mutable onvalidatemerchant: event => unit,
  completeMerchantValidation: (. Js.Json.t) => unit,
  mutable onpaymentauthorized: event => unit,
  completePayment: (. Js.Json.t) => unit,
  \"STATUS_SUCCESS": string,
  \"STATUS_FAILURE": string,
}
type applePaySession
type window = {\"ApplePaySession": applePaySession}

@val external window: window = "window"

@scope("window") @val external sessionForApplePay: Js.Nullable.t<session> = "ApplePaySession"

@new external applePaySession: (int, Js.Json.t) => session = "ApplePaySession"

@deriving(abstract)
type total = {
  label: string,
  @optional \"type": string,
  amount: string,
}
type sdkNextAction = {nextAction: string}

@deriving(abstract)
type paymentRequestData = {
  countryCode: string,
  currencyCode: string,
  total: total,
  merchantCapabilities: array<string>,
  supportedNetworks: array<string>,
  @optional merchantIdentifier: string,
}

let jsonToPaymentRequestDataType: Js.Dict.t<Js.Json.t> => paymentRequestData = jsonDict => {
  let clientTimeZone = CardUtils.dateTimeFormat(.).resolvedOptions(.).timeZone
  let clientCountry = Utils.getClientCountry(clientTimeZone)
  let defaultCountryCode = clientCountry.isoAlpha2

  let getTotal = totalDict => {
    Utils.getString(totalDict, "type", "") == ""
      ? total(
          ~label=Utils.getString(totalDict, "label", ""),
          ~amount=Utils.getString(totalDict, "amount", ""),
          (),
        )
      : total(
          ~label=Utils.getString(totalDict, "label", ""),
          ~amount=Utils.getString(totalDict, "amount", ""),
          ~\"type"=Utils.getString(totalDict, "type", ""),
          (),
        )
  }

  if Utils.getString(jsonDict, "merchant_identifier", "") == "" {
    paymentRequestData(
      ~countryCode=Utils.getString(jsonDict, "country_code", defaultCountryCode),
      ~currencyCode=Utils.getString(jsonDict, "currency_code", ""),
      ~merchantCapabilities=Utils.getStrArray(jsonDict, "merchant_capabilities"),
      ~supportedNetworks=Utils.getStrArray(jsonDict, "supported_networks"),
      ~total=getTotal(jsonDict->Utils.getDictFromObj("total")),
      (),
    )
  } else {
    paymentRequestData(
      ~countryCode=Utils.getString(jsonDict, "country_code", ""),
      ~currencyCode=Utils.getString(jsonDict, "currency_code", ""),
      ~merchantCapabilities=Utils.getStrArray(jsonDict, "merchant_capabilities"),
      ~supportedNetworks=Utils.getStrArray(jsonDict, "supported_networks"),
      ~total=getTotal(jsonDict->Utils.getDictFromObj("total")),
      ~merchantIdentifier=Utils.getString(jsonDict, "merchant_identifier", ""),
      (),
    )
  }
}
