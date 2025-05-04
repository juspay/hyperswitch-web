@react.component
let make = () => {
  open Utils
  open RecoilAtoms

  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let config = Recoil.useRecoilValueFromAtom(configAtom)

  React.useEffect(() => {
    let iframeURL = `${ApiEndpoint.sdkDomainUrl}/fullscreenIndex.html?fullscreenType=secureCardIframe`
    let mainEle = Window.querySelector(`#iframe-for-card`)
    switch mainEle->Nullable.toOption {
    | Some(ele) => {
        Console.log("Mounting iframe instead of card")
        ele->makeIframe4(iframeURL)->ignore
      }
    | None => ()
    }

    let handle = (ev: Window.event) => {
      // Console.log2("Event==>", ev)
      let json = ev.data->Identity.anyTypeToJson
      // Console.log2("JSON==>", json)
      let dict = json->Utils.getDictFromJson

      // Console.log2("Dicttt==>", dict)
      if dict->Dict.get("innerIframeMountedCallback")->Option.isSome {
        let metaData = [("config", config.config->Identity.anyTypeToJson)]->getJsonFromArrayOfJson
        let innerIframe = Window.querySelector(`#orca-inneriframe`)
        Console.log2("innerIframeMountedCallback==>", metaData)
        innerIframe->Window.iframePostMessage(
          [("metadata", metaData), ("innerIframeMounted", true->JSON.Encode.bool)]->Dict.fromArray,
        )
        // messageParentWindow([
        //   ("fullscreen", true->JSON.Encode.bool),
        //   ("iframeId", iframeId->JSON.Encode.string),
        //   ("metadata", metaData),
        // ])
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
    // None
  }, [])

  let submitCallback = React.useCallback((ev: Window.event) => {
    // ev->ReactEvent.Keyboard.preventDefault
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      //sendPostMessageForDoingTokenizeCall
      let innerIframe = Window.querySelector(`#orca-inneriframe`)
      innerIframe->Window.iframePostMessage(
        [("tokenizeCard", true->JSON.Encode.bool)]->Dict.fromArray,
      )
      //Add Event Listener for response Token
      let handle = (ev: Window.event) => {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        if dict->Dict.get("tokenReceived")->Option.isSome {
          Console.log2("Tokenize data==>", ev.data)
          //Do Intent/Confirm call on getting token
        }
      }
      Window.addEventListener("message", handle)
    }
  }, ())
  useSubmitPaymentData(submitCallback)

  <div
    id="iframe-for-card"
    style={
      width: "100%",
      height: "130px",
      position: "relative",
      overflow: "hidden",
    }
  />
}
