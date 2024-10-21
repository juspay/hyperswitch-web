@react.component
let make = (~token: SessionsType.token) => {
  open Utils
  open RecoilAtoms
  let {iframeId, publishableKey} = Recoil.useRecoilValueFromAtom(keys)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let (showLoader, setShowLoader) = React.useState(() => false)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(RecoilAtoms.isShowOrPayUsing)

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
          ("wallet", (token.walletName :> string)->JSON.Encode.string),
          ("clientId", token.clientId->JSON.Encode.string),
          ("clientName", token.clientName->JSON.Encode.string),
          ("clientProfileId", token.clientProfileId->JSON.Encode.string),
          ("sessionId", token.sessionId->JSON.Encode.string),
          ("currency", paymentMethodListValue.currency->JSON.Encode.string),
          ("publishableKey", publishableKey->JSON.Encode.string),
        ]->getJsonFromArrayOfJson,
      ),
    ])
  }

  React.useEffect0(() => {
    // open Promise
    let onPazeCallback = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->Utils.getDictFromJson->getDictFromDict("data")
      let isPaze = dict->getBool("isPaze", false)
      if isPaze {
        setShowLoader(_ => false)
        Js.log2("PAZE --- onPazeCallback", dict)

        // if dict->getOptionString("completeResponse")->Option.isSome {
        // confirm call need to be done over here
        // }
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
