type authorization = {authorization: string}
type environment = {environment: string}
type clientInstance = {}

type transactionInfo = {
  currencyCode: string,
  totalPriceStatus: string,
  totalPrice: string,
}

type gPayTransactionData = {transactionInfo: transactionInfo}

type merchantInfo = {merchantId: string}

type allowedPaymentMethod = {
  \"type": string,
  parameters: JSON.t,
}

type gPayPaymentDataRequest = {
  transactionInfo: transactionInfo,
  merchantInfo?: merchantInfo,
  allowedPaymentMethods?: array<allowedPaymentMethod>,
}

type cardInfo = {
  cardNetwork: string,
  cardDetails: string,
}

type tokenizationData = {
  \"type": string,
  token: string,
}

type paymentMethodData = {
  description: string,
  info: cardInfo,
  tokenizationData: tokenizationData,
  \"type": string,
}

type gPayPaymentData = {paymentMethodData: paymentMethodData}

type gPayInstance = {
  createPaymentDataRequest: gPayTransactionData => gPayPaymentDataRequest,
  parseResponse: gPayPaymentData => promise<JSON.t>,
}

type applePayTotal = {
  label: string,
  amount: string,
}

type applePayTransactionData = {
  total: applePayTotal,
  requiredBillingContactFields: array<string>,
}

type applePayValidationRequest = {
  validationURL: string,
  displayName: string,
}

type applePayTokenizeRequest = {token: string}

type applePayTokenizeResponse = {nonce: string}

type applePayInstance = {
  createPaymentRequest: applePayTransactionData => applePayTransactionData,
  performValidation: (applePayValidationRequest, (bool, JSON.t) => unit) => unit,
  tokenize: (applePayTokenizeRequest, (bool, applePayTokenizeResponse) => unit) => unit,
}

type createButtonConfig = {
  onClick: unit => promise<unit>,
  buttonSizeMode?: string,
  buttonType?: string,
}

type paymentClient = {
  createButton: createButtonConfig => Dom.element,
  loadPaymentData: gPayPaymentDataRequest => promise<gPayPaymentData>,
}

type clientCreateCallback = (bool, clientInstance) => unit
type gPayCreateCallback = (bool, gPayInstance) => unit
type applePayCreateCallback = (bool, applePayInstance) => unit

type applePayValidationEvent = {validationURL: string}

type applePayPayment = {token: string}

type applePayPaymentEvent = {payment: applePayPayment}

type applePaySessions = {
  mutable onvalidatemerchant: applePayValidationEvent => unit,
  mutable onpaymentauthorized: applePayPaymentEvent => unit,
  mutable oncancel: unit => unit,
  completeMerchantValidation: JSON.t => unit,
  completePayment: JSON.t => unit,
  begin: unit => unit,
  abort: unit => unit,
  \"STATUS_SUCCESS": JSON.t,
  \"STATUS_FAILURE": JSON.t,
}

type gPayConfig = {
  client: clientInstance,
  googlePayVersion: int,
  googleMerchantId: string,
}

type applePayConfig = {client: clientInstance}

// PayPal-specific types
type paypalCheckoutErr = {message: string}
type paypalData = {}
type paypalInitConfig = {
  currency: string,
  intent: string,
}
type paypalOrderDetails = {
  flow: string,
  amount: float,
  currency: string,
}
type paypalPayload = {nonce: string}
type paypalCheckoutInstance = {
  loadPayPalSDK: (paypalInitConfig, unit => unit) => unit,
  createPayment: paypalOrderDetails => string,
  tokenizePayment: (paypalData, (bool, paypalPayload) => unit) => unit,
}
type paypalCheckoutConfig = {client: clientInstance}
type paypalCreateCallback = (Nullable.t<paypalCheckoutErr>, paypalCheckoutInstance) => unit
type paypalStyle = {
  layout: string,
  color: string,
  shape: string,
  label: string,
  height: int,
}
type paypalButtons = {
  style: paypalStyle,
  fundingSource: string,
  createOrder: unit => string,
  onApprove: (paypalData, JSON.t) => unit,
  onCancel: paypalData => unit,
  onError: JSON.t => unit,
}
type paypalButtonRenderer = {render: string => unit}
type paypalFunding = {"PAYPAL": string}
type paypalSDK = {"Buttons": paypalButtons => paypalButtonRenderer, "FUNDING": paypalFunding}
