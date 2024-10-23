type field = {
  value: string,
  isValid: option<bool>,
  errorString: string,
  countryCode?: string,
}

type load = Loading | Loaded(JSON.t) | LoadError
type screenType = CARDFORM | SAVEDCARD | NONE
let defaultScreenValues = NONE

type paymentToken = {
  paymentToken: string,
  customerId: string,
}
