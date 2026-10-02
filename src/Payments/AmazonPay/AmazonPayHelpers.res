open Utils
open AmazonPayTypes

external renderAmazonPayButton: (~buttonId: string, ~config: amazonPayConfigType) => unit =
  "amazon.Pay.renderJSButton"

let deliveryPriceMapper = dict => {
  amount: dict->getInt("amount", 0),
  displayAmount: dict->getString("display_amount", ""),
  currencyCode: dict->getString("currency_code", ""),
}

let shippingMethodMapper = dict => {
  shippingMethodName: dict->getString("shipping_method_name", ""),
  shippingMethodCode: dict->getString("shipping_method_code", ""),
}

let deliveryOptionMapper = dict => {
  let priceData = dict->getDictFromDict("price")->deliveryPriceMapper
  {
    id: dict->getString("id", ""),
    price: {
      amount: priceData.displayAmount,
      currencyCode: priceData.currencyCode,
    },
    shippingMethod: dict->getDictFromDict("shipping_method")->shippingMethodMapper,
    isDefault: dict->getBool("is_default", false),
  }
}

let amazonPayTokenMapper = dict => {
  walletName: dict->getString("wallet_name", ""),
  merchantId: dict->getString("merchant_id", ""),
  ledgerCurrency: dict->getString("ledger_currency", ""),
  storeId: dict->getString("store_id", ""),
  paymentIntent: dict->getString("payment_intent", ""),
  totalTaxAmount: dict->getString("total_tax_amount", ""),
  totalBaseAmount: dict->getString("total_base_amount", ""),
  deliveryOptions: dict
  ->getArray("delivery_options")
  ->Array.map(item => item->getDictFromJson->deliveryOptionMapper),
}

let amazonPayBody = (amazonCheckoutSessionId, shipping) => {
  let wallet = {
    amazon_pay: {
      checkout_session_id: amazonCheckoutSessionId,
    },
  }
  let paymentMethodData = [("wallet", wallet->Identity.anyTypeToJson)]->getJsonFromArrayOfJson
  [
    ("payment_method", "wallet"->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
    ("capture_method", "automatic"->JSON.Encode.string),
    ("payment_experience", "invoke_sdk_client"->JSON.Encode.string),
    ("payment_method_type", "amazon_pay"->JSON.Encode.string),
    ("shipping", shipping->Identity.anyTypeToJson),
  ]
}

let defaultShipping = {
  address: {
    line1: "",
    line2: "",
    line3: "",
    city: "",
    state: "",
    zip: "",
    country: "",
    first_name: "",
    last_name: "",
  },
  phone: {number: ""},
}

let getShippingAddressFromEvent = event => {
  let eventDict = event->getDictFromJson
  let shippingAddressDict = eventDict->getDictFromDict("shippingAddress")
  let fullName = shippingAddressDict->getString("name", "")
  let addressLine1 = shippingAddressDict->getString("addressLine1", "")
  let addressLine2 = shippingAddressDict->getString("addressLine2", "")
  let addressLine3 = shippingAddressDict->getString("addressLine3", "")
  let city = shippingAddressDict->getString("city", "")
  let state = shippingAddressDict->getString("stateOrRegion", "")
  let zip = shippingAddressDict->getString("postalCode", "")
  let country = shippingAddressDict->getString("countryCode", "")
  let phoneNumber = shippingAddressDict->getString("phoneNumber", "")

  let (firstName, lastName) = fullName->getFirstAndLastNameFromFullName

  {
    address: {
      line1: addressLine1,
      line2: addressLine2,
      line3: addressLine3,
      city,
      state,
      zip,
      country,
      first_name: firstName->getStringFromJson(""),
      last_name: lastName->getStringFromJson(""),
    },
    phone: {number: phoneNumber},
  }
}

let handleOnInitCheckout = (
  event,
  shippingAddressRef: React.ref<shipping>,
  defaultShippingAmount,
  currencyCode,
  sessionToken: amazonPayTokenType,
  totalOrderAmount,
) => {
  shippingAddressRef.current = event->getShippingAddressFromEvent

  {
    totalShippingAmount: {amount: defaultShippingAmount, currencyCode},
    totalBaseAmount: {amount: sessionToken.totalBaseAmount, currencyCode},
    totalTaxAmount: {amount: sessionToken.totalTaxAmount, currencyCode},
    totalChargeAmount: {amount: totalOrderAmount, currencyCode},
    totalDiscountAmount: {amount: "0.00", currencyCode},
    deliveryOptions: sessionToken.deliveryOptions,
  }
}

// Shared function for onInitCheckout and onShippingAddressSelection
// Both handlers return identical values with updated shipping address
let handleOnShippingAddressSelection = handleOnInitCheckout

let handleOnDeliveryOptionSelection = (event, currencyCode, sessionToken: amazonPayTokenType) => {
  let selectedOption =
    sessionToken.deliveryOptions->Array.find(option => option.id === event.deliveryOptions.id)

  let newShippingAmount = selectedOption->Option.mapOr("0.0", option => option.price.amount)
  let baseAmount = sessionToken.totalBaseAmount->getFloatFromString(0.0)
  let taxAmount = sessionToken.totalTaxAmount->getFloatFromString(0.0)
  let shippingAmount = newShippingAmount->getFloatFromString(0.0)
  let newTotalAmount = (baseAmount +. taxAmount +. shippingAmount)->Float.toString

  {
    totalShippingAmount: {amount: newShippingAmount, currencyCode},
    totalBaseAmount: {amount: sessionToken.totalBaseAmount, currencyCode},
    totalTaxAmount: {amount: sessionToken.totalTaxAmount, currencyCode},
    totalChargeAmount: {amount: newTotalAmount, currencyCode},
    totalDiscountAmount: {amount: "0.00", currencyCode},
  }
}
