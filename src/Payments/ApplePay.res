open Utils
open Promise
@react.component
let make = (~sessionObj: option<JSON.t>, ~walletOptions) => {
  let paymentMethod = "wallet"
  let paymentMethodType = "apple_pay"
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let updateSession = Recoil.useRecoilValueFromAtom(RecoilAtoms.updateSession)
  let sdkHandleIsThere = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.isPaymentButtonHandlerProvidedAtom,
  )
  let {publishableKey, sdkAuthorization} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isApplePayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isApplePayReady)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(RecoilAtoms.isShowOrPayUsing)
  let (showApplePay, setShowApplePay) = React.useState(() => false)
  let (showApplePayLoader, setShowApplePayLoader) = React.useState(() => false)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Applepay)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let sync = PaymentHelpers.usePaymentSync(Some(loggerState), Applepay)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let (applePayClicked, setApplePayClicked) = React.useState(_ => false)
  let isApplePaySDKFlow = sessionObj->Option.isSome
  let areOneClickWalletsRendered = Recoil.useSetRecoilState(RecoilAtoms.areOneClickWalletsRendered)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let sdkConfigsValue = Recoil.useRecoilValueFromAtom(PaymentUtils.sdkConfigsValue)
  let trustPayScriptStatus = Recoil.useRecoilValueFromAtom(RecoilAtoms.trustPayScriptStatus)
  let isApplePayDelayedSessionFlow = ThirdPartyFlowHelpers.useIsApplePayDelayedSessionFlow()
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsEmpty)
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let isWallet = walletOptions->Array.includes(paymentMethodType)
  let isTestMode = Recoil.useRecoilValueFromAtom(RecoilAtoms.isTestMode)

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

  let css = `@supports (-webkit-appearance: -apple-pay-button) {
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
    .apple-pay-button-with-text {
        display: inline-block;
        -webkit-appearance: -apple-pay-button;
        -apple-pay-button-type: ${buttonType};
    }
    .apple-pay-button-with-text > * {
        display: none;
    }
    .apple-pay-button-black-with-text {
        -apple-pay-button-style: ${buttonColor};
        width: 100%;
        height: ${height->Int.toString}px;
        display: flex;
        cursor: pointer;
        border-radius: ${buttonRadius->Int.toString}px;
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
          border-radius: ${buttonRadius->Int.toString}px;
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

  let (requiredFields, _, _, resolutionContext) = DynamicFieldsUtils.useSuperpositionRequiredFields(
    ~paymentMethod,
    ~paymentMethodType,
  )

  DynamicFieldsUtils.useLogDynamicFieldsRendered(
    ~renderedFields=requiredFields,
    ~requiredFields,
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

  React.useEffect(() => {
    let isApplePayEligible =
      (isInvokeSDKFlow || paymentExperience === PaymentMethodsRecord.RedirectToURL) &&
      isApplePayReady &&
      isWallet

    let isApplePaySessionReady = !isApplePayDelayedSessionFlow || trustPayScriptStatus === Loaded

    if isApplePayEligible && isApplePaySessionReady {
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
            <button
              disabled=applePayClicked
              style={
                opacity: updateSession ? "0.5" : "1.0",
                pointerEvents: updateSession ? "none" : "auto",
              }
              className="apple-pay-button-with-text apple-pay-button-black-with-text"
              onClick={_ => onApplePayButtonClicked()}>
              <span className="text"> {React.string("Pay with")} </span>
              <span className="logo" />
            </button>
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
