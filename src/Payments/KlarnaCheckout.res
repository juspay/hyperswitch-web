open JotaiAtoms
open Promise

let klarnaIcon = <Icon size=35 width=90 name="klarna" />

@react.component
let make = () => {
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let sdkHandleIsThere = Jotai.useAtomValue(isPaymentButtonHandlerProvidedAtom)
  let {publishableKey} = Jotai.useAtomValue(keys)
  let options = Jotai.useAtomValue(optionAtom)
  let isManualRetryEnabled = Jotai.useAtomValue(isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let sdkConfigsValue = Jotai.useAtomValue(PaymentUtils.sdkConfigsValue)
  let (klarnaClicked, setKlarnaClicked) = React.useState(_ => false)
  let isTestMode = Jotai.useAtomValue(JotaiAtoms.isTestMode)
  let (_, _, _, heightType, _) = options.wallets.style.height
  let height = switch heightType {
  | Klarna(val) => val
  | _ => 48
  }
  let (buttonColor, textColor) =
    options.wallets.style.theme == Light ? ("#0070ba", "#ffffff") : ("#0b051d", "#000000")

  let onKlarnaClick = async _ev => {
    try {
      if isTestMode {
        Console.warn("Klarna checkout button clicked in test mode - interaction disabled")
        loggerState.setLogInfo(
          ~value="Klarna checkout button clicked in test mode - interaction disabled",
          ~eventName=KLARNA_CHECKOUT_FLOW,
          ~paymentMethod="KLARNA",
        )
        resolve()
      } else {
        loggerState.setLogInfo(
          ~value="Klarna Checkout Button Clicked",
          ~eventName=KLARNA_CHECKOUT_FLOW,
          ~paymentMethod="KLARNA",
        )

        setKlarnaClicked(_ => true)

        let result = await Utils.makeOneClickHandlerPromise(sdkHandleIsThere)
        let decodedResult = result->JSON.Decode.bool->Option.getOr(false)

        if decodedResult {
          let connectors = SdkConfigParser.getEligibleConnectorsFromPaymentMethods(
            sdkConfigsValue.payment_methods,
            "pay_later",
            "klarna",
          )
          let body = PaymentBody.klarnaCheckoutBody(~connectors)

          intent(
            ~bodyArr=body,
            ~confirmParam={
              return_url: options.wallets.walletReturnUrl,
              publishableKey,
            },
            ~handleUserError=true,
            ~manualRetry=isManualRetryEnabled,
          )
        } else {
          setKlarnaClicked(_ => false)
        }
        resolve()
      }
    } catch {
    | _ => resolve()
    }
  }

  <button
    style={
      display: "inline-block",
      color: textColor,
      height: `${height->Int.toString}px`,
      borderRadius: `${options.wallets.style.buttonRadius->Int.toString}px`,
      width: "100%",
      backgroundColor: buttonColor,
    }
    onClick={_ =>
      if !options.readOnly {
        onKlarnaClick()->ignore
      }}>
    <div className="justify-center" style={display: "flex", flexDirection: "row", color: textColor}>
      {if klarnaClicked {
        <Loader />
      } else {
        klarnaIcon
      }}
    </div>
  </button>
}

let default = make
