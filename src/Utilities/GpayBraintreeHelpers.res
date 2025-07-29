open GpayBraintreeTypes

@val
external braintreeClientCreate: (authorization, clientCreateCallback) => unit =
  "braintree.client.create"

@val
external braintreeGPayPaymentCreate: (JSON.t, paymentCreateCallback) => unit =
  "braintree.googlePayment.create"
@val
external braintreeApplePayPaymentCreate: (JSON.t, applePayCreateCallback) => unit =
  "braintree.applePay.create"

@val
external braintreeApplePaySession: nullable<unit> = "window.ApplePaySession"

@new
external newGPayPaymentClient: environment => paymentClient = "google.payments.api.PaymentsClient"
@new
external newApplePaySession: (int, JSON.t) => applePaySessions = "window.ApplePaySession"
@val
external applePaySession: applePaySessions = "window.ApplePaySession"

@send
external appendChildElement: (Dom.element, Dom.element) => unit = "appendChild"

let googleMerchantId = "01234567890123456789"
let googlePayVersion = 2
let environment = GlobalVars.isProd ? "PRODUCTION" : "TEST"
let buttonSizeMode = "fill"
let buttonType = "checkout"

let braintreeClientUrl = "https://js.braintreegateway.com/web/3.124.0/js/client.min.js"
let braintreeGPayUrl = "https://js.braintreegateway.com/web/3.124.0/js/google-payment.min.js"
let braintreeApplePayUrl = "https://js.braintreegateway.com/web/3.124.0/js/apple-pay.min.js"
let googlePayUrl = "https://pay.google.com/gp/p/js/pay.js"

let createGpayTransactionInfo = (sessionToken: SessionsType.token) => {
  let transactionDict = sessionToken.transaction_info->Utils.getDictFromJson
  {
    "transactionInfo": {
      "currencyCode": transactionDict->Utils.getString("currency_code", ""),
      "totalPriceStatus": transactionDict
      ->Utils.getString("total_price_status", "")
      ->String.toUpperCase,
      "totalPrice": transactionDict->Utils.getString("total_price", ""),
    },
  }->Identity.anyTypeToJson
}

let createApplePayTransactionInfo = (sessionToken: JSON.t) => {
  let sessionTokenDict = sessionToken->Utils.getDictFromJson
  let paymentRequestDataDict = sessionTokenDict->Utils.getDictFromDict("payment_request_data")
  let transactionDict = paymentRequestDataDict->Utils.getDictFromDict("total")

  {
    "total": {
      "label": transactionDict->Utils.getString("label", ""),
      "amount": transactionDict->Utils.getString("amount", ""),
    },
    "requiredBillingContactFields": ["postalAddress"],
  }->Identity.anyTypeToJson
}

let createGooglePayConfig = clientInstance => {
  {
    "client": clientInstance,
    "googlePayVersion": googlePayVersion,
    "googleMerchantId": googleMerchantId,
  }->Identity.anyTypeToJson
}
let createApplePayConfig = clientInstance => {
  {
    "client": clientInstance,
  }->Identity.anyTypeToJson
}

let createPayObj = (payloadDict): GooglePayType.paymentData => {
  let description = payloadDict->Utils.getString("description", "")
  let detailsDict = payloadDict->Utils.getDictFromDict("details")
  let cardNetwork = detailsDict->Utils.getString("cardType", "")
  let lastFour = detailsDict->Utils.getString("lastFour", "")
  let nonce = payloadDict->Utils.getString("nonce", "")

  {
    paymentMethodData: {
      description,
      info: {
        "card_network": cardNetwork->String.toUpperCase,
        "card_details": lastFour,
      }->Identity.anyTypeToJson,
      tokenizationData: {
        "type": "PAYMENT_GATEWAY",
        "token": nonce,
      }->Identity.anyTypeToJson,
      \"type": "CARD",
    },
  }
}
