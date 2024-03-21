open Utils
@react.component
let make = () => {
  let (expiryTime, setExpiryTime) = React.useState(_ => 900000.0)
  let (openModal, setOpenModal) = React.useState(_ => false)
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  let mountToInnerHTML = innerHTML => {
    let ele = Window.querySelector("#threeDsInvisibleIframe")
    switch ele->Js.Nullable.toOption {
    | Some(elem) => elem->Window.innerHTML(innerHTML)
    | None =>
      Js.Console.warn(
        "INTEGRATION ERROR: Div does not seem to exist on which threeDSMethod is to be mounted",
      )
    }
  }

  React.useEffect0(() => {
    handlePostMessage([("iframeMountedCallback", true->Js.Json.boolean)])
    let handle = (ev: Window.event) => {
      let json = ev.data->Js.Json.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->Js.Dict.get("fullScreenIframeMounted")->Belt.Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        let metaDataDict =
          metadata->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
        let threeDsDataDict =
          metaDataDict
          ->Js.Dict.get("threeDSData")
          ->Belt.Option.flatMap(Js.Json.decodeObject)
          ->Belt.Option.getWithDefault(Js.Dict.empty())
        let threeDsUrl =
          threeDsDataDict
          ->Js.Dict.get("three_ds_method_details")
          ->Belt.Option.flatMap(Js.Json.decodeObject)
          ->Belt.Option.flatMap(x => x->Js.Dict.get("three_ds_method_url"))
          ->Belt.Option.flatMap(Js.Json.decodeString)
          ->Belt.Option.getWithDefault("")
        let threeDsMethodData =
          threeDsDataDict
          ->Js.Dict.get("three_ds_method_details")
          ->Belt.Option.flatMap(Js.Json.decodeObject)
          ->Belt.Option.flatMap(x => x->Js.Dict.get("three_ds_method_data"))
          ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
        let iframeId = metaDataDict->getString("iframeId", "")

        open Promise
        PaymentHelpers.threeDsMethod(threeDsUrl, threeDsMethodData, ~optLogger=Some(logger))
        ->then(res => {
          mountToInnerHTML(res)
          resolve(res)
        })
        ->then(res => {
          metadata->Utils.getDictFromJson->Js.Dict.set("3dsMethodComp", "Y"->Js.Json.string)
          handlePostMessage([
            ("fullscreen", true->Js.Json.boolean),
            ("param", `3dsAuth`->Js.Json.string),
            ("iframeId", iframeId->Js.Json.string),
            ("metadata", metadata),
          ])
          resolve(res)
        })
        ->catch(e => {
          metadata->Utils.getDictFromJson->Js.Dict.set("3dsMethodComp", "N"->Js.Json.string)
          handlePostMessage([
            ("fullscreen", true->Js.Json.boolean),
            ("param", `3dsAuth`->Js.Json.string),
            ("iframeId", iframeId->Js.Json.string),
            ("metadata", metadata),
          ])
          Js.log("3DS validation failed")
          reject(e)
        })
        ->ignore

        let headersDict =
          metaDataDict
          ->getJsonObjectFromDict("headers")
          ->Js.Json.decodeObject
          ->Belt.Option.getWithDefault(Js.Dict.empty())
        let headers = Js.Dict.empty()

        headersDict
        ->Js.Dict.entries
        ->Js.Array2.forEach(entries => {
          let (x, val) = entries
          Js.Dict.set(headers, x, val->Js.Json.decodeString->Belt.Option.getWithDefault(""))
        })
        let _timeExpiry = metaDataDict->getString("expiryTime", "")
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })
  React.useEffect1(() => {
    if expiryTime < 1000.0 {
      Modal.close(setOpenModal)
    }
    let intervalID = Js.Global.setInterval(() => {
      setExpiryTime(prev => prev -. 1000.0)
    }, 1000)
    Some(
      () => {
        Js.Global.clearInterval(intervalID)
      },
    )
  }, [expiryTime])

  <div id="threeDsInvisibleIframe" className="bg-black-100 h-96" />
}
