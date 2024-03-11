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
let make = (~cvcProps, ~cardProps, ~expiryProps) => {
  open RecoilAtoms
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
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

  let buttonText =
    sdkHandleConfirmPayment.buttonText->String.length > 0
      ? sdkHandleConfirmPayment.buttonText
      : localeString.payNowButton

  let confirmPayload =
    [
      ("redirect", "always"->JSON.Encode.string),
      (
        "confirmParams",
        [("return_url", sdkHandleConfirmPayment.confirmParams.return_url->JSON.Encode.string)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object

  let handleOnClick = _ => {
    setIsDisabled(_ => true)
    setShowLoader(_ => true)
    Utils.handlePostMessage([("handleSdkConfirm", confirmPayload)])
  }
  React.useEffect1(() => {
    setIsDisabled(_ => !validFormat)
    None
  }, [validFormat])

  <div className="flex flex-col gap-1 h-auto w-full items-center">
    <button
      disabled=isDisabled
      onClick=handleOnClick
      className={`w-full flex flex-row justify-center items-center`}
      style={ReactDOMStyle.make(
        ~borderRadius=sdkHandleConfirmPayment.borderRadius,
        ~backgroundColor=sdkHandleConfirmPayment.backgroundColor,
        ~height=sdkHandleConfirmPayment.buttonHeight,
        ~cursor={isDisabled ? "not-allowed" : "pointer"},
        ~opacity={isDisabled ? "0.6" : "1"},
        ~width=sdkHandleConfirmPayment.buttonWidth,
        ~borderColor=sdkHandleConfirmPayment.borderColor,
        (),
      )}>
      <span
        id="button-text"
        style={ReactDOMStyle.make(
          ~color=sdkHandleConfirmPayment.textColor,
          ~fontSize=sdkHandleConfirmPayment.textFontSize,
          ~fontWeight=sdkHandleConfirmPayment.textFontWeight,
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
