type authorization = {authorization: string}
type environment = {environment: string}
type clientInstance = {}

type gPayInstance = {
  createPaymentDataRequest: JSON.t => JSON.t,
  parseResponse: JSON.t => promise<JSON.t>,
}

type applePayInstance = {
  createPaymentRequest: JSON.t => JSON.t,
  performValidation: (JSON.t, (bool, JSON.t) => unit) => unit,
  tokenize: (JSON.t, (bool, JSON.t) => unit) => unit,
}

type createButtonConfig = {
  onClick: unit => promise<unit>,
  buttonSizeMode?: string,
  buttonType?: string,
}

type paymentClient = {
  createButton: createButtonConfig => Dom.element,
  loadPaymentData: JSON.t => promise<JSON.t>,
}

type clientCreateCallback = (bool, clientInstance) => unit
type paymentCreateCallback = (bool, gPayInstance) => unit
type applePayCreateCallback = (bool, applePayInstance) => unit

type applePaySessions = {
  mutable onvalidatemerchant: JSON.t => unit,
  mutable onpaymentauthorized: JSON.t => unit,
  mutable oncancel: unit => unit,
  completeMerchantValidation: JSON.t => unit,
  completePayment: JSON.t => unit,
  begin: unit => unit,
  abort: unit => unit,
  \"STATUS_SUCCESS": JSON.t,
  \"STATUS_FAILURE": JSON.t,
}
