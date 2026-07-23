open SubscriptionEventTypes
open PaymentEventTypes

// ---------------------------------------------------------------------------
// useSubscriptionEventEmitter
// ---------------------------------------------------------------------------
// Call once at the top of any component that needs to emit events imperatively
// (e.g. inside event handlers or callbacks, not in effects).
// Reads subscriptionEvents from Jotai — no prop drilling required.

type emitter = {
  emitCardInfo: (~cardInfo: PaymentEventData.cardInfo) => unit,
  emitPaymentMethodStatus: (
    ~paymentMethod: string,
    ~paymentMethodType: string,
    ~isSavedPaymentMethod: bool,
    ~isOneClickWallet: bool=?,
  ) => unit,
  emitBillingAddress: (~country: string, ~state: string, ~postalCode: string) => unit,
  emitCvcStatus: (~iframeId: string, ~isCvcEmpty: bool, ~isCvcComplete: bool) => unit,
  emitSurcharge: (
    ~surchargeDetails: option<EligibilityHelpers.eligibilitySurchargeDetails>,
  ) => unit,
}

let useSubscriptionEventEmitter = (): emitter => {
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let subscribedEvents = options.subscriptionEvents

  let emitCardInfo = (~cardInfo: PaymentEventData.cardInfo) => {
    if (
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscribedEvents->Option.getOr([]),
        ~eventType=PaymentMethodInfoCard,
      )
    ) {
      Utils.messageParentWindow(createCardInfoPayload(cardInfo))
    }
  }

  let emitPaymentMethodStatus = (
    ~paymentMethod,
    ~paymentMethodType,
    ~isSavedPaymentMethod,
    ~isOneClickWallet=false,
  ) => {
    if (
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscribedEvents->Option.getOr([]),
        ~eventType=PaymentMethodStatus,
      )
    ) {
      Utils.messageParentWindow(
        createPaymentMethodStatusPayload(
          ~paymentMethod,
          ~paymentMethodType,
          ~isSavedPaymentMethod,
          ~isOneClickWallet,
        ),
      )
    }
  }

  let emitBillingAddress = (~country, ~state, ~postalCode) => {
    if (
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscribedEvents->Option.getOr([]),
        ~eventType=PaymentMethodInfoBillingAddress,
      )
    ) {
      Utils.messageParentWindow(createBillingAddressPayload(~country, ~state, ~postalCode))
    }
  }

  let emitCvcStatus = (~iframeId, ~isCvcEmpty, ~isCvcComplete) => {
    if (
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscribedEvents->Option.getOr([]),
        ~eventType=CvcStatus,
      )
    ) {
      Utils.messageParentWindow(createCvcStatusPayload(~iframeId, ~isCvcEmpty, ~isCvcComplete))
    }
  }

  let emitSurcharge = (~surchargeDetails) => {
    if (
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscribedEvents->Option.getOr([]),
        ~eventType=Surcharge,
      ) &&
      surchargeDetails->Option.isSome
    ) {
      Utils.messageParentWindow(createSurchargePayload(~surchargeDetails))
    }
  }

  {emitCardInfo, emitPaymentMethodStatus, emitBillingAddress, emitCvcStatus, emitSurcharge}
}

// ---------------------------------------------------------------------------
// emitReady
// ---------------------------------------------------------------------------
// Fires unconditionally so every merchant receives the ready lifecycle event
// regardless of whether subscriptionEvents is configured.
let emitReady = (~iframeId, ~elementType) =>
  Utils.messageParentWindow([
    ("ready", true->JSON.Encode.bool),
    ("elementType", elementType->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
  ])

// ---------------------------------------------------------------------------
// useEmitFormStatus
// ---------------------------------------------------------------------------
// Effect hook: emits formStatus whenever empty/complete/isOneClickWallet changes.
let useEmitFormStatus = (~empty: bool, ~complete: bool, ~isOneClickWallet: bool=false) => {
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let subscribedEvents = options.subscriptionEvents

  React.useEffect(() => {
    if !isOneClickWallet {
      let formStatusValue = PaymentEventData.computeFormStatus(~isComplete=complete, ~isEmpty=empty)
      if (
        PaymentEventData.shouldEmitEvent(
          ~subscribedEvents=subscribedEvents->Option.getOr([]),
          ~eventType=FormStatus,
        )
      ) {
        Utils.messageParentWindow(createFormStatusPayload(~status=formStatusValue))
      }
    }
    None
  }, (empty, complete, isOneClickWallet, subscribedEvents))
}

// ---------------------------------------------------------------------------
// useEmitBillingAddress
// ---------------------------------------------------------------------------
// Effect hook: emits paymentMethodInfoBillingAddress whenever address atoms change.
let useEmitBillingAddress = () => {
  let country = Jotai.useAtomValue(JotaiAtoms.userCountry)
  let state = Jotai.useAtomValue(JotaiAtoms.userAddressState).value
  let pinCode = Jotai.useAtomValue(JotaiAtoms.userAddressPincode).value
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let subscribedEvents = options.subscriptionEvents

  React.useEffect(() => {
    if (
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscribedEvents->Option.getOr([]),
        ~eventType=PaymentMethodInfoBillingAddress,
      )
    ) {
      Utils.messageParentWindow(createBillingAddressPayload(~country, ~state, ~postalCode=pinCode))
    }
    None
  }, (country, state, pinCode, subscribedEvents))
}

// Internal helper: resolves (paymentMethod, paymentMethodType) from method name + list.
// Mirrors the old PaymentUtils.getPaymentMethodAndType which was removed from the new main.
let getPaymentMethodAndType = (
  ~paymentMethodName: string,
  ~paymentMethods: array<PaymentMethodsRecord.methods>,
  ~logger: HyperLoggerTypes.loggerMake,
) => {
  if paymentMethodName->String.includes("_debit") {
    Some(("bank_debit", paymentMethodName))
  } else if paymentMethodName->String.includes("_transfer") {
    Some(("bank_transfer", paymentMethodName))
  } else if paymentMethodName === "card" {
    Some(("card", "debit"))
  } else {
    let found =
      paymentMethods
      ->Array.filter(pm =>
        pm.payment_method_types
        ->Array.filter(t => t.payment_method_type === paymentMethodName)
        ->Array.length > 0
      )
      ->Array.get(0)

    switch found {
    | Some(pm) => Some((pm.payment_method, paymentMethodName))
    | None =>
      logger.setLogError(
        ~value="Payment method type not found",
        ~eventName=PAYMENT_METHOD_TYPE_DETECTION_FAILED,
      )
      None
    }
  }
}

// ---------------------------------------------------------------------------
// useEmitPaymentMethodStatus
// ---------------------------------------------------------------------------
// Effect hook: emits paymentMethodStatus when the selected payment method changes.
let useEmitPaymentMethodStatus = (
  ~paymentMethodName: string,
  ~paymentMethods: array<PaymentMethodsRecord.methods>,
  ~isSavedPaymentMethod: bool,
  ~isOneClickWallet: bool,
) => {
  let loggerState = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let subscribedEvents = options.subscriptionEvents

  React.useEffect(() => {
    if (
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscribedEvents->Option.getOr([]),
        ~eventType=PaymentMethodStatus,
      )
    ) {
      switch getPaymentMethodAndType(~paymentMethodName, ~paymentMethods, ~logger=loggerState) {
      | Some((paymentMethod, paymentMethodType)) =>
        Utils.messageParentWindow(
          createPaymentMethodStatusPayload(
            ~paymentMethod,
            ~paymentMethodType,
            ~isSavedPaymentMethod,
            ~isOneClickWallet,
          ),
        )
      | None => ()
      }
    }
    None
  }, (paymentMethodName, paymentMethods, isSavedPaymentMethod, isOneClickWallet, subscribedEvents))
}

// ---------------------------------------------------------------------------
// useEmitSurchargeInfo
// ---------------------------------------------------------------------------
// Effect hook: emits surcharge when the eligibility surcharge details change.
// Pass the surcharge details option from the component's React state.
let useEmitSurchargeInfo = (
  ~surchargeDetails: option<EligibilityHelpers.eligibilitySurchargeDetails>,
) => {
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let subscribedEvents = options.subscriptionEvents

  React.useEffect(() => {
    if (
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscribedEvents->Option.getOr([]),
        ~eventType=Surcharge,
      ) &&
      surchargeDetails->Option.isSome
    ) {
      Utils.messageParentWindow(createSurchargePayload(~surchargeDetails))
    }
    None
  }, (surchargeDetails, subscribedEvents))
}
