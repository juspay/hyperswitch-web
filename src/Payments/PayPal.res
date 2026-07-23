open JotaiAtoms

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
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let (paypalClicked, setPaypalClicked) = React.useState(_ => false)
  let sdkHandleIsThere = Jotai.useAtomValue(isPaymentButtonHandlerProvidedAtom)
  let {publishableKey, sdkAuthorization} = Jotai.useAtomValue(keys)
  let options = Jotai.useAtomValue(optionAtom)
  let areOneClickWalletsRendered = Jotai.useSetAtom(areOneClickWalletsRendered)
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let updateSession = Jotai.useAtomValue(updateSession)
  let isTestMode = Jotai.useAtomValue(JotaiAtoms.isTestMode)
  let {country, state, pinCode} = PaymentUtils.useNonPiiAddressData()
  let paymentMethod = "wallet"
  let paymentMethodType = "paypal"
  let isWallet = walletOptions->Array.includes(paymentMethodType)

  // Resolve PayPal button style — per-wallet config takes precedence over shared style
  let (height, buttonColor, textColor, borderRadius) = switch options.wallets.payPal {
  | PaypalConfigObj(cfg) =>
    let (_, _, sharedHeightType, _, _) = options.wallets.style.height
    let sharedHeight = switch sharedHeightType {
    | Paypal(val) => val
    | _ => 48
    }
    let (resolvedBg, resolvedText) = switch cfg.color {
    | Some(PaypalGold) => ("#ffc439", "#000000")
    | Some(PaypalBlue) => ("#0070ba", "#ffffff")
    | Some(PaypalSilver) => ("#eeeeee", "#000000")
    | Some(PaypalBlack) => ("#000000", "#ffffff")
    | Some(PaypalWhite) => ("#ffffff", "#000000")
    | None => options.wallets.style.theme == Light ? ("#0070ba", "#ffffff") : ("#ffc439", "#000000")
    }
    (
      cfg.height->Option.getOr(sharedHeight),
      resolvedBg,
      resolvedText,
      cfg.borderRadius->Option.getOr(options.wallets.style.buttonRadius),
    )
  | PaypalConfigString(_) =>
    let (_, _, heightType, _, _) = options.wallets.style.height
    let height = switch heightType {
    | Paypal(val) => val
    | _ => 48
    }
    let (bg, text) =
      options.wallets.style.theme == Light ? ("#0070ba", "#ffffff") : ("#ffc439", "#000000")
    (height, bg, text, options.wallets.style.buttonRadius)
  }
  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()
  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Paypal)
  UtilityHooks.useHandlePostMessages(
    ~complete=paypalClicked,
    ~empty=!paypalClicked,
    ~paymentType=paymentMethodType,
  )
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()
  SubscriptionEventHooks.useEmitFormStatus(
    ~empty=!paypalClicked,
    ~complete=paypalClicked,
    ~isOneClickWallet=isWallet,
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
        ~paymentMethod,
        ~paymentMethodType,
        ~country,
        ~state,
        ~pinCode,
      )
      emitter.emitPaymentMethodStatus(
        ~paymentMethod,
        ~paymentMethodType,
        ~isSavedPaymentMethod=false,
        ~isOneClickWallet=isWallet,
      )
      emitter.emitBillingAddress(~country, ~state, ~postalCode=pinCode)
      setPaypalClicked(_ => true)
      open Promise
      Utils.makeOneClickHandlerPromise(sdkHandleIsThere)
      ->then(result => {
        let result = result->JSON.Decode.bool->Option.getOr(false)
        if result {
          let body = PaymentBody.dynamicPaymentBody(paymentMethod, paymentMethodType)
          let basePaymentBody = PaymentUtils.appendedCustomerAcceptance(
            ~isGuestCustomer,
            ~paymentType=paymentMethodListValue.payment_type,
            ~body,
            ~alwaysSend=options.alwaysSendCustomerAcceptance,
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
    let areRequiredFieldsValid = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsValid)
    let areRequiredFieldsEmpty = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsEmpty)
    let {localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
    let {iframeId} = Jotai.useAtomValue(JotaiAtoms.keys)

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
    }, (
      areRequiredFieldsValid,
      areRequiredFieldsEmpty,
      isWallet,
      iframeId,
      sdkAuthorization,
      requiredFieldsBody,
    ))
  }

  let submitCallback = useSubmitCallback(~isWallet)
  Utils.useSubmitPaymentData(submitCallback)

  if isWallet {
    <button
      style={
        display: "inline-block",
        color: textColor,
        height: `${height->Int.toString}px`,
        borderRadius: `${borderRadius->Int.toString}px`,
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
    <>
      <DynamicFields paymentMethod paymentMethodType setRequiredFieldsBody />
      <Terms paymentMethod paymentMethodType />
    </>
  }
}

let default = make
