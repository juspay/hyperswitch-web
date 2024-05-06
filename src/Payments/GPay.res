open Utils
open RecoilAtoms

open GooglePayType

@react.component
let make = (
  ~sessionObj: option<SessionsType.token>,
  ~thirdPartySessionObj: option<JSON.t>,
  ~paymentType: option<CardThemeType.mode>,
  ~walletOptions: array<string>,
) => {
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let {publishableKey, sdkHandleOneClickConfirmPayment} = Recoil.useRecoilValueFromAtom(keys)
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Gpay)
  let sync = PaymentHelpers.usePaymentSync(Some(loggerState), Gpay)
  let isGPayReady = Recoil.useRecoilValueFromAtom(isGooglePayReady)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(isShowOrPayUsing)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsEmpty)
  let status = CommonHooks.useScript("https://pay.google.com/gp/p/js/pay.js")
  let isGooglePaySDKFlow = React.useMemo(() => {
    sessionObj->Option.isSome
  }, [sessionObj])
  let isGooglePayThirdPartyFlow = React.useMemo(() => {
    thirdPartySessionObj->Option.isSome
  }, [sessionObj])
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let areOneClickWalletsRendered = Recoil.useSetRecoilState(RecoilAtoms.areOneClickWalletsRendered)

  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  let googlePayPaymentMethodType = switch PaymentMethodsRecord.getPaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="google_pay",
  ) {
  | Some(paymentMethodType) => paymentMethodType
  | None => PaymentMethodsRecord.defaultPaymentMethodType
  }

  let isWallet = walletOptions->Array.includes("google_pay")
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

  let processPayment = (body: array<(string, JSON.t)>, ~isThirdPartyFlow=false, ()) => {
    intent(
      ~bodyArr=body,
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey,
      },
      ~handleUserError=true,
      ~isThirdPartyFlow,
      (),
    )
  }

  React.useEffect(() => {
    let handle = (ev: Window.event) => {
      let json = try {
        ev.data->JSON.parseExn
      } catch {
      | _ => Dict.make()->JSON.Encode.object
      }
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("gpayResponse")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("gpayResponse")
        let obj = metadata->getDictFromJson->itemToObjMapper
        let gPayBody = PaymentUtils.appendedCustomerAcceptance(
          ~isGuestCustomer,
          ~paymentType=paymentMethodListValue.payment_type,
          ~body=PaymentBody.gpayBody(~payObj=obj, ~connectors),
        )

        let body = {
          gPayBody
          ->Dict.fromArray
          ->JSON.Encode.object
          ->flattenObject(true)
          ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
          ->getArrayOfTupleFromDict
        }
        processPayment(body, ())
      }
      if dict->Dict.get("gpayError")->Option.isSome {
        Utils.handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
        if !isWallet {
          postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
        }
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  }, [requiredFieldsBody])

  let (_, buttonType, _) = options.wallets.style.type_
  let (_, heightType, _) = options.wallets.style.height
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
      (),
    )
  }

  let onGooglePaymentButtonClicked = () => {
    loggerState.setLogInfo(
      ~value="GooglePay Button Clicked",
      ~eventName=GOOGLE_PAY_FLOW,
      ~paymentMethod="GOOGLE_PAY",
      (),
    )
    open Promise
    makeOneClickHandlerPromise(sdkHandleOneClickConfirmPayment)->then(result => {
      let result = result->JSON.Decode.bool->Option.getOr(false)
      if result {
        if isInvokeSDKFlow {
          if isDelayedSessionToken {
            handlePostMessage([
              ("fullscreen", true->JSON.Encode.bool),
              ("param", "paymentloader"->JSON.Encode.string),
              ("iframeId", iframeId->JSON.Encode.string),
            ])
            let bodyDict = PaymentBody.gPayThirdPartySdkBody(~connectors)
            processPayment(bodyDict, ~isThirdPartyFlow=true, ())
          } else {
            handlePostMessage([
              ("fullscreen", true->JSON.Encode.bool),
              ("param", "paymentloader"->JSON.Encode.string),
              ("iframeId", iframeId->JSON.Encode.string),
            ])
            options.readOnly ? () : handlePostMessage([("GpayClicked", true->JSON.Encode.bool)])
          }
        } else {
          let bodyDict = PaymentBody.gpayRedirectBody(~connectors)
          processPayment(bodyDict, ())
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
      isDelayedSessionToken ||
      paymentExperience == PaymentMethodsRecord.RedirectToURL) &&
      isWallet
    ) {
      setIsShowOrPayUsing(_ => true)
      addGooglePayButton()
    }
    None
  }, (status, paymentMethodListValue, sessionObj, thirdPartySessionObj, isGPayReady))

  React.useEffect0(() => {
    let handleGooglePayMessages = (ev: Window.event) => {
      let json = try {
        ev.data->JSON.parseExn
      } catch {
      | _ => Dict.make()->JSON.Encode.object
      }
      let dict = json->Utils.getDictFromJson
      try {
        if dict->Dict.get("googlePaySyncPayment")->Option.isSome {
          syncPayment()
        }
      } catch {
      | _ => Utils.logInfo(Console.log("Error in syncing GooglePay Payment"))
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
    isDelayedSessionToken) && isWallet

  React.useEffect(() => {
    areOneClickWalletsRendered(prev => {
      ...prev,
      isGooglePay: isRenderGooglePayButton,
    })
    None
  }, [isRenderGooglePayButton])

  let submitCallback = (ev: Window.event) => {
    if !isWallet {
      let json = ev.data->JSON.parseExn
      let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
      if confirm.doSubmit && areRequiredFieldsValid && !areRequiredFieldsEmpty {
        handlePostMessage([
          ("fullscreen", true->JSON.Encode.bool),
          ("param", "paymentloader"->JSON.Encode.string),
          ("iframeId", iframeId->JSON.Encode.string),
        ])
        options.readOnly ? () : handlePostMessage([("GpayClicked", true->JSON.Encode.bool)])
      } else if areRequiredFieldsEmpty {
        postFailedSubmitResponse(
          ~errortype="validation_error",
          ~message=localeString.enterFieldsText,
        )
      } else if !areRequiredFieldsValid {
        postFailedSubmitResponse(
          ~errortype="validation_error",
          ~message=localeString.enterValidDetailsText,
        )
      }
    }
  }
  useSubmitPaymentData(submitCallback)

  {
    isWallet
      ? <RenderIf condition={isRenderGooglePayButton}>
          <div
            style={ReactDOMStyle.make(~height=`${height->Belt.Int.toString}px`, ())}
            id="google-pay-button"
            className={`w-full flex flex-row justify-center rounded-md`}
          />
        </RenderIf>
      : <DynamicFields
          paymentType={switch paymentType {
          | Some(val) => val
          | _ => NONE
          }}
          paymentMethod="wallet"
          paymentMethodType="google_pay"
          setRequiredFieldsBody
        />
  }
}

let default = make
