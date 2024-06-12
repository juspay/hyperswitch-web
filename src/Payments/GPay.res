open Utils
open RecoilAtoms

open GooglePayType
open Promise

@react.component
let make = (~sessionObj: option<SessionsType.token>, ~thirdPartySessionObj: option<JSON.t>) => {
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let {publishableKey, sdkHandleOneClickConfirmPayment} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Gpay)
  let sync = PaymentHelpers.usePaymentSync(Some(loggerState), Gpay)
  let isGPayReady = Recoil.useRecoilValueFromAtom(isGooglePayReady)
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

  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

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

  let paymentMethodTypes = DynamicFieldsUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="google_pay",
  )

  let (stateJson, setStatesJson) = React.useState(_ => JSON.Encode.null)

  PaymentUtils.useStatesJson(setStatesJson)

  React.useEffect(() => {
    let handle = (ev: Window.event) => {
      let json = try {
        ev.data->JSON.parseExn
      } catch {
      | _ => Dict.make()->JSON.Encode.object
      }
      let dict = json->getDictFromJson
      if dict->Dict.get("gpayResponse")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("gpayResponse")
        let obj = metadata->getDictFromJson->itemToObjMapper
        let gPayBody = PaymentUtils.appendedCustomerAcceptance(
          ~isGuestCustomer,
          ~paymentType=paymentMethodListValue.payment_type,
          ~body=PaymentBody.gpayBody(~payObj=obj, ~connectors),
        )

        let billingContact =
          obj.paymentMethodData.info
          ->getDictFromJson
          ->getJsonObjectFromDict("billingAddress")
          ->getDictFromJson
          ->billingContactItemToObjMapper

        let shippingContact =
          metadata
          ->getDictFromJson
          ->getJsonObjectFromDict("shippingAddress")
          ->getDictFromJson
          ->billingContactItemToObjMapper

        let email =
          metadata
          ->getDictFromJson
          ->getString("email", "")

        let requiredFieldsBody = DynamicFieldsUtils.getGooglePayRequiredFields(
          ~billingContact,
          ~shippingContact,
          ~paymentMethodTypes,
          ~statesList=stateJson,
          ~email,
        )

        let body = {
          gPayBody
          ->getJsonFromArrayOfJson
          ->flattenObject(true)
          ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
          ->getArrayOfTupleFromDict
        }
        processPayment(body, ())
      }
      if dict->Dict.get("gpayError")->Option.isSome {
        handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  }, (paymentMethodTypes, stateJson))

  let (_, buttonType, _) = options.wallets.style.type_
  let (_, heightType, _, _) = options.wallets.style.height
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
            let paymentDataRequest = getPaymentDataFromSession(~sessionObj, ~componentName)
            handlePostMessage([
              ("fullscreen", true->JSON.Encode.bool),
              ("param", "paymentloader"->JSON.Encode.string),
              ("iframeId", iframeId->JSON.Encode.string),
            ])
            if !options.readOnly {
              handlePostMessage([
                ("GpayClicked", true->JSON.Encode.bool),
                ("GpayPaymentDataRequest", paymentDataRequest->Identity.anyTypeToJson),
              ])
            }
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
        isDelayedSessionToken ||
        paymentExperience == PaymentMethodsRecord.RedirectToURL)
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
      let dict = json->getDictFromJson
      try {
        if dict->Dict.get("googlePaySyncPayment")->Option.isSome {
          syncPayment()
        }
      } catch {
      | _ => logInfo(Console.log("Error in syncing GooglePay Payment"))
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
    isGPayReady || paymentExperience == PaymentMethodsRecord.RedirectToURL || isDelayedSessionToken

  React.useEffect(() => {
    areOneClickWalletsRendered(prev => {
      ...prev,
      isGooglePay: isRenderGooglePayButton,
    })
    None
  }, [isRenderGooglePayButton])

  <RenderIf condition={isRenderGooglePayButton}>
    <div
      style={height: `${height->Int.toString}px`}
      id="google-pay-button"
      className={`w-full flex flex-row justify-center rounded-md`}
    />
  </RenderIf>
}

let default = make
