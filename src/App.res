@react.component
let make = () => {
  open CardUtils

  let url = RescriptReactRouter.useUrl()
  let (integrateError, setIntegrateErrorError) = React.useState(() => false)
  let setLoggerState = Jotai.useSetAtom(JotaiAtoms.loggerAtom)

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

      let appearanceJson = if dict->Utils.getDictIsSome("paymentElementCreate") {
        dict->Utils.getDictFromObj("paymentOptions")->Dict.get("appearance")
      } else if dict->Utils.getDictIsSome("fullScreenIframeMounted") {
        dict->Dict.get("appearance")
      } else if dict->Utils.getDictIsSome("ElementsUpdate") {
        dict->Utils.getDictFromObj("options")->Dict.get("appearance")
      } else {
        None
      }

      switch appearanceJson {
      | Some(appearanceJson) =>
        let colorScheme =
          appearanceJson
          ->Utils.getDictFromJson
          ->Utils.getString("colorScheme", "light")
          ->CardTheme.getColorScheme
        CardTheme.setColorSchemeMeta(colorScheme)
      | None => ()
      }
    }
    Window.addEventListener("message", handleMetaDataPostMessage)
    Some(() => Window.removeEventListener("message", handleMetaDataPostMessage))
  })

  /*
   Most branches below are reached through a `*Lazy.res` wrapper, so each route ships as its
   own async chunk. These stay eager on purpose:
   - the default branch (LoaderController -> Payment), the only one on the first-paint path;
   - "preMountLoader", which exists to start API calls early (see there);
   - every route that opens after the Pay click: 3ds, 3dsAuth, 3dsRedirectionPopup, redsys3ds,
     qrData, voucherData and the three bank-transfer popups. The loader opens their full-screen
     iframe and then waits, with no timeout, for the route itself to post back - so a chunk
     that failed to load would leave the payment stuck mid-flow with nothing able to end it.
     Eager, they come from app.js, which the payment form has already loaded (about 5 KB gzip).

   `loaderComponent` has no default, so every lazy route states what shows while its chunk
   loads. `React.null` is only for routes with nothing on screen at that point:
   CardFormCoordinator and FullScreenDivDriver render no UI, PaymentMethodsSDK renders nothing
   until its config is ready, and Plaid and Paze hand over to third-party UI that has its own
   loading state.
   */
  let lazyRoute = (~componentName, ~loaderComponent, children) =>
    <ReusableReactSuspense loaderComponent componentName> {children} </ReusableReactSuspense>

  /*
   Each fallback copies the first frame of the route it stands in for, so the swap from
   fallback to route is not visible:
   - modalLoader is Modal's loading state (Modal.res `loaderUI` on the Modal backdrop, minus the
     `overflow-scroll` that only matters once there is content), for clickToPayLearnMore,
     which renders a <Modal>.
   - collectLoader is a centred Loader for PaymentMethodCollect, which has no loading frame of
     its own to copy.
   */
  let modalLoader =
    <div className="h-screen w-screen bg-black/40 flex m-auto items-center backdrop-blur-sm">
      <div className="flex justify-center m-auto"> <Loader showText=false /> </div>
    </div>

  let collectLoader =
    <div className="flex justify-center items-center m-auto"> <Loader showText=false /> </div>

  let renderFullscreen = switch paymentMode {
  | "paymentMethodCollect" =>
    <LoaderController paymentMode setIntegrateErrorError logger initTimestamp>
      {lazyRoute(
        ~componentName="PaymentMethodCollectElementLazy",
        ~loaderComponent=collectLoader,
        <PaymentMethodCollectElementLazy integrateError logger />,
      )}
    </LoaderController>
  | "paymentMethodsSDK" =>
    <LoaderController paymentMode setIntegrateErrorError logger initTimestamp>
      {lazyRoute(
        ~componentName="PaymentMethodsSDKLazy",
        ~loaderComponent=React.null,
        <PaymentMethodsSDKLazy />,
      )}
    </LoaderController>
  | "cardFormCoordinator" =>
    <LoaderController paymentMode setIntegrateErrorError logger initTimestamp>
      {lazyRoute(
        ~componentName="CardFormCoordinatorLazy",
        ~loaderComponent=React.null,
        <CardFormCoordinatorLazy />,
      )}
    </LoaderController>
  | _ =>
    switch fullscreenMode {
    | "paymentloader" => <PaymentLoader />
    | "clickToPayLearnMore" =>
      lazyRoute(
        ~componentName="ClickToPayLearnMoreLazy",
        ~loaderComponent=modalLoader,
        <ClickToPayLearnMoreLazy />,
      )
    | "plaidSDK" =>
      lazyRoute(
        ~componentName="PlaidSDKIframeLazy",
        ~loaderComponent=React.null,
        <PlaidSDKIframeLazy />,
      )
    | "pazeWallet" =>
      lazyRoute(
        ~componentName="PazeWalletLazy",
        ~loaderComponent=React.null,
        <PazeWalletLazy logger />,
      )
    | "fullscreen" =>
      <div id="fullscreen">
        {lazyRoute(
          ~componentName="FullScreenDivDriverLazy",
          ~loaderComponent=React.null,
          <FullScreenDivDriverLazy />,
        )}
      </div>
    | "qrData" => <QRCodeDisplay />
    | "3dsAuth" => <ThreeDSAuth />
    | "redsys3ds" => <Redsys3ds />
    | "3ds" => <ThreeDSMethod />
    | "voucherData" => <VoucherDisplay />
    | "3dsRedirectionPopup" => <ThreeDSRedirectionModal />
    | "preMountLoader" => {
        let sdkAuthorization = getQueryParamsDictforKey(url.search, "sdkAuthorization")
        let clientSecret = getQueryParamsDictforKey(url.search, "clientSecret")
        let sessionId = getQueryParamsDictforKey(url.search, "sessionId")
        let publishableKey = getQueryParamsDictforKey(url.search, "publishableKey")
        let endpoint = getQueryParamsDictforKey(url.search, "endpoint")
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

        /*
         Deliberately NOT lazy: this route exists only to start the payment-methods / session
         API calls as early as possible, and the parent cannot begin until
         preMountLoaderIframeMountedCallback arrives. Behind a chunk boundary that callback
         costs a serial round trip that propagates to the visible checkout; the module is 1.1
         KB gzip - a bad trade for an RTT on the warm-up path.
         */
        <PreMountLoader
          publishableKey
          sessionId
          sdkAuthorization
          clientSecret
          endpoint
          pmSessionId
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
