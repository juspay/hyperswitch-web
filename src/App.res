@react.component
let make = () => {
  let (logger, initTimestamp) = React.useMemo0(() => {
    (OrcaLogger.make(), Date.now())
  })
  let url = RescriptReactRouter.useUrl()
  let (integrateError, setIntegrateErrorError) = React.useState(() => false)
  let setLoggerState = Recoil.useSetRecoilState(RecoilAtoms.loggerAtom)

  let paymentMode = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let fullscreenMode = CardUtils.getQueryParamsDictforKey(url.search, "fullscreenType")

  let logger = React.useMemo0(() => {
    let log = OrcaLogger.make()
    log
  })

  React.useEffect1(() => {
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
        <PreMountLoader publishableKey sessionId clientSecret />
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
