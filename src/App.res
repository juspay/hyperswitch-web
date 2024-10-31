@react.component
let make = () => {
  let url = RescriptReactRouter.useUrl()
  let (integrateError, setIntegrateErrorError) = React.useState(() => false)
  let setLoggerState = Recoil.useSetRecoilState(RecoilAtoms.loggerAtom)

  let paymentMode = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let paymentType = paymentMode->CardThemeType.getPaymentMode
  let (logger, initTimestamp) = React.useMemo0(() => {
    (OrcaLogger.make(~source=Elements(paymentType)), Date.now())
  })
  let fullscreenMode = CardUtils.getQueryParamsDictforKey(url.search, "fullscreenType")

  React.useEffect(() => {
    setLoggerState(_ => logger)
    None
  }, [logger])

  React.useEffect0(() => {
    let handleMetaDataPostMessage = (ev: Window.event) => {
      let json = ev.data->Utils.safeParse
      let dict = json->Utils.getDictFromJson

      if dict->Dict.get("metadata")->Option.isSome {
        let metadata = dict->Utils.getJsonObjectFromDict("metadata")
        let config = metadata->Utils.getDictFromJson->Dict.get("config")

        switch config {
        | Some(config) => {
            let config = CardTheme.itemToObjMapper(
              config->Utils.getDictFromJson,
              DefaultTheme.default,
              DefaultTheme.defaultRules,
              logger,
            )

            CardUtils.generateFontsLink(config.fonts)
            let dict = config.appearance.rules->Utils.getDictFromJson
            if dict->Dict.toArray->Array.length > 0 {
              Utils.generateStyleSheet("", dict, "mystyle")
            }
          }
        | None => ()
        }
      }
    }
    Window.addEventListener("message", handleMetaDataPostMessage)
    Some(() => Window.removeEventListener("message", handleMetaDataPostMessage))
  })

  let renderFullscreen = switch paymentMode {
  | "paymentMethodCollect" =>
    <LoaderController paymentMode setIntegrateErrorError logger initTimestamp>
      <PaymentMethodCollectElement integrateError logger />
    </LoaderController>
  | _ =>
    switch fullscreenMode {
    | "paymentloader" => <PaymentLoader />
    | "plaidSDK" => <PlaidSDKIframe />
    | "fullscreen" =>
      <div id="fullscreen">
        <FullScreenDivDriver />
      </div>
    | "qrData" => <QRCodeDisplay />
    | "3dsAuth" => <ThreeDSAuth />
    | "3ds" => <ThreeDSMethod />
    | "voucherData" => <VoucherDisplay />
    | "preMountLoader" => {
        let clientSecret = CardUtils.getQueryParamsDictforKey(url.search, "clientSecret")
        let sessionId = CardUtils.getQueryParamsDictforKey(url.search, "sessionId")
        let publishableKey = CardUtils.getQueryParamsDictforKey(url.search, "publishableKey")
        let endpoint = CardUtils.getQueryParamsDictforKey(url.search, "endpoint")
        let ephemeralKey = CardUtils.getQueryParamsDictforKey(url.search, "ephemeralKey")
        let hyperComponentName =
          CardUtils.getQueryParamsDictforKey(
            url.search,
            "hyperComponentName",
          )->Types.getHyperComponentNameFromStr
        let merchantHostname = CardUtils.getQueryParamsDictforKey(url.search, "merchantHostname")
        let customPodUri = CardUtils.getQueryParamsDictforKey(url.search, "customPodUri")

        <PreMountLoader
          publishableKey
          sessionId
          clientSecret
          endpoint
          ephemeralKey
          hyperComponentName
          merchantHostname
          customPodUri
        />
      }
    | "achBankTransfer"
    | "bacsBankTransfer"
    | "sepaBankTransfer" =>
      <BankTransfersPopup transferType=fullscreenMode />
    | _ =>
      <LoaderController paymentMode setIntegrateErrorError logger initTimestamp>
        <Payment paymentMode integrateError logger />
      </LoaderController>
    }
  }

  renderFullscreen
}
