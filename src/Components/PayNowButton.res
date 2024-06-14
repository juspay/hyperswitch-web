@send external postMessage: (Window.window, JSON.t, string) => unit = "postMessage"

module Loader = {
  @react.component
  let make = () => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    <div className=" w-8 h-8 animate-spin" style={color: themeObj.colorTextSecondary}>
      <Icon size=32 name="loader" />
    </div>
  }
}
@react.component
let make = () => {
  open RecoilAtoms
  open Utils
  let (showLoader, setShowLoader) = React.useState(() => false)
  let {themeObj, localeString} = configAtom->Recoil.useRecoilValueFromAtom
  let {sdkHandleConfirmPayment} = optionAtom->Recoil.useRecoilValueFromAtom
  let (isPayNowButtonDisable, setIsPayNowButtonDisable) = payNowButtonDisable->Recoil.useRecoilState

  let confirmPayload = sdkHandleConfirmPayment->PaymentBody.confirmPayloadForSDKButton
  let buttonText = sdkHandleConfirmPayment.buttonText->Option.getOr(localeString.payNowButton)

  let handleMessage = (event: Types.event) => {
    let json = event.data->Identity.anyTypeToJson->getStringFromJson("")->safeParse
    let dict = json->getDictFromJson
    switch dict->Dict.get("submitSuccessful") {
    | Some(submitSuccessfulVal) =>
      if !(submitSuccessfulVal->JSON.Decode.bool->Option.getOr(false)) {
        setIsPayNowButtonDisable(_ => false)
        setShowLoader(_ => false)
      }
    | None => ()
    }
  }

  let handleOnClick = _ => {
    setIsPayNowButtonDisable(_ => true)
    setShowLoader(_ => true)
    EventListenerManager.addSmartEventListener("message", handleMessage, "onSubmitSuccessful")
    handlePostMessage([("handleSdkConfirm", confirmPayload)])
  }

  <div className="flex flex-col gap-1 h-auto w-full items-center">
    <button
      disabled=isPayNowButtonDisable
      onClick=handleOnClick
      className={`w-full flex flex-row justify-center items-center`}
      style={
        borderRadius: themeObj.buttonBorderRadius,
        backgroundColor: themeObj.buttonBackgroundColor,
        height: themeObj.buttonHeight,
        cursor: {isPayNowButtonDisable ? "not-allowed" : "pointer"},
        opacity: {isPayNowButtonDisable ? "0.6" : "1"},
        width: themeObj.buttonWidth,
        border: `${themeObj.buttonBorderWidth} solid ${themeObj.buttonBorderColor}`,
      }>
      <span
        id="button-text"
        style={
          color: themeObj.buttonTextColor,
          fontSize: themeObj.buttonTextFontSize,
          fontWeight: themeObj.buttonTextFontWeight,
        }>
        {if showLoader {
          <Loader />
        } else {
          buttonText->React.string
        }}
      </span>
    </button>
  </div>
}
