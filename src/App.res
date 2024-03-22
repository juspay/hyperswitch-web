@react.component
let make = () => {
  let url = RescriptReactRouter.useUrl()
  let (integrateError, setIntegrateErrorError) = React.useState(() => false)
  let setLoggerState = Recoil.useSetRecoilState(RecoilAtoms.loggerAtom)

  let paymentMode = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let fullscreenMode = CardUtils.getQueryParamsDictforKey(url.search, "fullscreenType")

  let logger = React.useMemo0(() => {
    let log = OrcaLogger.make()
    log
  })

  React.useEffect(() => {
    setLoggerState(_ => logger)
    None
  }, [logger])

  let renderFullscreen = {
    switch fullscreenMode {
    | "paymentloader" => <PaymentLoader />
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
        let endpoint =
          CardUtils.getQueryParamsDictforKey(url.search, "endpoint")->decodeURIComponent
        <PreMountLoader publishableKey sessionId clientSecret endpoint />
      }
    | "achBankTransfer"
    | "bacsBankTransfer"
    | "sepaBankTransfer" =>
      <BankTransfersPopup transferType=fullscreenMode />
    | _ =>
      <LoaderController paymentMode setIntegrateErrorError logger>
        <Payment paymentMode integrateError logger />
      </LoaderController>
    }
  }

  renderFullscreen
}
