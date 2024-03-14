type clientErr = bool
type clientInstance
type paypalCheckoutErr = {message: string}
type data
type actions
type err
type payload = {nonce: string}
type vault = {vault: bool}
type shipping = {
  recipientName: option<string>,
  line1: option<string>,
  line2: option<string>,
  city: option<string>,
  countryCode: option<string>,
  postalCode: option<string>,
  state: option<string>,
  phone: option<string>,
}
type orderDetails = {
  flow: string,
  billingAgreementDescription: option<string>,
  enableShippingAddress: option<bool>,
  shippingAddressEditable: option<bool>,
  shippingAddressOverride: option<shipping>,
}
let defaultShipping = {
  recipientName: None,
  line1: None,
  line2: None,
  city: None,
  countryCode: None,
  postalCode: None,
  state: None,
  phone: None,
}

let defaultOrderDetails = {
  flow: "vault",
  billingAgreementDescription: None,
  enableShippingAddress: None,
  shippingAddressEditable: None,
  shippingAddressOverride: None,
}

type paypalCheckoutInstance = {
  loadPayPalSDK: (vault, unit => unit) => unit,
  createPayment: orderDetails => unit,
  tokenizePayment: (data, (err, payload) => unit) => unit,
}
type authType = {authorization: string}
type checkoutClient = {client: clientInstance}
type client = {create: (authType, (clientErr, clientInstance) => unit) => unit}
type paypalCheckout = {
  create: (checkoutClient, (Nullable.t<paypalCheckoutErr>, paypalCheckoutInstance) => unit) => unit,
}
type braintree = {
  client: client,
  paypalCheckout: paypalCheckout,
}
type funding = {"PAYPAL": string}
type style = {
  layout: string,
  color: string,
  shape: string,
  label: string,
  height: int,
}
type buttons = {
  style: style,
  fundingSource: string,
  createBillingAgreement: unit => unit,
  onApprove: (data, actions) => unit,
  onCancel: data => unit,
  onError: err => unit,
}
let getLabel = (var: PaymentType.paypalStyleType) => {
  switch var {
  | Paypal => "paypal"
  | Checkout => "checkout"
  | Pay => "pay"
  | Buynow => "buynow"
  | Installment => "installment"
  }
}
type some = {render: string => unit}
type paypal = {"Buttons": buttons => some, "FUNDING": funding}

@val external braintree: braintree = "braintree"
@val external paypal: paypal = "paypal"
