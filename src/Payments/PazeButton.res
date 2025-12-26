@react.component
let make = (~token: SessionsType.token) => {
  open Utils
  open RecoilAtoms

  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")

  let {iframeId, publishableKey, clientSecret} = Recoil.useRecoilValueFromAtom(keys)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let updateSession = Recoil.useRecoilValueFromAtom(updateSession)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(isShowOrPayUsing)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Paze)
  let paymentIntentID = clientSecret->Option.getOr("")->getPaymentId
  let (showLoader, setShowLoader) = React.useState(() => false)
  let {country, state, pinCode} = PaymentUtils.useNonPiiAddressData()

  let onClick = _ => {
    loggerState.setLogInfo(
      ~value="Paze SDK Button Clicked",
      ~eventName=PAZE_SDK_FLOW,
      ~paymentMethod="PAZE",
    )
    PaymentUtils.emitPaymentMethodInfo(
      ~paymentMethod="wallet",
      ~paymentMethodType="paze",
      ~country,
      ~state,
      ~pinCode,
    )
    setShowLoader(_ => true)
    let metadata =
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
      ]->getJsonFromArrayOfJson

    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "pazeWallet"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
      ("metadata", metadata),
    ])
  }

  React.useEffect(() => {
    let handlePazeCallback = ev => {
      let json = ev.data->safeParse
      let dict = json->Utils.getDictFromJson->getDictFromDict("data")
      if dict->getBool("isPaze", false) {
        setShowLoader(_ => false)
        messageParentWindow([
          ("fullscreen", true->JSON.Encode.bool),
          ("param", "paymentloader"->JSON.Encode.string),
          ("iframeId", iframeId->JSON.Encode.string),
        ])
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

    setIsShowOrPayUsing(_ => true)
    Window.addEventListener("message", handlePazeCallback)
    Some(() => Window.removeEventListener("message", handlePazeCallback))
  }, [])
  <button
    disabled={showLoader}
    onClick
    className="w-full flex flex-row justify-center items-center"
    style={
      borderRadius: themeObj.buttonBorderRadius,
      backgroundColor: "#2B63FF",
      height: themeObj.buttonHeight,
      cursor: {showLoader ? "not-allowed" : "pointer"},
      width: themeObj.buttonWidth,
      border: `${themeObj.buttonBorderWidth} solid ${themeObj.buttonBorderColor}`,
      pointerEvents: updateSession ? "none" : "auto",
      opacity: showLoader || updateSession ? "0.5" : "1.0",
    }>
    {showLoader ? <Spinner /> : <Icon name="paze" size=55 />}
  </button>
}
