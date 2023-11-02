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
@val @scope(("window", "location"))
external replace: string => unit = "replace"
@val @scope(("window", "parent", "location")) external href: string = "href"

@val @scope("document") external createElement: string => Dom.element = "createElement"
@set external windowOnload: (window, unit => unit) => unit = "onload"

@get external fullscreen: window => option<window> = "fullscreen"

@get external document: window => document = "document"
@get external parentNode: Dom.element => Dom.element = "parentNode"
@val @scope("document")
external querySelector: string => Js.Nullable.t<Dom.element> = "querySelector"
@val @scope("document")
external querySelectorAll: string => array<Dom.element> = "querySelectorAll"

type eventData = {
  elementType: string,
  clickTriggered: bool,
  ready: bool,
  focus: bool,
  blur: bool,
  confirmTriggered: bool,
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
external getElementById: (document, string) => Js.Nullable.t<Dom.element> = "getElementById"
@get
external frames: window => {..} = "frames"
@get external name: window => string = "name"
@get
external contentWindow: Dom.element => Dom.element = "contentWindow"
@get
external style: Dom.element => style = "style"
@set external setTransition: (style, string) => unit = "transition"
@set external setHeight: (style, string) => unit = "height"
@send external paymentRequest: (Js.Json.t, Js.Json.t, Js.Json.t) => Js.Json.t = "PaymentRequest"

let iframePostMessage = (iframeRef: Js.nullable<Dom.element>, message) => {
  switch iframeRef->Js.Nullable.toOption {
  | Some(ref) =>
    try {
      ref
      ->contentWindow
      ->postMessage(message->Js.Json.object_->Js.Json.stringify, GlobalVars.targetOrigin)
    } catch {
    | _ => ()
    }
  | None => Js.Console.error("This element does not exist or is not mounted yet.")
  }
}

@send external preventDefault: (event, unit) => unit = "preventDefault"

type date = {now: (. unit) => string}
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
external getHyper: Js.Nullable.t<Types.hyperInstance> = "HyperMethod"
@set
external setHyper: (window, Types.hyperInstance) => unit = "HyperMethod"

type packageJson = {version: string}
@module("/package.json") @val external packageJson: packageJson = "default"
let version = packageJson.version
@val @scope("navigator")
external browserName: string = "appName"

@val @scope("navigator")
external browserVersion: string = "appVersion"

@val @scope("navigator")
external platform: string = "platform"

@val @scope("navigator")
external userAgent: string = "userAgent"

@val @scope("navigator")
external sendBeacon: (string, string) => unit = "sendBeacon"

@val @scope(("window", "location")) external hostname: string = "hostname"

let isSandbox = hostname === "beta.hyperswitch.io"

let isInteg = hostname === "dev.hyperswitch.io"

let isProd = hostname === "checkout.hyperswitch.io"
