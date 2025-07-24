type authorization = {authorization: string}
type environment = {environment: string}
type clientInstance = {}

type gPayInstance = {
  createPaymentDataRequest: JSON.t => JSON.t,
  parseResponse: JSON.t => promise<JSON.t>,
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
