type eligibilityState = {
  cardEligibilityError: option<string>,
  updateCardEligibilityError: option<string> => unit,
  eligibilitySurchargeDetails: option<EligibilityHelpers.eligibilitySurchargeDetails>,
  isEligibilityPending: bool,
  triggerOnCardNumberChange: (~cardNumber: string, ~isCardSupportedAndValid: bool) => unit,
  resetEligibilityState: unit => unit,
}

let useCardEligibility = (~logger, ~runEligibility=true): eligibilityState => {
  open RecoilAtoms

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let {clientSecret, publishableKey, sdkAuthorization} = Recoil.useRecoilValueFromAtom(keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let (cardEligibilityError, setCardEligibilityError) = React.useState(_ => None)
  let (eligibilitySurchargeDetails, setEligibilitySurchargeDetails) = React.useState(_ => None)
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
      ~logger,
      ~customPodUri,
      ~bodyArr=PaymentBody.cardPaymentMethodEligibilityBody(~cardNumber),
      ~sdkAuthorization,
      ~endpoint,
      ~shouldBlockConfirm=paymentMethodListValue.should_block_confirm,
      ~setIsEligibilityPending,
      ~setEligibilitySurchargeDetails,
      ~setEligibilityError=Some(setCardEligibilityError),
      ~errorLogMessage="Card payment eligibility check failed",
      ~fetchEligibility={
        (
          ~clientSecret,
          ~publishableKey,
          ~logger,
          ~customPodUri,
          ~bodyArr,
          ~sdkAuthorization,
          ~endpoint,
          ~signal,
        ) =>
          PaymentHelpers.fetchPaymentMethodEligibility(
            ~clientSecret,
            ~publishableKey,
            ~logger,
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
    setIsEligibilityPending(_ => false)
  }

  let triggerOnCardNumberChange = (~cardNumber, ~isCardSupportedAndValid) => {
    if runEligibility && paymentMethodListValue.sdk_next_action === Some("eligibility_check") {
      cancelEligibilityDebounce()
      setCardEligibilityError(_ => None)
      setEligibilitySurchargeDetails(_ => None)
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
    isEligibilityPending,
    triggerOnCardNumberChange,
    resetEligibilityState,
  }
}
