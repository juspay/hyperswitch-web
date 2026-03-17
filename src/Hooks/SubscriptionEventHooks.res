open SubscriptionEventTypes

let emitCardInfo = (
  ~subscriptionEvents,
  ~bin,
  ~last4,
  ~brand,
  ~expiryMonth,
  ~expiryYear,
  ~formattedExpiry,
  ~isCardNumberComplete,
  ~isCvcComplete,
  ~isExpiryComplete,
  ~isCardNumberValid,
  ~isExpiryValid,
  ~isCvcValid,
  ~isSavedCard,
) => {
  if (
    subscriptionEvents->Option.isNone ||
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscriptionEvents->Option.getOr([]),
        ~eventType=PaymentEventTypes.PaymentMethodInfoCard,
      )
  ) {
    let payload = createCardInfoPayload(
      ~bin,
      ~last4,
      ~brand,
      ~expiryMonth,
      ~expiryYear,
      ~formattedExpiry,
      ~isCardNumberComplete,
      ~isCvcComplete,
      ~isExpiryComplete,
      ~isCardNumberValid,
      ~isExpiryValid,
      ~isCvcValid,
      ~isSavedCard,
    )
    Utils.messageParentWindow(payload)
  }
}

let emitPaymentMethodStatus = (
  ~subscriptionEvents,
  ~paymentMethod,
  ~paymentMethodType,
  ~isSavedPaymentMethod,
  ~isOneClickWallet=false,
) => {
  if (
    subscriptionEvents->Option.isNone ||
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscriptionEvents->Option.getOr([]),
        ~eventType=PaymentEventTypes.PaymentMethodStatus,
      )
  ) {
    let payload = createPaymentMethodStatusPayload(
      ~paymentMethod,
      ~paymentMethodType,
      ~isSavedPaymentMethod,
      ~isOneClickWallet,
    )
    Utils.messageParentWindow(payload)
  }
}

let emitBillingAddress = (~subscriptionEvents, ~country, ~state, ~postalCode) => {
  if (
    subscriptionEvents->Option.isNone ||
      PaymentEventData.shouldEmitEvent(
        ~subscribedEvents=subscriptionEvents->Option.getOr([]),
        ~eventType=PaymentEventTypes.PaymentMethodInfoBillingAddress,
      )
  ) {
    let payload = createBillingAddressPayload(~country, ~state, ~postalCode)
    Utils.messageParentWindow(payload)
  }
}

let useFormStatus = (~empty: bool, ~complete: bool, ~isOneClickWallet: bool=false) => {
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let subscriptionEvents = options.subscriptionEvents

  React.useEffect(() => {
    if !isOneClickWallet {
      let formStatusValue = PaymentEventData.computeFormStatus(~isComplete=complete, ~isEmpty=empty)
      if (
        subscriptionEvents->Option.isNone ||
          PaymentEventData.shouldEmitEvent(
            ~subscribedEvents=subscriptionEvents->Option.getOr([]),
            ~eventType=PaymentEventTypes.FormStatus,
          )
      ) {
        let payload = SubscriptionEventTypes.createFormStatusPayload(~status=formStatusValue)
        Utils.messageParentWindow(payload)
      }
    }
    None
  }, (empty, complete, isOneClickWallet, subscriptionEvents))
}

let useBillingAddress = () => {
  let country = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let state = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressState).value
  let pinCode = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressPincode).value
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)

  React.useEffect(() => {
    emitBillingAddress(
      ~subscriptionEvents=options.subscriptionEvents,
      ~country,
      ~state,
      ~postalCode=pinCode,
    )

    None
  }, (country, state, pinCode, options.subscriptionEvents))
}

let usePaymentMethodStatus = (
  ~paymentMethodName: string,
  ~paymentMethods: array<PaymentMethodsRecord.methods>,
  ~isSavedPaymentMethod: bool,
  ~isOneClickWallet: bool,
) => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)

  React.useEffect(() => {
    switch PaymentUtils.getPaymentMethodAndType(
      ~paymentMethodName,
      ~paymentMethods,
      ~logger=loggerState,
    ) {
    | Some((paymentMethod, paymentMethodType)) =>
      emitPaymentMethodStatus(
        ~subscriptionEvents=options.subscriptionEvents,
        ~paymentMethod,
        ~paymentMethodType,
        ~isSavedPaymentMethod,
        ~isOneClickWallet,
      )
    | None => ()
    }

    None
  }, (
    paymentMethodName,
    paymentMethods,
    isSavedPaymentMethod,
    isOneClickWallet,
    options.subscriptionEvents,
  ))
}
