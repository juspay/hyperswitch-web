type eligibilityState = {
  cardEligibilityError: option<string>,
  updateCardEligibilityError: option<string> => unit,
  eligibilitySurchargeDetails: option<EligibilityHelpers.eligibilitySurchargeDetails>,
  eligibilityOfferDetails: option<EligibilityHelpers.eligibilityOfferDetails>,
  isEligibilityPending: bool,
  triggerOnCardNumberChange: (~cardNumber: string, ~isCardSupportedAndValid: bool) => unit,
  resetEligibilityState: unit => unit,
}

let useCardEligibility = (~runEligibility=true): eligibilityState => {
  open JotaiAtoms

  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let {clientSecret, publishableKey, sdkAuthorization} = Jotai.useAtomValue(keys)
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let (cardEligibilityError, setCardEligibilityError) = React.useState(_ => None)
  let (eligibilitySurchargeDetails, setEligibilitySurchargeDetails) = React.useState(_ => None)
  let (eligibilityOfferDetails, setEligibilityOfferDetails) = React.useState(_ => None)
  let (isEligibilityPending, setIsEligibilityPending) = React.useState(_ => false)
  let eligibilityControllerRef = React.useRef(None)
  let {
    startDebounce: startEligibilityDebounce,
    cancelDebounce: cancelEligibilityDebounce,
  } = CommonHooks.useDebounce(~delayMs=300)
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

  React.useEffect0(() => {
    Some(
      () => {
        eligibilityControllerRef.current->Option.forEach(c => Fetch.AbortController.abort(c))
      },
    )
  })

  let checkCardEligibility = async (~cardNumber) => {
    await EligibilityHelpers.startEligibilityCheck(
      ~controllerRef=eligibilityControllerRef,
      ~clientSecret,
      ~publishableKey,
      ~customPodUri,
      ~bodyArr=PaymentBody.cardPaymentMethodEligibilityBody(~cardNumber),
      ~sdkAuthorization,
      ~endpoint,
      ~setIsEligibilityPending,
      ~setEligibilitySurchargeDetails,
      ~setEligibilityOfferDetails,
      ~setEligibilityError=Some(setCardEligibilityError),
      ~errorLogMessage="Card payment eligibility check failed",
      ~fetchEligibility={
        (
          ~clientSecret,
          ~publishableKey,
          ~customPodUri,
          ~bodyArr,
          ~sdkAuthorization,
          ~endpoint,
          ~signal,
        ) =>
          PaymentHelpers.fetchPaymentMethodEligibility(
            ~clientSecret,
            ~publishableKey,
            ~customPodUri,
            ~bodyArr,
            ~sdkAuthorization,
            ~endpoint,
            ~signal,
          )
      },
    )
  }

  let resetEligibilityState = () => {
    setCardEligibilityError(_ => None)
    setEligibilitySurchargeDetails(_ => None)
    setEligibilityOfferDetails(_ => None)
    setIsEligibilityPending(_ => false)
  }

  let triggerOnCardNumberChange = (~cardNumber, ~isCardSupportedAndValid) => {
    let shouldRunEligibility = paymentMethodListValue.sdk_next_action === Some("eligibility_check")
    if runEligibility && shouldRunEligibility {
      cancelEligibilityDebounce()
      setCardEligibilityError(_ => None)
      setEligibilitySurchargeDetails(_ => None)
      setEligibilityOfferDetails(_ => None)
      if !isCardSupportedAndValid {
        eligibilityControllerRef.current->Option.forEach(c => Fetch.AbortController.abort(c))
        eligibilityControllerRef.current = None
        setIsEligibilityPending(_ => false)
      } else {
        startEligibilityDebounce(() => {
          checkCardEligibility(~cardNumber)->ignore
        })
      }
    }
  }

  {
    cardEligibilityError,
    updateCardEligibilityError: error => setCardEligibilityError(_ => error),
    eligibilitySurchargeDetails,
    eligibilityOfferDetails,
    isEligibilityPending,
    triggerOnCardNumberChange,
    resetEligibilityState,
  }
}
