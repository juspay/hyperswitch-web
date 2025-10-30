type authorization = {authorization: string}
type clientInstance = JSON.t
type clientCreateCallback = (bool, clientInstance) => unit

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
  createPayment: paypalOrderDetails => unit,
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
  createOrder: unit => unit,
  onApprove: (paypalData, JSON.t) => unit,
  onCancel: paypalData => unit,
  onError: JSON.t => unit,
}

type paypalButtonRenderer = {render: string => unit}
type paypalFunding = {"PAYPAL": string}
type paypalSDK = {"Buttons": paypalButtons => paypalButtonRenderer, "FUNDING": paypalFunding}
