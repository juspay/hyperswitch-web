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
  if shouldEmitEvent(subscriptionEvents, CARD_INFO) {
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
  if shouldEmitEvent(subscriptionEvents, PAYMENT_METHOD_STATUS) {
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
  if shouldEmitEvent(subscriptionEvents, PAYMENT_METHOD_INFO_BILLING_ADDRESS) {
    let payload = createBillingAddressPayload(~country, ~state, ~postalCode)
    Utils.messageParentWindow(payload)
  }
}

let useFormStatus = (~empty: bool, ~complete: bool, ~isOneClickWallet: bool=false) => {
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let subscriptionEvents = options.subscriptionEvents

  React.useEffect(() => {
    if !isOneClickWallet {
      let formStatusValue = if complete {
        Complete
      } else if empty {
        Empty
      } else {
        Filling
      }
      if shouldEmitEvent(subscriptionEvents, FORM_STATUS) {
        let payload = createFormStatusPayload(~status=formStatusValue->formStatusValueToString)
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
