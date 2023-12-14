open RecoilAtoms

module Loader = {
  @react.component
  let make = () => {
    <div className=" w-8 h-8 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600">
      <Icon size=32 name="loader" />
    </div>
  }
}
let payPalIcon = <Icon size=35 width=90 name="paypal" />

@react.component
let make = (~list: PaymentMethodsRecord.list) => {
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let (paypalClicked, setPaypalClicked) = React.useState(_ => false)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let (_, _, labelType) = options.wallets.style.type_
  let _label = switch labelType {
  | Paypal(val) => val->PaypalSDKTypes.getLabel
  | _ => Paypal->PaypalSDKTypes.getLabel
  }
  let (_, _, heightType) = options.wallets.style.height
  let height = switch heightType {
  | Paypal(val) => val
  | _ => 48
  }
  let (buttonColor, textColor) =
    options.wallets.style.theme == Light ? ("#0070ba", "#ffffff") : ("#ffc439", "#000000")
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Paypal)
  let onPaypalClick = _ev => {
    loggerState.setLogInfo(
      ~value="Paypal Button Clicked",
      ~eventName=PAYPAL_FLOW,
      ~paymentMethod="PAYPAL",
      (),
    )
    setPaypalClicked(_ => true)
    let (connectors, _) = list->PaymentUtils.getConnectors(Wallets(Paypal(Redirect)))
    let body = PaymentBody.paypalRedirectionBody(~connectors)
    intent(
      ~bodyArr=body,
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey,
      },
      ~handleUserError=true,
      (),
    )
  }
  <button
    style={ReactDOMStyle.make(
      ~display="inline-block",
      ~color=textColor,
      ~height=`${height->Belt.Int.toString}px`,
      ~borderRadius="2px",
      ~width="100%",
      ~backgroundColor=buttonColor,
      (),
    )}
    onClick={_ => options.readOnly ? () : onPaypalClick()}>
    <div
      className="justify-center"
      style={ReactDOMStyle.make(~display="flex", ~flexDirection="row", ~color=textColor, ())}>
      {if !paypalClicked {
        payPalIcon
      } else {
        <Loader />
      }}
    </div>
  </button>
}

let default = make
