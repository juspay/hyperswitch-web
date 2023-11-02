open Utils
open RecoilAtoms

type props = {
  sessionObj: option<SessionsType.token>,
  list: PaymentMethodsRecord.list,
  thirdPartySessionObj: option<Js.Json.t>,
}

open GooglePayType

let default = (props: props) => {
  let (loggerState, _setLoggerState) = Recoil.useRecoilState(loggerAtom)
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Gpay)
  let sync = PaymentHelpers.usePaymentSync(Some(loggerState), Gpay)
  let isGPayReady = Recoil.useRecoilValueFromAtom(isGooglePayReady)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(isShowOrPayUsing)
  let status = CommonHooks.useScript("https://pay.google.com/gp/p/js/pay.js")
  let isGooglePaySDKFlow = React.useMemo1(() => {
    props.sessionObj->Belt.Option.isSome
  }, [props.sessionObj])
  let isGooglePayThirdPartyFlow = React.useMemo1(() => {
    props.thirdPartySessionObj->Belt.Option.isSome
  }, [props.sessionObj])

  let googlePayPaymentMethodType = switch PaymentMethodsRecord.getPaymentMethodTypeFromList(
    ~list=props.list,
    ~paymentMethod="wallet",
    ~paymentMethodType="google_pay",
  ) {
  | Some(paymentMethodType) => paymentMethodType
  | None => PaymentMethodsRecord.defaultPaymentMethodType
  }

  let paymentExperience =
    googlePayPaymentMethodType.payment_experience->Js.Array2.length == 0
      ? PaymentMethodsRecord.RedirectToURL
      : googlePayPaymentMethodType.payment_experience[0].payment_experience_type

  let isInvokeSDKFlow = React.useMemo1(() => {
    (isGooglePaySDKFlow || isGooglePayThirdPartyFlow) &&
      paymentExperience == PaymentMethodsRecord.InvokeSDK
  }, [props.sessionObj])
  let (connectors, _) = isInvokeSDKFlow
    ? props.list->PaymentUtils.getConnectors(Wallets(Gpay(SDK)))
    : props.list->PaymentUtils.getConnectors(Wallets(Gpay(Redirect)))

  let isDelayedSessionToken = React.useMemo1(() => {
    props.thirdPartySessionObj
    ->Belt.Option.flatMap(Js.Json.decodeObject)
    ->Belt.Option.flatMap(x => x->Js.Dict.get("delayed_session_token"))
    ->Belt.Option.flatMap(Js.Json.decodeBoolean)
    ->Belt.Option.getWithDefault(false)
  }, [props.thirdPartySessionObj])

  let processPayment = (body: array<(string, Js.Json.t)>) => {
    intent(
      ~bodyArr=body,
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey: publishableKey,
      },
      ~handleUserError=true,
      (),
    )
  }

  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      let json = try {
        ev.data->Js.Json.parseExn
      } catch {
      | _ => Js.Dict.empty()->Js.Json.object_
      }
      let dict = json->Utils.getDictFromJson
      if dict->Js.Dict.get("gpayResponse")->Belt.Option.isSome {
        let metadata = dict->getJsonObjectFromDict("gpayResponse")
        let obj = metadata->getDictFromJson->itemToObjMapper
        let body = PaymentBody.gpayBody(~payObj=obj, ~connectors)
        processPayment(body)
      }
      if dict->Js.Dict.get("gpayError")->Belt.Option.isSome {
        Utils.handlePostMessage([("fullscreen", false->Js.Json.boolean)])
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  let (_, buttonType, _) = options.wallets.style.type_
  let (_, heightType, _) = options.wallets.style.height
  let height = switch heightType {
  | GooglePay(val) => val
  | _ => 48
  }

  let getGooglePaymentsClient = () => {
    google({"environment": GlobalVars.isProd ? "PRODUCTION" : "TEST"}->toJson)
  }

  let syncPayment = () => {
    sync(
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey: publishableKey,
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
    if isInvokeSDKFlow {
      if isDelayedSessionToken {
        let bodyDict = PaymentBody.gPayThirdPartySdkBody(~connectors)
        processPayment(bodyDict)
      } else {
        handlePostMessage([
          ("fullscreen", true->Js.Json.boolean),
          ("param", "paymentloader"->Js.Json.string),
          ("iframeId", iframeId->Js.Json.string),
        ])
        options.readOnly ? () : handlePostMessage([("GpayClicked", true->Js.Json.boolean)])
      }
    } else {
      let bodyDict = PaymentBody.gpayRedirectBody(~connectors)
      processPayment(bodyDict)
    }
    loggerState.setLogInfo(
      ~value="",
      ~eventName=PAYMENT_DATA_FILLED,
      ~paymentMethod="GOOGLE_PAY",
      (),
    )
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
    obj->toJson
  }
  let addGooglePayButton = () => {
    let paymentClient = getGooglePaymentsClient()

    let button = paymentClient.createButton(. buttonStyle)
    let gpayWrapper = getElementById(Utils.document, "google-pay-button")
    gpayWrapper.innerHTML = ""
    gpayWrapper.appendChild(. button)
  }
  React.useEffect3(() => {
    if (
      status == "ready" &&
        (isGPayReady ||
        isDelayedSessionToken ||
        paymentExperience == PaymentMethodsRecord.RedirectToURL)
    ) {
      addGooglePayButton()
    }
    None
  }, (status, props, isGPayReady))

  React.useEffect0(() => {
    let handleGooglePayMessages = (ev: Window.event) => {
      let json = try {
        ev.data->Js.Json.parseExn
      } catch {
      | _ => Js.Dict.empty()->Js.Json.object_
      }
      let dict = json->Utils.getDictFromJson
      try {
        if dict->Js.Dict.get("googlePaySyncPayment")->Belt.Option.isSome {
          syncPayment()
        }
      } catch {
      | _ => Utils.logInfo(Js.log("Error in syncing GooglePay Payment"))
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

  setIsShowOrPayUsing(.prev => prev || isRenderGooglePayButton)

  <RenderIf condition={isRenderGooglePayButton}>
    <div
      style={ReactDOMStyle.make(~height=`${height->Belt.Int.toString}px`, ())}
      id="google-pay-button"
      className={`w-full flex flex-row justify-center rounded-md`}
    />
  </RenderIf>
}
