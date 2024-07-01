open PaypalSDKTypes
open Promise

let loadPaypalSDK = (
  ~loggerState: OrcaLogger.loggerMake,
  ~sdkHandleOneClickConfirmPayment,
  ~buttonStyle,
  ~iframeId,
  ~isManualRetryEnabled,
  ~paymentMethodListValue,
  ~isGuestCustomer,
  ~intent: PaymentHelpers.paymentIntent,
  ~options: PaymentType.options,
  ~publishableKey,
  ~paymentMethodTypes,
  ~stateJson,
  ~completeAuthorize: PaymentHelpers.completeAuthorize,
  ~handleCloseLoader,
  ~areOneClickWalletsRendered: (
    RecoilAtoms.areOneClickWalletsRendered => RecoilAtoms.areOneClickWalletsRendered
  ) => unit,
) => {
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
      let paypalWrapper = GooglePayType.getElementById(Utils.document, "paypal-button")
      paypalWrapper.innerHTML = ""
      paypal["Buttons"]({
        style: buttonStyle,
        fundingSource: paypal["FUNDING"]["PAYPAL"],
        createOrder: () => {
          Utils.handlePostMessage([
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
            intent(
              ~bodyArr=modifiedPaymentBody,
              ~confirmParam={
                return_url: options.wallets.walletReturnUrl,
                publishableKey,
              },
              ~handleUserError=true,
              ~intentCallback=val =>
                val->Utils.getDictFromJson->Utils.getString("orderId", "")->resolve,
              ~manualRetry=isManualRetryEnabled,
              (),
            )
          })
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
              let details = purchaseUnit->paypalShippingDetails
              let requiredFieldsBody = DynamicFieldsUtils.getPaypalRequiredFields(
                ~details,
                ~paymentMethodTypes,
                ~statesList=stateJson,
              )

              let bodyArr =
                requiredFieldsBody
                ->JSON.Encode.object
                ->Utils.unflattenObject
                ->Utils.getArrayOfTupleFromDict

              completeAuthorize(
                ~bodyArr,
                ~confirmParam={
                  return_url: options.wallets.walletReturnUrl,
                  publishableKey,
                },
                ~handleUserError=true,
                (),
              )

              resolve()
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
    resolve()
  })
  ->ignore
}

let loadBraintreePaypalSdk = (
  ~loggerState: OrcaLogger.loggerMake,
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
