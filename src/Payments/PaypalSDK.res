open PaypalSDKTypes
open PaymentTypeContext

@react.component
let make = (~sessionObj: SessionsType.token) => {
  let {
    iframeId,
    publishableKey,
    sdkHandleOneClickConfirmPayment,
    clientSecret,
  } = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let sdkHandleIsThere = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.isPaymentButtonHandlerProvidedAtom,
  )
  let (loggerState, _setLoggerState) = Recoil.useRecoilState(RecoilAtoms.loggerAtom)
  let areOneClickWalletsRendered = Recoil.useSetRecoilState(RecoilAtoms.areOneClickWalletsRendered)
  let (isCompleted, setIsCompleted) = React.useState(_ => false)
  let isCallbackUsedVal = Recoil.useRecoilValueFromAtom(RecoilAtoms.isCompleteCallbackUsed)
  let paymentType = usePaymentType()
  let nonPiiAdderessData = PaymentUtils.useNonPiiAddressData()

  let token = sessionObj.token
  let orderDetails = sessionObj.orderDetails->getOrderDetails(paymentType)
  let intent = PaymentHelpers.usePostSessionTokens(Some(loggerState), Paypal, Wallet)
  let confirm = PaymentHelpers.usePaymentIntent(Some(loggerState), Paypal)
  let sessions = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let updateSession = Recoil.useRecoilValueFromAtom(RecoilAtoms.updateSession)
  let completeAuthorize = PaymentHelpers.useCompleteAuthorize(Some(loggerState), Paypal)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let checkoutScript =
    Window.document(Window.window)->Window.getElementById("braintree-checkout")->Nullable.toOption
  let clientScript =
    Window.document(Window.window)->Window.getElementById("braintree-client")->Nullable.toOption
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let (_, _, buttonType, _) = options.wallets.style.type_
  let (_, _, heightType, _, _) = options.wallets.style.height
  let buttonStyle = {
    layout: "vertical",
    color: options.wallets.style.theme == Outline
      ? "white"
      : options.wallets.style.theme == Dark
      ? "gold"
      : "blue",
    shape: "rect",
    label: switch buttonType {
    | Paypal(var) => var->getLabel
    | _ => Paypal->getLabel
    },
    height: switch heightType {
    | Paypal(val) => val
    | _ => 48
    },
    disableMaxWidth: true,
  }
  let handleCloseLoader = () => Utils.messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  let paymentMethodTypes = DynamicFieldsUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="paypal",
  )

  UtilityHooks.useHandlePostMessages(
    ~complete=isCompleted,
    ~empty=!isCompleted,
    ~paymentType="paypal",
  )

  let mountPaypalSDK = () => {
    let clientId = sessionObj.token
    let paypalScriptURL = `https://www.paypal.com/sdk/js?client-id=${clientId}&components=buttons,hosted-fields&currency=${paymentMethodListValue.currency}`
    loggerState.setLogInfo(~value="PayPal SDK Script Loading", ~eventName=PAYPAL_SDK_FLOW)
    let paypalScript = Window.createElement("script")
    paypalScript->Window.elementSrc(paypalScriptURL)
    paypalScript->Window.elementOnerror(exn => {
      let err = exn->Identity.anyTypeToJson->JSON.stringify
      loggerState.setLogError(
        ~value=`Error During Loading PayPal SDK Script: ${err}`,
        ~eventName=PAYPAL_SDK_FLOW,
      )
    })
    paypalScript->Window.elementOnload(_ => {
      loggerState.setLogInfo(~value="PayPal SDK Script Loaded", ~eventName=PAYPAL_SDK_FLOW)
      PaypalSDKHelpers.loadPaypalSDK(
        ~loggerState,
        ~sdkHandleOneClickConfirmPayment,
        ~buttonStyle,
        ~iframeId,
        ~paymentMethodListValue,
        ~isGuestCustomer,
        ~postSessionTokens=intent,
        ~isManualRetryEnabled,
        ~options,
        ~publishableKey,
        ~paymentMethodTypes,
        ~confirm,
        ~completeAuthorize,
        ~handleCloseLoader,
        ~areOneClickWalletsRendered,
        ~setIsCompleted,
        ~isCallbackUsedVal,
        ~sdkHandleIsThere,
        ~sessions,
        ~clientSecret,
        ~nonPiiAdderessData,
      )
    })
    Window.body->Window.appendChild(paypalScript)
  }

  React.useEffect(() => {
    try {
      switch sessionObj.connector {
      | "paypal" => mountPaypalSDK()
      | _ =>
        switch (checkoutScript, clientScript) {
        | (Some(_), Some(_)) =>
          PaypalSDKHelpers.loadBraintreePaypalSdk(
            ~loggerState,
            ~sdkHandleOneClickConfirmPayment,
            ~token,
            ~buttonStyle,
            ~iframeId,
            ~paymentMethodListValue,
            ~isGuestCustomer,
            ~intent,
            ~options,
            ~orderDetails,
            ~publishableKey,
            ~paymentMethodTypes,
            ~handleCloseLoader,
            ~areOneClickWalletsRendered,
            ~isManualRetryEnabled,
          )
        | _ => ()
        }
      }
    } catch {
    | _ =>
      loggerState.setLogError(
        ~value="Error loading Paypal",
        ~eventName=PAYPAL_SDK_FLOW,
        // ~internalMetadata=err->Utils.formatException->JSON.stringify,
        ~paymentMethod="PAYPAL_SDK",
      )
    }
    None
  }, [])

  <div
    id="paypal-button"
    style={
      pointerEvents: updateSession || isGiftCardOnlyPayment ? "none" : "auto",
      opacity: updateSession || isGiftCardOnlyPayment ? "0.5" : "1.0",
    }
    className="w-full flex flex-row justify-center rounded-md h-auto"
  />
}

let default = make
