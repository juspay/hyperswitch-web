open Utils

type deliveryPrice = {
  amount: int,
  displayAmount: string,
  currencyCode: string,
}

type shippingMethod = {
  shippingMethodName: string,
  shippingMethodCode: string,
}

type deliveryOption = {
  id: string,
  price: deliveryPrice,
  shippingMethod: shippingMethod,
  isDefault: bool,
}

type amazonPayTokenType = {
  walletName: string,
  merchantId: string,
  ledgerCurrency: string,
  storeId: string,
  paymentIntent: string,
  totalShippingAmount: string,
  totalTaxAmount: string,
  totalBaseAmount: string,
  deliveryOptions: array<deliveryOption>,
}

let deliveryPriceMapper = dict => {
  {
    amount: getInt(dict, "amount", 0),
    displayAmount: getString(dict, "display_amount", ""),
    currencyCode: getString(dict, "currency_code", ""),
  }
}

let shippingMethodMapper = dict => {
  {
    shippingMethodName: getString(dict, "shipping_method_name", ""),
    shippingMethodCode: getString(dict, "shipping_method_code", ""),
  }
}

let deliveryOptionMapper = dict => {
  {
    id: getString(dict, "id", ""),
    price: dict->getDictFromDict("price")->deliveryPriceMapper,
    shippingMethod: dict->getDictFromDict("shipping_method")->shippingMethodMapper,
    isDefault: getBool(dict, "is_default", false),
  }
}

let amazonPayTokenMapper = dict => {
  {
    walletName: getString(dict, "wallet_name", ""),
    merchantId: getString(dict, "merchant_id", ""),
    ledgerCurrency: getString(dict, "ledger_currency", ""),
    storeId: getString(dict, "store_id", ""),
    paymentIntent: getString(dict, "payment_intent", ""),
    totalShippingAmount: getString(dict, "total_shipping_amount", ""),
    totalTaxAmount: getString(dict, "total_tax_amount", ""),
    totalBaseAmount: getString(dict, "total_base_amount", ""),
    deliveryOptions: getArray(dict, "delivery_options")->Array.map(item =>
      item->getDictFromJson->deliveryOptionMapper
    ),
  }
}

@react.component
let make = (~amazonPayToken) => {
  let token = amazonPayToken->amazonPayTokenMapper
  Js.Console.log2("Amazon Pay Token", token)
  <div />
}
