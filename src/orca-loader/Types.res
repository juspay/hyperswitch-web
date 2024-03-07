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
@send external onload: (Dom.element, unit => Js.Promise.t<'a>) => Js.Promise.t<'a> = "onload"
module This = {
  type t
  @get
  external iframeElem: t => option<Js.nullable<Dom.element>> = "iframeElem"
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
  fetchUpdates: unit => Js.Promise.t<JSON.t>,
  create: (string, JSON.t) => paymentElement,
}

type confirmParams = {return_url: string}

type confirmPaymentParams = {
  elements: JSON.t,
  confirmParams: Js.Nullable.t<confirmParams>,
}

type hyperInstance = {
  confirmOneClickPayment: (JSON.t, bool) => Js.Promise.t<JSON.t>,
  confirmPayment: JSON.t => Js.Promise.t<JSON.t>,
  elements: JSON.t => element,
  confirmCardPayment: Js_OO.Callback.arity4<
    (This.t, string, option<JSON.t>, option<JSON.t>) => Js.Promise.t<JSON.t>,
  >,
  retrievePaymentIntent: string => Js.Promise.t<JSON.t>,
  widgets: JSON.t => element,
  paymentRequest: JSON.t => JSON.t,
}

let oneClickConfirmPaymentFn = (_, _) => {
  Js.Promise.resolve(Dict.make()->JSON.Encode.object)
}

let confirmPaymentFn = (_elements: JSON.t) => {
  Js.Promise.resolve(Dict.make()->JSON.Encode.object)
}
let confirmCardPaymentFn =
  @this
  (_this: This.t, _clientSecretId: string, _data: option<JSON.t>, _options: option<JSON.t>) => {
    Js.Promise.resolve(Dict.make()->JSON.Encode.object)
  }

let retrievePaymentIntentFn = _paymentIntentId => {
  Js.Promise.resolve(Dict.make()->JSON.Encode.object)
}
let update = _options => {
  ()
}

let getElement = _componentName => {
  None
}

let fetchUpdates = () => {
  Js.Promise.make((~resolve, ~reject as _) => {
    setTimeout(() => resolve(. Dict.make()->JSON.Encode.object), 1000)->ignore
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

let defaultHyperInstance = {
  confirmOneClickPayment: oneClickConfirmPaymentFn,
  confirmPayment: confirmPaymentFn,
  confirmCardPayment: confirmCardPaymentFn,
  retrievePaymentIntent: retrievePaymentIntentFn,
  elements: _ev => defaultElement,
  widgets: _ev => defaultElement,
  paymentRequest: _ev => JSON.Encode.null,
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
type ele = {
  mutable id: string,
  mutable src: string,
  mutable name: string,
  mutable style: string,
  mutable onload: unit => unit,
}
@scope("document") @val external createElement: string => ele = "createElement"

@send external appendChild: (Dom.element, ele) => unit = "appendChild"
