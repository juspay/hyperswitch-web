open Utils

type calculateTaxResponse = {
  payment_id: string,
  net_amount: float,
  order_tax_amount: float,
  shipping_cost: float,
}

let taxResponseToObjMapper = resp => {
  let responseDict = resp->getDictFromJson
  let displayAmountDict = responseDict->getDictFromDict("display_amount")
  {
    payment_id: responseDict->getString("payment_id", ""),
    net_amount: displayAmountDict->getFloat("net_amount", 0.0),
    order_tax_amount: displayAmountDict->getFloat("order_tax_amount", 0.0),
    shipping_cost: displayAmountDict->getFloat("shipping_cost", 0.0),
  }
}

let calculateTax = (
  ~shippingAddress,
  ~logger,
  ~clientSecret,
  ~publishableKey,
  ~paymentMethodType,
) => {
  PaymentHelpers.calculateTax(
    ~clientSecret=clientSecret->JSON.Encode.string,
    ~apiKey=publishableKey,
    ~paymentId=clientSecret->getPaymentId,
    ~paymentMethodType,
    ~shippingAddress,
    ~logger,
    ~customPodUri="",
  )
}
