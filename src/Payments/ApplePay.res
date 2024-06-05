open Utils
open Promise
@react.component
let make = (~sessionObj: option<JSON.t>) => {
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let {publishableKey, sdkHandleOneClickConfirmPayment} = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.keys,
  )
  let isApplePayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isApplePayReady)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(RecoilAtoms.isShowOrPayUsing)
  let (showApplePay, setShowApplePay) = React.useState(() => false)
  let (showApplePayLoader, setShowApplePayLoader) = React.useState(() => false)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Applepay)
  let sync = PaymentHelpers.usePaymentSync(Some(loggerState), Applepay)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let (applePayClicked, setApplePayClicked) = React.useState(_ => false)
  let isApplePaySDKFlow = sessionObj->Option.isSome
  let areOneClickWalletsRendered = Recoil.useSetRecoilState(RecoilAtoms.areOneClickWalletsRendered)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let (stateJson, setStatesJson) = React.useState(_ => JSON.Encode.null)

  let applePayPaymentMethodType = React.useMemo(() => {
    switch PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~paymentMethodListValue,
      ~paymentMethod="wallet",
      ~paymentMethodType="apple_pay",
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

  let (connectors, _) = isInvokeSDKFlow
    ? paymentMethodListValue->PaymentUtils.getConnectors(Wallets(ApplePay(SDK)))
    : paymentMethodListValue->PaymentUtils.getConnectors(Wallets(ApplePay(Redirect)))

  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  PaymentUtils.useStatesJson(setStatesJson)

  let processPayment = (bodyArr, ~isThirdPartyFlow=false, ()) => {
    let requestBody = PaymentUtils.appendedCustomerAcceptance(
      ~isGuestCustomer,
      ~paymentType=paymentMethodListValue.payment_type,
      ~body=bodyArr,
    )

    intent(
      ~bodyArr=requestBody,
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey,
      },
      ~handleUserError=true,
      ~isThirdPartyFlow,
      (),
    )
  }

  let syncPayment = () => {
    sync(
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey,
      },
      ~handleUserError=true,
      (),
    )
  }

  let buttonColor = switch options.wallets.style.theme {
  | Outline
  | Light => "white-outline"
  | Dark => "black"
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
      height: 3rem;
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
        -apple-pay-button-type: plain;
    }
    .apple-pay-button-with-text > * {
        display: none;
    }
    .apple-pay-button-black-with-text {
        -apple-pay-button-style: ${buttonColor};
        width: 100%;
        height: 3rem;
        display: flex;
        cursor: pointer;
        border-radius: 2px;
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
          border-radius: 5px;
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

  let onApplePayButtonClicked = () => {
    loggerState.setLogInfo(
      ~value="Apple Pay Button Clicked",
      ~eventName=APPLE_PAY_FLOW,
      ~paymentMethod="APPLE_PAY",
      (),
    )
    setApplePayClicked(_ => true)
    makeOneClickHandlerPromise(sdkHandleOneClickConfirmPayment)
    ->then(result => {
      let result = result->JSON.Decode.bool->Option.getOr(false)
      if result {
        if isInvokeSDKFlow {
          let isDelayedSessionToken =
            sessionObj
            ->Option.getOr(JSON.Encode.null)
            ->JSON.Decode.object
            ->Option.getOr(Dict.make())
            ->Dict.get("delayed_session_token")
            ->Option.getOr(JSON.Encode.null)
            ->JSON.Decode.bool
            ->Option.getOr(false)

          if isDelayedSessionToken {
            setShowApplePayLoader(_ => true)
            let bodyDict = PaymentBody.applePayThirdPartySdkBody(~connectors)
            processPayment(bodyDict, ~isThirdPartyFlow=true, ())
          } else {
            let paymentRequest = ApplePayTypes.getPaymentRequestFromSession(
              ~sessionObj,
              ~componentName,
            )
            let message = [
              ("applePayButtonClicked", true->JSON.Encode.bool),
              ("applePayPaymentRequest", paymentRequest),
            ]
            handlePostMessage(message)
          }
        } else {
          let bodyDict = PaymentBody.applePayRedirectBody(~connectors)
          processPayment(bodyDict, ())
        }
      } else {
        setApplePayClicked(_ => false)
      }
      resolve()
    })
    ->ignore
  }

  let paymentMethodTypes = DynamicFieldsUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="apple_pay",
  )

  React.useEffect(() => {
    let handleApplePayMessages = (ev: Window.event) => {
      let json = try {
        ev.data->JSON.parseExn
      } catch {
      | _ => Dict.make()->JSON.Encode.object
      }

      try {
        let dict = json->getDictFromJson
        if dict->Dict.get("applePayProcessPayment")->Option.isSome {
          let token =
            dict->Dict.get("applePayProcessPayment")->Option.getOr(Dict.make()->JSON.Encode.object)

          let billingContact =
            dict
            ->getDictfromDict("applePayBillingContact")
            ->ApplePayTypes.billingContactItemToObjMapper

          let shippingContact =
            dict
            ->getDictfromDict("applePayShippingContact")
            ->ApplePayTypes.shippingContactItemToObjMapper

          let requiredFieldsBody = DynamicFieldsUtils.getApplePayRequiredFields(
            ~billingContact,
            ~shippingContact,
            ~paymentMethodTypes,
            ~statesList=stateJson,
          )

          let bodyDict = PaymentBody.applePayBody(~token, ~connectors)

          let applePayBody =
            bodyDict
            ->getJsonFromArrayOfJson
            ->flattenObject(true)
            ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
            ->getArrayOfTupleFromDict

          processPayment(applePayBody, ())
        } else if dict->Dict.get("showApplePayButton")->Option.isSome {
          setApplePayClicked(_ => false)
        } else if dict->Dict.get("applePaySyncPayment")->Option.isSome {
          syncPayment()
        }
      } catch {
      | _ => logInfo(Console.log("Error in parsing Apple Pay Data"))
      }
    }
    Window.addEventListener("message", handleApplePayMessages)
    Some(
      () => {
        handlePostMessage([("applePaySessionAbort", true->JSON.Encode.bool)])
        Window.removeEventListener("message", handleApplePayMessages)
      },
    )
  }, (isInvokeSDKFlow, processPayment, stateJson))

  React.useEffect(() => {
    if (
      (isInvokeSDKFlow || paymentExperience == PaymentMethodsRecord.RedirectToURL) &&
        isApplePayReady
    ) {
      setShowApplePay(_ => true)
      areOneClickWalletsRendered(prev => {
        ...prev,
        isApplePay: true,
      })
      setIsShowOrPayUsing(_ => true)
    }
    None
  }, (isApplePayReady, isInvokeSDKFlow, paymentExperience))

  <div>
    <style> {React.string(css)} </style>
    <RenderIf condition={showApplePay}>
      {if showApplePayLoader {
        <div className="apple-pay-loader-div">
          <div className="apple-pay-loader" />
        </div>
      } else {
        <button
          disabled=applePayClicked
          className="apple-pay-button-with-text apple-pay-button-black-with-text"
          onClick={_ => onApplePayButtonClicked()}>
          <span className="text"> {React.string("Pay with")} </span>
          <span className="logo" />
        </button>
      }}
    </RenderIf>
  </div>
}

let default = make
