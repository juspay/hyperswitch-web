open ApplePayTypes
open Utils
open TaxCalculation
open BraintreeHelpers

let applePaySessionAbortedBySdk = ref(false)

let abortApplePaySession = session => {
  applePaySessionAbortedBySdk := true
  try session.abort() catch {
  | error => Console.error2("Abort fail", error)
  }
}

let processPayment = (
  ~bodyArr,
  ~isThirdPartyFlow=false,
  ~isGuestCustomer,
  ~paymentMethodListValue=PaymentMethodsRecord.defaultList,
  ~intent: PaymentHelpersTypes.paymentIntent,
  ~options: PaymentType.options,
  ~publishableKey,
  ~isManualRetryEnabled,
  ~isTrustpayInterceptorConfirm=false,
) => {
  let requestBody = PaymentUtils.appendedCustomerAcceptance(
    ~isGuestCustomer,
    ~paymentType=paymentMethodListValue.payment_type,
    ~body=bodyArr,
    ~alwaysSend=options.alwaysSendCustomerAcceptance,
  )

  intent(
    ~bodyArr=requestBody,
    ~confirmParam={
      return_url: options.wallets.walletReturnUrl,
      publishableKey,
    },
    ~handleUserError=true,
    ~isThirdPartyFlow,
    ~manualRetry=isManualRetryEnabled,
    ~isTrustpayInterceptorConfirm,
  )
}

let getApplePayFromResponse = (
  ~token,
  ~billingContactDict,
  ~shippingContactDict,
  ~requiredFields: array<SuperpositionTypes.fieldConfig>=[],
  ~connectors,
  ~isPaymentSession=false,
  ~isSavedMethodsFlow=false,
) => {
  let billingContact = billingContactDict->ApplePayTypes.billingContactItemToObjMapper

  let shippingContact = shippingContactDict->ApplePayTypes.shippingContactItemToObjMapper

  let requiredFieldsBody = if isPaymentSession || isSavedMethodsFlow {
    DynamicFieldsUtils.getApplePayRequiredFields(~billingContact, ~shippingContact)
  } else {
    DynamicFieldsUtils.getApplePayRequiredFields(
      ~billingContact,
      ~shippingContact,
      ~requiredFieldPaths=requiredFields->Array.map(fieldConfig =>
        fieldConfig.confirmRequestWritePath
      ),
    )
  }

  let bodyDict = PaymentBody.applePayBody(~token, ~connectors)

  bodyDict->mergeAndFlattenToTuples(requiredFieldsBody)
}

let startApplePaySession = (
  ~paymentRequest,
  ~applePaySessionRef,
  ~applePayPresent,
  ~callBackFunc,
  ~resolvePromise,
  ~clientSecret,
  ~publishableKey,
  ~isTaxCalculationEnabled=false,
  ~sdkAuthorization=None,
) => {
  open Promise
  let sdkHandleIsThere = LoaderPaymentElement.isPaymentButtonHandlerProvided.contents
  let ssn = applePaySession(3, paymentRequest)
  switch applePaySessionRef.contents->Nullable.toOption {
  | Some(session) => session->abortApplePaySession
  | None => ()
  }

  applePaySessionRef := ssn->Nullable.make

  let handleValidateMerchant = (_event: ApplePayTypes.event) =>
    makeOneClickHandlerPromise(sdkHandleIsThere)
    ->then(result => {
      let result = result->JSON.Decode.bool->Option.getOr(false)
      if result {
        let merchantSession =
          applePayPresent
          ->Belt.Option.flatMap(JSON.Decode.object)
          ->Option.getOr(Dict.make())
          ->Dict.get("session_token_data")
          ->Option.getOr(Dict.make()->JSON.Encode.object)
          ->transformKeysWithoutModifyingValue(CamelCase)
        ssn.completeMerchantValidation(merchantSession)
      } else {
        ssn.completeMerchantValidation(Dict.make()->JSON.Encode.object)
        handleFailureResponse(
          ~message="ApplePay Merchant Validation Cancelled",
          ~errorType="apple_pay",
        )->resolvePromise
      }
      resolve()
    })
    ->catch(_ => {
      ssn.completeMerchantValidation(Dict.make()->JSON.Encode.object)
      handleFailureResponse(
        ~message="ApplePay Merchant Validation failed",
        ~errorType="apple_pay",
      )->resolvePromise
      resolve()
    })

  let handleShippingContactSelected = (
    shippingAddressChangeEvent: ApplePayTypes.shippingAddressChangeEvent,
  ) => {
    let currentTotal = paymentRequest->getDictFromJson->getDictFromDict("total")
    let label = currentTotal->getString("label", "apple")
    let currentAmount = currentTotal->getString("amount", "0.00")
    let \"type" = currentTotal->getString("type", "final")

    let oldTotal: lineItem = {
      label,
      amount: currentAmount,
      \"type",
    }
    let currentOrderDetails: orderDetails = {
      newTotal: oldTotal,
      newLineItems: [oldTotal],
    }
    if isTaxCalculationEnabled {
      let newShippingContact =
        shippingAddressChangeEvent.shippingContact
        ->getDictFromJson
        ->shippingContactItemToObjMapper
      let newShippingAddress =
        [
          ("state", newShippingContact.administrativeArea->JSON.Encode.string),
          ("country", newShippingContact.countryCode->JSON.Encode.string),
          ("zip", newShippingContact.postalCode->JSON.Encode.string),
        ]->getJsonFromArrayOfJson

      let paymentMethodType = "apple_pay"->JSON.Encode.string

      calculateTax(
        ~shippingAddress=[("address", newShippingAddress)]->getJsonFromArrayOfJson,
        ~publishableKey,
        ~clientSecret,
        ~paymentMethodType,
        ~sdkAuthorization,
      )->thenResolve(response => {
        switch response->taxResponseToObjMapper {
        | Some(taxCalculationResponse) => {
            let (netAmount, ordertaxAmount, shippingCost) = (
              taxCalculationResponse.net_amount,
              taxCalculationResponse.order_tax_amount,
              taxCalculationResponse.shipping_cost,
            )
            let newTotal: lineItem = {
              label,
              amount: netAmount->minorUnitToString,
              \"type",
            }
            let newLineItems: array<lineItem> = [
              {
                label: "Subtotal",
                amount: (netAmount - ordertaxAmount - shippingCost)->minorUnitToString,
                \"type": "final",
              },
              {
                label: "Order Tax Amount",
                amount: ordertaxAmount->minorUnitToString,
                \"type": "final",
              },
              {
                label: "Shipping Cost",
                amount: shippingCost->minorUnitToString,
                \"type": "final",
              },
            ]
            let updatedOrderDetails: orderDetails = {
              newTotal,
              newLineItems,
            }
            ssn.completeShippingContactSelection(updatedOrderDetails)
          }
        | None => ssn.completeShippingContactSelection(currentOrderDetails)
        }
      })
    } else {
      ssn.completeShippingContactSelection(currentOrderDetails)
      resolve()
    }
  }

  let handlePaymentAuthorized = (event: ApplePayTypes.event) => {
    ssn.completePayment({"status": ssn.\"STATUS_SUCCESS"}->Identity.anyTypeToJson)
    applePaySessionRef := Nullable.null
    SdkLogger.logLifecycle(~event=WalletTokenReceived, ~paymentMethod=Wallet(ApplePay))

    let payment = event.payment
    payment->callBackFunc
  }

  let handleCancel = () => {
    applePaySessionRef := Nullable.null
    let abortedBySdk = applePaySessionAbortedBySdk.contents
    applePaySessionAbortedBySdk := false
    let message = "ApplePay Session Cancelled"
    if abortedBySdk {
      SdkLogger.logLifecycle(~event=WalletFlowExited, ~paymentMethod=Wallet(ApplePay), ~message)
    }
    handleFailureResponse(~message, ~errorType="apple_pay")->resolvePromise
  }

  let validateMerchant = SdkLogger.observeFunctionCallback(
    ~event=OnValidateMerchant,
    ~paymentMethod=Wallet(ApplePay),
    ~timeoutMs=LoggerRuntime.userGatedTimeoutMs,
    ~callback=handleValidateMerchant,
  )
  ssn.onvalidatemerchant = event => validateMerchant(event)->ignore

  ssn.onshippingcontactselected = SdkLogger.observeFunctionCallback(
    ~event=OnShippingContactSelected,
    ~paymentMethod=Wallet(ApplePay),
    ~callback=handleShippingContactSelected,
  )

  ssn.onpaymentauthorized = SdkLogger.observeFunctionCallback(
    ~event=OnPaymentAuthorized,
    ~paymentMethod=Wallet(ApplePay),
    ~callback=handlePaymentAuthorized,
  )

  ssn.oncancel = SdkLogger.observeFunctionCallback(
    ~event=OnCancel,
    ~paymentMethod=Wallet(ApplePay),
    ~callback=handleCancel,
  )

  ssn.begin()
}

let useHandleApplePayResponse = (
  ~connectors,
  ~intent,
  ~setApplePayClicked=_ => (),
  ~setShowApplePayLoader=_ => (),
  ~syncPayment=() => (),
  ~isInvokeSDKFlow=true,
  ~isSavedMethodsFlow=false,
  ~isWallet=true,
  ~requiredFieldsBody=Dict.make(),
  ~requiredFields: array<SuperpositionTypes.fieldConfig>=[],
  ~sdkAuthorization,
) => {
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let {publishableKey} = Jotai.useAtomValue(JotaiAtoms.keys)
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)

  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)

  React.useEffect(() => {
    let handleApplePayMessages = (ev: Window.event) => {
      let json = ev.data->safeParse
      let parsed = try Ok(json->getDictFromJson) catch {
      | exn => Error(exn)
      }
      switch parsed {
      | Error(exn) =>
        SdkLogger.logLifecycle(
          ~event=WalletFlowFailed({reason: MessageHandlingFailed}),
          ~paymentMethod=Wallet(ApplePay),
          ~exn,
        )
      | Ok(dict) =>
        if (
          dict->Dict.get("applePayPaymentToken")->Option.isSome &&
            dict->Utils.getBool("isSavedMethodsFlow", false) === isSavedMethodsFlow
        ) {
          let token =
            dict->Dict.get("applePayPaymentToken")->Option.getOr(Dict.make()->JSON.Encode.object)

          let billingContactDict = dict->getDictFromDict("applePayBillingContact")
          let shippingContactDict = dict->getDictFromDict("applePayShippingContact")

          let applePayBody = getApplePayFromResponse(
            ~token,
            ~billingContactDict,
            ~shippingContactDict,
            ~requiredFields,
            ~connectors,
            ~isSavedMethodsFlow,
          )

          let bodyArr = if isWallet {
            applePayBody
          } else {
            applePayBody->mergeAndFlattenToTuples(requiredFieldsBody)
          }

          processPayment(
            ~bodyArr,
            ~isThirdPartyFlow=false,
            ~isGuestCustomer,
            ~paymentMethodListValue,
            ~intent,
            ~options,
            ~publishableKey,
            ~isManualRetryEnabled,
          )
        } else if dict->Dict.get("showApplePayButton")->Option.isSome {
          setApplePayClicked(_ => false)
          setShowApplePayLoader(_ => false)
          if isSavedMethodsFlow || !isWallet {
            let message = "Something went wrong"
            SdkLogger.logLifecycle(
              ~event=WalletFlowFailed({reason: SheetFailed}),
              ~paymentMethod=Wallet(ApplePay),
              ~message,
            )
            postFailedSubmitResponse(~errortype="server_error", ~message)
          }
        } else if dict->Dict.get("applePaySyncPayment")->Option.isSome {
          syncPayment()
        } else if dict->Dict.get("applePayBraintreeSuccess")->Option.isSome {
          let token = dict->Utils.getString("token", "")
          processPayment(
            ~bodyArr=PaymentBody.applePayThirdPartySdkBody(~connectors, ~token),
            ~isThirdPartyFlow=true,
            ~isGuestCustomer,
            ~paymentMethodListValue,
            ~intent,
            ~options,
            ~publishableKey,
            ~isManualRetryEnabled,
          )
        } else if dict->Dict.get("applePayConfirmRequest")->Option.isSome {
          SdkLogger.logLifecycle(
            ~event=WalletStageReached({stage: ConfirmRequestReceived}),
            ~paymentMethod=Wallet(ApplePay),
          )

          processPayment(
            ~bodyArr=PaymentBody.applePayThirdPartySdkBody(~connectors),
            ~isThirdPartyFlow=true,
            ~isTrustpayInterceptorConfirm=true,
            ~isGuestCustomer,
            ~paymentMethodListValue,
            ~intent,
            ~options,
            ~publishableKey,
            ~isManualRetryEnabled,
          )
        }
      }
    }
    Window.addEventListener("message", handleApplePayMessages)
    Some(
      () => {
        messageParentWindow([("applePaySessionAbort", true->JSON.Encode.bool)])
        Window.removeEventListener("message", handleApplePayMessages)
      },
    )
  }, (
    isInvokeSDKFlow,
    processPayment,
    isManualRetryEnabled,
    isWallet,
    requiredFieldsBody,
    requiredFields,
    isSavedMethodsFlow,
    sdkAuthorization,
  ))
}

let handleApplePayButtonClicked = (
  ~sessionObj,
  ~componentName,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
  ~isSavedMethodsFlow=false,
) => {
  let paymentRequest = ApplePayTypes.getPaymentRequestFromSession(~sessionObj, ~componentName)
  let authToken =
    sessionObj
    ->getOptionsDict
    ->getDictFromDict("session_token_data")
    ->getDictFromDict("secrets")
    ->getString("display", "")
  let connector = sessionObj->getOptionsDict->getString("connector", "")

  let message = [
    ("applePayButtonClicked", true->JSON.Encode.bool),
    ("applePayPaymentRequest", paymentRequest),
    (
      "isTaxCalculationEnabled",
      paymentMethodListValue.is_tax_calculation_enabled->JSON.Encode.bool,
    ),
    ("componentName", componentName->JSON.Encode.string),
    ("authToken", authToken->JSON.Encode.string),
    ("connector", connector->JSON.Encode.string),
    ("isSavedMethodsFlow", isSavedMethodsFlow->JSON.Encode.bool),
  ]
  messageParentWindow(message)
}

let useSubmitCallback = (~isWallet, ~sessionObj, ~componentName) => {
  let areRequiredFieldsValid = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsEmpty)
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let {localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)

  React.useCallback((ev: Window.event) => {
    if !isWallet {
      let json = ev.data->safeParse
      let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
      if confirm.doSubmit && areRequiredFieldsValid && !areRequiredFieldsEmpty {
        if !options.readOnly {
          handleApplePayButtonClicked(~sessionObj, ~componentName, ~paymentMethodListValue)
        }
      } else if areRequiredFieldsEmpty {
        SdkLogger.logLifecycle(
          ~event=FormValidationFailed({reason: localeString.enterFieldsText}),
          ~paymentMethod=Wallet(ApplePay),
        )
        postFailedSubmitResponse(
          ~errortype="validation_error",
          ~message=localeString.enterFieldsText,
        )
      } else if !areRequiredFieldsValid {
        SdkLogger.logLifecycle(
          ~event=FormValidationFailed({reason: localeString.enterValidDetailsText}),
          ~paymentMethod=Wallet(ApplePay),
        )
        postFailedSubmitResponse(
          ~errortype="validation_error",
          ~message=localeString.enterValidDetailsText,
        )
      }
    }
  }, (areRequiredFieldsValid, areRequiredFieldsEmpty, isWallet, sessionObj, componentName))
}

let createApplePayTransactionInfo = jsonDict =>
  paymentRequestData(
    ~countryCode=getString(jsonDict, "countryCode", defaultCountryCode),
    ~currencyCode=getString(jsonDict, "currencyCode", ""),
    ~merchantCapabilities=getStrArray(jsonDict, "merchantCapabilities"),
    ~supportedNetworks=getStrArray(jsonDict, "supportedNetworks"),
    ~total=getTotal(jsonDict->getDictFromObj("total")),
    (),
  )

let thirdPartyApplePayConnectors = ["braintree"]

let observeBraintreeCall = (~event: SdkLogger.functionEvent, ~doneDetails=[], run) => {
  let startedAt = Date.now()
  SdkLogger.logFunction(~event, ~outcome=Started, ~paymentMethod=Wallet(ApplePay))
  run(
    ~done_=() =>
      SdkLogger.logFunction(
        ~event,
        ~outcome=Done,
        ~startedAt,
        ~details=doneDetails,
        ~paymentMethod=Wallet(ApplePay),
      ),
    ~failed=err =>
      SdkLogger.logFunction(
        ~event,
        ~outcome=Failed,
        ~startedAt,
        ~exn=err->Identity.anyTypeToJson,
        ~paymentMethod=Wallet(ApplePay),
      ),
  )
}

let handleApplePayBraintreePaymentSession = (
  applePayPaymentRequest,
  applePayInstance,
  onError,
  onSuccess,
  ~onCancel,
) => {
  try {
    let transactionInfo = applePayPaymentRequest->createApplePayTransactionInfo
    let paymentRequest = transactionInfo->applePayInstance.createPaymentRequest
    let sessions = applePaySession(3, paymentRequest)

    let braintreeDetails = [("connector", "braintree"->JSON.Encode.string)]

    // Apple Pay invokes these synchronously, so each logs `callback_triggered`.
    // The outcome of the Braintree call made inside is reported by
    // `onSuccess` / `onError` as lifecycle events.
    sessions.onvalidatemerchant = SdkLogger.observeFunctionCallback(
      ~event=OnValidateMerchant,
      ~details=braintreeDetails,
      ~paymentMethod=Wallet(ApplePay),
      ~callback=(event: ApplePayTypes.event) =>
        applePayInstance.performValidation(
          {
            validationURL: event.validationURL,
            displayName: transactionInfo->totalGet->labelGet,
          },
          (err, merchantSession) => {
            switch err->Nullable.toOption {
            | None => sessions.completeMerchantValidation(merchantSession)
            | Some(err) => {
                onError(err)
                sessions->abortApplePaySession
              }
            }
          },
        ),
    )

    sessions.onpaymentauthorized = SdkLogger.observeFunctionCallback(
      ~event=OnPaymentAuthorized,
      ~details=braintreeDetails,
      ~paymentMethod=Wallet(ApplePay),
      ~callback=(event: ApplePayTypes.event) =>
        applePayInstance.tokenize(
          {
            token: event.payment.token,
            billingContact: JSON.Encode.null,
            shippingContact: JSON.Encode.null,
          },
          (err, payload) => {
            switch sessionForApplePay->Nullable.toOption {
            | Some(ssn) =>
              switch err->Nullable.toOption {
              | None => {
                  sessions.completePayment(ssn.\"STATUS_SUCCESS"->JSON.Encode.string)
                  onSuccess(payload.nonce)
                }
              | Some(_) => {
                  sessions.completePayment(ssn.\"STATUS_FAILURE"->JSON.Encode.string)
                  onError("ApplePay Tokenization Failed"->JSON.Encode.string)
                }
              }
            | None =>
              onError("ApplePay session is null in onpaymentauthorized."->JSON.Encode.string)
            }
          },
        ),
    )

    sessions.oncancel = SdkLogger.observeFunctionCallback(
      ~event=OnCancel,
      ~details=braintreeDetails,
      ~paymentMethod=Wallet(ApplePay),
      ~callback=onCancel,
    )

    sessions.begin()
  } catch {
  | err => onError(err->formatException)
  }
}

let handleApplePayBraintreeClick = (
  authorization,
  applePayPaymentRequest,
  selectorString,
  event: Types.event,
) => {
  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", "paymentloader"->JSON.Encode.string),
    ("iframeId", selectorString->JSON.Encode.string),
  ])

  let onSuccess = token => {
    if token == "" {
      messageParentWindow([
        ("fullscreen", false->JSON.Encode.bool),
        ("param", "paymentloader"->JSON.Encode.string),
        ("iframeId", selectorString->JSON.Encode.string),
      ])
      let message = "ApplePay Braintree nonce is empty"
      postFailedSubmitResponse(~errortype="validation_error", ~message)
      SdkLogger.logLifecycle(
        ~event=WalletFlowFailed({reason: MissingNonce, connector: "braintree"}),
        ~paymentMethod=Wallet(ApplePay),
        ~message,
      )
    } else {
      SdkLogger.logLifecycle(~event=WalletTokenReceived, ~paymentMethod=Wallet(ApplePay))
      event.source->Window.sendPostMessage(
        [
          ("applePayBraintreeSuccess", true->JSON.Encode.bool),
          ("token", token->JSON.Encode.string),
        ]->Dict.fromArray,
      )
    }
  }

  let restoreButton = () => {
    messageParentWindow([
      ("fullscreen", false->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
      ("iframeId", selectorString->JSON.Encode.string),
    ])
    event.source->Window.sendPostMessage(
      [("showApplePayButton", true->JSON.Encode.bool)]->Dict.fromArray,
    )
  }

  let onError = err => {
    // Our own failure strings become the row's message; Braintree error
    // objects are summarised through ~exn as before.
    switch err->JSON.Decode.string {
    | Some(message) =>
      SdkLogger.logLifecycle(
        ~event=WalletFlowFailed({reason: PaymentDataFailed, connector: "braintree"}),
        ~paymentMethod=Wallet(ApplePay),
        ~message,
      )
    | None =>
      SdkLogger.logLifecycle(
        ~event=WalletFlowFailed({reason: PaymentDataFailed, connector: "braintree"}),
        ~paymentMethod=Wallet(ApplePay),
        ~exn=err->JsExn.anyToExnInternal,
      )
    }
    restoreButton()
  }

  let onCancel = () => {
    let abortedBySdk = applePaySessionAbortedBySdk.contents
    applePaySessionAbortedBySdk := false
    if abortedBySdk {
      SdkLogger.logLifecycle(~event=WalletFlowExited, ~paymentMethod=Wallet(ApplePay))
    }
    restoreButton()
  }

  try {
    observeBraintreeCall(
      ~event=BraintreeClientCreate,
      ~doneDetails=[("connector", "braintree"->JSON.Encode.string)],
      (~done_, ~failed) =>
        braintreeClientCreate(
          {
            authorization: authorization,
          },
          (err, clientInstance) => {
            switch err->Nullable.toOption {
            | None =>
              try {
                done_()
                observeBraintreeCall(
                  ~event=BraintreeApplePayCreate,
                  (~done_, ~failed) =>
                    braintreeApplePayPaymentCreate(
                      {
                        client: clientInstance,
                      },
                      (err, applePayInstance) => {
                        switch err->Nullable.toOption {
                        | None =>
                          done_()
                          handleApplePayBraintreePaymentSession(
                            applePayPaymentRequest,
                            applePayInstance,
                            onError,
                            onSuccess,
                            ~onCancel,
                          )

                        | Some(err) =>
                          failed(err)
                          onError(err)
                        }
                      },
                    ),
                )
              } catch {
              | err => onError(err->formatException)
              }
            | Some(err) =>
              failed(err)
              onError(err)
            }
          },
        ),
    )
  } catch {
  | err => onError(err->formatException)
  }
}
