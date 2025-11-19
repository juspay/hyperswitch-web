open Utils

type token = {paymentData: JSON.t}
type billingContact = {
  addressLines: array<string>,
  administrativeArea: string,
  countryCode: string,
  familyName: string,
  givenName: string,
  locality: string,
  postalCode: string,
}

type shippingContact = {
  emailAddress: string,
  phoneNumber: string,
  addressLines: array<string>,
  administrativeArea: string,
  countryCode: string,
  familyName: string,
  givenName: string,
  locality: string,
  postalCode: string,
}

type paymentResult = {token: JSON.t, billingContact: JSON.t, shippingContact: JSON.t}
type event = {validationURL: string, payment: paymentResult}
type lineItem = {
  label: string,
  amount: string,
  \"type": string,
}

type applePayValidationRequest = {
  validationURL: string,
  displayName: string,
}

type applePayTokenizeResponse = {nonce: string}

type shippingAddressChangeEvent = {shippingContact: JSON.t}
type orderDetails = {newTotal: lineItem, newLineItems: array<lineItem>}
type innerSession
type session = {
  begin: unit => unit,
  abort: unit => unit,
  mutable oncancel: unit => unit,
  canMakePayments: unit => bool,
  mutable onvalidatemerchant: event => unit,
  completeMerchantValidation: JSON.t => unit,
  mutable onpaymentauthorized: event => unit,
  mutable onshippingcontactselected: shippingAddressChangeEvent => promise<unit>,
  completeShippingContactSelection: orderDetails => unit,
  completePayment: JSON.t => unit,
  \"STATUS_SUCCESS": string,
  \"STATUS_FAILURE": string,
}
type applePaySession
type window = {\"ApplePaySession": applePaySession}

@val external window: window = "window"

@scope("window") @val external sessionForApplePay: Nullable.t<session> = "ApplePaySession"

@new external applePaySession: (int, JSON.t) => session = "ApplePaySession"

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

type headlessApplePayToken = {
  paymentRequestData: JSON.t,
  sessionTokenData: option<JSON.t>,
}

let defaultHeadlessApplePayToken: headlessApplePayToken = {
  paymentRequestData: JSON.Encode.null,
  sessionTokenData: None,
}

let getTotal = totalDict => {
  getString(totalDict, "type", "") == ""
    ? total(
        ~label=getString(totalDict, "label", ""),
        ~amount=getString(totalDict, "amount", ""),
        (),
      )
    : total(
        ~label=getString(totalDict, "label", ""),
        ~amount=getString(totalDict, "amount", ""),
        ~\"type"=getString(totalDict, "type", ""),
        (),
      )
}

let jsonToPaymentRequestDataType = jsonDict => {
  if getString(jsonDict, "merchant_identifier", "") == "" {
    paymentRequestData(
      ~countryCode=getString(jsonDict, "country_code", defaultCountryCode),
      ~currencyCode=getString(jsonDict, "currency_code", ""),
      ~merchantCapabilities=getStrArray(jsonDict, "merchant_capabilities"),
      ~supportedNetworks=getStrArray(jsonDict, "supported_networks"),
      ~total=getTotal(jsonDict->getDictFromObj("total")),
      (),
    )
  } else {
    paymentRequestData(
      ~countryCode=getString(jsonDict, "country_code", ""),
      ~currencyCode=getString(jsonDict, "currency_code", ""),
      ~merchantCapabilities=getStrArray(jsonDict, "merchant_capabilities"),
      ~supportedNetworks=getStrArray(jsonDict, "supported_networks"),
      ~total=getTotal(jsonDict->getDictFromObj("total")),
      ~merchantIdentifier=getString(jsonDict, "merchant_identifier", ""),
      (),
    )
  }
}

let billingContactItemToObjMapper = dict => {
  {
    addressLines: dict->getStrArray("addressLines"),
    administrativeArea: dict->getString("administrativeArea", ""),
    countryCode: dict->getString("countryCode", ""),
    familyName: dict->getString("familyName", ""),
    givenName: dict->getString("givenName", ""),
    locality: dict->getString("locality", ""),
    postalCode: dict->getString("postalCode", ""),
  }
}

let shippingContactItemToObjMapper = dict => {
  {
    emailAddress: dict->getString("emailAddress", ""),
    phoneNumber: dict->getString("phoneNumber", ""),
    addressLines: dict->getStrArray("addressLines"),
    administrativeArea: dict->getString("administrativeArea", ""),
    countryCode: dict->getString("countryCode", ""),
    familyName: dict->getString("familyName", ""),
    givenName: dict->getString("givenName", ""),
    locality: dict->getString("locality", ""),
    postalCode: dict->getString("postalCode", ""),
  }
}

let getPaymentRequestFromSession = (~sessionObj, ~componentName) => {
  let paymentRequest =
    sessionObj
    ->Option.flatMap(JSON.Decode.object)
    ->Option.getOr(Dict.make())
    ->Dict.get("payment_request_data")
    ->Option.getOr(Dict.make()->JSON.Encode.object)
    ->transformKeys(CamelCase)

  let requiredShippingContactFields =
    paymentRequest
    ->getDictFromJson
    ->getStrArray("requiredShippingContactFields")

  if (
    componentName->getIsExpressCheckoutComponent->not &&
      requiredShippingContactFields->Array.length !== 0
  ) {
    let shippingFieldsWithoutPostalAddress =
      requiredShippingContactFields->Array.filter(item => item !== "postalAddress")

    paymentRequest
    ->getDictFromJson
    ->Dict.set(
      "requiredShippingContactFields",
      shippingFieldsWithoutPostalAddress
      ->getArrofJsonString
      ->JSON.Encode.array,
    )
  }

  paymentRequest
}
