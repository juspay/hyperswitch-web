type eventData = {
  iframeMounted: bool,
  focus: bool,
  blur: bool,
  ready: bool,
  clickTriggered: bool,
  elementType: string,
  classChange: bool,
  newClassType: string,
  confirmTriggered: bool,
  oneClickConfirmTriggered: bool,
}
type event = {key: string, data: eventData}
type eventParam = Event(event) | EventData(eventData) | Empty
type eventHandler = option<JSON.t> => unit
@send external onload: (Dom.element, unit => Promise.t<'a>) => Promise.t<'a> = "onload"
module This = {
  type t
  @get
  external iframeElem: t => option<nullable<Dom.element>> = "iframeElem"
}

type paymentElement = {
  on: (string, option<option<eventData> => unit>) => unit,
  collapse: unit => unit,
  blur: unit => unit,
  update: JSON.t => unit,
  destroy: unit => unit,
  unmount: unit => unit,
  mount: string => unit,
  focus: unit => unit,
  clear: unit => unit,
}

type element = {
  getElement: string => option<paymentElement>,
  update: JSON.t => unit,
  fetchUpdates: unit => Promise.t<JSON.t>,
  create: (string, JSON.t) => paymentElement,
}

type getCustomerSavedPaymentMethods = {
  getCustomerDefaultSavedPaymentMethodData: unit => JSON.t,
  confirmWithCustomerDefaultPaymentMethod: JSON.t => Promise.t<JSON.t>,
}

type initPaymentSession = {getCustomerSavedPaymentMethods: unit => Promise.t<JSON.t>}

type confirmParams = {return_url: string}

type confirmPaymentParams = {
  elements: JSON.t,
  confirmParams: Nullable.t<confirmParams>,
}

type hyperInstance = {
  confirmOneClickPayment: (JSON.t, bool) => Promise.t<JSON.t>,
  confirmPayment: JSON.t => Promise.t<JSON.t>,
  elements: JSON.t => element,
  confirmCardPayment: (string, option<JSON.t>, option<JSON.t>) => Promise.t<JSON.t>,
  retrievePaymentIntent: string => Promise.t<JSON.t>,
  widgets: JSON.t => element,
  paymentRequest: JSON.t => JSON.t,
  initPaymentSession: JSON.t => initPaymentSession,
}

let oneClickConfirmPaymentFn = (_, _) => {
  Promise.resolve(Dict.make()->JSON.Encode.object)
}

let confirmPaymentFn = (_elements: JSON.t) => {
  Promise.resolve(Dict.make()->JSON.Encode.object)
}
let confirmCardPaymentFn = (
  _clientSecretId: string,
  _data: option<JSON.t>,
  _options: option<JSON.t>,
) => {
  Promise.resolve(Dict.make()->JSON.Encode.object)
}

let retrievePaymentIntentFn = _paymentIntentId => {
  Promise.resolve(Dict.make()->JSON.Encode.object)
}
let update = _options => {
  ()
}

let getElement = _componentName => {
  None
}

let fetchUpdates = () => {
  Promise.make((resolve, _) => {
    setTimeout(() => resolve(Dict.make()->JSON.Encode.object), 1000)->ignore
  })
}
let defaultPaymentElement = {
  on: (_str, _func) => (),
  collapse: () => (),
  blur: () => (),
  update: _x => (),
  destroy: () => (),
  unmount: () => (),
  mount: _string => (),
  focus: () => (),
  clear: () => (),
}

let create = (_componentType, _options) => {
  defaultPaymentElement
}

let defaultElement = {
  getElement,
  update,
  fetchUpdates,
  create,
}

let getCustomerDefaultSavedPaymentMethodData = () => {
  JSON.Encode.null
}

let confirmWithCustomerDefaultPaymentMethod = _confirmParams => {
  Promise.resolve(Dict.make()->JSON.Encode.object)
}

let defaultGetCustomerSavedPaymentMethods = () => {
  // TODO: After rescript migration to v11, add this without TAG using enums
  // Promise.resolve({
  //   getCustomerDefaultSavedPaymentMethodData,
  //   confirmWithCustomerDefaultPaymentMethod,
  // })
  Promise.resolve(JSON.Encode.null)
}

let defaultInitPaymentSession: initPaymentSession = {
  getCustomerSavedPaymentMethods: defaultGetCustomerSavedPaymentMethods,
}

let defaultHyperInstance = {
  confirmOneClickPayment: oneClickConfirmPaymentFn,
  confirmPayment: confirmPaymentFn,
  confirmCardPayment: confirmCardPaymentFn,
  retrievePaymentIntent: retrievePaymentIntentFn,
  elements: _ev => defaultElement,
  widgets: _ev => defaultElement,
  paymentRequest: _ev => JSON.Encode.null,
  initPaymentSession: _ev => defaultInitPaymentSession,
}

type eventType =
  Escape | Change | Click | Ready | Focus | Blur | ConfirmPayment | OneClickConfirmPayment | None

let eventTypeMapper = event => {
  switch event {
  | "escape" => Escape
  | "change" => Change
  | "clickTriggered" => Click
  | "ready" => Ready
  | "focus" => Focus
  | "blur" => Blur
  | "confirmTriggered" => ConfirmPayment
  | "oneClickConfirmTriggered" => OneClickConfirmPayment
  | _ => None
  }
}
type rec ele = {
  mutable id: string,
  mutable src: string,
  mutable name: string,
  mutable style: string,
  mutable onload: unit => unit,
  mutable action: string,
  mutable method: string,
  mutable target: string,
  mutable enctype: string,
  mutable value: string,
  submit: unit => unit,
  appendChild: ele => unit,
}
@scope("document") @val external createElement: string => ele = "createElement"

@send external appendChild: (Dom.element, ele) => unit = "appendChild"
