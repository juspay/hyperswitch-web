@react.component
let make = () => {
  open Utils
  open RecoilAtoms
  open RecoilAtomsV2

  let config = Recoil.useRecoilValueFromAtom(configAtom)
  let setKeys = Recoil.useSetRecoilState(keys)
  let session = Recoil.useRecoilValueFromAtom(sessions)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)

  let paymentsListValue = Recoil.useRecoilValueFromAtom(paymentsListValue)
  let setVaultPublishableKey = Recoil.useSetRecoilState(vaultPublishableKey)
  let setVaultProfileId = Recoil.useSetRecoilState(vaultProfileId)

  let (innerIframeHeight, setInnerIframeHeight) = React.useState(_ => "0px")

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)

  React.useEffect(() => {
    let handleMessage = (ev: Window.event) => {
      let json = ev.data->Identity.anyTypeToJson
      let dict = json->getDictFromJson

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
      let dict = json->getDictFromJson
      if dict->Dict.get("innerIframeMountedCallback")->Option.isSome {
        let {
          pmSessionId,
          pmClientSecret,
          vaultPublishableKey,
          vaultProfileId,
        } = VaultHelpers.getHyperswitchVaultDetails(session)

        setKeys(prev => {
          ...prev,
          pmClientSecret,
          pmSessionId,
        })
        setVaultPublishableKey(_ => vaultPublishableKey)
        setVaultProfileId(_ => vaultProfileId)

        let metaData =
          [
            ("config", config.config->Identity.anyTypeToJson),
            ("pmSessionId", pmSessionId->JSON.Encode.string),
            ("pmClientSecret", pmClientSecret->JSON.Encode.string),
            ("vaultPublishableKey", vaultPublishableKey->JSON.Encode.string),
            ("vaultProfileId", vaultProfileId->JSON.Encode.string),
            ("paymentList", paymentsListValue->Identity.anyTypeToJson),
            ("endpoint", ApiEndpoint.getApiEndPoint()->JSON.Encode.string),
            ("customPodUri", customPodUri->JSON.Encode.string),
          ]->getJsonFromArrayOfJson
        let innerIframe = Window.querySelector(`#orca-inneriframe`)
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
        [("generateToken", true->JSON.Encode.bool)]->Dict.fromArray,
      )
      let handle = (ev: Window.event) => {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        if dict->Dict.get("paymentToken")->Option.isSome {
          let json = ev.data->safeParse
          let dict = json->getDictFromJson
          let token = dict->getString("paymentToken", "")
          let cardBody = PaymentManagementBody.hyperswitchVaultBody(token)

          intent(
            ~bodyArr=cardBody,
            ~confirmParam=confirm.confirmParams,
            ~handleUserError=false,
            ~manualRetry=isManualRetryEnabled,
          )
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
      src={`${ApiEndpoint.sdkDomainUrl}/fullscreenIndex.html?fullscreenType=cardVault`}
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
