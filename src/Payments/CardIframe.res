@react.component
let make = () => {
  open Utils
  open RecoilAtoms

  let config = Recoil.useRecoilValueFromAtom(configAtom)
  let paymentsListValue = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentsListValue)
  let (keys, setKeys) = Recoil.useRecoilState(keys)
  let setVaultPublishableKey = Recoil.useSetRecoilState(RecoilAtomsV2.vaultPublishableKey)
  let setVaultProfileId = Recoil.useSetRecoilState(RecoilAtomsV2.vaultProfileId)
  let ssn = Recoil.useRecoilValueFromAtom(sessions)
  let (innerIframeHeight, setInnerIframeHeight) = React.useState(_ => "0px")

  React.useEffect(() => {
    let handleMessage = (ev: Window.event) => {
      let json = ev.data->Identity.anyTypeToJson
      let dict = json->Utils.getDictFromJson

      switch dict->Dict.get("cardIframeContentHeight") {
      | Some(heightValue) =>
        switch heightValue->JSON.Decode.float {
        | Some(h) =>
          let newHeightPx = `${h->Float.toString}px`
          setInnerIframeHeight(_ => newHeightPx)
        | None => Console.warn("Received cardIframeContentHeight but value is not a float")
        }
      | None => ()
      }
    }
    Window.addEventListener("message", handleMessage)
    Some(() => Window.removeEventListener("message", handleMessage))
  }, [])

  React.useEffect(() => {
    let handle = (ev: Window.event) => {
      let json = ev.data->Identity.anyTypeToJson
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("innerIframeMountedCallback")->Option.isSome {
        let (
          pmSessionId,
          pmClientSecret,
          vaultPublishableKey,
          vaultProfileId,
        ) = VaultHelpers.getHyperswitchVaultDetails(ssn)
        setKeys(prev => {
          ...prev,
          pmClientSecret,
          pmSessionId,
        })
        setVaultPublishableKey(_ => vaultPublishableKey)
        setVaultProfileId(_ => vaultProfileId)
        let supportedCardBrandsValue = paymentsListValue->PaymentUtilsV2.getSupportedCardBrandsV2

        let metaData = [
          ("config", config.config->Identity.anyTypeToJson),
          ("pmSessionId", pmSessionId->JSON.Encode.string),
          ("pmClientSecret", pmClientSecret->JSON.Encode.string),
          ("vaultPublishableKey", vaultPublishableKey->JSON.Encode.string),
          ("vaultProfileId", vaultProfileId->JSON.Encode.string),
          (
            "supportedCardBrands",
            supportedCardBrandsValue
            ->Option.getOr([])
            ->Array.map(JSON.Encode.string)
            ->JSON.Encode.array,
          ),
          ("paymentList", paymentsListValue->Identity.anyTypeToJson),
        ]->getJsonFromArrayOfJson
        let innerIframe = Window.querySelector(`#orca-inneriframe`)
        Console.log2("innerIframeMountedCallback==>", metaData)
        innerIframe->Window.iframePostMessage(
          [("metadata", metaData), ("innerIframeMounted", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  }, [])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      let innerIframe = Window.querySelector(`#orca-inneriframe`)
      innerIframe->Window.iframePostMessage(
        [("tokenizeCard", true->JSON.Encode.bool)]->Dict.fromArray,
      )
      let handle = (ev: Window.event) => {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        if dict->Dict.get("tokenReceived")->Option.isSome {
          Console.log2("Tokenized data==>", ev.data)
          // TODO - Do Intent/Confirm call V2 on getting token
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
      height: innerIframeHeight,
      position: "relative",
    }>
    <iframe
      id="orca-inneriframe"
      src={`${ApiEndpoint.sdkDomainUrl}/fullscreenIndex.html?fullscreenType=cardIframe`}
      style={
        width: "100%",
        height: "100%",
        border: "none",
        position: "absolute",
        top: "0",
        left: "0",
      }
      className="mb-[4px] mr-4px ml-4px"
    />
  </div>
}
