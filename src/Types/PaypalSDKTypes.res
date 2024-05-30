type clientErr = bool
type clientInstance
type paypalCheckoutErr = {message: string}
type data
type order = {get: unit => RescriptCore.Promise.t<JSON.t>}
type actions = {order: order}
type err
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
type details = {
  email: string,
  shippingAddress: shipping,
  phone: option<string>,
}
type payload = {nonce: string, details: details}
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
  createBillingAgreement?: unit => unit,
  createOrder?: unit => RescriptCore.Promise.t<string>,
  onApprove: (data, actions) => unit,
  onCancel: data => unit,
  onError?: err => unit,
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

let getShippingDetails = shippingAddressOverrideObj => {
  let shippingAddressOverride = shippingAddressOverrideObj->Utils.getDictFromJson

  let recipientName = shippingAddressOverride->Utils.getOptionString("recipient_name")
  let line1 = shippingAddressOverride->Utils.getOptionString("line1")
  let line2 = shippingAddressOverride->Utils.getOptionString("line2")
  let city = shippingAddressOverride->Utils.getOptionString("city")
  let countryCode = shippingAddressOverride->Utils.getOptionString("country_code")
  let postalCode = shippingAddressOverride->Utils.getOptionString("postal_code")
  let state = shippingAddressOverride->Utils.getOptionString("state")
  let phone = shippingAddressOverride->Utils.getOptionString("phone")

  if (
    [recipientName, line1, line2, city, countryCode, postalCode, state, phone]->Array.includes(None)
  ) {
    None
  } else {
    Some({
      recipientName,
      line1,
      line2,
      city,
      countryCode,
      postalCode,
      state,
      phone,
    })
  }
}

let paypalShippingDetails = purchaseUnit => {
  let shippingAddress = purchaseUnit->Utils.getDictfromDict("shipping")
  let payee = purchaseUnit->Utils.getDictfromDict("payee")

  let address = shippingAddress->Utils.getDictfromDict("address")
  let name = shippingAddress->Utils.getDictfromDict("name")

  let recipientName = name->Utils.getOptionString("full_name")
  let line1 = address->Utils.getOptionString("address_line_1")
  let line2 = address->Utils.getOptionString("address_line_2")
  let city = address->Utils.getOptionString("admin_area_2")
  let countryCode = address->Utils.getOptionString("country_code")
  let postalCode = address->Utils.getOptionString("postal_code")
  let state = address->Utils.getOptionString("admin_area_1")
  let email = payee->Utils.getString("email_address", "")

  let payeePhone = payee->Utils.getOptionString("phone")
  let shippingAddressPhone = address->Utils.getOptionString("phone")

  {
    email,
    shippingAddress: {
      recipientName,
      line1,
      line2,
      city,
      countryCode,
      postalCode,
      state,
      phone: shippingAddressPhone,
    },
    phone: payeePhone,
  }
}

let getOrderDetails = (orderDetails, paymentType) => {
  let orderDetailsDict = orderDetails->Utils.getDictFromJson

  let isWalletElementPaymentType = paymentType->Utils.getIsWalletElementPaymentType

  let shippingAddressOverride = isWalletElementPaymentType
    ? orderDetailsDict->Utils.getJsonObjectFromDict("shipping_address_override")->getShippingDetails
    : None

  let enableShippingAddress = isWalletElementPaymentType
    ? orderDetailsDict->Utils.getOptionBool("enable_shipping_address")
    : None

  {
    flow: orderDetailsDict->Utils.getString("flow", "vault"),
    billingAgreementDescription: None,
    enableShippingAddress,
    shippingAddressEditable: None,
    shippingAddressOverride,
  }
}
