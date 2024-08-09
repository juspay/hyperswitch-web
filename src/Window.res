type window
type parent
type document
@val external window: window = "window"
@val @scope("window") external windowInnerHeight: int = "innerHeight"
@val @scope("window") external windowInnerWidth: int = "innerWidth"

@val @scope("window")
external windowParent: window = "parent"
type style

@val external parent: window = "parent"
@get external cardNumberElement: window => option<window> = "cardNumber"
@get external cardCVCElement: window => option<window> = "cardCvc"
@get external cardExpiryElement: window => option<window> = "cardExpiry"
@get external value: Dom.element => 'a = "value"

@val @scope("document") external createElement: string => Dom.element = "createElement"
@set external windowOnload: (window, unit => unit) => unit = "onload"

@get external fullscreen: window => option<window> = "fullscreen"

@get external document: window => document = "document"
@get external parentNode: Dom.element => Dom.element = "parentNode"
@val @scope("document")
external querySelector: string => Nullable.t<Dom.element> = "querySelector"
@val @scope("document")
external querySelectorAll: string => array<Dom.element> = "querySelectorAll"

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
@set external innerHTML: (Dom.element, string) => unit = "innerHTML"
type event = {key: string, data: string, origin: string}
@val @scope("window")
external addEventListener: (string, _ => unit) => unit = "addEventListener"
@val @scope("window")
external removeEventListener: (string, 'ev => unit) => unit = "removeEventListener"
@send external postMessage: (Dom.element, string, string) => unit = "postMessage"
@send
external getElementById: (document, string) => Nullable.t<Dom.element> = "getElementById"
@get
external frames: window => {..} = "frames"
@get external name: window => string = "name"
@get
external contentWindow: Dom.element => Dom.element = "contentWindow"
@get
external style: Dom.element => style = "style"
@set external setTransition: (style, string) => unit = "transition"
@set external setHeight: (style, string) => unit = "height"
@send external paymentRequest: (JSON.t, JSON.t, JSON.t) => JSON.t = "PaymentRequest"
@send external click: Dom.element => unit = "click"

let sendPostMessage = (element, message) => {
  element->postMessage(message->JSON.Encode.object->JSON.stringify, GlobalVars.targetOrigin)
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

@send external preventDefault: (event, unit) => unit = "preventDefault"

type date = {now: unit => string}
@new external date: date = "Date"
@set external className: (Dom.element, string) => unit = "className"
@set external id: (Dom.element, string) => unit = "id"
@send external setAttribute: (Dom.element, string, string) => unit = "setAttribute"
@set external elementSrc: (Dom.element, string) => unit = "src"
type body

@val @scope("document")
external body: body = "body"
@send external appendChild: (body, Dom.element) => unit = "appendChild"
@send external remove: Dom.element => unit = "remove"

@set external elementOnload: (Dom.element, unit => unit) => unit = "onload"
@set external elementOnerror: (Dom.element, exn => unit) => unit = "onerror"
@val @scope("window")
external getHyper: Nullable.t<Types.hyperInstance> = "HyperMethod"
@set
external setHyper: (window, Types.hyperInstance) => unit = "HyperMethod"

type packageJson = {version: string}
@module("/package.json") @val external packageJson: packageJson = "default"
let version = packageJson.version

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
}

module Parent = {
  module Location = {
    @val @scope(("window", "parent", "location"))
    external replace: string => unit = "replace"

    @val @scope(("window", "parent", "location"))
    external hostname: string = "hostname"

    @val @scope(("window", "parent", "location"))
    external href: string = "href"

    @val @scope(("window", "parent", "location"))
    external origin: string = "origin"

    @val @scope(("window", "parent", "location"))
    external protocol: string = "protocol"

    @val @scope(("window", "parent", "location"))
    external pathname: string = "pathname"
  }
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

module Element = {
  @get external clientWidth: Dom.element => int = "clientWidth"
}

@val @scope("window")
external btoa: string => string = "btoa"

let hrefWithoutSearch = Location.origin ++ Location.pathname

let isSandbox = Location.hostname === "beta.hyperswitch.io"

let isInteg = Location.hostname === "dev.hyperswitch.io"

let isProd = Location.hostname === "checkout.hyperswitch.io"

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

let isParentAndTopSame = () =>
  try {
    Parent.Location.href === Top.Location.href
  } catch {
  | e => {
      let default = false
      Js.Console.error3(
        "Failed to check whether or not parent and top were same",
        e,
        `Using "${default->String.make}" as default (due to DOMException)`,
      )
      default
    }
  }

let getRootHostName = () =>
  switch isIframed() {
  | true =>
    try {
      if isParentAndTopSame() {
        Parent.Location.hostname
      } else {
        Top.Location.hostname
      }
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

let replaceRootHref = (href: string) => {
  switch isIframed() {
  | true =>
    try {
      if isParentAndTopSame() {
        Parent.Location.replace(href)
      } else {
        Top.Location.replace(href)
      }
    } catch {
    | e => {
        Js.Console.error3(
          "Failed to redirect root document",
          e,
          `Using [window.location.replace] for redirection`,
        )
        Location.replace(href)
      }
    }
  | false => Location.replace(href)
  }
}
