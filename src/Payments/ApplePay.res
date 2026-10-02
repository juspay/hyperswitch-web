open Utils
open Promise
@react.component
let make = (~sessionObj: option<JSON.t>, ~walletOptions) => {
  let paymentMethod = "wallet"
  let paymentMethodType = "apple_pay"
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let loggerState = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  let updateSession = Jotai.useAtomValue(JotaiAtoms.updateSession)
  let sdkHandleIsThere = Jotai.useAtomValue(JotaiAtoms.isPaymentButtonHandlerProvidedAtom)
  let {publishableKey, sdkAuthorization} = Jotai.useAtomValue(JotaiAtoms.keys)
  let isApplePayReady = Jotai.useAtomValue(JotaiAtoms.isApplePayReady)
  let setIsShowOrPayUsing = Jotai.useSetAtom(JotaiAtoms.isShowOrPayUsing)
  let (showApplePay, setShowApplePay) = React.useState(() => false)
  let (showApplePayLoader, setShowApplePayLoader) = React.useState(() => false)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Applepay)
  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)
  let sync = PaymentHelpers.usePaymentSync(Some(loggerState), Applepay)
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let (applePayClicked, setApplePayClicked) = React.useState(_ => false)
  let isApplePaySDKFlow = sessionObj->Option.isSome
  let areOneClickWalletsRendered = Jotai.useSetAtom(JotaiAtoms.areOneClickWalletsRendered)
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let sdkConfigsValue = Jotai.useAtomValue(PaymentUtils.sdkConfigsValue)
  let trustPayScriptStatus = Jotai.useAtomValue(JotaiAtoms.trustPayScriptStatus)
  let isApplePayDelayedSessionFlow = ThirdPartyFlowHelpers.useIsApplePayDelayedSessionFlow()
  let areRequiredFieldsValid = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsEmpty)
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let isWallet = walletOptions->Array.includes(paymentMethodType)
  let isTestMode = Jotai.useAtomValue(JotaiAtoms.isTestMode)

  let (heightType, _, _, _, _) = options.wallets.style.height
  let sharedHeight = switch heightType {
  | ApplePay(val) => val
  | _ => 48
  }

  let (height, buttonColor, buttonType, buttonRadius) = switch options.wallets.applePay {
  | ApplePayConfigObj(cfg) =>
    let styleStr = switch cfg.buttonStyle {
    | Some(ApplePayBlack) => "black"
    | Some(ApplePayWhite) => "white"
    | Some(ApplePayWhiteOutline) => "white-outline"
    | None =>
      switch options.wallets.style.theme {
      | Outline | Light => "white-outline"
      | Dark => "black"
      }
    }
    let typeStr = switch cfg.buttonType {
    | Default => "default"
    | Plain => "plain"
    | Buy => "buy"
    | Donate => "donate"
    | SetUp => "set-up"
    | Book => "book"
    | Checkout => "check-out"
    | Subscribe => "subscribe"
    | AddMoney => "add-money"
    | Contribute => "contribute"
    | Order => "order"
    | Reload => "reload"
    | Rent => "rent"
    | Support => "support"
    | Tip => "tip"
    | TopUp => "top-up"
    }
    (
      cfg.height->Option.getOr(sharedHeight),
      styleStr,
      typeStr,
      cfg.buttonRadius->Option.getOr(options.wallets.style.buttonRadius),
    )
  | ApplePayConfigString(_) => (
      sharedHeight,
      switch options.wallets.style.theme {
      | Outline | Light => "white-outline"
      | Dark => "black"
      },
      "plain",
      options.wallets.style.buttonRadius,
    )
  }

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType=paymentMethodType,
  )
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()
  SubscriptionEventHooks.useEmitFormStatus(
    ~empty=areRequiredFieldsEmpty,
    ~complete=areRequiredFieldsValid,
    ~isOneClickWallet=isWallet,
  )

  let applePayPaymentMethodType = React.useMemo(() => {
    switch PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~paymentMethodListValue,
      ~paymentMethod,
      ~paymentMethodType,
    ) {
    | Some(paymentMethodType) => paymentMethodType
    | None => PaymentMethodsRecord.defaultPaymentMethodType
    }
  }, [paymentMethodListValue])

  let paymentExperience = React.useMemo(() => {
    switch applePayPaymentMethodType.payment_experience[0] {
    | Some(paymentExperience) => paymentExperience.payment_experience_type
    | None => PaymentMethodsRecord.RedirectToURL
    }
  }, [applePayPaymentMethodType])

  let isInvokeSDKFlow = React.useMemo(() => {
    paymentExperience == PaymentMethodsRecord.InvokeSDK && isApplePaySDKFlow
  }, [sessionObj])

  let connectors = React.useMemo(() => {
    SdkConfigParser.getEligibleConnectorsFromPaymentMethods(
      sdkConfigsValue.payment_methods,
      paymentMethod,
      paymentMethodType,
    )
  }, [sdkConfigsValue.payment_methods])

  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  let syncPayment = () => {
    sync(
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey,
      },
      ~handleUserError=true,
    )
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

  // Apple's `<apple-pay-button>` web component (from the Apple Pay JS SDK) renders the
  // official button in Safari and in third-party browsers like Chrome, where the
  // `-webkit-appearance: -apple-pay-button` CSS is not supported.
  let css = `
    .apple-pay-loader-div {
      background-color: ${loaderDivBackgroundColor};
      height: ${height->Int.toString}px;
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
    apple-pay-button {
      display: block;
      width: 100%;
      cursor: pointer;
      --apple-pay-button-width: 100%;
      --apple-pay-button-height: ${height->Int.toString}px;
      --apple-pay-button-border-radius: ${buttonRadius->Int.toString}px;
      --apple-pay-button-padding: 0px 0px;
      --apple-pay-button-box-sizing: border-box;
    }`

  let (isApplePayButtonLoaded, setIsApplePayButtonLoaded) = React.useState(_ => false)

  React.useEffect0(() => {
    ApplePayHelpers.loadApplePayButton()
    ->thenResolve(loaded => setIsApplePayButtonLoaded(_ => loaded))
    ->catch(_ => resolve())
    ->ignore
    None
  })

  let {country, state, pinCode} = PaymentUtils.useNonPiiAddressData()

  let onApplePayButtonClicked = () => {
    if isTestMode {
      Console.warn("Apple Pay button clicked in test mode - interaction disabled")
      loggerState.setLogInfo(
        ~value="Apple Pay button clicked in test mode - interaction disabled",
        ~eventName=APPLE_PAY_FLOW,
        ~paymentMethod="APPLE_PAY",
      )
    } else {
      loggerState.setLogInfo(
        ~value="Apple Pay Button Clicked",
        ~eventName=APPLE_PAY_FLOW,
        ~paymentMethod="APPLE_PAY",
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
      setApplePayClicked(_ => true)
      if isInvokeSDKFlow {
        if isApplePayDelayedSessionFlow {
          setShowApplePayLoader(_ => true)
          let sessionData = sessionObj->getOptionsDict->JSON.Encode.object
          messageParentWindow([
            ("applePayButtonClicked", true->JSON.Encode.bool),
            ("applePayPresent", sessionData),
            ("componentName", componentName->JSON.Encode.string),
          ])
        } else {
          ApplePayHelpers.handleApplePayButtonClicked(
            ~sessionObj,
            ~componentName,
            ~paymentMethodListValue,
          )
        }
      } else {
        makeOneClickHandlerPromise(sdkHandleIsThere)
        ->then(result => {
          let result = result->JSON.Decode.bool->Option.getOr(false)
          if result {
            let bodyDict = PaymentBody.applePayRedirectBody(~connectors)
            ApplePayHelpers.processPayment(
              ~bodyArr=bodyDict,
              ~isGuestCustomer,
              ~paymentMethodListValue,
              ~intent,
              ~options,
              ~publishableKey,
              ~isManualRetryEnabled,
            )
          } else {
            setApplePayClicked(_ => false)
          }
          resolve()
        })
        ->catch(_ => {
          resolve()
        })
        ->ignore
      }
    }
  }

  // `<apple-pay-button>` is a custom element, so a native listener is attached (as per
  // Apple's docs) instead of relying on React's synthetic onClick.
  let applePayButtonRef = React.useRef(Nullable.null)
  let onApplePayButtonClickedRef = React.useRef(onApplePayButtonClicked)
  onApplePayButtonClickedRef.current = onApplePayButtonClicked

  React.useEffect(() => {
    switch applePayButtonRef.current->Nullable.toOption {
    | Some(button) =>
      let handleClick = _ => onApplePayButtonClickedRef.current()
      button->CommonHooks.addEventListener("click", handleClick)
      Some(() => button->CommonHooks.removeEventListener("click", handleClick))
    | None => None
    }
  }, (showApplePay, isApplePayButtonLoaded, showApplePayLoader))

  let (requiredFields, _, _, resolutionContext) = DynamicFieldsUtils.useSuperpositionRequiredFields(
    ~paymentMethod,
    ~paymentMethodType,
  )

  DynamicFieldsUtils.useLogDynamicFieldsRendered(
    ~fields=requiredFields,
    ~paymentMethod,
    ~resolutionContext,
  )

  ApplePayHelpers.useHandleApplePayResponse(
    ~connectors,
    ~intent,
    ~setApplePayClicked,
    ~setShowApplePayLoader,
    ~syncPayment,
    ~isInvokeSDKFlow,
    ~isWallet,
    ~requiredFieldsBody,
    ~requiredFields,
    ~sdkAuthorization,
  )

  // When an Apple Pay session token is present and not delayed, it must carry the merchant
  // session (`session_token_data`); without it merchant validation cannot complete (e.g. in
  // Chrome via Apple's JS SDK), so the button is not shown.
  let hasApplePaySessionTokenData =
    sessionObj->getOptionsDict->getDictFromDict("session_token_data")->Dict.keysToArray->Array.length > 0
  let isApplePaySessionTokenValid =
    !isApplePaySDKFlow || isApplePayDelayedSessionFlow || hasApplePaySessionTokenData

  React.useEffect(() => {
    let isApplePayEligible =
      (isInvokeSDKFlow || paymentExperience === PaymentMethodsRecord.RedirectToURL) &&
      isApplePayReady &&
      isWallet &&
      isApplePaySessionTokenValid

    let isApplePaySessionReady = !isApplePayDelayedSessionFlow || trustPayScriptStatus === Loaded

    if isApplePayEligible && isApplePaySessionReady && isApplePayButtonLoaded {
      setShowApplePay(_ => true)
      areOneClickWalletsRendered(prev => {
        ...prev,
        isApplePay: true,
      })
      setIsShowOrPayUsing(_ => true)
    }
    None
  }, (
    isApplePayReady,
    isInvokeSDKFlow,
    paymentExperience,
    isWallet,
    isApplePayDelayedSessionFlow,
    trustPayScriptStatus,
    isApplePayButtonLoaded,
    isApplePaySessionTokenValid,
  ))

  let submitCallback = ApplePayHelpers.useSubmitCallback(~isWallet, ~sessionObj, ~componentName)
  useSubmitPaymentData(submitCallback)

  let shouldShowWalletShimmer =
    isApplePayDelayedSessionFlow && isApplePayReady && trustPayScriptStatus === Loading

  if isWallet {
    <>
      <RenderIf condition={shouldShowWalletShimmer}>
        <WalletShimmer />
      </RenderIf>
      <RenderIf condition={showApplePay}>
        <div>
          <style> {React.string(css)} </style>
          {if showApplePayLoader {
            <div className="apple-pay-loader-div">
              <div className="apple-pay-loader" />
            </div>
          } else {
            ReactDOM.createDOMElementVariadic(
              "apple-pay-button",
              ~props={
                "buttonstyle": buttonColor,
                "type": buttonType,
                "style": {
                  "opacity": updateSession || applePayClicked ? "0.5" : "1.0",
                  "pointerEvents": updateSession || applePayClicked ? "none" : "auto",
                },
                "ref": applePayButtonRef,
              }->Obj.magic,
              [],
            )
          }}
        </div>
      </RenderIf>
    </>
  } else {
    <>
      <DynamicFields paymentMethod paymentMethodType setRequiredFieldsBody />
      <Terms paymentMethod paymentMethodType />
    </>
  }
}

let default = make
