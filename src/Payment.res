open CardUtils
open CardThemeType
open CardTheme
open JotaiAtoms
open PaymentTypeContext
open CommonCardProps

let setUserError = message => {
  SdkLogger.logLifecycle(
    ~event=FormValidationFailed({reason: message}),
    ~paymentMethod=Card,
  )
  Utils.postFailedSubmitResponse(~errortype="validation_error", ~message)
}

@react.component
let make = (~paymentMode, ~integrateError) => {
  let {localeString} = Jotai.useAtomValue(configAtom)
  let {iframeId, sdkAuthorization} = Jotai.useAtomValue(keys)
  let isManualRetryEnabled = Jotai.useAtomValue(isManualRetryEnabled)
  let areRequiredFieldsValid = Jotai.useAtomValue(areRequiredFieldsValid)
  let (isFocus, setIsFocus) = React.useState(_ => false)

  let intent = PaymentHelpers.usePaymentIntent(Card)

  let paymentType = React.useMemo1(() => {
    paymentMode->getPaymentMode
  }, [paymentMode])

  let {cardProps, expiryProps, cvcProps, zipProps, blurState} = useCardForm(
    ~paymentType,
    ~runEligibility=paymentType !== Card,
  )
  let {
    isCardValid,
    setCardError,
    cardNumber,
    cardBrand,
    cardEligibilityError,
    eligibilityOfferDetails,
    isEligibilityPending,
  } = cardProps
  let {isExpiryValid, setExpiryError, cardExpiry} = expiryProps
  let {isCVCValid, setCvcError, cvcNumber} = cvcProps
  let {isZipValid} = zipProps

  let handleElementFocus = React.useMemo(() => {
    isFocus => {
      setIsFocus(_ => isFocus)
    }
  }, (isCardValid, isCVCValid, isExpiryValid, isZipValid))
  React.useEffect(() => {
    switch (isCardValid, isExpiryValid, isCVCValid) {
    | (Some(cardValid), Some(expiryValid), Some(cvcValid)) =>
      CardUtils.emitIsFormReadyForSubmission(
        cardValid && expiryValid && cvcValid && areRequiredFieldsValid && !isEligibilityPending,
      )
    | _ => ()
    }
    None
  }, (isCardValid, isExpiryValid, isCVCValid, areRequiredFieldsValid, isEligibilityPending))
  let submitAPICall = (body, confirmParam) => {
    let offerDetailsBody =
      eligibilityOfferDetails
      ->Option.map(offerDetails =>
        PaymentBody.offerDetailsBody(~offerQuoteIds=offerDetails.offerQuoteIds)
      )
      ->Option.getOr([])
    intent(
      ~bodyArr=body->Array.concat(offerDetailsBody),
      ~confirmParam,
      ~handleUserError=false,
      ~manualRetry=isManualRetryEnabled,
    )
  }

  let submitValue = (_ev, confirmParam) => {
    let validFormat = switch paymentMode->getPaymentMode {
    | Card =>
      isCardValid->Option.getOr(false) &&
      isExpiryValid->Option.getOr(false) &&
      isCVCValid->Option.getOr(false) &&
      cardEligibilityError->Option.isNone &&
      !isEligibilityPending
    | CardNumberElement =>
      isCardValid->Option.getOr(false) &&
      checkCardCVC(getCardElementValue(iframeId, "card-cvc"), cardBrand) &&
      checkCardExpiry(getCardElementValue(iframeId, "card-expiry")) &&
      cardEligibilityError->Option.isNone &&
      !isEligibilityPending
    | _ => true
    }
    let cardNetwork = [
      ("card_network", cardBrand != "" ? cardBrand->JSON.Encode.string : JSON.Encode.null),
    ]
    if validFormat {
      let body = switch paymentMode->getPaymentMode {
      | Card =>
        let (month, year) = getExpiryDates(cardExpiry)

        PaymentBody.cardPaymentBody(
          ~cardNumber,
          ~month,
          ~year,
          ~cardHolderName=None,
          ~cvcNumber,
          ~cardBrand=cardNetwork,
        )
      | CardNumberElement =>
        let (month, year) = getExpiryDates(getCardElementValue(iframeId, "card-expiry"))
        let localCvcNumber = getCardElementValue(iframeId, "card-cvc")
        PaymentBody.cardPaymentBody(
          ~cardNumber,
          ~month,
          ~year,
          ~cardHolderName=None,
          ~cvcNumber=localCvcNumber,
          ~cardBrand=cardNetwork,
        )
      | _ => []
      }

      switch paymentMode->getPaymentMode {
      | Card
      | CardNumberElement =>
        submitAPICall(body, confirmParam)
      | _ => ()
      }
    } else {
      let userError = ref(None)
      let noteUserError = message =>
        switch userError.contents {
        | None => userError := Some(message)
        | Some(_) => ()
        }
      if cardNumber === "" {
        setCardError(_ => localeString.cardNumberEmptyText)
        noteUserError(localeString.enterFieldsText)
      } else if cardEligibilityError->Option.isSome {
        let msg = EligibilityHelpers.getCardEligibilityErrorText(
          ~cardEligibilityError,
          ~localeString,
        )
        setCardError(_ => msg)
        noteUserError(msg)
      } else if isEligibilityPending {
        noteUserError(localeString.paymentDetailsBeingCheckedText)
      }
      if cardExpiry === "" {
        setExpiryError(_ => localeString.cardExpiryDateEmptyText)
        noteUserError(localeString.enterFieldsText)
      }
      if cvcNumber === "" {
        setCvcError(_ => localeString.cvcNumberEmptyText)
        noteUserError(localeString.enterFieldsText)
      }
      if !validFormat {
        noteUserError(localeString.enterValidDetailsText)
      }
      switch userError.contents {
      | Some(message) => setUserError(message)
      | None => ()
      }
    }
  }

  React.useEffect(() => {
    open Utils
    let handleDoSubmit = (ev: Window.event) => {
      let json = ev.data->safeParse
      let jsonDict = json->getDictFromJson
      let confirm = jsonDict->ConfirmType.itemToObjMapper
      if confirm.doSubmit {
        submitValue(ev, confirm.confirmParams)
      }
    }
    handleMessage(handleDoSubmit, "")
  }, (
    cardNumber,
    cvcNumber,
    cardExpiry,
    isCVCValid,
    isExpiryValid,
    isCardValid,
    cardEligibilityError,
    eligibilityOfferDetails,
    isEligibilityPending,
    sdkAuthorization,
  ))

  React.useEffect(() => {
    // Only the payment element and cardCvc ever emit `ready`, so confirmPayment's ready-gate
    // stalled forever for card/cardNumber/cardExpiry mounts - emit for these modes too.
    switch paymentMode->getPaymentMode {
    | (Card | CardNumberElement | CardExpiryElement) as mode =>
      SubscriptionEventHooks.emitReady(
        ~iframeId,
        ~elementType=CardThemeType.getPaymentModeToString(mode),
      )
    | _ => ()
    }
    None
  }, (iframeId, paymentMode))

  if integrateError {
    <ErrorOccured />
  } else {
    <PaymentTypeContext.provider value={paymentType: paymentType}>
      <RenderPaymentMethods
        paymentType cardProps expiryProps cvcProps zipProps handleElementFocus blurState isFocus
      />
    </PaymentTypeContext.provider>
  }
}
