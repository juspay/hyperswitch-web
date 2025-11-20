@send external postMessage: (Types.window, JSON.t, string) => unit = "postMessage"

module Loader = {
  @react.component
  let make = () => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    <div className="w-8 h-8 animate-spin" style={color: themeObj.colorTextSecondary}>
      <Icon size=32 name="loader" />
    </div>
  }
}
@react.component
let make = (~onClickHandler=?, ~label=?) => {
  open RecoilAtoms
  open Utils
  open PaymentTypeContext
  let (showLoader, setShowLoader) = React.useState(() => false)
  let (isPayNowButtonDisable, setIsPayNowButtonDisable) = React.useState(() => false)
  let {themeObj, localeString} = configAtom->Recoil.useRecoilValueFromAtom
  let {sdkHandleConfirmPayment} = optionAtom->Recoil.useRecoilValueFromAtom

  let {sdkHandleSavePayment} = optionAtom->Recoil.useRecoilValueFromAtom
  let paymentType = usePaymentType()

  let confirmPayload = sdkHandleConfirmPayment->PaymentBody.confirmPayloadForSDKButton
  let buttonText = switch paymentType {
  | PaymentMethodsManagement => sdkHandleSavePayment.buttonText->Option.getOr("Save Card")
  | _ =>
    switch label {
    | Some(val) => val
    | None => sdkHandleConfirmPayment.buttonText->Option.getOr(localeString.payNowButton)
    }
  }

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

  let onClickHandlerFunc = _ => {
    switch onClickHandler {
    | Some(fn) => fn()
    | None => ()
    }
  }

  let handleOnClick = _ => {
    setIsPayNowButtonDisable(_ => true)
    setShowLoader(_ => true)
    EventListenerManager.addSmartEventListener("message", handleMessage, "onSubmitSuccessful")
    messageParentWindow([("handleSdkConfirm", confirmPayload)])
  }

  <div className="flex flex-col gap-1 h-auto w-full items-center">
    <button
      disabled=isPayNowButtonDisable
      onClick={onClickHandler->Option.isNone ? handleOnClick : onClickHandlerFunc}
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
