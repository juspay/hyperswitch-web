open ClickToPayHelpers
open Window
open Utils

type callbacks = {
  otpChanged: callback,
  continueClicked: callback,
  resendClicked: callback,
  rememberMe: callback,
}
type listener = {
  name: string,
  callback: callback,
}

module LoadingState = {
  @react.component
  let make = () => {
    <ClickToPayHelpers.SrcLoader dark=true />
  }
}

module OtpInput = {
  @react.component
  let make = (~getCards: string => promise<unit>, ~setIsClickToPayRememberMe) => {
    let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
    let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(
      RecoilAtoms.clickToPayConfig,
    )
    let otpValueRef = React.useRef("")
    let addListener = (~element, ~event, ~callback, ~options=?) =>
      element.addEventListener->Option.forEach(func => func(event, callback, options))
    let isResendingOtp = React.useRef(false)
    let isSubmittingOtp = React.useRef(false)
    let {config} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let theme = config.appearance.theme
    let isDarkTheme = switch theme {
    | Default => false
    | _ => true
    }
    let callBacks = {
      otpChanged: ev => {
        setClickToPayConfig(prev => {
          ...prev,
          otpError: "",
        })
        ev
        ->Nullable.toOption
        ->Option.forEach(value => {
          let otp = value->getDictFromJson->getString("detail", "")
          if otp->String.length == 6 {
            otpValueRef.current = otp
          }
        })
      },
      continueClicked: _ => {
        let verifyUserAndGetCards = async () => {
          try {
            isSubmittingOtp.current = true
            await getCards(otpValueRef.current)
            isSubmittingOtp.current = false
          } catch {
          | err =>
            loggerState.setLogError(
              ~value={
                "message": `User validation failed - ${err->Utils.formatException->JSON.stringify}`,
                "scheme": "VISA",
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
          }
        }
        verifyUserAndGetCards()->ignore
      },
      resendClicked: _ => {
        setClickToPayConfig(prev => {
          ...prev,
          otpError: "",
        })
        let resendOtp = async () => {
          try {
            isResendingOtp.current = true
            await getCards("")
            isResendingOtp.current = false
          } catch {
          | err =>
            loggerState.setLogError(
              ~value={
                "message": `resend otp failed - ${err->Utils.formatException->JSON.stringify}`,
                "scheme": "VISA",
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
          }
        }
        resendOtp()->ignore
      },
      rememberMe: ev => {
        ev
        ->Nullable.toOption
        ->Option.forEach(e => {
          let dict = e->getDictFromJson
          let rememberMe = dict->getDictFromDict("detail")->getBool("rememberMe", false)
          setIsClickToPayRememberMe(_ => rememberMe)
        })
      },
    }

    React.useEffect0(() => {
      let srcOtpInput = elementQuerySelector(myDocument, "src-otp-input")->Nullable.toOption
      let controller = AbortController.make()
      let signal = controller.signal
      let listeners = [
        {name: "otpChanged", callback: callBacks.otpChanged},
        {name: "continue", callback: callBacks.continueClicked},
        {name: "resendOtp", callback: callBacks.resendClicked},
        {name: "rememberMe", callback: callBacks.rememberMe},
      ]

      srcOtpInput->Option.forEach(element =>
        listeners->Array.forEach(
          listener =>
            addListener(
              ~element,
              ~event=listener.name,
              ~callback=listener.callback,
              ~options={signal: signal},
            ),
        )
      )

      Some(() => controller.abort())
    })

    <ClickToPayHelpers.SrcOtpInput
      errorReason=clickToPayConfig.otpError
      locale="en-US"
      header=false
      network=" "
      isAutoSubmit=false
      id="src-otp-input"
      cardBrand=""
      displayCancelOption=false
      maskedIdentityValue=clickToPayConfig.maskedIdentity
      typeName=""
      isOtpValid=false
      disableElements=isSubmittingOtp.current
      displayRememberMe=true
      isOtpResendLoading=isResendingOtp.current
      dark=isDarkTheme
    />
  }
}
