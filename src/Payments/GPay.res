open Utils
open RecoilAtoms

open GooglePayType
open Promise

@react.component
let make = (
  ~sessionObj: option<SessionsType.token>,
  ~thirdPartySessionObj: option<JSON.t>,
  ~walletOptions,
) => {
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {iframeId, sdkAuthorization} = Recoil.useRecoilValueFromAtom(keys)
  let isSDKHandleClick = Recoil.useRecoilValueFromAtom(isPaymentButtonHandlerProvidedAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(keys)
  let updateSession = Recoil.useRecoilValueFromAtom(updateSession)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Gpay)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let sync = PaymentHelpers.usePaymentSync(Some(loggerState), Gpay)
  let isGPayReady = Recoil.useRecoilValueFromAtom(isGooglePayReady)
  let trustPayScriptStatus = Recoil.useRecoilValueFromAtom(RecoilAtoms.trustPayScriptStatus)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(isShowOrPayUsing)
  let status = CommonHooks.useScript("https://pay.google.com/gp/p/js/pay.js")
  let isGooglePayDelayedSessionFlow = ThirdPartyFlowHelpers.useIsGooglePayDelayedSessionFlow()
  let isGooglePaySDKFlow = React.useMemo(() => {
    sessionObj->Option.isSome
  }, [sessionObj])
  let isGooglePayThirdPartyFlow = React.useMemo(() => {
    thirdPartySessionObj->Option.isSome
  }, [sessionObj])
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let areOneClickWalletsRendered = Recoil.useSetRecoilState(RecoilAtoms.areOneClickWalletsRendered)

  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsEmpty)
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let isWallet = walletOptions->Array.includes("google_pay")
  let isTestMode = Recoil.useRecoilValueFromAtom(RecoilAtoms.isTestMode)

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType="google_pay",
  )
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()
  SubscriptionEventHooks.useEmitFormStatus(
    ~empty=areRequiredFieldsEmpty,
    ~complete=areRequiredFieldsValid,
    ~isOneClickWallet=isWallet,
  )

  let googlePayPaymentMethodType = switch PaymentMethodsRecord.getPaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="google_pay",
  ) {
  | Some(paymentMethodType) => paymentMethodType
  | None => PaymentMethodsRecord.defaultPaymentMethodType
  }

  let paymentExperience = switch googlePayPaymentMethodType.payment_experience[0] {
  | Some(paymentExperience) => paymentExperience.payment_experience_type
  | None => PaymentMethodsRecord.RedirectToURL
  }

  let isInvokeSDKFlow = React.useMemo(() => {
    (isGooglePaySDKFlow || isGooglePayThirdPartyFlow) &&
      paymentExperience == PaymentMethodsRecord.InvokeSDK
  }, [sessionObj])
  let (connectors, _) = isInvokeSDKFlow
    ? paymentMethodListValue->PaymentUtils.getConnectors(Wallets(Gpay(SDK)))
    : paymentMethodListValue->PaymentUtils.getConnectors(Wallets(Gpay(Redirect)))

  GooglePayHelpers.useHandleGooglePayResponse(
    ~connectors,
    ~intent,
    ~isWallet,
    ~requiredFieldsBody,
    ~sdkAuthorization,
  )

  let (
    height,
    resolvedButtonColor,
    resolvedButtonType,
    resolvedButtonRadius,
    resolvedButtonBorderType,
  ) = switch options.wallets.googlePay {
  | GooglePayConfigObj(cfg) =>
    let (_, heightType, _, _, _) = options.wallets.style.height
    let sharedHeight = switch heightType {
    | GooglePay(val) => val
    | _ => 48
    }
    let (_, sharedButtonType, _, _) = options.wallets.style.type_
    let sharedGPayButtonType = switch sharedButtonType {
    | GooglePay(v) => v
    | _ => Default
    }
    let colorStr = switch cfg.buttonColor {
    | GPayBlack => "black"
    | GPayWhite => "white"
    | GPayDefault => options.wallets.style.theme == Dark ? "black" : "white"
    }
    let borderTypeStr = switch cfg.buttonBorderType {
    | GPayNoBorder => Some("no_border")
    | GPayDefaultBorder => None
    }
    (
      cfg.height->Option.getOr(sharedHeight),
      colorStr,
      cfg.buttonType->Option.getOr(sharedGPayButtonType),
      cfg.buttonRadius->Option.getOr(options.wallets.style.buttonRadius),
      borderTypeStr,
    )
  | GooglePayConfigString(_) =>
    let (_, buttonType, _, _) = options.wallets.style.type_
    let (_, heightType, _, _, _) = options.wallets.style.height
    let height = switch heightType {
    | GooglePay(val) => val
    | _ => 48
    }
    (
      height,
      options.wallets.style.theme == Dark ? "black" : "white",
      switch buttonType {
      | GooglePay(v) => v
      | _ => Default
      },
      options.wallets.style.buttonRadius,
      None,
    )
  }

  let getGooglePaymentsClient = () => {
    google({"environment": GlobalVars.isProd ? "PRODUCTION" : "TEST"}->Identity.anyTypeToJson)
  }

  let syncPayment = () => {
    sync(
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey,
      },
      ~handleUserError=true,
    )
  }
  let {country, state, pinCode} = PaymentUtils.useNonPiiAddressData()

  let onGooglePaymentButtonClicked = () => {
    if isTestMode {
      Console.warn("Google Pay button clicked in test mode - interaction disabled")
      loggerState.setLogInfo(
        ~value="Google Pay button clicked in test mode - interaction disabled",
        ~eventName=GOOGLE_PAY_FLOW,
        ~paymentMethod="GOOGLE_PAY",
      )
    } else {
      loggerState.setLogInfo(
        ~value="GooglePay Button Clicked",
        ~eventName=GOOGLE_PAY_FLOW,
        ~paymentMethod="GOOGLE_PAY",
      )
      PaymentUtils.emitPaymentMethodInfo(
        ~paymentMethod="wallet",
        ~paymentMethodType="google_pay",
        ~country,
        ~state,
        ~pinCode,
      )
      emitter.emitPaymentMethodStatus(
        ~paymentMethod="wallet",
        ~paymentMethodType="google_pay",
        ~isSavedPaymentMethod=false,
        ~isOneClickWallet=isWallet,
      )
      emitter.emitBillingAddress(~country, ~state, ~postalCode=pinCode)
      makeOneClickHandlerPromise(isSDKHandleClick)
      ->then(result => {
        let result = result->JSON.Decode.bool->Option.getOr(false)
        if result {
          if isInvokeSDKFlow {
            if isGooglePayDelayedSessionFlow {
              messageParentWindow([
                ("fullscreen", true->JSON.Encode.bool),
                ("param", "paymentloader"->JSON.Encode.string),
                ("iframeId", iframeId->JSON.Encode.string),
              ])
              let bodyDict = PaymentBody.gPayThirdPartySdkBody(~connectors)
              GooglePayHelpers.processPayment(
                ~body=bodyDict,
                ~isThirdPartyFlow=true,
                ~intent,
                ~options,
                ~publishableKey,
                ~isManualRetryEnabled,
              )
            } else {
              GooglePayHelpers.handleGooglePayClicked(
                ~sessionObj,
                ~componentName,
                ~iframeId,
                ~readOnly=options.readOnly,
              )
            }
          } else {
            let bodyDict = PaymentBody.gpayRedirectBody(~connectors)
            GooglePayHelpers.processPayment(
              ~body=bodyDict,
              ~intent,
              ~options,
              ~publishableKey,
              ~isManualRetryEnabled,
            )
          }
        }
        resolve()
      })
      ->catch(_ => resolve())
      ->ignore
    }
  }

  let buttonStyle = {
    let base = {
      "onClick": onGooglePaymentButtonClicked,
      "buttonType": resolvedButtonType->getLabel,
      "buttonSizeMode": "fill",
      "buttonColor": resolvedButtonColor,
      "buttonRadius": resolvedButtonRadius,
    }
    let obj = switch resolvedButtonBorderType {
    | Some(borderType) =>
      base
      ->Identity.anyTypeToJson
      ->JSON.Decode.object
      ->Option.getOr(Dict.make())
      ->Dict.toArray
      ->Array.concat([("buttonBorderType", borderType->JSON.Encode.string)])
      ->Dict.fromArray
      ->JSON.Encode.object
    | None => base->Identity.anyTypeToJson
    }
    obj
  }
  let addGooglePayButton = () => {
    let paymentClient = getGooglePaymentsClient()

    let button = paymentClient.createButton(buttonStyle)
    button->AccessibilityUtils.setAccessibleLabelAndTitle("Google Pay")
    let gpayWrapper = getElementById(Utils.document, "google-pay-button")
    gpayWrapper.innerHTML = ""
    gpayWrapper.appendChild(button)
  }
  React.useEffect(() => {
    if (
      status == "ready" &&
      (isGPayReady ||
      isGooglePayDelayedSessionFlow && trustPayScriptStatus === Loaded ||
      paymentExperience == PaymentMethodsRecord.RedirectToURL) &&
      isWallet
    ) {
      setIsShowOrPayUsing(_ => true)
      addGooglePayButton()
    }
    None
  }, (
    status,
    paymentMethodListValue,
    sessionObj,
    thirdPartySessionObj,
    isGPayReady,
    trustPayScriptStatus,
    isGooglePayDelayedSessionFlow,
  ))

  React.useEffect0(() => {
    let handleGooglePayMessages = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->getDictFromJson
      try {
        if dict->Dict.get("googlePaySyncPayment")->Option.isSome {
          syncPayment()
        }
      } catch {
      | _ =>
        loggerState.setLogError(
          ~value="Error in syncing GooglePay Payment",
          ~eventName=GOOGLE_PAY_FLOW,
          // ~internalMetadata=err->formatException->JSON.stringify,
          ~paymentMethod="GOOGLE_PAY",
        )
      }
    }
    Window.addEventListener("message", handleGooglePayMessages)
    Some(
      () => {
        Window.removeEventListener("message", handleGooglePayMessages)
      },
    )
  })

  let isRenderGooglePayButton =
    (isGPayReady ||
    paymentExperience == PaymentMethodsRecord.RedirectToURL ||
    (isGooglePayDelayedSessionFlow && trustPayScriptStatus === Loaded)) && isWallet

  let shouldShowWalletShimmer = isGooglePayDelayedSessionFlow && trustPayScriptStatus === Loading

  React.useEffect(() => {
    areOneClickWalletsRendered(prev => {
      ...prev,
      isGooglePay: isRenderGooglePayButton,
    })
    None
  }, [isRenderGooglePayButton])

  let submitCallback = GooglePayHelpers.useSubmitCallback(~isWallet, ~sessionObj, ~componentName)
  useSubmitPaymentData(submitCallback)

  let paymentMethod = "wallet"
  let paymentMethodType = "google_pay"

  if isWallet {
    <>
      <RenderIf condition={shouldShowWalletShimmer}>
        <WalletShimmer />
      </RenderIf>
      <RenderIf condition={isRenderGooglePayButton}>
        <div
          style={
            height: `${height->Int.toString}px`,
            pointerEvents: updateSession ? "none" : "auto",
            opacity: updateSession ? "0.5" : "1.0",
          }
          id="google-pay-button"
          ariaLabel="Google Pay"
          className={`w-full flex flex-row justify-center rounded-md`}
        />
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
