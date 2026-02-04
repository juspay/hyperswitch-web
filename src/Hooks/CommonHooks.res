open Window
type contentRect = {height: float}

type keys = {
  clientSecret: option<string>,
  sdkAuthorization: option<string>,
  paymentId: string,
  ephemeralKey?: string,
  pmSessionId?: string,
  pmClientSecret?: string,
  publishableKey: string,
  profileId: string,
  iframeId: string,
  parentURL: string,
  sdkHandleOneClickConfirmPayment: bool,
}
@val @scope("document") external querySelector: string => Nullable.t<element> = "querySelector"

type event = {\"type": string}
@val @scope("document") external createElement: string => element = "createElement"

@val @scope(("document", "body")) external appendChild: element => unit = "appendChild"

@send
external addEventListener: (element, string, event => unit) => unit = "addEventListener"

@send
external removeEventListener: (element, string, event => unit) => unit = "removeEventListener"

let useScript = (src: string, ~\"type"="") => {
  let (status, setStatus) = React.useState(_ => src != "" ? "loading" : "idle")
  React.useEffect(() => {
    if src == "" {
      setStatus(_ => "idle")
    }
    let script = querySelector(`script[src="${src}"]`)
    switch script->Nullable.toOption {
    | Some(dom) =>
      setStatus(_ => dom.getAttribute("data-status"))
      None
    | None =>
      let script = createElement("script")
      script.src = src
      if \"type" != "" {
        script.\"type" = \"type"
      }
      script.async = true
      script.setAttribute("data-status", "loading")
      appendChild(script)
      let setAttributeFromEvent = (event: event) => {
        setStatus(_ => event.\"type" === "load" ? "ready" : "error")
        script.setAttribute("data-status", event.\"type" === "load" ? "ready" : "error")
      }
      script->addEventListener("load", setAttributeFromEvent)
      script->addEventListener("error", setAttributeFromEvent)
      Some(
        () => {
          script->removeEventListener("load", setAttributeFromEvent)
          script->removeEventListener("error", setAttributeFromEvent)

          if script.getAttribute("data-status") !== "ready" {
            script.remove()
          }
        },
      )
    }
  }, [src])
  status
}

let useLink = (src: string) => {
  let (status, setStatus) = React.useState(_ => src != "" ? "loading" : "idle")
  React.useEffect(() => {
    if src == "" {
      setStatus(_ => "idle")
    }
    let link = querySelector(`link[href="${src}"]`)
    switch link->Nullable.toOption {
    | Some(dom) =>
      setStatus(_ => dom.getAttribute("data-status"))
      None
    | None =>
      let link = createElement("link")
      link.href = src
      link.rel = "stylesheet"
      link.setAttribute("data-status", "loading")
      appendChild(link)
      let setAttributeFromEvent = (event: event) => {
        setStatus(_ => event.\"type" === "load" ? "ready" : "error")
        link.setAttribute("data-status", event.\"type" === "load" ? "ready" : "error")
      }
      link->addEventListener("load", setAttributeFromEvent)
      link->addEventListener("error", setAttributeFromEvent)
      Some(
        () => {
          link->removeEventListener("load", setAttributeFromEvent)
          link->removeEventListener("error", setAttributeFromEvent)
        },
      )
    }
  }, [src])
  status
}

let updateKeys = (dict, keyPair, setKeys) => {
  let (key, value) = keyPair
  let valueStr = value->Utils.getStringFromJson("")
  let valueBool = default => value->JSON.Decode.bool->Option.getOr(default)
  if dict->Utils.getDictIsSome(key) {
    switch key {
    | "iframeId" =>
      setKeys(prev => {
        ...prev,
        iframeId: dict->Utils.getString(key, valueStr),
      })
    | "publishableKey" =>
      setKeys(prev => {
        ...prev,
        publishableKey: dict->Utils.getString(key, valueStr),
      })
    | "profileId" =>
      setKeys(prev => {
        ...prev,
        profileId: dict->Utils.getString(key, valueStr),
      })
    | "paymentId" =>
      setKeys(prev => {
        ...prev,
        paymentId: dict->Utils.getString(key, valueStr),
      })
    | "parentURL" =>
      setKeys(prev => {
        ...prev,
        parentURL: dict->Utils.getString(key, valueStr),
      })
    | "sdkHandleOneClickConfirmPayment" =>
      setKeys(prev => {
        ...prev,
        sdkHandleOneClickConfirmPayment: dict->Utils.getBool(key, valueBool(true)),
      })
    | _ => ()
    }
  }
}
let defaultkeys = {
  clientSecret: None,
  sdkAuthorization: None,
  publishableKey: "",
  profileId: "",
  paymentId: "",
  iframeId: "",
  parentURL: "*",
  sdkHandleOneClickConfirmPayment: true,
}
