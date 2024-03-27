@send external postMessage: (Window.window, JSON.t, string) => unit = "postMessage"

external eventToJson: 'a => JSON.t = "%identity"

module Loader = {
  @react.component
  let make = () => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    <div
      className=" w-8 h-8 animate-spin"
      style={ReactDOMStyle.make(~color=themeObj.colorTextSecondary, ())}>
      <Icon size=32 name="loader" />
    </div>
  }
}
@react.component
let make = () => {
  open RecoilAtoms
  let (showLoader, setShowLoader) = React.useState(() => false)

  let {themeObj, localeString} = configAtom->Recoil.useRecoilValueFromAtom
  let {sdkHandleConfirmPayment} = optionAtom->Recoil.useRecoilValueFromAtom
  let (isPayNowButtonDisable, setIsPayNowButtonDisable) = payNowButtonDisable->Recoil.useRecoilState

  let confirmPayload = sdkHandleConfirmPayment->PaymentBody.confirmPayloadForSDKButton
  let buttonText = sdkHandleConfirmPayment.buttonText->Option.getOr(localeString.payNowButton)

  let handleMessage = (event: Types.event) => {
    let json = event.data->eventToJson->OrcaUtils.getStringfromjson("")->OrcaUtils.safeParse
    let dict = json->Utils.getDictFromJson
    switch dict->Dict.get("submitSuccessful") {
    | Some(_) =>
      setIsPayNowButtonDisable(_ => false)
      setShowLoader(_ => false)
    | None => ()
    }
  }

  let handleOnClick = _ => {
    setIsPayNowButtonDisable(_ => true)
    setShowLoader(_ => true)
    EventListenerManager.addSmartEventListener("message", handleMessage, "onSubmitSuccessful")
    Utils.handlePostMessage([("handleSdkConfirm", confirmPayload)])
  }

  <div className="flex flex-col gap-1 h-auto w-full items-center">
    <button
      disabled=isPayNowButtonDisable
      onClick=handleOnClick
      className={`w-full flex flex-row justify-center items-center`}
      style={ReactDOMStyle.make(
        ~borderRadius=themeObj.buttonBorderRadius,
        ~backgroundColor=themeObj.buttonBackgroundColor,
        ~height=themeObj.buttonHeight,
        ~cursor={isPayNowButtonDisable ? "not-allowed" : "pointer"},
        ~opacity={isPayNowButtonDisable ? "0.6" : "1"},
        ~width=themeObj.buttonWidth,
        ~borderColor=themeObj.buttonBorderColor,
        (),
      )}>
      <span
        id="button-text"
        style={ReactDOMStyle.make(
          ~color=themeObj.buttonTextColor,
          ~fontSize=themeObj.buttonTextFontSize,
          ~fontWeight=themeObj.buttonTextFontWeight,
          (),
        )}>
        {if showLoader {
          <Loader />
        } else {
          buttonText->React.string
        }}
      </span>
    </button>
  </div>
}
