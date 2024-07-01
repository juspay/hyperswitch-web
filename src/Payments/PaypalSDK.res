open PaypalSDKTypes

@react.component
let make = (~sessionObj: SessionsType.token, ~paymentType: CardThemeType.mode) => {
  let {iframeId, publishableKey, sdkHandleOneClickConfirmPayment} = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.keys,
  )
  let (loggerState, _setLoggerState) = Recoil.useRecoilState(RecoilAtoms.loggerAtom)
  let areOneClickWalletsRendered = Recoil.useSetRecoilState(RecoilAtoms.areOneClickWalletsRendered)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let token = sessionObj.token
  let orderDetails = sessionObj.orderDetails->getOrderDetails(paymentType)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Paypal)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let completeAuthorize = PaymentHelpers.useCompleteAuthorize(Some(loggerState), Paypal)
  let checkoutScript =
    Window.document(Window.window)->Window.getElementById("braintree-checkout")->Nullable.toOption
  let clientScript =
    Window.document(Window.window)->Window.getElementById("braintree-client")->Nullable.toOption

  let (stateJson, setStatesJson) = React.useState(_ => JSON.Encode.null)

  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let (_, _, buttonType) = options.wallets.style.type_
  let (_, _, heightType, _) = options.wallets.style.height
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
  }
  let handleCloseLoader = () => Utils.handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  let paymentMethodTypes = DynamicFieldsUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="paypal",
  )

  PaymentUtils.useStatesJson(setStatesJson)

  let mountPaypalSDK = () => {
    let clientId = sessionObj.token
    let paypalScriptURL = `https://www.paypal.com/sdk/js?client-id=${clientId}&components=buttons,hosted-fields`
    loggerState.setLogInfo(~value="PayPal SDK Script Loading", ~eventName=PAYPAL_SDK_FLOW, ())
    let paypalScript = Window.createElement("script")
    paypalScript->Window.elementSrc(paypalScriptURL)
    paypalScript->Window.elementOnerror(exn => {
      let err = exn->Identity.anyTypeToJson->JSON.stringify
      loggerState.setLogError(
        ~value=`Error During Loading PayPal SDK Script: ${err}`,
        ~eventName=PAYPAL_SDK_FLOW,
        (),
      )
    })
    paypalScript->Window.elementOnload(_ => {
      loggerState.setLogInfo(~value="PayPal SDK Script Loaded", ~eventName=PAYPAL_SDK_FLOW, ())
      PaypalSDKHelpers.loadPaypalSDK(
        ~loggerState,
        ~sdkHandleOneClickConfirmPayment,
        ~buttonStyle,
        ~iframeId,
        ~paymentMethodListValue,
        ~isGuestCustomer,
        ~intent,
        ~isManualRetryEnabled,
        ~options,
        ~publishableKey,
        ~paymentMethodTypes,
        ~stateJson,
        ~completeAuthorize,
        ~handleCloseLoader,
        ~areOneClickWalletsRendered,
      )
    })
    Window.body->Window.appendChild(paypalScript)
  }

  React.useEffect(() => {
    try {
      if stateJson->Identity.jsonToNullableJson->Js.Nullable.isNullable->not {
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
              ~stateJson,
              ~handleCloseLoader,
              ~areOneClickWalletsRendered,
              ~isManualRetryEnabled,
            )
          | _ => ()
          }
        }
      }
    } catch {
    | _err => Utils.logInfo(Console.log("Error loading Paypal"))
    }
    None
  }, [stateJson])

  <div id="paypal-button" className="w-full flex flex-row justify-center rounded-md h-auto" />
}

let default = make
