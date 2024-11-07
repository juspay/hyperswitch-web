@react.component
let make = (~token: SessionsType.token) => {
  open Utils
  open RecoilAtoms

  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")

  let {iframeId, publishableKey, clientSecret} = Recoil.useRecoilValueFromAtom(keys)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let (showLoader, setShowLoader) = React.useState(() => false)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(RecoilAtoms.isShowOrPayUsing)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Paze)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let paymentIntentID = clientSecret->Option.getOr("")->getPaymentId

  React.useEffect0(() => {
    setIsShowOrPayUsing(_ => true)
    None
  })

  let onClick = _ => {
    setShowLoader(_ => true)
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "pazeWallet"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
      (
        "metadata",
        [
          ("componentName", componentName->JSON.Encode.string),
          ("wallet", (token.walletName :> string)->JSON.Encode.string),
          ("clientId", token.clientId->JSON.Encode.string),
          ("clientName", token.clientName->JSON.Encode.string),
          ("clientProfileId", token.clientProfileId->JSON.Encode.string),
          ("sessionId", paymentIntentID->JSON.Encode.string),
          ("publishableKey", publishableKey->JSON.Encode.string),
          ("emailAddress", token.email_address->JSON.Encode.string),
          ("transactionAmount", token.transaction_amount->JSON.Encode.string),
          ("transactionCurrencyCode", token.transaction_currency_code->JSON.Encode.string),
        ]->getJsonFromArrayOfJson,
      ),
    ])
  }

  React.useEffect0(() => {
    let onPazeCallback = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->Utils.getDictFromJson->getDictFromDict("data")
      let isPaze = dict->getBool("isPaze", false)
      if isPaze {
        setShowLoader(_ => false)
        if dict->getOptionString("completeResponse")->Option.isSome {
          let completeResponse = dict->getString("completeResponse", "")
          intent(
            ~bodyArr=PaymentBody.pazeBody(~completeResponse),
            ~confirmParam={
              return_url: options.wallets.walletReturnUrl,
              publishableKey,
            },
            ~handleUserError=false,
            ~manualRetry=isManualRetryEnabled,
          )
        }
      }
    }
    Window.addEventListener("message", onPazeCallback)
    Some(() => Window.removeEventListener("message", ev => onPazeCallback(ev)))
  })

  <button
    disabled={showLoader}
    onClick
    className={`w-full flex flex-row justify-center items-center`}
    style={
      borderRadius: themeObj.buttonBorderRadius,
      backgroundColor: "#2B63FF",
      height: themeObj.buttonHeight,
      cursor: {showLoader ? "not-allowed" : "pointer"},
      opacity: {showLoader ? "0.6" : "1"},
      width: themeObj.buttonWidth,
      border: `${themeObj.buttonBorderWidth} solid ${themeObj.buttonBorderColor}`,
    }>
    {showLoader ? <Spinner /> : <Icon name="paze" size=55 />}
  </button>
}
