open ApplePayTypes

type applePayInstance = {
  createPaymentRequest: paymentRequestData => JSON.t,
  performValidation: (applePayValidationRequest, (nullable<JSON.t>, JSON.t) => unit) => unit,
  tokenize: (paymentResult, (nullable<JSON.t>, applePayTokenizeResponse) => unit) => unit,
}

type applePayCallback = (nullable<JSON.t>, applePayInstance) => unit

type clientCreateCallback = (nullable<JSON.t>, {.}) => unit
type applePayCreateCallback = (nullable<JSON.t>, applePayInstance) => unit
type applePayConfig = {client: {.}}
type authorization = {authorization: string}

@val
external braintreeClientCreate: (authorization, clientCreateCallback) => unit =
  "braintree.client.create"

@val
external braintreeApplePayPaymentCreate: (applePayConfig, applePayCreateCallback) => unit =
  "braintree.applePay.create"

let braintreeApplePayUrl = "https://js.braintreegateway.com/web/3.92.1/js/apple-pay.min.js"
let braintreeClientUrl = "https://js.braintreegateway.com/web/3.92.1/js/client.min.js"

let loadBraintreeApplePayScripts = logger => {
  Utils.loadScriptIfNotExist(~url=braintreeClientUrl, ~logger, ~eventName=BRAINTREE_CLIENT_SCRIPT)
  Utils.loadScriptIfNotExist(
    ~url=braintreeApplePayUrl,
    ~logger,
    ~eventName=APPLE_PAY_BRAINTREE_SCRIPT,
  )
}
