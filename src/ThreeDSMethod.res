open Utils
@react.component
let make = () => {
  let logger = OrcaLogger.make()

  let (stateMetadata, setStateMetadata) = React.useState(_ => Dict.make()->JSON.Encode.object)

  let handleLoaded = _ev => {
    stateMetadata->Utils.getDictFromJson->Dict.set("3dsMethodComp", "Y"->JSON.Encode.string)
    let metadataDict = stateMetadata->JSON.Decode.object->Option.getOr(Dict.make())
    let iframeId = metadataDict->getString("iframeId", "")
    LoggerUtils.handleLogging(
      ~optLogger=Some(logger),
      ~eventName=THREE_DS_METHOD_RESULT,
      ~value="Successful Form Submission",
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
        let paymentIntentId = metaDataDict->Utils.getString("paymentIntentId", "")
        let publishableKey = metaDataDict->Utils.getString("publishableKey", "")

        logger.setClientSecret(paymentIntentId)
        logger.setMerchantId(publishableKey)

        let iframeId = metaDataDict->getString("iframeId", "")

        let handleFailureScenarios = (eventName, value, internalMetadata, logType) => {
          LoggerUtils.handleLogging(
            ~optLogger=Some(logger),
            ~eventName,
            ~value,
            ~internalMetadata,
            ~paymentMethod="CARD",
            ~logType,
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

            LoggerUtils.handleLogging(
              ~optLogger=Some(logger),
              ~eventName=THREE_DS_METHOD,
              ~value="Submitting Form",
              ~paymentMethod="CARD",
              (),
            )

            try {
              form.submit()
            } catch {
            | err => {
                let exceptionMessage = err->Utils.formatException->JSON.stringify
                handleFailureScenarios(
                  THREE_DS_METHOD_RESULT,
                  "Form Submission Failed",
                  exceptionMessage,
                  ERROR,
                )
              }
            }
          }
        | None =>
          handleFailureScenarios(THREE_DS_METHOD, "Unable to Locate threeDsInvisibleDiv", "", INFO)
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
