open BraintreeTypes

@val
external braintreeClientCreate: (authorization, clientCreateCallback) => unit =
  "braintree.client.create"

@val
external braintreePayPalCheckoutCreate: (paypalCheckoutConfig, paypalCreateCallback) => unit =
  "braintree.paypalCheckout.create"

@val external paypalSDK: paypalSDK = "paypal"

let braintreePayPalUrl = "https://js.braintreegateway.com/web/3.124.0/js/paypal-checkout.min.js"
let braintreeClientUrl = "https://js.braintreegateway.com/web/3.124.0/js/client.min.js"

let generatePayPalSDKUrl = clientId =>
  `https://www.paypal.com/sdk/js?client-id=${clientId}&currency=USD&intent=authorize`

let paypalButtonStyle = {
  layout: "vertical",
  color: "blue",
  shape: "rect",
  label: "paypal",
  height: 50,
}
