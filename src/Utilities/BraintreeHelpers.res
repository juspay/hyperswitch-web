open BraintreeTypes

let braintreeToken = "eyJ2ZXJzaW9uIjoyLCJhdXRob3JpemF0aW9uRmluZ2VycHJpbnQiOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpGVXpJMU5pSXNJbXRwWkNJNklqSXdNVGd3TkRJMk1UWXRjMkZ1WkdKdmVDSXNJbWx6Y3lJNkltaDBkSEJ6T2k4dllYQnBMbk5oYm1SaWIzZ3VZbkpoYVc1MGNtVmxaMkYwWlhkaGVTNWpiMjBpZlEuZXlKbGVIQWlPakUzTlRRd05EUTVOVGdzSW1wMGFTSTZJbUpqWlRRd1ltTTFMVE01T1RZdE5EYzBZaTFoTWpZMUxUTm1NemRqTW1VNFkySTNOQ0lzSW5OMVlpSTZJbWR6Wm5BMmJubG5lVE5rZW1JNGMyc2lMQ0pwYzNNaU9pSm9kSFJ3Y3pvdkwyRndhUzV6WVc1a1ltOTRMbUp5WVdsdWRISmxaV2RoZEdWM1lYa3VZMjl0SWl3aWJXVnlZMmhoYm5RaU9uc2ljSFZpYkdsalgybGtJam9pWjNObWNEWnVlV2Q1TTJSNllqaHpheUlzSW5abGNtbG1lVjlqWVhKa1gySjVYMlJsWm1GMWJIUWlPbVpoYkhObExDSjJaWEpwWm5sZmQyRnNiR1YwWDJKNVgyUmxabUYxYkhRaU9tWmhiSE5sZlN3aWNtbG5hSFJ6SWpwYkltMWhibUZuWlY5MllYVnNkQ0pkTENKelkyOXdaU0k2V3lKQ2NtRnBiblJ5WldVNlZtRjFiSFFpTENKQ2NtRnBiblJ5WldVNlFWaFBJbDBzSW05d2RHbHZibk1pT250OWZRLkY4aERMbm1zVEd2dWUybmdfZ1l0Nl9Ja2N0bWdYUl9NbnIwR290N3NKUWlybzdOWlYyVHl4YUJZZ0NrZk1YQXZtRHRYekN6NEtEckVRZU1WNDZrRHN3IiwiY29uZmlnVXJsIjoiaHR0cHM6Ly9hcGkuc2FuZGJveC5icmFpbnRyZWVnYXRld2F5LmNvbTo0NDMvbWVyY2hhbnRzL2dzZnA2bnlneTNkemI4c2svY2xpZW50X2FwaS92MS9jb25maWd1cmF0aW9uIiwiZ3JhcGhRTCI6eyJ1cmwiOiJodHRwczovL3BheW1lbnRzLnNhbmRib3guYnJhaW50cmVlLWFwaS5jb20vZ3JhcGhxbCIsImRhdGUiOiIyMDE4LTA1LTA4IiwiZmVhdHVyZXMiOlsidG9rZW5pemVfY3JlZGl0X2NhcmRzIl19LCJjbGllbnRBcGlVcmwiOiJodHRwczovL2FwaS5zYW5kYm94LmJyYWludHJlZWdhdGV3YXkuY29tOjQ0My9tZXJjaGFudHMvZ3NmcDZueWd5M2R6Yjhzay9jbGllbnRfYXBpIiwiZW52aXJvbm1lbnQiOiJzYW5kYm94IiwibWVyY2hhbnRJZCI6ImdzZnA2bnlneTNkemI4c2siLCJhc3NldHNVcmwiOiJodHRwczovL2Fzc2V0cy5icmFpbnRyZWVnYXRld2F5LmNvbSIsImF1dGhVcmwiOiJodHRwczovL2F1dGgudmVubW8uc2FuZGJveC5icmFpbnRyZWVnYXRld2F5LmNvbSIsInZlbm1vIjoib2ZmIiwiY2hhbGxlbmdlcyI6W10sInRocmVlRFNlY3VyZUVuYWJsZWQiOnRydWUsImFuYWx5dGljcyI6eyJ1cmwiOiJodHRwczovL29yaWdpbi1hbmFseXRpY3Mtc2FuZC5zYW5kYm94LmJyYWludHJlZS1hcGkuY29tL2dzZnA2bnlneTNkemI4c2sifSwiYXBwbGVQYXkiOnsiY291bnRyeUNvZGUiOiJVUyIsImN1cnJlbmN5Q29kZSI6IlVTRCIsIm1lcmNoYW50SWRlbnRpZmllciI6Im1lcmNoYW50LmNvbS5hZHllbi5zYW4iLCJzdGF0dXMiOiJtb2NrIiwic3VwcG9ydGVkTmV0d29ya3MiOlsidmlzYSIsIm1hc3RlcmNhcmQiLCJhbWV4IiwiZGlzY292ZXIiXX0sInBheXBhbEVuYWJsZWQiOnRydWUsInBheXBhbCI6eyJiaWxsaW5nQWdyZWVtZW50c0VuYWJsZWQiOnRydWUsImVudmlyb25tZW50Tm9OZXR3b3JrIjpmYWxzZSwidW52ZXR0ZWRNZXJjaGFudCI6ZmFsc2UsImFsbG93SHR0cCI6dHJ1ZSwiZGlzcGxheU5hbWUiOiJKdXNwYXkiLCJjbGllbnRJZCI6IkFTS0FHaDJXWGdxZlE1VHpqcFp6THNmaFZHbEZianE1VnJWNUlPWDhLWEREMk5fWHFrR2VZTkRrV3lyX1VYbmZoWHBFa0FCZG1QMjg0Yl8yIiwiYmFzZVVybCI6Imh0dHBzOi8vYXNzZXRzLmJyYWludHJlZWdhdGV3YXkuY29tIiwiYXNzZXRzVXJsIjoiaHR0cHM6Ly9jaGVja291dC5wYXlwYWwuY29tIiwiZGlyZWN0QmFzZVVybCI6bnVsbCwiZW52aXJvbm1lbnQiOiJvZmZsaW5lIiwiYnJhaW50cmVlQ2xpZW50SWQiOiJtYXN0ZXJjbGllbnQzIiwibWVyY2hhbnRBY2NvdW50SWQiOiJqdXNwYXkiLCJjdXJyZW5jeUlzb0NvZGUiOiJVU0QifX0"

@val
external braintreeClientCreate: (authorization, clientCreateCallback) => unit =
  "braintree.client.create"

@val
external braintreeGPayPaymentCreate: (gPayConfig, gPayCreateCallback) => unit =
  "braintree.googlePayment.create"

@val
external braintreeApplePayPaymentCreate: (applePayConfig, applePayCreateCallback) => unit =
  "braintree.applePay.create"

@val
external braintreePayPalCheckoutCreate: (paypalCheckoutConfig, paypalCreateCallback) => unit =
  "braintree.paypalCheckout.create"

@val external paypalSDK: paypalSDK = "paypal"

@val
external braintreeApplePaySession: nullable<unit> = "window.ApplePaySession"

@new
external newGPayPaymentClient: environment => paymentClient = "google.payments.api.PaymentsClient"

@new
external newApplePaySession: (int, applePayTransactionData) => applePaySessions =
  "window.ApplePaySession"

@val
external applePaySession: applePaySessions = "window.ApplePaySession"

@send
external appendChildElement: (Dom.element, Dom.element) => unit = "appendChild"

let environment = GlobalVars.isProd ? "PRODUCTION" : "TEST"
let googleMerchantId = "01234567890123456789"
let buttonSizeMode = "fill"
let buttonType = "checkout"
let googlePayVersion = 2

let braintreePayPalUrl = "https://js.braintreegateway.com/web/3.124.0/js/paypal-checkout.min.js"
let braintreeGPayUrl = "https://js.braintreegateway.com/web/3.124.0/js/google-payment.min.js"
let braintreeApplePayUrl = "https://js.braintreegateway.com/web/3.124.0/js/apple-pay.min.js"
let braintreeClientUrl = "https://js.braintreegateway.com/web/3.124.0/js/client.min.js"
let googlePayUrl = "https://pay.google.com/gp/p/js/pay.js"

let generatePayPalSDKUrl = (clientId: string): string =>
  `https://www.paypal.com/sdk/js?client-id=${clientId}&currency=USD&intent=authorize`

let createGpayTransactionInfo = (sessionToken: SessionsType.token): gPayTransactionData => {
  let transactionDict = sessionToken.transaction_info->Utils.getDictFromJson
  {
    transactionInfo: {
      currencyCode: transactionDict->Utils.getString("currency_code", ""),
      totalPriceStatus: transactionDict
      ->Utils.getString("total_price_status", "")
      ->String.toUpperCase,
      totalPrice: transactionDict->Utils.getString("total_price", ""),
    },
  }
}

let createApplePayTransactionInfo = (sessionToken: JSON.t): applePayTransactionData => {
  let sessionTokenDict = sessionToken->Utils.getDictFromJson
  let paymentRequestDataDict = sessionTokenDict->Utils.getDictFromDict("payment_request_data")
  let transactionDict = paymentRequestDataDict->Utils.getDictFromDict("total")

  {
    total: {
      label: transactionDict->Utils.getString("label", ""),
      amount: transactionDict->Utils.getString("amount", ""),
    },
    requiredBillingContactFields: ["postalAddress"],
  }
}

let createGooglePayConfig = (clientInstance: clientInstance): gPayConfig => {
  {
    client: clientInstance,
    googlePayVersion,
    googleMerchantId,
  }
}

let createApplePayConfig = (clientInstance: clientInstance): applePayConfig => {
  {
    client: clientInstance,
  }
}

let createPayPalCheckoutConfig = (clientInstance: clientInstance): paypalCheckoutConfig => {
  {
    client: clientInstance,
  }
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
