open ApplePayTypes
open Utils

let processPayment = (
  ~bodyArr,
  ~isThirdPartyFlow=false,
  ~isGuestCustomer,
  ~paymentMethodListValue=PaymentMethodsRecord.defaultList,
  ~intent: PaymentHelpers.paymentIntent,
  ~options: PaymentType.options,
  ~publishableKey,
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
    (),
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
) => {
  let billingContact = billingContactDict->ApplePayTypes.billingContactItemToObjMapper

  let shippingContact = shippingContactDict->ApplePayTypes.shippingContactItemToObjMapper

  let requiredFieldsBody = if isPaymentSession {
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
  ~applePayEvent: option<Types.event>=None,
  ~callBackFunc,
  ~resolvePromise: option<Core__JSON.t => unit>=None,
) => {
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

  ssn.onpaymentauthorized = event => {
    ssn.completePayment({"status": ssn.\"STATUS_SUCCESS"}->Identity.anyTypeToJson)
    applePaySessionRef := Nullable.null
    let value = "Payment Data Filled: New Payment Method"
    logger.setLogInfo(~value, ~eventName=PAYMENT_DATA_FILLED, ~paymentMethod="APPLE_PAY", ())

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
      (),
    )
    switch (applePayEvent, resolvePromise) {
    | (Some(applePayEvent), _) => {
        let msg = [("showApplePayButton", true->JSON.Encode.bool)]->Dict.fromArray
        applePayEvent.source->Window.sendPostMessage(msg)
      }
    | (_, Some(resolvePromise)) =>
      handleFailureResponse(
        ~message="ApplePay Session Cancelled",
        ~errorType="apple_pay",
      )->resolvePromise
    | _ => ()
    }
  }
  ssn.begin()
}

let useHandleApplePayResponse = (
  ~connectors,
  ~intent,
  ~setApplePayClicked=_ => (),
  ~syncPayment=() => (),
  ~isInvokeSDKFlow=true,
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

  React.useEffect(() => {
    let handleApplePayMessages = (ev: Window.event) => {
      let json = try {
        ev.data->JSON.parseExn
      } catch {
      | _ => Dict.make()->JSON.Encode.object
      }

      try {
        let dict = json->getDictFromJson
        if dict->Dict.get("applePayProcessPayment")->Option.isSome {
          let token =
            dict->Dict.get("applePayProcessPayment")->Option.getOr(Dict.make()->JSON.Encode.object)

          let billingContactDict = dict->getDictFromDict("applePayBillingContact")
          let shippingContactDict = dict->getDictFromDict("applePayShippingContact")

          let applePayBody = getApplePayFromResponse(
            ~token,
            ~billingContactDict,
            ~shippingContactDict,
            ~requiredFields=paymentMethodTypes.required_fields,
            ~stateJson,
            ~connectors,
          )

          processPayment(
            ~bodyArr=applePayBody,
            ~isThirdPartyFlow=false,
            ~isGuestCustomer,
            ~paymentMethodListValue,
            ~intent,
            ~options,
            ~publishableKey,
          )
        } else if dict->Dict.get("showApplePayButton")->Option.isSome {
          setApplePayClicked(_ => false)
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
        handlePostMessage([("applePaySessionAbort", true->JSON.Encode.bool)])
        Window.removeEventListener("message", handleApplePayMessages)
      },
    )
  }, (isInvokeSDKFlow, processPayment, stateJson))
}

let handleApplePayButtonClicked = (~sessionObj, ~componentName) => {
  let paymentRequest = ApplePayTypes.getPaymentRequestFromSession(~sessionObj, ~componentName)
  let message = [
    ("applePayButtonClicked", true->JSON.Encode.bool),
    ("applePayPaymentRequest", paymentRequest),
  ]
  handlePostMessage(message)
}
