open PaypalSDKTypes
open Promise
open Utils
open TaxCalculation

let loadPaypalSDK = (
  ~loggerState: HyperLogger.loggerMake,
  ~sdkHandleOneClickConfirmPayment as _,
  ~buttonStyle,
  ~iframeId,
  ~isManualRetryEnabled,
  ~paymentMethodListValue,
  ~isGuestCustomer,
  ~postSessionTokens: PaymentHelpers.paymentIntent,
  ~options: PaymentType.options,
  ~publishableKey,
  ~paymentMethodTypes,
  ~stateJson,
  ~confirm: PaymentHelpers.paymentIntent,
  ~completeAuthorize: PaymentHelpers.completeAuthorize,
  ~handleCloseLoader,
  ~areOneClickWalletsRendered: (
    RecoilAtoms.areOneClickWalletsRendered => RecoilAtoms.areOneClickWalletsRendered
  ) => unit,
  ~setIsCompleted,
  ~isCallbackUsedVal as _: bool,
  ~sdkHandleIsThere: bool,
  ~sessions: PaymentType.loadType,
  ~clientSecret,
) => {
  loggerState.setLogInfo(
    ~value="Paypal SDK Button Clicked",
    ~eventName=PAYPAL_SDK_FLOW,
    ~paymentMethod="PAYPAL",
  )
  let paypalWrapper = GooglePayType.getElementById(Utils.document, "paypal-button")
  paypalWrapper.innerHTML = ""
  setIsCompleted(_ => true)
  let paypalNextAction = switch sessions {
  | Loaded(data) =>
    data
    ->getDictFromJson
    ->getOptionalArrayFromDict("session_token")
    ->Option.flatMap(arr => {
      arr->Array.find(ele => ele->getDictFromJson->getString("connector", "") == "paypal")
    })
    ->Option.flatMap(ele => {
      ele
      ->getDictFromJson
      ->getDictFromDict("sdk_next_action")
      ->getOptionString("next_action")
    })
    ->Option.getOr("")
  | _ => ""
  }
  paypal["Buttons"]({
    style: buttonStyle,
    fundingSource: paypal["FUNDING"]["PAYPAL"],
    createOrder: () => {
      Utils.makeOneClickHandlerPromise(sdkHandleIsThere)->then(result => {
        let result = result->JSON.Decode.bool->Option.getOr(false)
        if result {
          Utils.messageParentWindow([
            ("fullscreen", true->JSON.Encode.bool),
            ("param", "paymentloader"->JSON.Encode.string),
            ("iframeId", iframeId->JSON.Encode.string),
          ])
          let (connectors, _) =
            paymentMethodListValue->PaymentUtils.getConnectors(Wallets(Paypal(SDK)))
          let body = PaymentBody.paypalSdkBody(~token="", ~connectors)
          let modifiedPaymentBody = PaymentUtils.appendedCustomerAcceptance(
            ~isGuestCustomer,
            ~paymentType=paymentMethodListValue.payment_type,
            ~body,
          )
          Promise.make((resolve, _) => {
            if paypalNextAction == "post_session_tokens" {
              postSessionTokens(
                ~bodyArr=modifiedPaymentBody,
                ~confirmParam={
                  return_url: options.wallets.walletReturnUrl,
                  publishableKey,
                },
                ~handleUserError=true,
                ~intentCallback=val => {
                  val
                  ->Utils.getDictFromJson
                  ->Utils.getDictFromDict("nextActionData")
                  ->Utils.getString("order_id", "")
                  ->resolve
                },
                ~manualRetry=isManualRetryEnabled,
              )
            } else {
              confirm(
                ~bodyArr=modifiedPaymentBody,
                ~confirmParam={
                  return_url: options.wallets.walletReturnUrl,
                  publishableKey,
                },
                ~handleUserError=true,
                ~intentCallback=val =>
                  val->Utils.getDictFromJson->Utils.getString("orderId", "")->resolve,
                ~manualRetry=isManualRetryEnabled,
              )
            }
          })
        } else {
          loggerState.setLogInfo(
            ~value="Paypal SDK oneClickDoSubmit - false",
            ~eventName=PAYPAL_SDK_FLOW,
            ~paymentMethod="PAYPAL",
          )
          resolve("")
        }
      })
    },
    onShippingAddressChange: data => {
      let isTaxCalculationEnabled = paymentMethodListValue.is_tax_calculation_enabled
      if isTaxCalculationEnabled {
        let newShippingAddressObj =
          data
          ->getDictFromJson
          ->getDictFromObj("shippingAddress")
          ->shippingAddressItemToObjMapper
        let newShippingAddress =
          [
            ("state", newShippingAddressObj.state->Option.getOr("")->JSON.Encode.string),
            ("country", newShippingAddressObj.countryCode->Option.getOr("")->JSON.Encode.string),
            ("zip", newShippingAddressObj.postalCode->Option.getOr("")->JSON.Encode.string),
          ]->getJsonFromArrayOfJson

        let paymentMethodType = "paypal"->JSON.Encode.string

        calculateTax(
          ~shippingAddress=[("address", newShippingAddress)]->getJsonFromArrayOfJson,
          ~logger=loggerState,
          ~publishableKey,
          ~clientSecret=clientSecret->Option.getOr(""),
          ~paymentMethodType,
          ~sessionId=data->getDictFromJson->Dict.get("orderID"),
        )
      } else {
        Js.Json.null->Js.Promise.resolve
      }
    },
    onApprove: (_data, actions) => {
      if !options.readOnly {
        actions.order.get()
        ->then(val => {
          let purchaseUnit =
            val
            ->Utils.getDictFromJson
            ->Utils.getArray("purchase_units")
            ->Array.get(0)
            ->Option.flatMap(JSON.Decode.object)
            ->Option.getOr(Dict.make())
          let payerDetails =
            val
            ->Utils.getDictFromJson
            ->Dict.get("payer")
            ->Option.flatMap(JSON.Decode.object)
            ->Option.getOr(Dict.make())
            ->PaymentType.itemToPayerDetailsObjectMapper

          let details = purchaseUnit->paypalShippingDetails(payerDetails)
          let requiredFieldsBody = DynamicFieldsUtils.getPaypalRequiredFields(
            ~details,
            ~paymentMethodTypes,
            ~statesList=stateJson,
          )

          let (connectors, _) =
            paymentMethodListValue->PaymentUtils.getConnectors(Wallets(Paypal(SDK)))
          let orderId = val->getDictFromJson->Utils.getString("id", "")
          let body = PaymentBody.paypalSdkBody(~token=orderId, ~connectors)
          let modifiedPaymentBody = PaymentUtils.appendedCustomerAcceptance(
            ~isGuestCustomer,
            ~paymentType=paymentMethodListValue.payment_type,
            ~body,
          )

          let bodyArr =
            requiredFieldsBody
            ->JSON.Encode.object
            ->Utils.unflattenObject
            ->Utils.getArrayOfTupleFromDict

          let confirmBody = bodyArr->Array.concatMany([modifiedPaymentBody])
          Promise.make((_resolve, _) => {
            if paypalNextAction == "post_session_tokens" {
              confirm(
                ~bodyArr=confirmBody,
                ~confirmParam={
                  return_url: options.wallets.walletReturnUrl,
                  publishableKey,
                },
                ~handleUserError=true,
                ~manualRetry=true,
              )
            } else {
              completeAuthorize(
                ~bodyArr,
                ~confirmParam={
                  return_url: options.wallets.walletReturnUrl,
                  publishableKey,
                },
                ~handleUserError=true,
              )
            }
          })
        })
        ->ignore
      }
    },
    onCancel: _data => {
      handleCloseLoader()
    },
    onError: _err => {
      handleCloseLoader()
    },
  }).render("#paypal-button")
  areOneClickWalletsRendered(prev => {
    ...prev,
    isPaypal: true,
  })
}

let loadBraintreePaypalSdk = (
  ~loggerState: HyperLogger.loggerMake,
  ~sdkHandleOneClickConfirmPayment,
  ~token,
  ~buttonStyle,
  ~iframeId,
  ~paymentMethodListValue,
  ~isGuestCustomer,
  ~intent: PaymentHelpers.paymentIntent,
  ~options: PaymentType.options,
  ~orderDetails,
  ~publishableKey,
  ~paymentMethodTypes,
  ~stateJson,
  ~handleCloseLoader,
  ~areOneClickWalletsRendered: (
    RecoilAtoms.areOneClickWalletsRendered => RecoilAtoms.areOneClickWalletsRendered
  ) => unit,
  ~isManualRetryEnabled,
) => {
  loggerState.setLogInfo(
    ~value="Paypal Braintree SDK Button Clicked",
    ~eventName=PAYPAL_SDK_FLOW,
    ~paymentMethod="PAYPAL",
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
                    Utils.messageParentWindow([
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
                            let body = PaymentBody.paypalSdkBody(~token=payload.nonce, ~connectors)

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
                              ~manualRetry=isManualRetryEnabled,
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
