open Utils
@val @scope("Object") external assign: (JSON.t, JSON.t, JSON.t) => JSON.t = "assign"
type transactionInfo = {
  countryCode: string,
  currencyCode: string,
  totalPriceStatus: string,
  totalPrice: string,
}
type merchantInfo = {merchantName: string}
type paymentDataRequest = {
  mutable allowedPaymentMethods: array<JSON.t>,
  mutable transactionInfo: JSON.t,
  mutable merchantInfo: JSON.t,
  mutable shippingAddressRequired: bool,
  mutable emailRequired: bool,
  mutable shippingAddressParameters: JSON.t,
}
@val @scope("Object") external assign2: (JSON.t, JSON.t) => paymentDataRequest = "assign"
type element = {
  mutable innerHTML: string,
  appendChild: Dom.element => unit,
  removeChild: Dom.element => unit,
  children: array<Dom.element>,
}
type document
@val external document: document = "document"
@send external getElementById: (document, string) => element = "getElementById"
type client = {
  isReadyToPay: JSON.t => Promise.t<JSON.t>,
  createButton: JSON.t => Dom.element,
  loadPaymentData: JSON.t => Promise.t<Fetch.Response.t>,
}
@new external google: JSON.t => client = "google.payments.api.PaymentsClient"
let getLabel = (var: PaymentType.googlePayStyleType) => {
  switch var {
  | Default => "plain"
  | Donate => "donate"
  | Buy => "buy"
  | Pay => "pay"
  | Book => "book"
  | Order => "order"
  | Subscribe => "subscribe"
  | Checkout => "checkout"
  }
}

type baseRequest = {
  apiVersion: int,
  apiVersionMinor: int,
}
type parameters = {
  gateway: option<string>,
  gatewayMerchantId: option<string>,
  allowedAuthMethods: option<array<string>>,
  allowedCardNetworks: option<array<string>>,
}

type tokenizationSpecification = {
  \"type": string,
  parameters: parameters,
}
type tokenizationData = {token: string}
type paymentMethodData = {
  description: string,
  info: JSON.t,
  tokenizationData: JSON.t,
  \"type": string,
}

type billingContact = {
  address1: string,
  address2: string,
  address3: string,
  administrativeArea: string,
  countryCode: string,
  locality: string,
  name: string,
  phoneNumber: string,
  postalCode: string,
  sortingCode: string,
}

type paymentData = {paymentMethodData: paymentMethodData}
let defaultTokenizationData = {
  token: "",
}
let defaultPaymentMethodData = {
  description: "",
  info: Dict.make()->JSON.Encode.object,
  tokenizationData: Dict.make()->JSON.Encode.object,
  \"type": "",
}

let getTokenizationData = (str, dict) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      token: getString(json, "token", ""),
    }
  })
  ->Option.getOr(defaultTokenizationData)
}
let getPaymentMethodData = (str, dict) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      description: getString(json, "description", ""),
      tokenizationData: getJsonFromDict(json, "tokenizationData", Dict.make()->JSON.Encode.object),
      info: getJsonFromDict(json, "info", Dict.make()->JSON.Encode.object),
      \"type": getString(json, "type", ""),
    }
  })
  ->Option.getOr(defaultPaymentMethodData)
}
let itemToObjMapper = dict => {
  {
    paymentMethodData: getPaymentMethodData("paymentMethodData", dict),
  }
}

let jsonToPaymentRequestDataType: (paymentDataRequest, Dict.t<JSON.t>) => paymentDataRequest = (
  paymentRequest,
  jsonDict,
) => {
  paymentRequest.allowedPaymentMethods =
    jsonDict
    ->getArray("allowed_payment_methods")
    ->Array.map(json => transformKeys(json, CamelCase))
  paymentRequest.transactionInfo =
    jsonDict
    ->getJsonFromDict("transaction_info", JSON.Encode.null)
    ->transformKeys(CamelCase)
  paymentRequest.merchantInfo =
    jsonDict
    ->getJsonFromDict("merchant_info", JSON.Encode.null)
    ->transformKeys(CamelCase)

  paymentRequest
}

let billingContactItemToObjMapper = dict => {
  {
    address1: dict->getString("address1", ""),
    address2: dict->getString("address2", ""),
    address3: dict->getString("address3", ""),
    administrativeArea: dict->getString("administrativeArea", ""),
    countryCode: dict->getString("countryCode", ""),
    locality: dict->getString("locality", ""),
    name: dict->getString("name", ""),
    phoneNumber: dict->getString("phoneNumber", ""),
    postalCode: dict->getString("postalCode", ""),
    sortingCode: dict->getString("sortingCode", ""),
  }
}
