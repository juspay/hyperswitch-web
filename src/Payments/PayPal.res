open RecoilAtoms

module Loader = {
  @react.component
  let make = () => {
    <div className="w-8 h-8 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600">
      <Icon size=32 name="loader" />
    </div>
  }
}
let payPalIcon = <Icon size=35 width=90 name="paypal" />

@react.component
let make = (~walletOptions) => {
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let (paypalClicked, setPaypalClicked) = React.useState(_ => false)
  let sdkHandleIsThere = Recoil.useRecoilValueFromAtom(isPaymentButtonHandlerProvidedAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let areOneClickWalletsRendered = Recoil.useSetRecoilState(areOneClickWalletsRendered)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let isWallet = walletOptions->Array.includes("paypal")
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let updateSession = Recoil.useRecoilValueFromAtom(updateSession)
  let isTestMode = Recoil.useRecoilValueFromAtom(RecoilAtoms.isTestMode)
  let {country, state, pinCode} = PaymentUtils.useNonPiiAddressData()

  let (_, _, labelType, _) = options.wallets.style.type_
  let _label = switch labelType {
  | Paypal(val) => val->PaypalSDKTypes.getLabel
  | _ => Paypal->PaypalSDKTypes.getLabel
  }
  let (_, _, heightType, _, _) = options.wallets.style.height
  let height = switch heightType {
  | Paypal(val) => val
  | _ => 48
  }
  let (buttonColor, textColor) =
    options.wallets.style.theme == Light ? ("#0070ba", "#ffffff") : ("#ffc439", "#000000")
  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Paypal)
  UtilityHooks.useHandlePostMessages(
    ~complete=paypalClicked,
    ~empty=!paypalClicked,
    ~paymentType="paypal",
  )
  let onPaypalClick = _ev => {
    if isTestMode {
      Console.warn("PayPal button clicked in test mode - interaction disabled")
      loggerState.setLogInfo(
        ~value="PayPal button clicked in test mode - interaction disabled",
        ~eventName=PAYPAL_FLOW,
        ~paymentMethod="PAYPAL",
      )
    } else {
      loggerState.setLogInfo(
        ~value="Paypal Button Clicked",
        ~eventName=PAYPAL_FLOW,
        ~paymentMethod="PAYPAL",
      )
      PaymentUtils.emitPaymentMethodInfo(
        ~paymentMethod="wallet",
        ~paymentMethodType="paypal",
        ~country,
        ~state,
        ~pinCode,
      )
      setPaypalClicked(_ => true)
      open Promise
      Utils.makeOneClickHandlerPromise(sdkHandleIsThere)
      ->then(result => {
        let result = result->JSON.Decode.bool->Option.getOr(false)
        if result {
          let body = switch GlobalVars.sdkVersion {
          | V1 => PaymentBody.dynamicPaymentBody("wallet", "paypal")
          | V2 => PaymentBodyV2.dynamicPaymentBodyV2("wallet", "paypal")
          }
          let basePaymentBody = PaymentUtils.appendedCustomerAcceptance(
            ~isGuestCustomer,
            ~paymentType=paymentMethodListValue.payment_type,
            ~body,
          )
          let modifiedPaymentBody = if isWallet {
            basePaymentBody
          } else {
            basePaymentBody->Utils.mergeAndFlattenToTuples(requiredFieldsBody)
          }

          intent(
            ~bodyArr=modifiedPaymentBody,
            ~confirmParam={
              return_url: options.wallets.walletReturnUrl,
              publishableKey,
            },
            ~handleUserError=true,
            ~manualRetry=isManualRetryEnabled,
          )
        } else {
          setPaypalClicked(_ => false)
        }
        resolve()
      })
      ->catch(_ => resolve())
      ->ignore
    }
  }

  React.useEffect0(() => {
    areOneClickWalletsRendered(prev => {
      ...prev,
      isPaypal: true,
    })
    None
  })

  let useSubmitCallback = (~isWallet) => {
    let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
    let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsEmpty)
    let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

    React.useCallback((ev: Window.event) => {
      if !isWallet {
        let json = ev.data->Utils.safeParse
        let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
        if confirm.doSubmit && areRequiredFieldsValid && !areRequiredFieldsEmpty {
          onPaypalClick(ev)
        } else if areRequiredFieldsEmpty {
          Utils.postFailedSubmitResponse(
            ~errortype="validation_error",
            ~message=localeString.enterFieldsText,
          )
        } else if !areRequiredFieldsValid {
          Utils.postFailedSubmitResponse(
            ~errortype="validation_error",
            ~message=localeString.enterValidDetailsText,
          )
        }
      }
    }, (areRequiredFieldsValid, areRequiredFieldsEmpty, isWallet, iframeId))
  }

  let submitCallback = useSubmitCallback(~isWallet)
  Utils.useSubmitPaymentData(submitCallback)

  if isWallet {
    <button
      style={
        display: "inline-block",
        color: textColor,
        height: `${height->Int.toString}px`,
        borderRadius: `${options.wallets.style.buttonRadius->Int.toString}px`,
        width: "100%",
        backgroundColor: buttonColor,
        pointerEvents: updateSession ? "none" : "auto",
        opacity: updateSession ? "0.5" : "1.0",
      }
      onClick={_ => options.readOnly ? () : onPaypalClick()}>
      <div
        className="justify-center" style={display: "flex", flexDirection: "row", color: textColor}>
        {if !paypalClicked {
          payPalIcon
        } else {
          <Loader />
        }}
      </div>
    </button>
  } else {
    <DynamicFields paymentMethod="wallet" paymentMethodType="paypal" setRequiredFieldsBody />
  }
}

let default = make
