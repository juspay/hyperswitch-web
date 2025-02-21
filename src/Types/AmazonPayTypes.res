type amount = {
  amount: string,
  currencyCode: string,
}

type shippingMethod = {
  shippingMethodName: string,
  shippingMethodCode: string,
}

type deliveryOption = {
  id: string,
  price: amount,
  shippingMethod: shippingMethod,
  isDefault: bool,
}

type paymentDetails = {
  paymentIntent: string,
}

type checkoutSessionConfig = {
  storeId: string,
  paymentDetails: paymentDetails,
}

type config = {
  merchantId: string,
  ledgerCurrency: string,
  sandbox: bool,
  checkoutLanguage: string,
  productType: string,
  placement: string,
  buttonColor: string,
  checkoutSessionConfig: checkoutSessionConfig,
  onInitCheckout: Js.Json.t => Js.Json.t,
  onShippingAddressSelection: Js.Json.t => Js.Json.t,
  onCompleteCheckout: Js.Json.t => unit,
  onDeliveryOptionSelection: Js.Json.t => Js.Json.t,
  onCancel: unit => unit,
}

type sessionTokenResponseData = {
  merchantId: string,
  ledgerCurrency: string,
  storeId: string,
  paymentIntent: string,
  totalShippingAmount: string,
  totalTaxAmount: string,
  totalBaseAmount: string,
  deliveryOptions: Js.Json.t,
}

type sessionResponse = {
  payment_id: string,
  client_secret: string,
  session_token: array<config>,
}

type callbackData = {
  shippingAddress: option<string>,
  amazonCheckoutSessionId: option<string>,
  deliveryOptions: option<deliveryOption>,
}

type buyerShippingAddress = Js.Json.t