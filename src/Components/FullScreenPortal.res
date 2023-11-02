open Utils
@val @scope(("window", "parent", "frames", `"fullscreen"`, "document"))
external getElementById: string => Dom.element = "getElementById"

@react.component
let make = (~children) => {
  let (fullScreenIframeNode, setFullScreenIframeNode) = React.useState(() => Js.Nullable.null)

  React.useEffect(() => {
    let handle = (ev: Window.event) => {
      try {
        let json = ev.data->Js.Json.parseExn
        let dict = json->getDictFromJson

        if dict->Js.Dict.get("fullScreenIframeMounted")->Belt.Option.isSome {
          if dict->getBool("fullScreenIframeMounted", false) {
            setFullScreenIframeNode(_ =>
              switch Window.windowParent->Window.fullscreen {
              | Some(doc) => doc->Window.document->Window.getElementById("fullscreen")
              | None => Js.Nullable.null
              }
            )
          }
        }
      } catch {
      | _err => ()
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  switch fullScreenIframeNode->Js.Nullable.toOption {
  | Some(domNode) => ReactDOM.createPortal(children, domNode)
  | None => React.null
  }
}
