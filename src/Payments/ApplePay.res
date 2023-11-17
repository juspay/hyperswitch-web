type props = {sessionObj: option<Js.Json.t>, list: PaymentMethodsRecord.list}

let default = (props: props) => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(RecoilAtoms.isShowOrPayUsing)
  let (showApplePay, setShowApplePay) = React.useState(() => false)
  let (showApplePayLoader, setShowApplePayLoader) = React.useState(() => false)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Applepay)
  let sync = PaymentHelpers.usePaymentSync(Some(loggerState), Applepay)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let (applePayClicked, setApplePayClicked) = React.useState(_ => false)
  let isApplePaySDKFlow = props.sessionObj->Belt.Option.isSome

  let applePayPaymentMethodType = React.useMemo1(() => {
    switch PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~list=props.list,
      ~paymentMethod="wallet",
      ~paymentMethodType="apple_pay",
    ) {
    | Some(paymentMethodType) => paymentMethodType
    | None => PaymentMethodsRecord.defaultPaymentMethodType
    }
  }, [props.list])

  let paymentExperience = React.useMemo1(() => {
    applePayPaymentMethodType.payment_experience->Js.Array2.length == 0
      ? PaymentMethodsRecord.RedirectToURL
      : applePayPaymentMethodType.payment_experience[0].payment_experience_type
  }, [applePayPaymentMethodType])

  let isInvokeSDKFlow = React.useMemo1(() => {
    paymentExperience == PaymentMethodsRecord.InvokeSDK && isApplePaySDKFlow
  }, [props.sessionObj])

  let (connectors, _) = isInvokeSDKFlow
    ? props.list->PaymentUtils.getConnectors(Wallets(ApplePay(SDK)))
    : props.list->PaymentUtils.getConnectors(Wallets(ApplePay(Redirect)))

  let processPayment = bodyArr => {
    intent(
      ~bodyArr,
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey: publishableKey,
      },
      ~handleUserError=true,
      (),
    )
  }

  let syncPayment = () => {
    sync(
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey: publishableKey,
      },
      ~handleUserError=true,
      (),
    )
  }

  let buttonColor = switch options.wallets.style.theme {
  | Outline
  | Light => "white"
  | Dark => "black"
  }

  let loaderDivBackgroundColor = switch options.wallets.style.theme {
  | Outline
  | Light => "white"
  | Dark => "black"
  }

  let loaderBorderColor = switch options.wallets.style.theme {
  | Outline
  | Light => "#828282"
  | Dark => "white"
  }

  let loaderBorderTopColor = switch options.wallets.style.theme {
  | Outline
  | Light => "black"
  | Dark => "#828282"
  }

  let css = `@supports (-webkit-appearance: -apple-pay-button) {
    .apple-pay-loader-div {
      background-color: ${loaderDivBackgroundColor};
      height: 3rem;
      display: flex;
      justify-content: center;
      align-items: center;
      border-radius: 2px
    }
    .apple-pay-loader {
      border: 4px solid ${loaderBorderColor};
      border-radius: 50%;
      border-top: 4px solid ${loaderBorderTopColor};
      width: 2.1rem;
      height: 2.1rem;
      -webkit-animation: spin 2s linear infinite; /* Safari */
      animation: spin 2s linear infinite;
    }

    /* Safari */
    @-webkit-keyframes spin {
      0% { -webkit-transform: rotate(0deg); }
      100% { -webkit-transform: rotate(360deg); }
    }

    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .apple-pay-button-with-text {
        display: inline-block;
        -webkit-appearance: -apple-pay-button;
        -apple-pay-button-type: plain;
    }
    .apple-pay-button-with-text > * {
        display: none;
    }
    .apple-pay-button-black-with-text {
        -apple-pay-button-style: ${buttonColor};
        width: 100%;
        height: 3rem;
        display: flex;
        cursor: pointer;
        border-radius: 2px;
    }
    .apple-pay-button-white-with-text {
        -apple-pay-button-style: white;
        display: flex;
        cursor: pointer;
    }
    .apple-pay-button-white-with-line-with-text {
        -apple-pay-button-style: white-outline;
    }
  }

  @supports not (-webkit-appearance: -apple-pay-button) {
      .apple-pay-button-with-text {
          --apple-pay-scale: 2; /* (height / 32) */
          display: inline-flex;
          justify-content: center;
          font-size: 12px;
          border-radius: 5px;
          padding: 0px;
          box-sizing: border-box;
          min-width: 200px;
          min-height: 32px;
          max-height: 64px;
      }
      .apple-pay-button-black-with-text {
          background-color: black;
          color: white;
      }
      .apple-pay-button-white-with-text {
          background-color: white;
          color: black;
      }
      .apple-pay-button-white-with-line-with-text {
          background-color: white;
          color: black;
          border: .5px solid black;
      }
      .apple-pay-button-with-text.apple-pay-button-black-with-text > .logo {
          background-image: -webkit-named-image(apple-pay-logo-white);
          background-color: black;
      }
      .apple-pay-button-with-text.apple-pay-button-white-with-text > .logo {
          background-image: -webkit-named-image(apple-pay-logo-black);
          background-color: white;
      }
      .apple-pay-button-with-text.apple-pay-button-white-with-line-with-text > .logo {
          background-image: -webkit-named-image(apple-pay-logo-black);
          background-color: black;
      }
      .apple-pay-button-with-text > .text {
          font-family: -apple-system;
          font-size: calc(1em * var(--apple-pay-scale));
          font-weight: 300;
          align-self: center;
          margin-right: calc(2px * var(--apple-pay-scale));
      }
      .apple-pay-button-with-text > .logo {
          width: calc(35px * var(--scale));
          height: 100%;
          background-size: 100% 60%;
          background-repeat: no-repeat;
          background-position: 0 50%;
          margin-left: calc(2px * var(--apple-pay-scale));
          border: none;
      }
  }`

  let onApplePayButtonClicked = () => {
    loggerState.setLogInfo(
      ~value="Apple Pay Button Clicked",
      ~eventName=APPLE_PAY_FLOW,
      ~paymentMethod="APPLE_PAY",
      (),
    )
    setApplePayClicked(_ => true)

    if isInvokeSDKFlow {
      let isDelayedSessionToken =
        props.sessionObj
        ->Belt.Option.getWithDefault(Js.Json.null)
        ->Js.Json.decodeObject
        ->Belt.Option.getWithDefault(Js.Dict.empty())
        ->Js.Dict.get("delayed_session_token")
        ->Belt.Option.getWithDefault(Js.Json.null)
        ->Js.Json.decodeBoolean
        ->Belt.Option.getWithDefault(false)

      if isDelayedSessionToken {
        setShowApplePayLoader(_ => true)
        let bodyDict = PaymentBody.applePayThirdPartySdkBody(~connectors)
        processPayment(bodyDict)
      } else {
        let message = [("applePayButtonClicked", true->Js.Json.boolean)]
        Utils.handlePostMessage(message)
      }
    } else {
      let bodyDict = PaymentBody.applePayRedirectBody(~connectors)
      processPayment(bodyDict)
    }
  }

  React.useEffect1(() => {
    Utils.handlePostMessage([("applePayMounted", true->Js.Json.boolean)])
    let handleApplePayMessages = (ev: Window.event) => {
      let json = try {
        ev.data->Js.Json.parseExn
      } catch {
      | _ => Js.Dict.empty()->Js.Json.object_
      }

      try {
        let dict = json->Utils.getDictFromJson
        if dict->Js.Dict.get("applePayCanMakePayments")->Belt.Option.isSome {
          if isInvokeSDKFlow || paymentExperience == PaymentMethodsRecord.RedirectToURL {
            setShowApplePay(_ => true)
          }
        } else if dict->Js.Dict.get("applePayProcessPayment")->Belt.Option.isSome {
          let token =
            dict
            ->Js.Dict.get("applePayProcessPayment")
            ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
          let bodyDict = PaymentBody.applePayBody(~token, ~connectors)
          processPayment(bodyDict)
        } else if dict->Js.Dict.get("showApplePayButton")->Belt.Option.isSome {
          setApplePayClicked(_ => false)
        } else if dict->Js.Dict.get("applePaySyncPayment")->Belt.Option.isSome {
          syncPayment()
        }
      } catch {
      | _ => Utils.logInfo(Js.log("Error in parsing Apple Pay Data"))
      }
    }
    Window.addEventListener("message", handleApplePayMessages)
    Some(
      () => {
        Utils.handlePostMessage([("applePaySessionAbort", true->Js.Json.boolean)])
        Window.removeEventListener("message", handleApplePayMessages)
      },
    )
  }, [isInvokeSDKFlow])

  React.useEffect0(() => {
    setIsShowOrPayUsing(.prev => prev || showApplePay)
    None
  })

  <div>
    <style> {React.string(css)} </style>
    {if showApplePay {
      if showApplePayLoader {
        <div className="apple-pay-loader-div"> <div className="apple-pay-loader" /> </div>
      } else {
        <button
          disabled=applePayClicked
          className="apple-pay-button-with-text apple-pay-button-black-with-text"
          onClick={_ => onApplePayButtonClicked()}>
          <span className="text"> {React.string("Pay with")} </span> <span className="logo" />
        </button>
      }
    } else {
      React.null
    }}
  </div>
}
