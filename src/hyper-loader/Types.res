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
  iframeId: string,
  classChange: bool,
  newClassType: string,
  confirmTriggered: bool,
  oneClickConfirmTriggered: bool,
}
type event = {key: string, data: eventData, origin: string, source: Dom.element}
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
  confirmPayment: JSON.t => promise<JSON.t>,
}

type fieldHandle = {
  mount: string => unit,
  unmount: unit => unit,
  destroy: unit => unit,
  update: JSON.t => unit,
  focus: unit => unit,
  blur: unit => unit,
  clear: unit => unit,
  on: (string, JSON.t => unit) => unit,
}

type cardForm = {
  create: (string, JSON.t) => fieldHandle,
  on: (string, JSON.t => unit) => unit,
  confirm: unit => promise<JSON.t>,
  deinit: unit => unit,
  update: JSON.t => unit,
  fields: ref<JSON.t>,
}

type paymentMethodsSessionGroup = {
  cardForm: unit => cardForm,
  update: JSON.t => unit,
  on: (string, JSON.t => unit) => unit,
  deinit: unit => unit,
  fields: ref<JSON.t>,
}

type element = {
  getElement: string => option<paymentElement>,
  update: JSON.t => unit,
  fetchUpdates: unit => promise<JSON.t>,
  create: (JSON.t, Nullable.t<JSON.t>) => paymentElement,
  updateIntent: (unit => promise<JSON.t>) => promise<JSON.t>,
  cardForm: unit => cardForm,
}

type getCustomerSavedPaymentMethods = {
  getCustomerDefaultSavedPaymentMethodData: unit => JSON.t,
  getCustomerLastUsedPaymentMethodData: unit => JSON.t,
  confirmWithCustomerDefaultPaymentMethod: JSON.t => promise<JSON.t>,
  confirmWithLastUsedPaymentMethod: JSON.t => promise<JSON.t>,
}

type initPaymentSession = {
  getCustomerSavedPaymentMethods: option<JSON.t> => promise<JSON.t>,
  updateIntent: (unit => promise<JSON.t>) => promise<JSON.t>,
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

type clickToPayObj = {session: Nullable.t<clickToPaySession>}

type initClickToPaySessionInput = {request3DSAuthentication: option<bool>}

type initAuthenticationSession = {
  initClickToPaySession: initClickToPaySessionInput => promise<JSON.t>,
  getActiveClickToPaySession: unit => promise<JSON.t>,
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
  paymentMethodsSession: JSON.t => paymentMethodsSessionGroup,
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
  confirmPayment: _payload => Promise.resolve(Dict.make()->JSON.Encode.object),
}

let create = (_options: JSON.t, _options2: Nullable.t<JSON.t>) => {
  defaultPaymentElement
}

let vaultSDKNotLoadedError: JSON.t = {
  let errorDict = Dict.make()
  errorDict->Dict.set("code", "sdk_not_ready"->JSON.Encode.string)
  errorDict->Dict.set("message", "Default stub — hyper not initialized"->JSON.Encode.string)
  let resultDict = Dict.make()
  resultDict->Dict.set("status", "error"->JSON.Encode.string)
  resultDict->Dict.set("error", errorDict->JSON.Encode.object)
  resultDict->JSON.Encode.object
}

let defaultFieldHandle: fieldHandle = {
  mount: _ => (),
  unmount: () => (),
  destroy: () => (),
  update: _ => (),
  focus: () => (),
  blur: () => (),
  clear: () => (),
  on: (_, _) => (),
}

let defaultCardForm: cardForm = {
  create: (_, _) => defaultFieldHandle,
  on: (_, _) => (),
  confirm: () => Promise.resolve(vaultSDKNotLoadedError),
  deinit: () => (),
  update: _ => (),
  fields: ref(Dict.make()->JSON.Encode.object),
}

let defaultElement = {
  getElement,
  update,
  fetchUpdates,
  create,
  updateIntent: _ => Promise.resolve(JSON.Encode.null),
  cardForm: () => defaultCardForm,
}

let getCustomerDefaultSavedPaymentMethodData = () => {
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

let defaultGetCustomerSavedPaymentMethods = (_options: option<JSON.t>) => {
  // TODO: After rescript migration to v11, add this without TAG using enums
  // Promise.resolve({
  //   getCustomerDefaultSavedPaymentMethodData,
  //   confirmWithCustomerDefaultPaymentMethod,
  // })
  Promise.resolve(JSON.Encode.null)
}

let defaultInitPaymentSession: initPaymentSession = {
  getCustomerSavedPaymentMethods: defaultGetCustomerSavedPaymentMethods,
  updateIntent: _ => Promise.resolve(JSON.Encode.null),
}

let defaultInitAuthenticationSession: initAuthenticationSession = {
  initClickToPaySession: _ => Promise.resolve(JSON.Encode.null),
  getActiveClickToPaySession: _ => Promise.resolve(JSON.Encode.null),
}

let defaultPaymentMethodsSessionGroup: paymentMethodsSessionGroup = {
  cardForm: () => defaultCardForm,
  update: _ => (),
  on: (_, _) => (),
  deinit: () => (),
  fields: ref(Dict.make()->JSON.Encode.object),
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
  confirmTokenization: _ => Promise.resolve(Dict.make()->JSON.Encode.object),
  paymentMethodsSession: _ => defaultPaymentMethodsSessionGroup,
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
  | CvcStatus
  | FormStatus
  | PaymentMethodInfoCard
  | PaymentMethodStatus
  | BillingAddress
  | Surcharge
  | Offers
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
  | "surchargeInfo" => Surcharge
  | "appliedOffersInfo" => Offers
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

type sdkAuthorizationData = {
  publishableKey: option<string>,
  clientSecret: option<string>,
  customerId: option<string>,
  profileId: option<string>,
  pmSessionId: option<string>,
  paymentId: option<string>,
}
