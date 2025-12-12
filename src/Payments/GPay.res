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
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let isSDKHandleClick = Recoil.useRecoilValueFromAtom(isPaymentButtonHandlerProvidedAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(keys)
  let updateSession = Recoil.useRecoilValueFromAtom(updateSession)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Gpay)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let sync = PaymentHelpers.usePaymentSync(Some(loggerState), Gpay)
  let isGPayReady = Recoil.useRecoilValueFromAtom(isGooglePayReady)
  let isTrustpayScriptReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isTrustpayScriptReady)
  let isTrustpayScriptFailed = Recoil.useRecoilValueFromAtom(RecoilAtoms.isTrustpayScriptFailed)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(isShowOrPayUsing)
  let status = CommonHooks.useScript("https://pay.google.com/gp/p/js/pay.js")
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

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType="google_pay",
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

  let isDelayedSessionToken = React.useMemo(() => {
    thirdPartySessionObj
    ->Option.flatMap(JSON.Decode.object)
    ->Option.flatMap(x => x->Dict.get("delayed_session_token"))
    ->Option.flatMap(JSON.Decode.bool)
    ->Option.getOr(false)
  }, [thirdPartySessionObj])

  GooglePayHelpers.useHandleGooglePayResponse(~connectors, ~intent, ~isWallet, ~requiredFieldsBody)

  let (_, buttonType, _, _) = options.wallets.style.type_
  let (_, heightType, _, _, _) = options.wallets.style.height
  let height = switch heightType {
  | GooglePay(val) => val
  | _ => 48
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
    makeOneClickHandlerPromise(isSDKHandleClick)->then(result => {
      let result = result->JSON.Decode.bool->Option.getOr(false)
      if result {
        if isInvokeSDKFlow || GlobalVars.sdkVersion == V2 {
          if isDelayedSessionToken {
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
  }

  let buttonStyle = {
    let obj = {
      "onClick": onGooglePaymentButtonClicked,
      "buttonType": switch buttonType {
      | GooglePay(var) => var->getLabel
      | _ => Default->getLabel
      },
      "buttonSizeMode": "fill",
      "buttonColor": options.wallets.style.theme == Dark ? "black" : "white",
      "buttonRadius": options.wallets.style.buttonRadius,
    }
    obj->Identity.anyTypeToJson
  }
  let addGooglePayButton = () => {
    let paymentClient = getGooglePaymentsClient()

    let button = paymentClient.createButton(buttonStyle)
    let gpayWrapper = getElementById(Utils.document, "google-pay-button")
    gpayWrapper.innerHTML = ""
    gpayWrapper.appendChild(button)
  }
  React.useEffect(() => {
    if (
      status == "ready" &&
      (isGPayReady ||
      isDelayedSessionToken && isTrustpayScriptReady ||
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
    isTrustpayScriptReady,
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
    (isDelayedSessionToken && isTrustpayScriptReady)) && isWallet

  React.useEffect(() => {
    areOneClickWalletsRendered(prev => {
      ...prev,
      isGooglePay: isRenderGooglePayButton,
    })
    None
  }, [isRenderGooglePayButton])

  let submitCallback = GooglePayHelpers.useSubmitCallback(~isWallet, ~sessionObj, ~componentName)
  useSubmitPaymentData(submitCallback)

  if isWallet {
    <>
      <RenderIf
        condition={sessionObj->Option.isSome && !isTrustpayScriptFailed && !isTrustpayScriptReady}>
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
          className={`w-full flex flex-row justify-center rounded-md`}
        />
      </RenderIf>
    </>
  } else {
    <DynamicFields paymentMethod="wallet" paymentMethodType="google_pay" setRequiredFieldsBody />
  }
}

let default = make
