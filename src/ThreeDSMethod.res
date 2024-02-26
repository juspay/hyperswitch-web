open Utils
let getKeyValue = (json, str) => {
  json
  ->Js.Dict.get(str)
  ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
  ->Js.Json.decodeString
  ->Belt.Option.getWithDefault("")
}

@react.component
let make = () => {
  let (qrCode, setQrCode) = React.useState(_ => "")
  let (expiryTime, setExpiryTime) = React.useState(_ => 900000.0)
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (return_url, setReturnUrl) = React.useState(_ => "")
  let (clientSecret, setClientSecret) = React.useState(_ => "")
  let (headers, setHeaders) = React.useState(_ => [])
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let switchToCustomPod = Recoil.useRecoilValueFromAtom(RecoilAtoms.switchToCustomPod)

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
      Js.log2("DICT", dict)
      if dict->Js.Dict.get("fullScreenIframeMounted")->Belt.Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        let metaDataDict =
          metadata->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
        Js.log2("METADATA DICT", metaDataDict)
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
        Js.log3("THREEDSURL", threeDsUrl, threeDsMethodData)
        let iframeId = metaDataDict->getString("iframeId", "")

        open Promise
        PaymentHelpers.threeDsMethod(threeDsUrl, threeDsMethodData, ~optLogger=Some(logger))
        ->then(res => {
          Js.log2("PREMOUNT RES", res)
          mountToInnerHTML(res)
          resolve(res)
        })
        ->then(res => {
          handlePostMessage([
            ("fullscreen", true->Js.Json.boolean),
            ("param", `3dsAuth`->Js.Json.string),
            ("iframeId", iframeId->Js.Json.string),
            ("metadata", metadata),
          ])
          resolve(res)
        })
        ->catch(e => {
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
