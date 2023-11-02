open Utils
@val @scope("Object") external assign: (Js.Json.t, Js.Json.t, Js.Json.t) => Js.Json.t = "assign"
external toSome: Js.Json.t => 'a = "%identity"
type transactionInfo = {
  countryCode: string,
  currencyCode: string,
  totalPriceStatus: string,
  totalPrice: string,
}
type merchantInfo = {merchantName: string}
type paymentDataRequest = {
  mutable allowedPaymentMethods: array<Js.Json.t>,
  mutable transactionInfo: Js.Json.t,
  mutable merchantInfo: Js.Json.t,
}
@val @scope("Object") external assign2: (Js.Json.t, Js.Json.t) => paymentDataRequest = "assign"
type element = {
  mutable innerHTML: string,
  appendChild: (. Dom.element) => unit,
  removeChild: (. Dom.element) => unit,
  children: array<Dom.element>,
}
type document
@val external document: document = "document"
@send external getElementById: (document, string) => element = "getElementById"
type client = {
  isReadyToPay: (. Js.Json.t) => Js.Promise.t<Js.Json.t>,
  createButton: (. Js.Json.t) => Dom.element,
  loadPaymentData: (. Js.Json.t) => Js.Promise.t<Fetch.Response.t>,
}
@new external google: Js.Json.t => client = "google.payments.api.PaymentsClient"
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
  info: Js.Json.t,
  tokenizationData: Js.Json.t,
  \"type": string,
}

type paymentData = {paymentMethodData: paymentMethodData}
let defaultTokenizationData = {
  token: "",
}
let defaultPaymentMethodData = {
  description: "",
  info: Js.Dict.empty()->Js.Json.object_,
  tokenizationData: Js.Dict.empty()->Js.Json.object_,
  \"type": "",
}

let getTokenizationData = (str, dict) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      token: getString(json, "token", ""),
    }
  })
  ->Belt.Option.getWithDefault(defaultTokenizationData)
}
let getPaymentMethodData = (str, dict) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      description: getString(json, "description", ""),
      tokenizationData: getJsonFromDict(json, "tokenizationData", Js.Dict.empty()->Js.Json.object_),
      info: getJsonFromDict(json, "info", Js.Dict.empty()->Js.Json.object_),
      \"type": getString(json, "type", ""),
    }
  })
  ->Belt.Option.getWithDefault(defaultPaymentMethodData)
}
let itemToObjMapper = dict => {
  {
    paymentMethodData: getPaymentMethodData("paymentMethodData", dict),
  }
}

let jsonToPaymentRequestDataType: (
  paymentDataRequest,
  Js.Dict.t<Js.Json.t>,
) => paymentDataRequest = (paymentRequest, jsonDict) => {
  paymentRequest.allowedPaymentMethods =
    jsonDict
    ->Utils.getArray("allowed_payment_methods")
    ->Js.Array2.map(json => Utils.transformKeys(json, Utils.CamelCase))
  paymentRequest.transactionInfo =
    jsonDict
    ->Utils.getJsonFromDict("transaction_info", Js.Json.null)
    ->Utils.transformKeys(Utils.CamelCase)
  paymentRequest.merchantInfo =
    jsonDict
    ->Utils.getJsonFromDict("merchant_info", Js.Json.null)
    ->Utils.transformKeys(Utils.CamelCase)

  paymentRequest
}
