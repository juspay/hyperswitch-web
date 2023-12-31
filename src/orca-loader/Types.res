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
}
type event = {key: string, data: eventData}
type eventParam = Event(event) | EventData(eventData) | Empty
type eventHandler = option<Js.Json.t> => unit
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
  update: Js.Json.t => unit,
  destroy: unit => unit,
  unmount: unit => unit,
  mount: string => unit,
  focus: unit => unit,
  clear: unit => unit,
}

type element = {
  getElement: Js.Dict.key => option<paymentElement>,
  update: Js.Json.t => unit,
  fetchUpdates: unit => Js.Promise.t<Js.Json.t>,
  create: (Js.Dict.key, Js.Json.t) => paymentElement,
}

type confirmParams = {return_url: string}

type confirmPaymentParams = {
  elements: Js.Json.t,
  confirmParams: Js.Nullable.t<confirmParams>,
}

type hyperInstance = {
  confirmPayment: Js.Json.t => Js.Promise.t<Js.Json.t>,
  elements: Js.Json.t => element,
  confirmCardPayment: Js_OO.Callback.arity4<
    (This.t, string, option<Js.Json.t>, option<Js.Json.t>) => Js.Promise.t<Js.Json.t>,
  >,
  retrievePaymentIntent: string => Js.Promise.t<Js.Json.t>,
  widgets: Js.Json.t => element,
  paymentRequest: Js.Json.t => Js.Json.t,
}

let confirmPaymentFn = (_elements: Js.Json.t) => {
  Js.Promise.resolve(Js.Dict.empty()->Js.Json.object_)
}
let confirmCardPaymentFn =
  @this
  (
    _this: This.t,
    _clientSecretId: string,
    _data: option<Js.Json.t>,
    _options: option<Js.Json.t>,
  ) => {
    Js.Promise.resolve(Js.Dict.empty()->Js.Json.object_)
  }

let retrievePaymentIntentFn = _paymentIntentId => {
  Js.Promise.resolve(Js.Dict.empty()->Js.Json.object_)
}
let update = _options => {
  ()
}

let getElement = _componentName => {
  None
}

let fetchUpdates = () => {
  Js.Promise.make((~resolve, ~reject as _) => {
    Js.Global.setTimeout(() => resolve(. Js.Dict.empty()->Js.Json.object_), 1000)->ignore
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
  getElement: getElement,
  update: update,
  fetchUpdates: fetchUpdates,
  create: create,
}

let defaultHyperInstance = {
  confirmPayment: confirmPaymentFn,
  confirmCardPayment: confirmCardPaymentFn,
  retrievePaymentIntent: retrievePaymentIntentFn,
  elements: _ev => defaultElement,
  widgets: _ev => defaultElement,
  paymentRequest: _ev => Js.Json.null,
}

type eventType = Escape | Change | Click | Ready | Focus | Blur | ConfirmPayment | None

let eventTypeMapper = event => {
  switch event {
  | "escape" => Escape
  | "change" => Change
  | "clickTriggered" => Click
  | "ready" => Ready
  | "focus" => Focus
  | "blur" => Blur
  | "confirmTriggered" => ConfirmPayment
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
