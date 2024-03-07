open Utils
@val @scope("Object") external assign: (JSON.t, JSON.t, JSON.t) => JSON.t = "assign"
external toSome: JSON.t => 'a = "%identity"
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
}
@val @scope("Object") external assign2: (JSON.t, JSON.t) => paymentDataRequest = "assign"
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
  isReadyToPay: (. JSON.t) => Js.Promise.t<JSON.t>,
  createButton: (. JSON.t) => Dom.element,
  loadPaymentData: (. JSON.t) => Js.Promise.t<Fetch.Response.t>,
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

type paymentData = {paymentMethodData: paymentMethodData}
let defaultTokenizationData = {
  token: "",
}
let defaultPaymentMethodData = {
  description: "",
  info: Js.Dict.empty()->JSON.Encode.object,
  tokenizationData: Js.Dict.empty()->JSON.Encode.object,
  \"type": "",
}

let getTokenizationData = (str, dict) => {
  dict
  ->Js.Dict.get(str)
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
  ->Js.Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      description: getString(json, "description", ""),
      tokenizationData: getJsonFromDict(
        json,
        "tokenizationData",
        Js.Dict.empty()->JSON.Encode.object,
      ),
      info: getJsonFromDict(json, "info", Js.Dict.empty()->JSON.Encode.object),
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

let jsonToPaymentRequestDataType: (paymentDataRequest, Js.Dict.t<JSON.t>) => paymentDataRequest = (
  paymentRequest,
  jsonDict,
) => {
  paymentRequest.allowedPaymentMethods =
    jsonDict
    ->Utils.getArray("allowed_payment_methods")
    ->Array.map(json => Utils.transformKeys(json, Utils.CamelCase))
  paymentRequest.transactionInfo =
    jsonDict
    ->Utils.getJsonFromDict("transaction_info", JSON.Encode.null)
    ->Utils.transformKeys(Utils.CamelCase)
  paymentRequest.merchantInfo =
    jsonDict
    ->Utils.getJsonFromDict("merchant_info", JSON.Encode.null)
    ->Utils.transformKeys(Utils.CamelCase)

  paymentRequest
}
