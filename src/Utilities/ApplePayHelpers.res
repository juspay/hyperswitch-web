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

let applePaySdkUrl = "https://applepay.cdn-apple.com/jsapi/1.latest/apple-pay-sdk.js"
let applePayButtonTag = "apple-pay-button"
let applePaySdkLoadTimeout = 3000
let applePayCapabilitiesTimeout = 3000
let merchantIdentifierTimeout = 1500

let getOrCreateApplePaySdkScript = () =>
  switch Window.querySelector(`script[src="${applePaySdkUrl}"]`)->Nullable.toOption {
  | Some(script) => script
  | None =>
    let script = Window.createElement("script")
    script->Window.elementSrc(applePaySdkUrl)
    script->setScriptAsync(true)
    script->setCrossOrigin("anonymous")
    Window.head->Window.appendChildElement(script)
    script
  }

let supportsApplePayCapabilities = (session: session) =>
  Type.typeof(session.applePayCapabilities) === #function

// Safari draws the Apple Pay button natively, without Apple's JS SDK.
let isNativeApplePayButtonSupported = () =>
  try {
    cssSupports("-webkit-appearance", "-apple-pay-button")
  } catch {
  | _ => false
  }

// Apple's JS SDK cannot offer Apple Pay in mobile third-party browsers (e.g. Android Chrome),
// so it is not loaded there.
let isMobileThirdPartyBrowser = () =>
  userAgentData->Nullable.toOption->Option.mapOr(false, data => data.mobile)

// Apple's JS SDK sets `window.onbeforeunload` (to close its QR code window); keep the
// merchant's handler running as well.
let keepMerchantBeforeUnload = merchantBeforeUnload =>
  switch (merchantBeforeUnload->Nullable.toOption, onBeforeUnload->Nullable.toOption) {
  | (Some(merchantHandler), Some(sdkHandler)) if merchantHandler !== sdkHandler =>
    Window.window->setOnBeforeUnload(event => {
      sdkHandler(event)->ignore
      merchantHandler(event)
    })
  | _ => ()
  }

let applePaySdkLoadPromiseRef: ref<option<promise<unit>>> = ref(None)

// Makes `window.ApplePaySession` available: native in Safari, provided by Apple's JS SDK in
// third-party browsers like Chrome. Resolves once loaded, failed or timed out; shared across callers.
let loadApplePaySdk = () =>
  switch applePaySdkLoadPromiseRef.contents {
  | Some(loadPromise) => loadPromise
  | None =>
    let loadPromise = Promise.make((resolve, _) =>
      if (
        sessionForApplePay->Nullable.toOption->Option.mapOr(false, supportsApplePayCapabilities) ||
          isMobileThirdPartyBrowser()
      ) {
        resolve()
      } else {
        let merchantBeforeUnload = onBeforeUnload
        let script = getOrCreateApplePaySdkScript()
        script->addScriptEventListener("load", () => {
          keepMerchantBeforeUnload(merchantBeforeUnload)
          resolve()
        })
        script->addScriptEventListener("error", resolve)
        setTimeout(resolve, applePaySdkLoadTimeout)->ignore
      }
    )
    applePaySdkLoadPromiseRef := Some(loadPromise)
    loadPromise
  }

// Resolves to true once the `<apple-pay-button>` web component is registered in the current
// window, however long Apple's JS SDK takes to load.
let loadApplePayButton = () =>
  switch customElements->Nullable.toOption {
  | None => Promise.resolve(false)
  | Some(registry) =>
    if registry->getCustomElement(applePayButtonTag)->Nullable.toOption->Option.isNone {
      getOrCreateApplePaySdkScript()->ignore
    }
    registry->whenDefined(applePayButtonTag)->Promise.thenResolve(_ => true)
  }

let getStatusFromCanMakePayments = (session: session) =>
  try {
    session.canMakePayments() ? PaymentCredentialStatusUnknown : ApplePayUnsupported
  } catch {
  | err =>
    // e.g. Apple's JS SDK throws "InvalidAccessError" on non-https pages
    Console.warn2("[ApplePay] canMakePayments failed:", err)
    ApplePayUnsupported
  }

let getPaymentCredentialStatus = (~merchantIdentifier) => {
  open Promise
  loadApplePaySdk()
  ->then(_ =>
    switch sessionForApplePay->Nullable.toOption {
    | None => resolve(ApplePayUnsupported)
    | Some(session) if merchantIdentifier === "" || !supportsApplePayCapabilities(session) =>
      resolve(getStatusFromCanMakePayments(session))
    | Some(session) =>
      // In third-party browsers this calls Apple's servers, so bound it with a timeout.
      [
        session.applePayCapabilities(merchantIdentifier)->thenResolve(response =>
          response.paymentCredentialStatus->Option.mapOr(
            getStatusFromCanMakePayments(session),
            paymentCredentialStatusFromString,
          )
        ),
        Promise.make((resolve, _) =>
          setTimeout(
            () => resolve(getStatusFromCanMakePayments(session)),
            applePayCapabilitiesTimeout,
          )->ignore
        ),
      ]
      ->Promise.race
      ->catch(err => {
        Console.warn2("[ApplePay] applePayCapabilities failed:", err)
        resolve(getStatusFromCanMakePayments(session))
      })
    }
  )
  ->catch(_ => resolve(ApplePayUnsupported))
}

let getMerchantIdentifierFromSessions = sessionsPromise =>
  [
    sessionsPromise->Promise.thenResolve(sessionsJson =>
      sessionsJson
      ->getDictFromJson
      ->getArray("session_token")
      ->Array.find(token => token->getDictFromJson->getString("wallet_name", "") === "apple_pay")
      ->Option.mapOr("", token =>
        token
        ->getDictFromJson
        ->getDictFromDict("payment_request_data")
        ->getString("merchant_identifier", "")
      )
    ),
    Promise.make((resolve, _) => {
      let _ = setTimeout(() => resolve(""), merchantIdentifierTimeout)
    }),
  ]
  ->Promise.race
  ->Promise.catch(_ => Promise.resolve(""))

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
  ~sdkAuthorization=None,
) => {
  open Promise
  let sdkHandleIsThere = LoaderPaymentElement.isPaymentButtonHandlerProvided.contents
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
          Js.log2("merchant session", merchantSession)
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
    ->ignore
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

  ssn.onpaymentauthorized = event => {
    ssn.completePayment({"status": getStatusSuccess()}->Identity.anyTypeToJson)
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
  let logger = Jotai.useAtomValue(JotaiAtoms.loggerAtom)

  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)

  React.useEffect(() => {
    let handleApplePayMessages = (ev: Window.event) => {
      let json = ev.data->safeParse
      try {
        let dict = json->getDictFromJson
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
        } else if dict->Dict.get("applePayConfirmRequest")->Option.isSome {
          // The interceptor in the parent window is asking us to call /confirm and
          // return the TrustPay secrets so it can swap them into TrustPay's
          // merchant-validation FormData. Reuse processPayment so the confirm goes
          // through PaymentHelpers; intentCall posts "applePayConfirmSecrets" back to
          // the parent for the interceptor flow (~isTrustpayInterceptorConfirm=true).
          logger.setLogInfo(
            ~value="[ApplePayInterceptor] applePayConfirmRequest received — calling /confirm",
            ~eventName=APPLE_PAY_FLOW,
            ~paymentMethod="APPLE_PAY",
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
