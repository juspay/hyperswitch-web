type deliveryPrice = {
  amount: int,
  displayAmount: string,
  currencyCode: string,
}

type shippingMethod = {
  shippingMethodName: string,
  shippingMethodCode: string,
}

type priceAmount = {
  amount: string,
  currencyCode: string,
}

type deliveryOption = {
  id: string,
  price: priceAmount,
  shippingMethod: shippingMethod,
  isDefault: bool,
}

type amazonPayTokenType = {
  walletName: string,
  merchantId: string,
  ledgerCurrency: string,
  storeId: string,
  paymentIntent: string,
  totalTaxAmount: string,
  totalBaseAmount: string,
  deliveryOptions: array<deliveryOption>,
}

type estimatedOrderAmount = {
  amount: string,
  currencyCode: string,
}

type paymentDetails = {
  paymentIntent: string,
  canHandlePendingAuthorization: bool,
}

type checkoutSessionConfig = {
  storeId: string,
  scopes: array<string>,
  paymentDetails: paymentDetails,
}

type amountDetails = {
  amount: string,
  currencyCode: string,
}

type shippingAddressResponse = {
  totalShippingAmount: amountDetails,
  totalBaseAmount: amountDetails,
  totalTaxAmount: amountDetails,
  totalChargeAmount: amountDetails,
  totalDiscountAmount: amountDetails,
  deliveryOptions: array<deliveryOption>,
}

type deliveryOptionResponse = {
  totalShippingAmount: amountDetails,
  totalBaseAmount: amountDetails,
  totalTaxAmount: amountDetails,
  totalChargeAmount: amountDetails,
  totalDiscountAmount: amountDetails,
}

type deliveryOptionEventDetails = {id: string}

type deliveryOptionEvent = {deliveryOptions: deliveryOptionEventDetails}

type amazonPayConfigType = {
  merchantId: string,
  ledgerCurrency: string,
  sandbox: bool,
  checkoutLanguage: string,
  productType: string,
  placement: string,
  buttonColor: string,
  estimatedOrderAmount: estimatedOrderAmount,
  checkoutSessionConfig: checkoutSessionConfig,
  onInitCheckout: JSON.t => shippingAddressResponse,
  onShippingAddressSelection: JSON.t => shippingAddressResponse,
  onDeliveryOptionSelection: deliveryOptionEvent => deliveryOptionResponse,
  onCompleteCheckout: JSON.t => unit,
  onCancel: JSON.t => unit,
}

type amazonPayData = {checkout_session_id: string}

type wallet = {amazon_pay: amazonPayData}

type shippingAddress = {
  line1: string,
  line2: string,
  line3: string,
  city: string,
  state: string,
  zip: string,
  country: string,
  first_name: string,
  last_name: string,
}

type shippingPhone = {number: string}

type shipping = {
  address: shippingAddress,
  phone: shippingPhone,
}
