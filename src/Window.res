open Types
type parent
type document
type style
type eventData = {
  elementType: string,
  clickTriggered: bool,
  ready: bool,
  focus: bool,
  blur: bool,
  confirmTriggered: bool,
  oneClickConfirmTriggered: bool,
}
type loaderEvent = {key: string, data: eventData}
type event = {key: string, data: string, origin: string}
type date = {now: unit => string}
type body
type packageJson = {version: string}
type callback = Nullable.t<JSON.t> => unit
type options = {signal: unit}

type element = {
  mutable getAttribute: string => string,
  mutable src: string,
  mutable async: bool,
  mutable rel: string,
  mutable href: string,
  mutable \"as": string,
  mutable crossorigin: string,
  mutable \"type": string,
  mutable id: string,
  mutable width: string,
  mutable height: string,
  remove: unit => unit,
  contentWindow: option<window>,
  setAttribute: (string, string) => unit,
  addEventListener?: (string, callback, option<options>) => unit,
}

type elementRef
@val external myDocument: elementRef = "document"

/* External Declarations */
@val external window: window = "window"
@val @scope("window") external innerHeight: int = "innerHeight"
@val @scope("window") external innerWidth: int = "innerWidth"
@val @scope("window") external windowParent: window = "parent"
@val external parent: window = "parent"
@val @scope("document") external createElement: string => Dom.element = "createElement"
@val @scope("document") external querySelector: string => Nullable.t<Dom.element> = "querySelector"
@val @scope("document") external querySelectorAll: string => array<Dom.element> = "querySelectorAll"
@module("/package.json") @val external packageJson: packageJson = "default"
@val @scope("document") external body: body = "body"
@val @scope("window") external getHyper: Nullable.t<Types.hyperInstance> = "HyperMethod"
@val @scope("window") external addEventListener: (string, _ => unit) => unit = "addEventListener"
@send
external elementQuerySelector: (elementRef, string) => Nullable.t<element> = "querySelector"

@val @scope("window")
external removeEventListener: (string, 'ev => unit) => unit = "removeEventListener"
@val @scope("window") external btoa: string => string = "btoa"
@val @scope("window") external atob: string => string = "atob"
@new external date: date = "Date"
@get external value: Dom.element => 'a = "value"

/* External Methods */
@scope("window") @get external cardNumberElement: window => option<window> = "cardNumber"
@get external cardCVCElement: window => option<window> = "cardCvc"
@get external cardExpiryElement: window => option<window> = "cardExpiry"
@get external document: window => document = "document"
@get external fullscreen: window => option<window> = "fullscreen"
@get external frames: window => {..} = "frames"
@get external name: window => string = "name"
@get external contentWindow: Dom.element => Dom.element = "contentWindow"
@get external style: Dom.element => style = "style"
@get external readyState: document => string = "readyState"
@send external getAttribute: (Dom.element, string) => Nullable.t<string> = "getAttribute"
@send external postMessage: (Dom.element, string, string) => unit = "postMessage"
@send external postMessageJSON: (Dom.element, JSON.t, string) => unit = "postMessage"
@send external getElementById: (document, string) => Nullable.t<Dom.element> = "getElementById"
@send external preventDefault: (event, unit) => unit = "preventDefault"
@send external appendChild: (body, Dom.element) => unit = "appendChild"
@send external remove: Dom.element => unit = "remove"
@send external setAttribute: (Dom.element, string, string) => unit = "setAttribute"
@send external paymentRequest: (JSON.t, JSON.t, JSON.t) => JSON.t = "PaymentRequest"
@send external click: Dom.element => unit = "click"
@set external innerHTML: (Dom.element, string) => unit = "innerHTML"
@set external className: (Dom.element, string) => unit = "className"
@set external id: (Dom.element, string) => unit = "id"
@set external elementSrc: (Dom.element, string) => unit = "src"
@set external elementOnload: (Dom.element, unit => unit) => unit = "onload"
@set external elementOnerror: (Dom.element, exn => unit) => unit = "onerror"
@set external setTransition: (style, string) => unit = "transition"
@set external setHeight: (style, string) => unit = "height"
@set external windowOnload: (window, unit => unit) => unit = "onload"
@set external setHyper: (window, Types.hyperInstance) => unit = "HyperMethod"

@send external closeWindow: window => unit = "close"
@val external windowOpen: (string, string, string) => Nullable.t<window> = "open"
@val external isSecureContext: bool = "isSecureContext"

/* Module Definitions */
module Navigator = {
  @val @scope("navigator")
  external browserName: string = "appName"

  @val @scope("navigator")
  external browserVersion: string = "appVersion"

  @val @scope(("window", "navigator"))
  external language: string = "language"

  @val @scope(("window", "navigator"))
  external platform: string = "platform"

  @val @scope(("window", "navigator"))
  external userAgent: string = "userAgent"

  @val @scope("navigator")
  external sendBeacon: (string, string) => unit = "sendBeacon"
}

module Location = {
  @val @scope(("window", "location"))
  external replace: string => unit = "replace"

  @val @scope(("window", "location"))
  external hostname: string = "hostname"

  @val @scope(("window", "location"))
  external href: string = "href"

  @val @scope(("window", "location"))
  external origin: string = "origin"

  @val @scope(("window", "location"))
  external protocol: string = "protocol"

  @val @scope(("window", "location"))
  external pathname: string = "pathname"

  @get @scope("location")
  external documentHref: document => string = "href"
}

module Top = {
  module Location = {
    @val @scope(("window", "top", "location"))
    external replace: string => unit = "replace"

    @val @scope(("window", "top", "location"))
    external hostname: string = "hostname"

    @val @scope(("window", "top", "location"))
    external href: string = "href"

    @val @scope(("window", "top", "location"))
    external origin: string = "origin"

    @val @scope(("window", "top", "location"))
    external protocol: string = "protocol"

    @val @scope(("window", "top", "location"))
    external pathname: string = "pathname"
  }
}

module LocalStorage = {
  @scope(("window", "localStorage")) @val external setItem: (string, string) => unit = "setItem"
  @scope(("window", "localStorage")) @val external getItem: string => Nullable.t<string> = "getItem"
  @scope(("window", "localStorage")) @val external removeItem: string => unit = "removeItem"
}

module Element = {
  @get external clientWidth: Dom.element => int = "clientWidth"
  @get external nullableContentWindow: Dom.element => Nullable.t<Dom.element> = "contentWindow"
  @get external nullableContentDocument: Dom.element => Nullable.t<document> = "contentDocument"
  @get external document: Dom.element => Nullable.t<document> = "document"
}

/* Helper Functions */
let sendPostMessage = (element, message) => {
  element->postMessage(message->JSON.Encode.object->JSON.stringify, GlobalVars.targetOrigin)
}

let sendPostMessageJSON = (element, message) => {
  element->postMessageJSON(message, GlobalVars.targetOrigin)
}

let iframePostMessage = (iframeRef: nullable<Dom.element>, message) => {
  switch iframeRef->Nullable.toOption {
  | Some(ref) =>
    try {
      ref
      ->contentWindow
      ->sendPostMessage(message)
    } catch {
    | _ => ()
    }
  | None => Console.error("This element does not exist or is not mounted yet.")
  }
}

/* Version Handling */
let version = packageJson.version

/* URL Handling */
let hrefWithoutSearch = Location.origin ++ Location.pathname

/* iFrame Detection */
let isIframed = () =>
  try {
    Location.href !== Top.Location.href
  } catch {
  | e => {
      let default = true
      Js.Console.error3(
        "Failed to check whether or not document is within an iframe",
        e,
        `Using "${default->String.make}" as default (due to DOMException)`,
      )
      default
    }
  }

/* Root Hostname Retrieval */
let getRootHostName = () =>
  switch isIframed() {
  | true =>
    try {
      Top.Location.hostname
    } catch {
    | e => {
        let default = Location.hostname
        Js.Console.error3(
          "Failed to get root document's hostname",
          e,
          `Using "${default}" [window.location.hostname] as default`,
        )
        default
      }
    }
  | false => Location.hostname
  }
