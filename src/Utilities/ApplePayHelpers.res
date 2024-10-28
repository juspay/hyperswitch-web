open ApplePayTypes
open Utils
open TaxCalculation

let processPayment = (
  ~bodyArr,
  ~isThirdPartyFlow=false,
  ~isGuestCustomer,
  ~paymentMethodListValue=PaymentMethodsRecord.defaultList,
  ~intent: PaymentHelpers.paymentIntent,
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
  ~stateJson,
  ~connectors,
  ~isPaymentSession=false,
  ~isSavedMethodsFlow=false,
) => {
  let billingContact = billingContactDict->ApplePayTypes.billingContactItemToObjMapper

  let shippingContact = shippingContactDict->ApplePayTypes.shippingContactItemToObjMapper

  let requiredFieldsBody = if isPaymentSession || isSavedMethodsFlow {
    DynamicFieldsUtils.getApplePayRequiredFields(
      ~billingContact,
      ~shippingContact,
      ~statesList=stateJson,
    )
  } else {
    DynamicFieldsUtils.getApplePayRequiredFields(
      ~billingContact,
      ~shippingContact,
      ~requiredFields,
      ~statesList=stateJson,
    )
  }

  let bodyDict = PaymentBody.applePayBody(~token, ~connectors)

  bodyDict
  ->getJsonFromArrayOfJson
  ->flattenObject(true)
  ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
  ->getArrayOfTupleFromDict
}

let startApplePaySession = (
  ~paymentRequest,
  ~applePaySessionRef,
  ~applePayPresent,
  ~logger: OrcaLogger.loggerMake,
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
    | error => Console.log2("Abort fail", error)
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
  ssn.oncancel = _ev => {
    applePaySessionRef := Nullable.null
    logInfo(Console.log("Apple Pay Payment Cancelled"))
    logger.setLogInfo(
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

  let (stateJson, setStatesJson) = React.useState(_ => JSON.Encode.null)

  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  PaymentUtils.useStatesJson(setStatesJson)
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
            ~stateJson,
            ~connectors,
            ~isSavedMethodsFlow,
          )

          let bodyArr = if isWallet {
            applePayBody
          } else {
            applePayBody
            ->getJsonFromArrayOfJson
            ->flattenObject(true)
            ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
            ->getArrayOfTupleFromDict
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
        }
      } catch {
      | _ => logInfo(Console.log("Error in parsing Apple Pay Data"))
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
    stateJson,
    isManualRetryEnabled,
    isWallet,
    requiredFieldsBody,
  ))
}

let handleApplePayButtonClicked = (
  ~sessionObj,
  ~componentName,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
) => {
  let paymentRequest = ApplePayTypes.getPaymentRequestFromSession(~sessionObj, ~componentName)
  let message = [
    ("applePayButtonClicked", true->JSON.Encode.bool),
    ("applePayPaymentRequest", paymentRequest),
    (
      "isTaxCalculationEnabled",
      paymentMethodListValue.is_tax_calculation_enabled->JSON.Encode.bool,
    ),
    ("componentName", componentName->JSON.Encode.string),
  ]
  messageParentWindow(message)
}

let useSubmitCallback = (~isWallet, ~sessionObj, ~componentName) => {
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsEmpty)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

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
