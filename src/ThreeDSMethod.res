open Utils
@react.component
let make = () => {
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  let mountToInnerHTML = innerHTML => {
    let ele = Window.querySelector("#threeDsInvisibleIframe")
    switch ele->Nullable.toOption {
    | Some(elem) => elem->Window.innerHTML(innerHTML)
    | None =>
      Console.warn(
        "INTEGRATION ERROR: Div does not seem to exist on which threeDSMethod is to be mounted",
      )
    }
  }

  React.useEffect0(() => {
    handlePostMessage([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
        let threeDsDataDict =
          metaDataDict
          ->Dict.get("threeDSData")
          ->Belt.Option.flatMap(JSON.Decode.object)
          ->Option.getOr(Dict.make())
        let threeDsUrl =
          threeDsDataDict
          ->Dict.get("three_ds_method_details")
          ->Belt.Option.flatMap(JSON.Decode.object)
          ->Belt.Option.flatMap(x => x->Dict.get("three_ds_method_url"))
          ->Belt.Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")
        let threeDsMethodData =
          threeDsDataDict
          ->Dict.get("three_ds_method_details")
          ->Belt.Option.flatMap(JSON.Decode.object)
          ->Belt.Option.flatMap(x => x->Dict.get("three_ds_method_data"))
          ->Option.getOr(Dict.make()->JSON.Encode.object)
        let iframeId = metaDataDict->getString("iframeId", "")

        open Promise
        PaymentHelpers.threeDsMethod(threeDsUrl, threeDsMethodData, ~optLogger=Some(logger))
        ->then(res => {
          mountToInnerHTML(res)
          resolve(res)
        })
        ->then(res => {
          metadata->Utils.getDictFromJson->Dict.set("3dsMethodComp", "Y"->JSON.Encode.string)
          handlePostMessage([
            ("fullscreen", true->JSON.Encode.bool),
            ("param", `3dsAuth`->JSON.Encode.string),
            ("iframeId", iframeId->JSON.Encode.string),
            ("metadata", metadata),
          ])
          resolve(res)
        })
        ->catch(e => {
          metadata->Utils.getDictFromJson->Dict.set("3dsMethodComp", "N"->JSON.Encode.string)
          handlePostMessage([
            ("fullscreen", true->JSON.Encode.bool),
            ("param", `3dsAuth`->JSON.Encode.string),
            ("iframeId", iframeId->JSON.Encode.string),
            ("metadata", metadata),
          ])
          reject(e)
        })
        ->ignore

        let headersDict =
          metaDataDict
          ->getJsonObjectFromDict("headers")
          ->JSON.Decode.object
          ->Option.getOr(Dict.make())
        let headers = Dict.make()

        headersDict
        ->Dict.toArray
        ->Array.forEach(entries => {
          let (x, val) = entries
          Dict.set(headers, x, val->JSON.Decode.string->Option.getOr(""))
        })
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  <div id="threeDsInvisibleIframe" className="bg-black-100 h-96" />
}
