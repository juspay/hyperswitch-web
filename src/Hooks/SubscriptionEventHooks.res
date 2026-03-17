open SubscriptionEventTypes
open PaymentEventData
open PaymentEventTypes

let emitCardInfo = (~subscriptionEvents, ~cardInfo: cardInfo) => {
  if (
    subscriptionEvents->Option.isNone ||
      shouldEmitEvent(
        ~subscribedEvents=subscriptionEvents->Option.getOr([]),
        ~eventType=PaymentMethodInfoCard,
      )
  ) {
    let payload = createCardInfoPayload(cardInfo)
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
      shouldEmitEvent(
        ~subscribedEvents=subscriptionEvents->Option.getOr([]),
        ~eventType=PaymentMethodStatus,
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
      shouldEmitEvent(
        ~subscribedEvents=subscriptionEvents->Option.getOr([]),
        ~eventType=PaymentMethodInfoBillingAddress,
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
      let formStatusValue = computeFormStatus(~isComplete=complete, ~isEmpty=empty)
      if (
        subscriptionEvents->Option.isNone ||
          shouldEmitEvent(
            ~subscribedEvents=subscriptionEvents->Option.getOr([]),
            ~eventType=FormStatus,
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
