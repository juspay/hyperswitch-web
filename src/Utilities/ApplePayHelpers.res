open ApplePayTypes
open Utils
open TaxCalculation
open BraintreeHelpers

let processPayment = (
  ~bodyArr,
  ~isThirdPartyFlow=false,
  ~isGuestCustomer,
  ~paymentMethodListValue=PaymentMethodsRecord.defaultList,
  ~intent: PaymentHelpersTypes.paymentIntent,
  ~options: PaymentType.options,
  ~publishableKey,
  ~isManualRetryEnabled,
) => {
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
    ~manualRetry=isManualRetryEnabled,
  )
}

let getApplePayFromResponse = (
  ~token,
  ~billingContactDict,
  ~shippingContactDict,
  ~requiredFields=[],
  ~connectors,
  ~isPaymentSession=false,
  ~isSavedMethodsFlow=false,
) => {
  let billingContact = billingContactDict->ApplePayTypes.billingContactItemToObjMapper

  let shippingContact = shippingContactDict->ApplePayTypes.shippingContactItemToObjMapper

  let requiredFieldsBody = if isPaymentSession || isSavedMethodsFlow {
    DynamicFieldsUtils.getApplePayRequiredFields(~billingContact, ~shippingContact)
  } else {
    DynamicFieldsUtils.getApplePayRequiredFields(~billingContact, ~shippingContact, ~requiredFields)
  }

  let bodyDict = PaymentBody.applePayBody(~token, ~connectors)

  bodyDict->mergeAndFlattenToTuples(requiredFieldsBody)
}

let startApplePaySession = (
  ~paymentRequest,
  ~applePaySessionRef,
  ~applePayPresent,
  ~logger: HyperLoggerTypes.loggerMake,
  ~callBackFunc,
  ~resolvePromise,
  ~clientSecret,
  ~publishableKey,
  ~isTaxCalculationEnabled=false,
) => {
  open Promise
  let ssn = applePaySession(3, paymentRequest)
  switch applePaySessionRef.contents->Nullable.toOption {
  | Some(session) =>
    try {
      session.abort()
    } catch {
    | error => Console.error2("Abort fail", error)
    }
  | None => ()
  }

  applePaySessionRef := ssn->Js.Nullable.return

  ssn.onvalidatemerchant = _event => {
    let merchantSession =
      applePayPresent
      ->Belt.Option.flatMap(JSON.Decode.object)
      ->Option.getOr(Dict.make())
      ->Dict.get("session_token_data")
      ->Option.getOr(Dict.make()->JSON.Encode.object)
      ->transformKeys(CamelCase)
    ssn.completeMerchantValidation(merchantSession)
  }

  ssn.onshippingcontactselected = shippingAddressChangeEvent => {
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
        ~logger,
        ~publishableKey,
        ~clientSecret,
        ~paymentMethodType,
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

  ssn.onpaymentauthorized = event => {
    ssn.completePayment({"status": ssn.\"STATUS_SUCCESS"}->Identity.anyTypeToJson)
    applePaySessionRef := Nullable.null
    let value = "Payment Data Filled: New Payment Method"
    logger.setLogInfo(~value, ~eventName=PAYMENT_DATA_FILLED, ~paymentMethod="APPLE_PAY")

    let payment = event.payment
    payment->callBackFunc
  }
  ssn.oncancel = _ => {
    applePaySessionRef := Nullable.null
    logger.setLogError(
      ~value="Apple Pay Payment Cancelled",
      ~eventName=APPLE_PAY_FLOW,
      ~paymentMethod="APPLE_PAY",
    )
    handleFailureResponse(
      ~message="ApplePay Session Cancelled",
      ~errorType="apple_pay",
    )->resolvePromise
  }
  ssn.begin()
}

let useHandleApplePayResponse = (
  ~connectors,
  ~intent,
  ~setApplePayClicked=_ => (),
  ~syncPayment=() => (),
  ~isInvokeSDKFlow=true,
  ~isSavedMethodsFlow=false,
  ~isWallet=true,
  ~requiredFieldsBody=Dict.make(),
) => {
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  let paymentMethodTypes = DynamicFieldsUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="apple_pay",
  )

  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)

  React.useEffect(() => {
    let handleApplePayMessages = (ev: Window.event) => {
      let json = ev.data->safeParse
      try {
        let dict = json->getDictFromJson
        if dict->Dict.get("applePayPaymentToken")->Option.isSome {
          let token =
            dict->Dict.get("applePayPaymentToken")->Option.getOr(Dict.make()->JSON.Encode.object)

          let billingContactDict = dict->getDictFromDict("applePayBillingContact")
          let shippingContactDict = dict->getDictFromDict("applePayShippingContact")

          let applePayBody = getApplePayFromResponse(
            ~token,
            ~billingContactDict,
            ~shippingContactDict,
            ~requiredFields=paymentMethodTypes.required_fields,
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
          if isSavedMethodsFlow || !isWallet {
            postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
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
        }
      } catch {
      | _ =>
        logger.setLogError(
          ~value="Error in parsing Apple Pay Data",
          ~eventName=APPLE_PAY_FLOW,
          ~paymentMethod="APPLE_PAY",
          // ~internalMetadata=err->formatException->JSON.stringify,
        )
      }
    }
    Window.addEventListener("message", handleApplePayMessages)
    Some(
      () => {
        messageParentWindow([("applePaySessionAbort", true->JSON.Encode.bool)])
        Window.removeEventListener("message", handleApplePayMessages)
      },
    )
  }, (isInvokeSDKFlow, processPayment, isManualRetryEnabled, isWallet, requiredFieldsBody))
}

let handleApplePayButtonClicked = (
  ~sessionObj,
  ~componentName,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
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
  ]
  messageParentWindow(message)
}

let useSubmitCallback = (
  ~isWallet,
  ~sessionObj,
  ~componentName,
  ~areRequiredFieldsValid,
  ~areRequiredFieldsEmpty,
) => {
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  React.useCallback((ev: Window.event) => {
    if !isWallet && !isGiftCardOnlyPayment {
      let json = ev.data->safeParse
      let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
      if confirm.doSubmit && areRequiredFieldsValid && !areRequiredFieldsEmpty {
        if !options.readOnly {
          handleApplePayButtonClicked(~sessionObj, ~componentName, ~paymentMethodListValue)
        }
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

let handleApplePayBraintreePaymentSession = (
  applePayPaymentRequest,
  applePayInstance,
  onError,
  onSuccess,
) => {
  try {
    let transactionInfo = applePayPaymentRequest->createApplePayTransactionInfo
    let paymentRequest = transactionInfo->applePayInstance.createPaymentRequest
    let sessions = applePaySession(3, paymentRequest)

    sessions.onvalidatemerchant = event => {
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
              sessions.abort()
            }
          }
        },
      )
    }

    sessions.onpaymentauthorized = event => {
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
          | None => onError("ApplePay session is null in onpaymentauthorized."->JSON.Encode.string)
          }
        },
      )
    }

    sessions.oncancel = _ => onError("Apple Pay Payment Cancelled."->JSON.Encode.string)

    sessions.begin()
  } catch {
  | err => onError(err->formatException)
  }
}

let handleApplePayBraintreeClick = (
  authorization,
  applePayPaymentRequest,
  selectorString,
  logger: HyperLoggerTypes.loggerMake,
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
      postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message="ApplePay Braintree nonce is empty",
      )
      logger.setLogError(
        ~value="ApplePay Braintree nonce is empty",
        ~eventName=APPLE_PAY_FLOW,
        ~paymentMethod="APPLE_PAY",
      )
    } else {
      logger.setLogInfo(
        ~value="ApplePay Braintree payment Successfull",
        ~eventName=APPLE_PAY_FLOW,
        ~paymentMethod="APPLE_PAY",
      )
      event.source->Window.sendPostMessage(
        [
          ("applePayBraintreeSuccess", true->JSON.Encode.bool),
          ("token", token->JSON.Encode.string),
        ]->Dict.fromArray,
      )
    }
  }

  let onError = err => {
    logger.setLogError(
      ~value=err->JSON.stringify,
      ~eventName=APPLE_PAY_FLOW,
      ~paymentMethod="APPLE_PAY",
    )
    messageParentWindow([
      ("fullscreen", false->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
      ("iframeId", selectorString->JSON.Encode.string),
    ])
    event.source->Window.sendPostMessage(
      [("showApplePayButton", true->JSON.Encode.bool)]->Dict.fromArray,
    )
  }
  try {
    braintreeClientCreate(
      {
        authorization: authorization,
      },
      (err, clientInstance) => {
        switch err->Nullable.toOption {
        | None =>
          try {
            logger.setLogInfo(
              ~value="Braintree ApplePay instance created successfully",
              ~eventName=APPLE_PAY_FLOW,
              ~paymentMethod="APPLE_PAY",
            )
            braintreeApplePayPaymentCreate(
              {
                client: clientInstance,
              },
              (err, applePayInstance) => {
                switch err->Nullable.toOption {
                | None =>
                  logger.setLogInfo(
                    ~value="Braintree ApplePay payment session started",
                    ~eventName=APPLE_PAY_FLOW,
                    ~paymentMethod="APPLE_PAY",
                  )
                  handleApplePayBraintreePaymentSession(
                    applePayPaymentRequest,
                    applePayInstance,
                    onError,
                    onSuccess,
                  )

                | Some(err) => onError(err)
                }
              },
            )
          } catch {
          | err => onError(err->formatException)
          }
        | Some(err) => onError(err)
        }
      },
    )
  } catch {
  | err => onError(err->formatException)
  }
}
