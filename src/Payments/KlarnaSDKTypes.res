type token = {client_token: string}
type collected_shipping_address = {
  city: string,
  country: string,
  email: string,
  family_name: string,
  given_name: string,
  phone: string,
  postal_code: string,
  region: string,
  street_address: string,
}
let defaultCollectedShippingAddress = {
  city: "",
  country: "",
  email: "",
  family_name: "",
  given_name: "",
  phone: "",
  postal_code: "",
  region: "",
  street_address: "",
}

type res = {
  approved: bool,
  show_form: bool,
  authorization_token: string,
  finalize_required: bool,
  collected_shipping_address?: collected_shipping_address,
}
type authorizeAttributes = {collect_shipping_address: bool}
type authorize = (authorizeAttributes, JSON.t, res => unit) => unit
type loadType = {
  container?: string,
  color_text?: string,
  payment_method_category?: string,
  theme?: string,
  shape?: string,
  on_click?: authorize => Promise.t<unit>,
}
type some = {
  init: token => unit,
  load: (loadType, JSON.t => unit) => unit,
}
