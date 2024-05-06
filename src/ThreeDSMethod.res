open Utils
@react.component
let make = () => {
  let logger = OrcaLogger.make(~source=Elements(Payment), ())

  let (stateMetadata, setStateMetadata) = React.useState(_ => Dict.make()->JSON.Encode.object)

  let handleLoaded = _ev => {
    stateMetadata->Utils.getDictFromJson->Dict.set("3dsMethodComp", "Y"->JSON.Encode.string)
    let metadataDict = stateMetadata->JSON.Decode.object->Option.getOr(Dict.make())
    let iframeId = metadataDict->getString("iframeId", "")
    LoggerUtils.handleLogging(
      ~optLogger=Some(logger),
      ~eventName=THREE_DS_METHOD_RESULT,
      ~value="Y",
      ~paymentMethod="CARD",
      (),
    )
    handlePostMessage([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", `3dsAuth`->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
      ("metadata", stateMetadata),
    ])
  }

  React.useEffect0(() => {
    handlePostMessage([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        setStateMetadata(_ => metadata)
        let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
        let threeDsDataDict =
          metaDataDict
          ->Dict.get("threeDSData")
          ->Option.flatMap(JSON.Decode.object)
          ->Option.getOr(Dict.make())
        let threeDsUrl =
          threeDsDataDict
          ->Dict.get("three_ds_method_details")
          ->Option.flatMap(JSON.Decode.object)
          ->Option.flatMap(x => x->Dict.get("three_ds_method_url"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")
        let threeDsMethodData =
          threeDsDataDict
          ->Dict.get("three_ds_method_details")
          ->Option.flatMap(JSON.Decode.object)
          ->Option.flatMap(x => x->Dict.get("three_ds_method_data"))
          ->Option.getOr(Dict.make()->JSON.Encode.object)
        let paymentIntentId = metaDataDict->Utils.getString("paymentIntentId", "")
        let publishableKey = metaDataDict->Utils.getString("publishableKey", "")

        logger.setClientSecret(paymentIntentId)
        logger.setMerchantId(publishableKey)

        let iframeId = metaDataDict->getString("iframeId", "")

        let handleFailureScenarios = value => {
          LoggerUtils.handleLogging(
            ~optLogger=Some(logger),
            ~eventName=THREE_DS_METHOD_RESULT,
            ~value,
            ~paymentMethod="CARD",
            ~logType=ERROR,
            (),
          )
          metadata->Utils.getDictFromJson->Dict.set("3dsMethodComp", "N"->JSON.Encode.string)
          handlePostMessage([
            ("fullscreen", true->JSON.Encode.bool),
            ("param", `3dsAuth`->JSON.Encode.string),
            ("iframeId", iframeId->JSON.Encode.string),
            ("metadata", stateMetadata),
          ])
        }

        let ele = Window.querySelector("#threeDsInvisibleDiv")

        switch ele->Nullable.toOption {
        | Some(elem) => {
            let form = elem->makeForm(threeDsUrl, "threeDsHiddenPostMethod")
            let input = Types.createElement("input")
            input.name = encodeURIComponent("threeDSMethodData")
            let threeDsMethodStr = threeDsMethodData->JSON.Decode.string->Option.getOr("")
            input.value = encodeURIComponent(threeDsMethodStr)
            form.target = "threeDsInvisibleIframe"
            form.appendChild(input)
            try {
              form.submit()
            } catch {
            | err => {
                let exceptionMessage = err->Utils.formatException->JSON.stringify
                handleFailureScenarios(exceptionMessage)
              }
            }
          }
        | None => handleFailureScenarios("Unable to Locate threeDsInvisibleDiv")
        }
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  <>
    <div id="threeDsInvisibleDiv" className="hidden" />
    <iframe
      id="threeDsInvisibleIframe"
      name="threeDsInvisibleIframe"
      className="h-96 invisible"
      onLoad=handleLoaded
    />
  </>
}
