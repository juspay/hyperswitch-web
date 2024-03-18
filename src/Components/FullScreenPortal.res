open Utils
@val @scope(("window", "parent", "frames", `"fullscreen"`, "document"))
external getElementById: string => Dom.element = "getElementById"

@react.component
let make = (~children) => {
  let (fullScreenIframeNode, setFullScreenIframeNode) = React.useState(() => Nullable.null)

  React.useEffectOnEveryRender(() => {
    let handle = (ev: Window.event) => {
      try {
        let json = ev.data->JSON.parseExn
        let dict = json->getDictFromJson

        if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
          if dict->getBool("fullScreenIframeMounted", false) {
            setFullScreenIframeNode(_ =>
              switch Window.windowParent->Window.fullscreen {
              | Some(doc) => doc->Window.document->Window.getElementById("fullscreen")
              | None => Nullable.null
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

  switch fullScreenIframeNode->Nullable.toOption {
  | Some(domNode) => ReactDOM.createPortal(children, domNode)
  | None => React.null
  }
}
