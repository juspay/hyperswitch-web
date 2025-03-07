@react.component
let make = () => {
  open CardUtils

  let url = RescriptReactRouter.useUrl()
  let (integrateError, setIntegrateErrorError) = React.useState(() => false)
  let setLoggerState = Recoil.useSetRecoilState(RecoilAtoms.loggerAtom)

  let paymentMode = getQueryParamsDictforKey(url.search, "componentName")
  let paymentType = paymentMode->CardThemeType.getPaymentMode
  let (logger, initTimestamp) = React.useMemo0(() => {
    (HyperLogger.make(~source=Elements(paymentType)), Date.now())
  })

  let setCountry = Recoil.useSetRecoilState(RecoilAtoms.countryAtom)
  let setState = Recoil.useSetRecoilState(RecoilAtoms.stateAtom)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  React.useEffect(() => {
    let fetchData = async () => {
      try {
        let data = await S3Utils.getCountryStateData(~locale=localeString.locale)
        setCountry(_ => data.countries)
        setState(_ => data.states)
      } catch {
      | _ => {
          setCountry(_ => Country.country)
          try {
            let fallbackStates = await AddressPaymentInput.importStates("./States.json")
            setState(_ => fallbackStates.states)
          } catch {
          | _ => setState(_ => JSON.Encode.null)
          }
        }
      }
    }
    fetchData()->ignore
    None
  }, [localeString.locale])
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
    | "3ds" => <ThreeDSMethod />
    | "voucherData" => <VoucherDisplay />
    | "preMountLoader" => {
        let clientSecret = getQueryParamsDictforKey(url.search, "clientSecret")
        let sessionId = getQueryParamsDictforKey(url.search, "sessionId")
        let publishableKey = getQueryParamsDictforKey(url.search, "publishableKey")
        let endpoint = getQueryParamsDictforKey(url.search, "endpoint")
        let ephemeralKey = getQueryParamsDictforKey(url.search, "ephemeralKey")
        let hyperComponentName =
          getQueryParamsDictforKey(
            url.search,
            "hyperComponentName",
          )->Types.getHyperComponentNameFromStr
        let merchantHostname = getQueryParamsDictforKey(url.search, "merchantHostname")
        let customPodUri = getQueryParamsDictforKey(url.search, "customPodUri")

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
