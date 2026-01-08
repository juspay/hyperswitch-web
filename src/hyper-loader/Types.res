type window

@val external window: {..} = "window"

type eventData = {
  iframeMounted: bool,
  focus: bool,
  blur: bool,
  ready: bool,
  clickTriggered: bool,
  completeDoThis: bool,
  elementType: string,
  classChange: bool,
  newClassType: string,
  confirmTriggered: bool,
  oneClickConfirmTriggered: bool,
}
type event = {key: string, data: eventData, source: Dom.element}
type eventParam = Event(event) | EventData(eventData) | Empty
type eventHandler = option<JSON.t> => unit
@send external onload: (Dom.element, unit => promise<'a>) => promise<'a> = "onload"
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
  onSDKHandleClick: option<unit => Promise.t<unit>> => unit,
}

type element = {
  getElement: string => option<paymentElement>,
  update: JSON.t => unit,
  fetchUpdates: unit => promise<JSON.t>,
  create: (string, JSON.t) => paymentElement,
}

type getCustomerSavedPaymentMethods = {
  getCustomerDefaultSavedPaymentMethodData: unit => JSON.t,
  getCustomerLastUsedPaymentMethodData: unit => JSON.t,
  confirmWithCustomerDefaultPaymentMethod: JSON.t => promise<JSON.t>,
  confirmWithLastUsedPaymentMethod: JSON.t => promise<JSON.t>,
}

type getPaymentManagementMethods = {
  getSavedPaymentManagementMethodsList: unit => promise<JSON.t>,
  deleteSavedPaymentMethod: JSON.t => promise<JSON.t>,
}

type initPaymentSession = {
  getCustomerSavedPaymentMethods: unit => promise<JSON.t>,
  getPaymentManagementMethods: unit => promise<JSON.t>,
}

type isCustomerPresentInput = {email: string}

type validateCustomerAuthenticationInput = {value: string}

type checkoutWithCardInput = {
  srcDigitalCardId: string,
  rememberMe: option<bool>,
  windowRef: Nullable.t<window>,
}

type clickToPaySession = {
  isCustomerPresent: option<isCustomerPresentInput> => promise<JSON.t>,
  getUserType: unit => promise<JSON.t>, // getUserType
  getRecognizedCards: unit => promise<JSON.t>,
  validateCustomerAuthentication: validateCustomerAuthenticationInput => promise<JSON.t>,
  checkoutWithCard: checkoutWithCardInput => promise<JSON.t>,
  signOut: unit => promise<JSON.t>,
}

type initClickToPaySessionInput = {request3DSAuthentication: option<bool>}

type initAuthenticationSession = {
  initClickToPaySession: initClickToPaySessionInput => promise<JSON.t>,
}

type confirmParams = {return_url: string}

type confirmPaymentParams = {
  elements: JSON.t,
  confirmParams: Nullable.t<confirmParams>,
}

type hyperInstance = {
  confirmOneClickPayment: (JSON.t, bool) => promise<JSON.t>,
  confirmPayment: JSON.t => promise<JSON.t>,
  elements: JSON.t => element,
  confirmCardPayment: (string, option<JSON.t>, option<JSON.t>) => promise<JSON.t>,
  retrievePaymentIntent: string => promise<JSON.t>,
  widgets: JSON.t => element,
  paymentRequest: JSON.t => JSON.t,
  initPaymentSession: JSON.t => initPaymentSession,
  initAuthenticationSession: JSON.t => initAuthenticationSession,
  paymentMethodsManagementElements: JSON.t => element,
  completeUpdateIntent: string => promise<JSON.t>,
  initiateUpdateIntent: unit => promise<JSON.t>,
  confirmTokenization: JSON.t => promise<JSON.t>,
}

let oneClickConfirmPaymentFn = (_, _) => {
  Promise.resolve(Dict.make()->JSON.Encode.object)
}

let confirmPaymentFn = (_elements: JSON.t) => {
  Promise.resolve(Dict.make()->JSON.Encode.object)
}
let confirmTokenizationFn = (_elements: JSON.t) => {
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

let fnArgument = Some(() => Promise.make((_, _) => {()}))
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
  onSDKHandleClick: _fnArgument => (),
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

let getSavedPaymentManagementMethodsList = () => {
  JSON.Encode.null
}

let deleteSavedPaymentMethod = () => {
  JSON.Encode.null
}

let getCustomerLastUsedPaymentMethodData = () => {
  JSON.Encode.null
}

let confirmWithCustomerDefaultPaymentMethod = _confirmParams => {
  Promise.resolve(Dict.make()->JSON.Encode.object)
}

let confirmWithLastUsedPaymentMethod = _confirmParams => {
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

let defaultGetPaymentManagementMethods = () => {
  Promise.resolve(JSON.Encode.null)
}

let defaultInitPaymentSession: initPaymentSession = {
  getCustomerSavedPaymentMethods: defaultGetCustomerSavedPaymentMethods,
  getPaymentManagementMethods: defaultGetPaymentManagementMethods,
}

let defaultInitAuthenticationSession: initAuthenticationSession = {
  initClickToPaySession: _ => Promise.resolve(JSON.Encode.null),
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
  initAuthenticationSession: _ev => defaultInitAuthenticationSession,
  paymentMethodsManagementElements: _ev => defaultElement,
  completeUpdateIntent: _ => Promise.resolve(Dict.make()->JSON.Encode.object),
  initiateUpdateIntent: _ => Promise.resolve(Dict.make()->JSON.Encode.object),
  confirmTokenization: confirmTokenizationFn,
}

type eventType =
  | Escape
  | Change
  | Click
  | Ready
  | Focus
  | Blur
  | CompleteDoThis
  | ConfirmPayment
  | OneClickConfirmPayment
  | None

let eventTypeMapper = event => {
  switch event {
  | "escape" => Escape
  | "change" => Change
  | "clickTriggered" => Click
  | "ready" => Ready
  | "completeDoThis" => CompleteDoThis
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

type hyperComponentName = Elements | PaymentMethodsManagementElements

let getStrFromHyperComponentName = hyperComponentName => {
  switch hyperComponentName {
  | Elements => "Elements"
  | PaymentMethodsManagementElements => "PaymentMethodsManagementElements"
  }
}

let getHyperComponentNameFromStr = hyperComponentName => {
  switch hyperComponentName {
  | "PaymentMethodsManagementElements" => PaymentMethodsManagementElements
  | _ => Elements
  }
}
