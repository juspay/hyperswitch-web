open PaypalSDKTypes
open Promise

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
  let checkoutScript =
    Window.document(Window.window)->Window.getElementById("braintree-checkout")->Nullable.toOption
  let clientScript =
    Window.document(Window.window)->Window.getElementById("braintree-client")->Nullable.toOption

  let (stateJson, setStatesJson) = React.useState(_ => JSON.Encode.null)

  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let (_, _, buttonType) = options.wallets.style.type_
  let (_, _, heightType) = options.wallets.style.height
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

  let loadPaypalSdk = () => {
    loggerState.setLogInfo(
      ~value="Paypal SDK Button Clicked",
      ~eventName=PAYPAL_SDK_FLOW,
      ~paymentMethod="PAYPAL",
      (),
    )
    Utils.makeOneClickHandlerPromise(sdkHandleOneClickConfirmPayment)
    ->then(result => {
      let result = result->JSON.Decode.bool->Option.getOr(false)
      if result {
        braintree.client.create({authorization: token}, (clientErr, clientInstance) => {
          if clientErr {
            Console.error2("Error creating client", clientErr)
          }
          braintree.paypalCheckout.create(
            {client: clientInstance},
            (paypalCheckoutErr, paypalCheckoutInstance) => {
              switch paypalCheckoutErr->Nullable.toOption {
              | Some(val) => Console.warn(`INTEGRATION ERROR: ${val.message}`)
              | None => ()
              }
              paypalCheckoutInstance.loadPayPalSDK(
                {vault: true},
                () => {
                  let paypalWrapper = GooglePayType.getElementById(Utils.document, "paypal-button")
                  paypalWrapper.innerHTML = ""
                  paypal["Buttons"]({
                    style: buttonStyle,
                    fundingSource: paypal["FUNDING"]["PAYPAL"],
                    createBillingAgreement: () => {
                      //Paypal Clicked
                      Utils.handlePostMessage([
                        ("fullscreen", true->JSON.Encode.bool),
                        ("param", "paymentloader"->JSON.Encode.string),
                        ("iframeId", iframeId->JSON.Encode.string),
                      ])
                      options.readOnly ? () : paypalCheckoutInstance.createPayment(orderDetails)
                    },
                    onApprove: (data, _actions) => {
                      options.readOnly
                        ? ()
                        : paypalCheckoutInstance.tokenizePayment(
                            data,
                            (_err, payload) => {
                              let (connectors, _) =
                                paymentMethodListValue->PaymentUtils.getConnectors(
                                  Wallets(Paypal(SDK)),
                                )
                              let body = PaymentBody.paypalSdkBody(
                                ~token=payload.nonce,
                                ~connectors,
                              )

                              let requiredFieldsBody = DynamicFieldsUtils.getPaypalRequiredFields(
                                ~details=payload.details,
                                ~paymentMethodTypes,
                                ~statesList=stateJson,
                              )

                              let paypalBody =
                                body
                                ->Utils.getJsonFromArrayOfJson
                                ->Utils.flattenObject(true)
                                ->Utils.mergeTwoFlattenedJsonDicts(requiredFieldsBody)
                                ->Utils.getArrayOfTupleFromDict

                              let modifiedPaymentBody = PaymentUtils.appendedCustomerAcceptance(
                                ~isGuestCustomer,
                                ~paymentType=paymentMethodListValue.payment_type,
                                ~body=paypalBody,
                              )

                              intent(
                                ~bodyArr=modifiedPaymentBody,
                                ~confirmParam={
                                  return_url: options.wallets.walletReturnUrl,
                                  publishableKey,
                                },
                                ~handleUserError=true,
                                (),
                              )
                            },
                          )
                    },
                    onCancel: _data => {
                      handleCloseLoader()
                    },
                    onError: _err => {
                      handleCloseLoader()
                    },
                  }).render("#paypal-button")
                  areOneClickWalletsRendered(
                    prev => {
                      ...prev,
                      isPaypal: true,
                    },
                  )
                },
              )
            },
          )
        })->ignore
      }
      resolve()
    })
    ->ignore
  }
  React.useEffect(() => {
    try {
      switch (
        checkoutScript,
        clientScript,
        stateJson->Identity.jsonToNullableJson->Js.Nullable.isNullable,
      ) {
      | (Some(_), Some(_), false) => loadPaypalSdk()
      | (_, _, _) => Utils.logInfo(Console.log("Error loading Paypal"))
      }
    } catch {
    | _err => Utils.logInfo(Console.log("Error loading Paypal"))
    }
    None
  }, [stateJson])

  <div id="paypal-button" className="w-full flex flex-row justify-center rounded-md h-auto" />
}

let default = make
