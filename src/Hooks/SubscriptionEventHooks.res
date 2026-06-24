open SubscriptionEventTypes
open PaymentEventData
open PaymentEventTypes

// Internal helper: returns true if the event should be emitted.
// None  → all events emitted (backward compat — merchant did not configure subscriptionEvents)
// Some([]) → no events (empty list is normalised to None in getSubscriptionEvents, but guard here anyway)
// Some([...]) → only listed events
let shouldEmit = (subscribedEvents: option<array<PaymentEventTypes.events>>, eventType) =>
  subscribedEvents->Option.isNone ||
    PaymentEventData.shouldEmitEvent(
      ~subscribedEvents=subscribedEvents->Option.getOr([]),
      ~eventType,
    )

// ---------------------------------------------------------------------------
// useSubscriptionEventEmitter
// ---------------------------------------------------------------------------
// Call once at the top of any component that needs to emit events imperatively
// (e.g. inside event handlers or callbacks, not in effects).
// Reads subscriptionEvents from Recoil — no prop drilling required.

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
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let subscribedEvents = options.subscriptionEvents

  let emitCardInfo = (~cardInfo: PaymentEventData.cardInfo) => {
    if shouldEmit(subscribedEvents, PaymentMethodInfoCard) {
      Utils.messageParentWindow(createCardInfoPayload(cardInfo))
    }
  }

  let emitPaymentMethodStatus = (
    ~paymentMethod,
    ~paymentMethodType,
    ~isSavedPaymentMethod,
    ~isOneClickWallet=false,
  ) => {
    if shouldEmit(subscribedEvents, PaymentMethodStatus) {
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
    if shouldEmit(subscribedEvents, PaymentMethodInfoBillingAddress) {
      Utils.messageParentWindow(createBillingAddressPayload(~country, ~state, ~postalCode))
    }
  }

  let emitCvcStatus = (~iframeId, ~isCvcEmpty, ~isCvcComplete) => {
    if shouldEmit(subscribedEvents, CvcStatus) {
      Utils.messageParentWindow(createCvcStatusPayload(~iframeId, ~isCvcEmpty, ~isCvcComplete))
    }
  }

  let emitSurcharge = (~surchargeDetails) => {
    if shouldEmit(subscribedEvents, Surcharge) {
      Utils.messageParentWindow(createSurchargePayload(~surchargeDetails))
    }
  }

  {emitCardInfo, emitPaymentMethodStatus, emitBillingAddress, emitCvcStatus, emitSurcharge}
}

// ---------------------------------------------------------------------------
// useIsLegacyEventMode
// ---------------------------------------------------------------------------
// Returns true when the merchant has NOT configured subscriptionEvents,
// meaning old-style unconditional events should still fire for backward compat.
let useIsLegacyEventMode = (): bool => {
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  options.subscriptionEvents->Option.isNone
}

// ---------------------------------------------------------------------------
// useLegacyEvents
// ---------------------------------------------------------------------------
// Single hook that wraps ALL old-style event functions with the legacy gate.
// When subscriptionEvents is not set (None) → fires as before (backward compat).
// When subscriptionEvents is explicitly set → all legacy events are suppressed.
//
// Use this hook instead of calling CardUtils / PaymentUtils / Utils event
// functions directly, so the gate lives in exactly one place.
type legacyEvents = {
  isLegacy: bool,
  emitIsFormReadyForSubmission: bool => unit,
  emitExpiryDate: string => unit,
  handlePostMessageEvents: (
    ~iframeId: string,
    ~complete: bool,
    ~empty: bool,
    ~paymentType: string,
    ~loggerState: HyperLoggerTypes.loggerMake,
    ~savedMethod: bool=?,
  ) => unit,
  emitCvcInfo: (~isCvcEmpty: bool) => unit,
  emitPaymentMethodInfo: (
    ~paymentMethod: string,
    ~paymentMethodType: string,
    ~cardBrand: CardUtils.cardIssuer=?,
    ~cardLast4: string=?,
    ~cardBin: string=?,
    ~cardExpiryMonth: string=?,
    ~cardExpiryYear: string=?,
    ~country: string=?,
    ~state: string=?,
    ~pinCode: string=?,
    ~isSavedPaymentMethod: bool=?,
    ~isCvcEmpty: bool=?,
  ) => unit,
}

// ---------------------------------------------------------------------------
// emitReady
// ---------------------------------------------------------------------------
// NOT a legacy event — fires unconditionally so every merchant receives the
// ready lifecycle event regardless of whether subscriptionEvents is configured.
// elementType is informational only; LoaderPaymentElement does not filter
// ready/focus/blur by elementType (only Change is filtered that way).
let emitReady = (~iframeId, ~elementType) =>
  Utils.messageParentWindow([
    ("ready", true->JSON.Encode.bool),
    ("elementType", elementType->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
  ])

let useLegacyEvents = (): legacyEvents => {
  let isLegacy = useIsLegacyEventMode()

  let emitIsFormReadyForSubmission = isReady =>
    if isLegacy {
      CardUtils.emitIsFormReadyForSubmission(isReady)
    }

  let emitExpiryDate = expiry =>
    if isLegacy {
      CardUtils.emitExpiryDate(expiry)
    }

  let handlePostMessageEvents = (
    ~iframeId,
    ~complete,
    ~empty,
    ~paymentType,
    ~loggerState,
    ~savedMethod=false,
  ) =>
    if isLegacy {
      Utils.handlePostMessageEvents(
        ~iframeId,
        ~complete,
        ~empty,
        ~paymentType,
        ~loggerState,
        ~savedMethod,
      )
    }

  let emitCvcInfo = (~isCvcEmpty) =>
    if isLegacy {
      let cvcInfoDict = [("isCvcEmpty", isCvcEmpty->JSON.Encode.bool)]->Dict.fromArray
      Utils.messageParentWindow([("cvcInfo", cvcInfoDict->JSON.Encode.object)])
    }

  let emitPaymentMethodInfo = (
    ~paymentMethod,
    ~paymentMethodType,
    ~cardBrand=CardUtils.NOTFOUND,
    ~cardLast4="",
    ~cardBin="",
    ~cardExpiryMonth="",
    ~cardExpiryYear="",
    ~country="",
    ~state="",
    ~pinCode="",
    ~isSavedPaymentMethod=false,
    ~isCvcEmpty=true,
  ) =>
    if isLegacy {
      PaymentUtils.emitPaymentMethodInfo(
        ~paymentMethod,
        ~paymentMethodType,
        ~cardBrand,
        ~cardLast4,
        ~cardBin,
        ~cardExpiryMonth,
        ~cardExpiryYear,
        ~country,
        ~state,
        ~pinCode,
        ~isSavedPaymentMethod,
        ~isCvcEmpty,
      )
    }

  {
    isLegacy,
    emitIsFormReadyForSubmission,
    emitExpiryDate,
    handlePostMessageEvents,
    emitCvcInfo,
    emitPaymentMethodInfo,
  }
}

// ---------------------------------------------------------------------------
// useEmitFormStatus
// ---------------------------------------------------------------------------
// Effect hook: emits FORM_STATUS whenever empty/complete/isOneClickWallet changes.
let useEmitFormStatus = (~empty: bool, ~complete: bool, ~isOneClickWallet: bool=false) => {
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let subscribedEvents = options.subscriptionEvents

  React.useEffect(() => {
    if !isOneClickWallet {
      let formStatusValue = PaymentEventData.computeFormStatus(~isComplete=complete, ~isEmpty=empty)
      if shouldEmit(subscribedEvents, FormStatus) {
        Utils.messageParentWindow(createFormStatusPayload(~status=formStatusValue))
      }
    }
    None
  }, (empty, complete, isOneClickWallet, subscribedEvents))
}

// ---------------------------------------------------------------------------
// useEmitBillingAddress
// ---------------------------------------------------------------------------
// Effect hook: emits PAYMENT_METHOD_INFO_BILLING_ADDRESS whenever address atoms change.
let useEmitBillingAddress = () => {
  let country = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let state = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressState).value
  let pinCode = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressPincode).value
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let subscribedEvents = options.subscriptionEvents

  React.useEffect(() => {
    if shouldEmit(subscribedEvents, PaymentMethodInfoBillingAddress) {
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
// Effect hook: emits PAYMENT_METHOD_STATUS when the selected payment method changes.
let useEmitPaymentMethodStatus = (
  ~paymentMethodName: string,
  ~paymentMethods: array<PaymentMethodsRecord.methods>,
  ~isSavedPaymentMethod: bool,
  ~isOneClickWallet: bool,
) => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let subscribedEvents = options.subscriptionEvents

  React.useEffect(() => {
    if shouldEmit(subscribedEvents, PaymentMethodStatus) {
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
// useEmitSurcharge
// ---------------------------------------------------------------------------
// Effect hook: emits SURCHARGE when the eligibility surcharge details change.
// Pass the surcharge details option from the component's React state.
let useEmitSurcharge = (
  ~surchargeDetails: option<EligibilityHelpers.eligibilitySurchargeDetails>,
) => {
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let subscribedEvents = options.subscriptionEvents

  React.useEffect(() => {
    if shouldEmit(subscribedEvents, Surcharge) {
      Utils.messageParentWindow(createSurchargePayload(~surchargeDetails))
    }
    None
  }, (surchargeDetails, subscribedEvents))
}
