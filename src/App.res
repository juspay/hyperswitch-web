@react.component
let make = () => {
  open CardUtils

  let url = RescriptReactRouter.useUrl()
  let (integrateError, setIntegrateErrorError) = React.useState(() => false)
  let setLoggerState = Recoil.useSetRecoilState(RecoilAtoms.loggerAtom)

  let paymentMode = getQueryParamsDictforKey(url.search, "componentName")
  let paymentType = paymentMode->CardThemeType.getPaymentMode

  let networkStatus = NetworkInformation.useNetworkInformation()
  let (logger, initTimestamp) = React.useMemo0(() => {
    (HyperLogger.make(~source=Elements(paymentType)), Date.now())
  })

  React.useEffect1(() => {
    switch networkStatus {
    | Value(val) =>
      logger.setLogInfo(
        ~value=val->Identity.anyTypeToJson->JSON.stringify,
        ~eventName=NETWORK_STATE,
        ~logType=DEBUG,
      )
    | NOT_AVAILABLE => ()
    }

    None
  }, [networkStatus])

  let fullscreenMode = getQueryParamsDictforKey(url.search, "fullscreenType")

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

            generateFontsLink(config.fonts)
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
    | "clickToPayLearnMore" => <ClickToPayLearnMore />
    | "plaidSDK" => <PlaidSDKIframe />
    | "pazeWallet" => <PazeWallet logger />
    | "fullscreen" =>
      <div id="fullscreen">
        <FullScreenDivDriver />
      </div>
    | "qrData" => <QRCodeDisplay />
    | "3dsAuth" => <ThreeDSAuth />
    | "redsys3ds" => <Redsys3ds />
    | "3ds" => <ThreeDSMethod />
    | "voucherData" => <VoucherDisplay />
    | "cardVault" => <CardVault />
    | "3dsRedirectionPopup" => <ThreeDSRedirectionModal />
    | "preMountLoader" => {
        let paymentId = getQueryParamsDictforKey(url.search, "paymentId")
        let clientSecret = getQueryParamsDictforKey(url.search, "clientSecret")
        let sessionId = getQueryParamsDictforKey(url.search, "sessionId")
        let publishableKey = getQueryParamsDictforKey(url.search, "publishableKey")
        let profileId = getQueryParamsDictforKey(url.search, "profileId")
        let endpoint = getQueryParamsDictforKey(url.search, "endpoint")
        let ephemeralKey = getQueryParamsDictforKey(url.search, "ephemeralKey")
        let pmClientSecret = getQueryParamsDictforKey(url.search, "pmClientSecret")
        let pmSessionId = getQueryParamsDictforKey(url.search, "pmSessionId")
        let hyperComponentName =
          getQueryParamsDictforKey(
            url.search,
            "hyperComponentName",
          )->Types.getHyperComponentNameFromStr
        let merchantHostname = getQueryParamsDictforKey(url.search, "merchantHostname")
        let customPodUri = getQueryParamsDictforKey(url.search, "customPodUri")
        let isTestMode = getQueryParamsDictforKey(url.search, "isTestMode") === "true"
        let isSdkParamsEnabled =
          getQueryParamsDictforKey(url.search, "isSdkParamsEnabled") === "true"

        <PreMountLoader
          publishableKey
          profileId
          sessionId
          clientSecret
          paymentId
          endpoint
          ephemeralKey
          pmSessionId
          pmClientSecret
          hyperComponentName
          merchantHostname
          customPodUri
          isTestMode
          isSdkParamsEnabled
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
