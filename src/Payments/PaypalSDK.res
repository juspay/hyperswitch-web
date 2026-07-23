open PaypalSDKTypes
open PaymentTypeContext

@react.component
let make = (~sessionObj: SessionsType.token) => {
  let paymentMethod = "wallet"
  let paymentMethodType = "paypal"
  let {
    iframeId,
    publishableKey,
    sdkHandleOneClickConfirmPayment,
    clientSecret,
    sdkAuthorization,
  } = Jotai.useAtomValue(JotaiAtoms.keys)
  let sdkHandleIsThere = Jotai.useAtomValue(JotaiAtoms.isPaymentButtonHandlerProvidedAtom)
  let (loggerState, _setLoggerState) = Jotai.useAtom(JotaiAtoms.loggerAtom)
  let areOneClickWalletsRendered = Jotai.useSetAtom(JotaiAtoms.areOneClickWalletsRendered)
  let (isCompleted, setIsCompleted) = React.useState(_ => false)
  let isCallbackUsedVal = Jotai.useAtomValue(JotaiAtoms.isCompleteCallbackUsed)
  let paymentType = usePaymentType()
  let nonPiiAdderessData = PaymentUtils.useNonPiiAddressData()

  let token = sessionObj.token
  let orderDetails = sessionObj.orderDetails->getOrderDetails(paymentType)
  let intent = PaymentHelpers.usePostSessionTokens(Some(loggerState), Paypal, Wallet)
  let confirm = PaymentHelpers.usePaymentIntent(Some(loggerState), Paypal)
  let sessions = Jotai.useAtomValue(JotaiAtoms.sessions)
  let updateSession = Jotai.useAtomValue(JotaiAtoms.updateSession)
  let completeAuthorize = PaymentHelpers.useCompleteAuthorize(Some(loggerState), Paypal)
  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)
  let checkoutScript =
    Window.document(Window.window)->Window.getElementById("braintree-checkout")->Nullable.toOption
  let clientScript =
    Window.document(Window.window)->Window.getElementById("braintree-client")->Nullable.toOption
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let sdkConfigsValue = Jotai.useAtomValue(PaymentUtils.sdkConfigsValue)
  let connectors = React.useMemo(() => {
    SdkConfigParser.getEligibleConnectorsFromPaymentMethods(
      sdkConfigsValue.payment_methods,
      paymentMethod,
      paymentMethodType,
    )
  }, [sdkConfigsValue.payment_methods])
  let isTestMode = Jotai.useAtomValue(JotaiAtoms.isTestMode)

  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()

  let buttonStyle = switch options.wallets.payPal {
  | PaypalConfigObj(cfg) =>
    let (_, _, sharedButtonType, _) = options.wallets.style.type_
    let (_, _, sharedHeightType, _, _) = options.wallets.style.height
    let sharedHeight = switch sharedHeightType {
    | Paypal(val) => val
    | _ => 48
    }
    let sharedLabel = switch sharedButtonType {
    | Paypal(var) => var->getLabel
    | _ => Paypal->getLabel
    }
    let colorStr = switch cfg.color {
    | Some(PaypalGold) => "gold"
    | Some(PaypalBlue) => "blue"
    | Some(PaypalSilver) => "silver"
    | Some(PaypalBlack) => "black"
    | Some(PaypalWhite) => "white"
    | None =>
      options.wallets.style.theme == Outline
        ? "white"
        : options.wallets.style.theme == Dark
        ? "gold"
        : "blue"
    }
    let shapeStr = switch cfg.shape {
    | PaypalRect => "rect"
    | PaypalPill => "pill"
    | PaypalSharp => "sharp"
    }
    let resolvedBorderRadius = cfg.borderRadius->Option.getOr(options.wallets.style.buttonRadius)
    let resolvedHeight = cfg.height->Option.getOr(sharedHeight)

    let style: PaypalSDKTypes.style = {
      layout: "vertical",
      color: colorStr,
      shape: shapeStr,
      label: cfg.label->Option.map(getLabel)->Option.getOr(sharedLabel),
      height: resolvedHeight,
      borderRadius: resolvedBorderRadius,
      disableMaxWidth: true,
    }
    style

  | PaypalConfigString(_) =>
    let (_, _, buttonType, _) = options.wallets.style.type_
    let (_, _, heightType, _, _) = options.wallets.style.height
    let height = switch heightType {
    | Paypal(val) => val
    | _ => 48
    }
    let style: PaypalSDKTypes.style = {
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
      height,
      borderRadius: options.wallets.style.buttonRadius,
      disableMaxWidth: true,
    }
    style
  }
  let handleCloseLoader = () => Utils.messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  let (requiredFields, _, _, resolutionContext) = DynamicFieldsUtils.useSuperpositionRequiredFields(
    ~paymentMethod,
    ~paymentMethodType,
  )

  DynamicFieldsUtils.useLogDynamicFieldsRendered(
    ~fields=requiredFields,
    ~paymentMethod,
    ~resolutionContext,
  )

  UtilityHooks.useHandlePostMessages(
    ~complete=isCompleted,
    ~empty=!isCompleted,
    ~paymentType=paymentMethodType,
  )

  let mountPaypalSDK = () => {
    let clientId = sessionObj.token
    let paypalIntent = sessionObj.intent
    let currency = sessionObj.currency

    let intentParam = if paypalIntent !== "" {
      `&intent=${paypalIntent}`
    } else {
      loggerState.setLogInfo(
        ~value="PayPal SDK: intent is missing from session object, omitting intent param from SDK URL",
        ~eventName=PAYPAL_SDK_FLOW,
      )
      ""
    }

    let currencyParam = if currency !== "" {
      `&currency=${currency}`
    } else {
      loggerState.setLogInfo(
        ~value="PayPal SDK: currency is missing from session object, omitting currency param from SDK URL",
        ~eventName=PAYPAL_SDK_FLOW,
      )
      ""
    }

    let paypalScriptURL = `https://www.paypal.com/sdk/js?client-id=${clientId}&components=buttons,hosted-fields${currencyParam}${intentParam}`
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
        ~connectors,
        ~isGuestCustomer,
        ~postSessionTokens=intent,
        ~isManualRetryEnabled,
        ~options,
        ~publishableKey,
        ~requiredFields,
        ~confirm,
        ~completeAuthorize,
        ~handleCloseLoader,
        ~areOneClickWalletsRendered,
        ~setIsCompleted,
        ~isCallbackUsedVal,
        ~sdkHandleIsThere,
        ~sessions,
        ~clientSecret,
        ~isTestMode,
        ~nonPiiAdderessData,
        ~sdkAuthorization,
        ~emitter,
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
            ~connectors,
            ~isGuestCustomer,
            ~intent,
            ~options,
            ~orderDetails,
            ~publishableKey,
            ~requiredFields,
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
  }, [sdkAuthorization])

  <div
    id="paypal-button"
    style={
      pointerEvents: updateSession ? "none" : "auto",
      opacity: updateSession ? "0.5" : "1.0",
      borderRadius: `${buttonStyle.borderRadius->Int.toString}px`,
    }
    className="w-full flex flex-row justify-center h-auto overflow-hidden"
  />
}

let default = make
