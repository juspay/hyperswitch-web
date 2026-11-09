open PaypalSDKTypes
open Utils
open TaxCalculation

// Closing the PayPal popup before it finishes loading rejects through onError
// ("Window is closed, can not determine type") instead of onCancel.
// String() covers both Error objects ("Error: Window is closed, ...") and plain string rejections.
let isPopupClosedError = (err: err) => err->String.make->String.includes("Window is closed")

let handlePaypalError = (err, ~handleCancel, ~handleCloseLoader) =>
  if err->isPopupClosedError {
    handleCancel()
  } else {
    handleCloseLoader()
  }

let renderButtons = (buttons: some, ~onButtonSettled, ~details=[]) => {
  try {
    SdkLogger.observeFunction(
      ~event=PaypalButtonsRender,
      ~details,
      ~paymentMethod=Wallet(PaypalSdk),
      ~call=() => buttons.render("#paypal-button"),
    )
    ->Promise.then(_ => Promise.resolve(onButtonSettled()))
    ->Promise.catch(_ => Promise.resolve(onButtonSettled()))
    ->ignore
  } catch {
  | _ => onButtonSettled()
  }
}

let loadPaypalSDK = (
  ~onButtonSettled,
  ~parentOrigin,
  ~sdkHandleOneClickConfirmPayment as _,
  ~buttonStyle: PaypalSDKTypes.style,
  ~iframeId,
  ~isManualRetryEnabled,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
  ~connectors,
  ~isGuestCustomer,
  ~postSessionTokens: PaymentHelpersTypes.paymentIntent,
  ~options: PaymentType.options,
  ~publishableKey,
  ~requiredFields: array<SuperpositionTypes.fieldConfig>,
  ~confirm: PaymentHelpersTypes.paymentIntent,
  ~completeAuthorize: PaymentHelpersTypes.completeAuthorize,
  ~handleCloseLoader,
  ~handleCancel,
  ~areOneClickWalletsRendered: (
    JotaiAtoms.areOneClickWalletsRendered => JotaiAtoms.areOneClickWalletsRendered
  ) => unit,
  ~setIsCompleted,
  ~isCallbackUsedVal as _: bool,
  ~sdkHandleIsThere: bool,
  ~sessions: PaymentType.loadType,
  ~clientSecret,
  ~isTestMode=false,
  ~nonPiiAdderessData: PaymentUtils.nonPiiAdderessData,
  ~sdkAuthorization,
  ~emitter: SubscriptionEventHooks.emitter,
) => {
  open Promise

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
  let paypalButtons = paypal["Buttons"]({
    style: buttonStyle,
    fundingSource: paypal["FUNDING"]["PAYPAL"],
    createOrder: SdkLogger.observeFunctionCallback(
      ~event=CreateOrder,
      ~paymentMethod=Wallet(PaypalSdk),
      ~timeoutMs=LoggerConfig.userGatedTimeoutMs,
      ~callback=() =>
        if isTestMode {
          resolve("")
        } else {
          let {country, state, pinCode} = nonPiiAdderessData
          PaymentUtils.emitPaymentMethodInfo(
            ~paymentMethod="wallet",
            ~paymentMethodType="paypal",
            ~country,
            ~state,
            ~pinCode,
          )
          emitter.emitPaymentMethodStatus(
            ~paymentMethod="wallet",
            ~paymentMethodType="paypal",
            ~isSavedPaymentMethod=false,
            ~isOneClickWallet=true,
          )
          emitter.emitBillingAddress(~country, ~state, ~postalCode=pinCode)
          makeOneClickHandlerPromise(sdkHandleIsThere, ~parentOrigin)->then(result => {
            let result = result->JSON.Decode.bool->Option.getOr(false)
            if result {
              messageParentWindow([
                ("fullscreen", true->JSON.Encode.bool),
                ("param", "paymentloader"->JSON.Encode.string),
                ("iframeId", iframeId->JSON.Encode.string),
              ])
              let body = PaymentBody.paypalSdkBody(~token="", ~connectors)
              let modifiedPaymentBody = PaymentUtils.appendedCustomerAcceptance(
                ~isGuestCustomer,
                ~paymentType=paymentMethodListValue.payment_type,
                ~body,
                ~alwaysSend=options.alwaysSendCustomerAcceptance,
              )
              make(
                (resolve, _) => {
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
                        ->getDictFromJson
                        ->getDictFromDict("nextActionData")
                        ->getString("order_id", "")
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
                        val->getDictFromJson->getString("orderId", "")->resolve,
                      ~manualRetry=isManualRetryEnabled,
                    )
                  }
                },
              )
            } else {
              SdkLogger.logLifecycle(
                ~event=WalletStageReached({stage: OneClickDeclined}),
                ~paymentMethod=Wallet(PaypalSdk),
              )
              resolve("")
            }
          })
        },
    ),
    onShippingAddressChange: SdkLogger.observeFunctionCallback(
      ~event=OnShippingAddressChange,
      ~paymentMethod=Wallet(PaypalSdk),
      ~callback=data => {
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
            ~publishableKey,
            ~clientSecret=clientSecret->Option.getOr(""),
            ~paymentMethodType,
            ~sessionId=data->getDictFromJson->Dict.get("orderID"),
            ~sdkAuthorization,
          )
        } else {
          JSON.Encode.null->resolve
        }
      },
    ),
    onApprove: SdkLogger.observeFunctionCallback(
      ~event=OnApprove,
      ~paymentMethod=Wallet(PaypalSdk),
      ~callback=(_data, actions) => {
        if !options.readOnly {
          actions.order.get()
          ->then(val => {
            let purchaseUnit =
              val
              ->getDictFromJson
              ->getArray("purchase_units")
              ->Array.get(0)
              ->Option.flatMap(JSON.Decode.object)
              ->Option.getOr(Dict.make())
            let payerDetails =
              val
              ->getDictFromJson
              ->Dict.get("payer")
              ->Option.flatMap(JSON.Decode.object)
              ->Option.getOr(Dict.make())
              ->PaymentType.itemToPayerDetailsObjectMapper

            let details = purchaseUnit->paypalShippingDetails(payerDetails)
            let requiredFieldsBody = DynamicFieldsUtils.getPaypalRequiredFields(
              ~details,
              ~requiredFields,
            )

            let orderId = val->getDictFromJson->getString("id", "")
            let body = PaymentBody.paypalSdkBody(~token=orderId, ~connectors)
            let modifiedPaymentBody = PaymentUtils.appendedCustomerAcceptance(
              ~isGuestCustomer,
              ~paymentType=paymentMethodListValue.payment_type,
              ~body,
              ~alwaysSend=options.alwaysSendCustomerAcceptance,
            )

            let bodyArr =
              requiredFieldsBody
              ->JSON.Encode.object
              ->unflattenObject
              ->getArrayOfTupleFromDict

            let confirmBody = bodyArr->Array.concatMany([modifiedPaymentBody])
            make(
              (_resolve, _) => {
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
              },
            )
          })
          ->catch(_ => resolve())
          ->ignore
        }
      },
    ),
    onCancel: SdkLogger.observeFunctionCallback(
      ~event=OnCancel,
      ~paymentMethod=Wallet(PaypalSdk),
      ~callback=_data => handleCancel(),
    ),
    onError: SdkLogger.observeFunctionCallback(
      ~event=OnError,
      ~paymentMethod=Wallet(PaypalSdk),
      ~callback=err => {
        if !(err->isPopupClosedError) {
          SdkLogger.logLifecycle(
            ~event=WalletFlowFailed({reason: PaymentDataFailed}),
            ~paymentMethod=Wallet(PaypalSdk),
            ~exn=err->JsExn.anyToExnInternal,
          )
        }
        err->handlePaypalError(~handleCancel, ~handleCloseLoader)
      },
    ),
    onClick: SdkLogger.observeFunctionCallback(
      ~event=OnClick,
      ~paymentMethod=Wallet(PaypalSdk),
      ~callback=() => (),
    ),
  })
  paypalButtons->renderButtons(~onButtonSettled)
  areOneClickWalletsRendered(prev => {
    ...prev,
    isPaypal: true,
  })
}

let loadBraintreePaypalSdk = (
  ~onButtonSettled,
  ~parentOrigin,
  ~sdkHandleOneClickConfirmPayment,
  ~token,
  ~buttonStyle: PaypalSDKTypes.style,
  ~iframeId,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
  ~connectors,
  ~isGuestCustomer,
  ~intent: PaymentHelpersTypes.paymentIntent,
  ~options: PaymentType.options,
  ~orderDetails,
  ~publishableKey,
  ~requiredFields: array<SuperpositionTypes.fieldConfig>,
  ~handleCloseLoader,
  ~handleCancel,
  ~areOneClickWalletsRendered: (
    JotaiAtoms.areOneClickWalletsRendered => JotaiAtoms.areOneClickWalletsRendered
  ) => unit,
  ~isManualRetryEnabled,
) => {
  open Promise
  makeOneClickHandlerPromise(sdkHandleOneClickConfirmPayment, ~parentOrigin)
  ->then(result => {
    let result = result->JSON.Decode.bool->Option.getOr(false)
    if result {
      braintree.client.create({authorization: token}, (clientErr, clientInstance) => {
        if clientErr {
          Console.error2("Error creating client", clientErr)
          SdkLogger.logLifecycle(
            ~event=WalletFlowFailed({reason: ClientCreationFailed, connector: "braintree"}),
            ~paymentMethod=Wallet(PaypalSdk),
            ~details=[("client", "braintree_client"->JSON.Encode.string)],
          )
        }
        braintree.paypalCheckout.create(
          {client: clientInstance},
          (paypalCheckoutErr, paypalCheckoutInstance) => {
            switch paypalCheckoutErr->Nullable.toOption {
            | Some(val) =>
              Console.warn(`INTEGRATION ERROR: ${val.message}`)
              SdkLogger.logLifecycle(
                ~event=WalletFlowFailed({reason: ClientCreationFailed, connector: "braintree"}),
                ~paymentMethod=Wallet(PaypalSdk),
                ~details=[
                  ("client", "paypal_checkout"->JSON.Encode.string),
                  ("error_message", val.message->JSON.Encode.string),
                ],
              )
            | None => ()
            }
            paypalCheckoutInstance.loadPayPalSDK(
              {vault: true},
              () => {
                let paypalWrapper = GooglePayType.getElementById(Utils.document, "paypal-button")
                paypalWrapper.innerHTML = ""
                let paypalButtons = paypal["Buttons"]({
                  style: buttonStyle,
                  fundingSource: paypal["FUNDING"]["PAYPAL"],
                  createBillingAgreement: SdkLogger.observeFunctionCallback(
                    ~event=CreateBillingAgreement,
                    ~details=[("connector", "braintree"->JSON.Encode.string)],
                    ~paymentMethod=Wallet(PaypalSdk),
                    ~callback=() => {
                      //Paypal Clicked
                      messageParentWindow([
                        ("fullscreen", true->JSON.Encode.bool),
                        ("param", "paymentloader"->JSON.Encode.string),
                        ("iframeId", iframeId->JSON.Encode.string),
                      ])
                      options.readOnly ? () : paypalCheckoutInstance.createPayment(orderDetails)
                    },
                  ),
                  onApprove: SdkLogger.observeFunctionCallback(
                    ~event=OnApprove,
                    ~details=[("connector", "braintree"->JSON.Encode.string)],
                    ~paymentMethod=Wallet(PaypalSdk),
                    ~callback=(data, _actions) =>
                      options.readOnly
                        ? ()
                        : paypalCheckoutInstance.tokenizePayment(
                            data,
                            (_err, payload) => {
                              let body = PaymentBody.paypalSdkBody(
                                ~token=payload.nonce,
                                ~connectors,
                              )

                              let requiredFieldsBody = DynamicFieldsUtils.getPaypalRequiredFields(
                                ~details=payload.details,
                                ~requiredFields,
                              )

                              let paypalBody = body->mergeAndFlattenToTuples(requiredFieldsBody)

                              let modifiedPaymentBody = PaymentUtils.appendedCustomerAcceptance(
                                ~isGuestCustomer,
                                ~paymentType=paymentMethodListValue.payment_type,
                                ~body=paypalBody,
                                ~alwaysSend=options.alwaysSendCustomerAcceptance,
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
                          ),
                  ),
                  onCancel: SdkLogger.observeFunctionCallback(
                    ~event=OnCancel,
                    ~details=[("connector", "braintree"->JSON.Encode.string)],
                    ~paymentMethod=Wallet(PaypalSdk),
                    ~callback=_data => handleCancel(),
                  ),
                  onError: SdkLogger.observeFunctionCallback(
                    ~event=OnError,
                    ~details=[("connector", "braintree"->JSON.Encode.string)],
                    ~paymentMethod=Wallet(PaypalSdk),
                    ~callback=err => {
                      if !(err->isPopupClosedError) {
                        SdkLogger.logLifecycle(
                          ~event=WalletFlowFailed({
                            reason: PaymentDataFailed,
                            connector: "braintree",
                          }),
                          ~paymentMethod=Wallet(PaypalSdk),
                          ~exn=err->JsExn.anyToExnInternal,
                        )
                      }
                      err->handlePaypalError(~handleCancel, ~handleCloseLoader)
                    },
                  ),
                  onClick: SdkLogger.observeFunctionCallback(
                    ~event=OnClick,
                    ~details=[("connector", "braintree"->JSON.Encode.string)],
                    ~paymentMethod=Wallet(PaypalSdk),
                    ~callback=() => (),
                  ),
                })
                paypalButtons->renderButtons(
                  ~onButtonSettled,
                  ~details=[("connector", "braintree"->JSON.Encode.string)],
                )
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
  ->catch(_ => resolve())
  ->ignore
}
