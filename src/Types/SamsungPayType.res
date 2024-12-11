type client = {
  isReadyToPay: JSON.t => promise<JSON.t>,
  createButton: JSON.t => Dom.element,
  loadPaymentSheet: (JSON.t, JSON.t) => promise<Fetch.Response.t>,
  notify: JSON.t => unit,
}

type env = {environment: string}

@new external samsung: env => client = "SamsungPay.PaymentClient"

type merchant = {
  name: string,
  url: string,
  countryCode: string,
}
type amount = {
  option: string,
  currency: string,
  total: string,
}
type transactionDetail = {
  orderNumber: string,
  merchant: merchant,
  amount: amount,
}
type paymentMethods = {
  version: string,
  serviceId: string,
  protocol: string,
  allowedBrands: array<string>,
}

type threeDS = {
  \"type": string,
  version: string,
  data: string,
}
type paymentMethodData = {
  method: string,
  recurring_payment: bool,
  card_brand: string,
  card_last4digits: string,
  @as("3_d_s") threeDS: threeDS,
}
type paymentData = {paymentMethodData: paymentMethodData}
