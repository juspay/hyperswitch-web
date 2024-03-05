@send external postMessage: (Window.window, Js.Json.t, string) => unit = "postMessage"

external eventToJson: ReactEvent.Mouse.t => Js.Json.t = "%identity"

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
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (isDisabled, setIsDisabled) = React.useState(() => false)
  let (showLoader, setShowLoader) = React.useState(() => false)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let {sdkHandleConfirmPaymentProps} = Recoil.useRecoilValueFromAtom(optionAtom)

  let buttonText =
    sdkHandleConfirmPaymentProps.buttonText->Js.String2.length > 0
      ? sdkHandleConfirmPaymentProps.buttonText
      : localeString.payNowButton

  let confirmPayload =
    [
      ("redirect", "always"->Js.Json.string),
      (
        "confirmParams",
        [("return_url", sdkHandleConfirmPaymentProps.confirmParams.return_url->Js.Json.string)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_

  let handleOnClick = _ => {
    setIsDisabled(_ => true)
    setShowLoader(_ => true)
    Utils.handlePostMessage([("handleSdkConfirm", confirmPayload)])
  }
  React.useEffect1(() => {
    setIsDisabled(_ => !areRequiredFieldsValid)
    None
  }, [areRequiredFieldsValid])

  <div className="flex flex-col gap-1 h-auto w-full">
    <button
      disabled=isDisabled
      onClick=handleOnClick
      className={`w-full flex flex-row justify-center items-center rounded-md`}
      style={ReactDOMStyle.make(
        ~backgroundColor={
          sdkHandleConfirmPaymentProps.buttonBackgroundColor->Js.String2.length > 0
            ? sdkHandleConfirmPaymentProps.buttonBackgroundColor
            : themeObj.buttonBackgroundColor
        },
        ~height={
          sdkHandleConfirmPaymentProps.buttonHeight->Js.String2.length > 0
            ? sdkHandleConfirmPaymentProps.buttonHeight
            : "48px"
        },
        ~cursor={isDisabled ? "not-allowed" : "pointer"},
        ~opacity={isDisabled ? "0.6" : "1"},
        ~borderWidth=sdkHandleConfirmPaymentProps.buttonWidth,
        ~borderColor={
          sdkHandleConfirmPaymentProps.borderColor->Js.String2.length > 0
            ? sdkHandleConfirmPaymentProps.borderColor
            : themeObj.colorPrimary
        },
        (),
      )}>
      <span
        id="button-text"
        style={ReactDOMStyle.make(
          ~color={
            sdkHandleConfirmPaymentProps.textColor->Js.String2.length > 0
              ? sdkHandleConfirmPaymentProps.textColor
              : themeObj.buttonTextColor
          },
          ~fontSize={
            sdkHandleConfirmPaymentProps.textFontSize->Js.String2.length > 0
              ? sdkHandleConfirmPaymentProps.textFontSize
              : themeObj.fontSizeLg
          },
          ~fontWeight={
            sdkHandleConfirmPaymentProps.textFontWeight->Js.String2.length > 0
              ? sdkHandleConfirmPaymentProps.textFontWeight
              : themeObj.fontWeightMedium
          },
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
