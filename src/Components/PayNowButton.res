@send external postMessage: (Window.window, JSON.t, string) => unit = "postMessage"

external eventToJson: ReactEvent.Mouse.t => JSON.t = "%identity"

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
let make = (
  ~cvcProps: CardUtils.cvcProps,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~selectedOption: PaymentModeType.payment,
) => {
  open RecoilAtoms
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (isDisabled, setIsDisabled) = React.useState(() => false)
  let (showLoader, setShowLoader) = React.useState(() => false)
  let areRequiredFieldsValidValue = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let {sdkHandleConfirmPayment} = Recoil.useRecoilValueFromAtom(optionAtom)

  let (isCVCValid, _, _, _, _, _, _, _, _, _) = cvcProps
  let (isCardValid, _, _, _, _, _, _, _, _, _) = cardProps
  let (isExpiryValid, _, _, _, _, _, _, _, _) = expiryProps

  let validFormat =
    isCVCValid->Option.getOr(false) &&
    isCardValid->Option.getOr(false) &&
    isExpiryValid->Option.getOr(false) &&
    areRequiredFieldsValidValue

  let confirmPayload = sdkHandleConfirmPayment->PaymentBody.confirmPayloadForSDKButton

  let handleOnClick = _ => {
    setIsDisabled(_ => true)
    setShowLoader(_ => true)
    Utils.handlePostMessage([("handleSdkConfirm", confirmPayload)])
  }
  React.useEffect3(() => {
    if selectedOption === Card {
      setIsDisabled(_ => !validFormat)
    } else {
      setIsDisabled(_ => !areRequiredFieldsValidValue)
    }
    None
  }, (validFormat, areRequiredFieldsValidValue, selectedOption))

  <div className="flex flex-col gap-1 h-auto w-full items-center">
    <button
      disabled=isDisabled
      onClick=handleOnClick
      className={`w-full flex flex-row justify-center items-center`}
      style={ReactDOMStyle.make(
        ~borderRadius=themeObj.buttonBorderRadius,
        ~backgroundColor=themeObj.buttonBackgroundColor,
        ~height=themeObj.buttonHeight,
        ~cursor={isDisabled ? "not-allowed" : "pointer"},
        ~opacity={isDisabled ? "0.6" : "1"},
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
          localeString.payNowButton->React.string
        }}
      </span>
    </button>
  </div>
}
