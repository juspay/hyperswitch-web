open Utils

type calculateTaxResponse = {
  payment_id: string,
  net_amount: int,
  order_tax_amount: int,
  shipping_cost: int,
}

let taxResponseToObjMapper = resp => {
  resp
  ->JSON.Decode.object
  ->Option.map(dict => {
    payment_id: dict->getString("payment_id", ""),
    net_amount: dict->getInt("net_amount", 0),
    order_tax_amount: dict->getInt("order_tax_amount", 0),
    shipping_cost: dict->getInt("shipping_cost", 0),
  })
}

let calculateTax = (
  ~shippingAddress,
  ~logger,
  ~clientSecret,
  ~publishableKey,
  ~paymentMethodType,
  ~sessionId=None,
  ~sdkAuthorization=None,
) => {
  PaymentHelpers.calculateTax(
    ~clientSecret,
    ~apiKey=publishableKey,
    ~paymentMethodType,
    ~shippingAddress,
    ~logger,
    ~customPodUri="",
    ~sessionId,
    ~sdkAuthorization,
  )
}
