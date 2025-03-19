open ClickToPayHelpers

type event = {detail: Js.Nullable.t<string>, preventDefault: unit => unit}

type callback = event => unit
type options = {signal: unit}
type element = {
  id: string,
  addEventListener?: (string, callback, option<options>) => unit,
}

type callbacks = {
  otpChanged: callback,
  continueClicked: callback,
  resendClicked: callback,
}
type listener = {
  name: string,
  callback: callback,
}

type listners = array<listener>

type elementDocument
@val external myDocument: elementDocument = "document"
@send external querySelector: (elementDocument, string) => Nullable.t<element> = "querySelector"

module AbortController = {
  type controller = {
    abort: unit => unit,
    signal: unit,
  }

  @new external make: unit => controller = "AbortController"
}

module LoadingState = {
  @react.component
  let make = () => {
    <ClickToPayHelpers.SrcLoader />
  }
}

module ConsumerIdInput = {
  @react.component
  let make = () => {
    <div className="w-full aspect-square border border-black flex items-center justify-center">
      {React.string("CONSUMER ID MISSING")}
    </div>
  }
}

module OtpInput = {
  @react.component
  let make = (~getCards: string => promise<unit>, ~otpError, ~setOtpError, ~maskedIdentity) => {
    let (otpSubmitting, setOtpSubmitting) = React.useState(_ => false)
    let otpValueRef = React.useRef("")
    let (resendLoading, setResendLoading) = React.useState(_ => false)
    let addListener = (element, event, callback, ~options=?) => {
      switch element.addEventListener {
      | Some(fn) => fn(event, callback, options)
      | None => ()
      }
    }

    let callBacks = {
      otpChanged: ev => {
        Console.log2("Otp changed", ev)
        setOtpError(_ => "")
        switch Js.Nullable.toOption(ev.detail) {
        | Some(value) =>
          if value->String.length == 6 {
            Console.log2("OTP", value)
            otpValueRef.current = value
          }
        | None => Console.log("No OTP")
        }
      },
      continueClicked: _ => {
        (
          async _ => {
            setOtpSubmitting(_ => true)
            await getCards(otpValueRef.current)
            setOtpSubmitting(_ => false)
          }
        )()->ignore
      },
      resendClicked: _ => {
        setOtpError(_ => "")

        (
          async _ => {
            setResendLoading(_ => true)
            await getCards("")
            setResendLoading(_ => false)
          }
        )()->ignore
      },
    }

    React.useEffect0(() => {
      let srcOtpInput = querySelector(myDocument, "src-otp-input")->Js.Nullable.toOption
      let controller = AbortController.make()
      let signal = controller.signal
      let listeners = [
        {name: "otpChanged", callback: callBacks.otpChanged},
        {name: "continue", callback: callBacks.continueClicked},
        {name: "resendOtp", callback: callBacks.resendClicked},
      ]

      switch srcOtpInput {
      | Some(element) =>
        listeners->Array.forEach(listener =>
          addListener(element, listener.name, listener.callback, ~options={signal: signal})
        )
      | None => ()
      }

      Some(() => controller.abort())
    })

    <ClickToPayHelpers.SrcOtpInput
      errorReason=otpError
      locale="en-US"
      header=false
      network="VISA"
      isAutoSubmit=false
      id="src-otp-input"
      cardBrand=""
      displayCancelOption=false
      maskedIdentityValue=maskedIdentity
      typeName=""
      isOtpValid=false
      disableElements=otpSubmitting
      displayRememberMe=true
      isOtpResendLoading=resendLoading
    />
  }
}

module ErrorOccured = {
  @react.component
  let make = () => {
    <div className="w-full aspect-square border border-black flex items-center justify-center">
      {React.string("ERROR OCCURED")}
    </div>
  }
}
