let useIsGuestCustomer = () => {
  let {customerPaymentMethods} = RecoilAtoms.optionAtom->Recoil.useRecoilValueFromAtom

  React.useMemo(() => {
    switch customerPaymentMethods {
    | LoadedSavedCards(_, false)
    | NoResult(false) => false
    | _ => true
    }
  }, [customerPaymentMethods])
}

let useHandlePostMessages = (~complete, ~empty, ~paymentType, ~savedMethod=false) => {
  open RecoilAtoms

  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let setIsPayNowButtonDisable = Recoil.useSetRecoilState(payNowButtonDisable)
  let {sdkHandleConfirmPayment} = Recoil.useRecoilValueFromAtom(optionAtom)
  let showMainScreen = Recoil.useRecoilValueFromAtom(showCardFieldsAtom)

  React.useEffect(() => {
    let isPaymentMethodScreenAndWallet =
      showMainScreen &&
      (paymentType === "google_pay" || paymentType === "paypal" || paymentType === "apple_pay")
    if !sdkHandleConfirmPayment.allowButtonBeforeValidation && !isPaymentMethodScreenAndWallet {
      let isCompletelyFilled = complete && paymentType !== ""
      setIsPayNowButtonDisable(_ => !isCompletelyFilled)
    }
    Utils.handlePostMessageEvents(~complete, ~empty, ~paymentType, ~loggerState, ~savedMethod)
    None
  }, (complete, empty, paymentType))
}

let useIsCustomerAcceptanceRequired = (
  ~displaySavedPaymentMethodsCheckbox,
  ~isSaveCardsChecked,
  ~isGuestCustomer,
) => {
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  React.useMemo(() => {
    if displaySavedPaymentMethodsCheckbox {
      isSaveCardsChecked || paymentMethodListValue.payment_type === SETUP_MANDATE
    } else {
      !(isGuestCustomer || paymentMethodListValue.payment_type === NORMAL)
    }
  }, (
    isSaveCardsChecked,
    paymentMethodListValue.payment_type,
    isGuestCustomer,
    displaySavedPaymentMethodsCheckbox,
  ))
}
