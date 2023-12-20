type element = {
  mutable getAttribute: (. string) => string,
  mutable src: string,
  mutable async: bool,
  mutable rel: string,
  mutable href: string,
  mutable \"as": string,
  mutable crossorigin: string,
  setAttribute: (. string, string) => unit,
}
type keys = {
  clientSecret: option<string>,
  publishableKey: string,
  iframeId: string,
  parentURL: string,
  sdkHandleConfirmPayment: bool,
  sdkHandleOneClickConfirmPayment: bool,
}
@val @scope("document") external querySelector: string => Js.Nullable.t<element> = "querySelector"

type event = {\"type": string}
@val @scope("document") external createElement: string => element = "createElement"

@val @scope(("document", "body")) external appendChild: element => unit = "appendChild"

@send
external addEventListener: (element, string, event => unit) => unit = "addEventListener"

@send
external removeEventListener: (element, string, event => unit) => unit = "removeEventListener"

external dictToObj: Js.Dict.t<'a> => {..} = "%identity"

let useScript = (src: string) => {
  let (status, setStatus) = React.useState(_ => src != "" ? "loading" : "idle")
  React.useEffect1(() => {
    if src == "" {
      setStatus(_ => "idle")
    }
    let script = querySelector(`script[src="${src}"]`)
    switch script->Js.Nullable.toOption {
    | Some(dom) =>
      setStatus(_ => dom.getAttribute(. "data-status"))
      None
    | None =>
      let script = createElement("script")
      script.src = src
      script.async = true
      script.setAttribute(. "data-status", "loading")
      appendChild(script)
      let setAttributeFromEvent = (event: event) => {
        setStatus(_ => event.\"type" === "load" ? "ready" : "error")
        script.setAttribute(. "data-status", event.\"type" === "load" ? "ready" : "error")
      }
      script->addEventListener("load", setAttributeFromEvent)
      script->addEventListener("error", setAttributeFromEvent)
      Some(
        () => {
          script->removeEventListener("load", setAttributeFromEvent)
          script->removeEventListener("error", setAttributeFromEvent)
        },
      )
    }
  }, [src])
  status
}

let updateKeys = (dict, keyPair, setKeys) => {
  let (key, value) = keyPair
  let valueStr = value->Js.Json.decodeString->Belt.Option.getWithDefault("")
  let valueBool = default => value->Js.Json.decodeBoolean->Belt.Option.getWithDefault(default)
  if dict->Utils.getDictIsSome(key) {
    switch key {
    | "iframeId" =>
      setKeys(.prev => {
        ...prev,
        iframeId: dict->Utils.getString(key, valueStr),
      })
    | "publishableKey" =>
      setKeys(.prev => {
        ...prev,
        publishableKey: dict->Utils.getString(key, valueStr),
      })
    | "parentURL" =>
      setKeys(.prev => {
        ...prev,
        parentURL: dict->Utils.getString(key, valueStr),
      })
    | "sdkHandleConfirmPayment" =>
      setKeys(.prev => {
        ...prev,
        sdkHandleConfirmPayment: dict->Utils.getBool(key, valueBool(false)),
      })
    | "sdkHandleOneClickConfirmPayment" =>
      setKeys(.prev => {
        ...prev,
        sdkHandleOneClickConfirmPayment: dict->Utils.getBool(key, valueBool(true)),
      })
    | _ => ()
    }
  }
}
let defaultkeys = {
  clientSecret: None,
  publishableKey: "",
  iframeId: "",
  parentURL: "*",
  sdkHandleConfirmPayment: false,
  sdkHandleOneClickConfirmPayment: true,
}
