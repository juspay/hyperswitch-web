open PaymentType
open RecoilAtoms

@react.component
let make = (~paymentType: CardThemeType.mode) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {savedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)
  let (savedMethods, setSavedMethods) = React.useState(_ => [])
  let (savedMethodsV2, setSavedMethodsV2) = React.useState(_ => [])
  let (isLoading, setIsLoading) = React.useState(_ => false)
  let (showAddScreen, setShowAddScreen) = Recoil.useRecoilState(RecoilAtomsV2.showAddScreen)
  let (cardBrand, setCardBrand) = Recoil.useRecoilState(cardBrand)
  let (paymentMethodListValue, _setPaymentMethodListValue) = Recoil.useRecoilState(
    PaymentUtils.paymentMethodListValue,
  )
  let (logger, _initTimestamp) = React.useMemo0(() => {
    (HyperLogger.make(~source=Elements(PaymentMethodsManagement)), Date.now())
  })
  let handleOnClick = () => {
    setShowAddScreen(_ => true)
  }
  let supportedCardBrands = React.useMemo(() => {
    paymentMethodListValue->PaymentUtils.getSupportedCardBrands
  }, [paymentMethodListValue])
  let cardType = React.useMemo1(() => {
    cardBrand->CardUtils.getCardType
  }, [cardBrand])
  let (cardProps, expiryProps, cvcProps, _zipProps) = CommonCardProps.useCardProps(
    ~logger,
    ~supportedCardBrands,
    ~cardType,
    ~cardBrand,
  )
  let handleBack = _ => {
    Console.log("ONClick of back")
    setShowAddScreen(_ => false)
  }
  let (
    isCardValid,
    setIsCardValid,
    isCardSupported,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    icon,
    cardError,
    setCardError,
    maxCardLength,
    _,
  ) = cardProps

  let (
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    onExpiryKeyDown,
    expiryError,
    setExpiryError,
  ) = expiryProps

  let (
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    setCvcNumber,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    onCvcKeyDown,
    cvcError,
    setCvcError,
  ) = cvcProps

  React.useEffect(() => {
    setCardBrand(_ => cardNumber->CardUtils.getCardBrand)
    None
  }, [cardNumber])

  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let (savedPaymentMethodsV2, setSavedPaymentMethodsV2) = Recoil.useRecoilState(
    PaymentUtils.paymentManagementListValue,
  )
  let {showCardFormByDefault, displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(
    optionAtom,
  )

  let handleConfirmClick = () => {
    //Confirm Api
    Console.log("Save the card")
  }

  React.useEffect(() => {
    switch paymentManagementList {
    | LoadedV2(val) =>
      setSavedPaymentMethodsV2(_ => val)
      setIsLoading(_ => false)
    | _ => ()
    }
    None
  }, (paymentManagementList, showCardFormByDefault))

  React.useEffect(() => {
    switch savedPaymentMethods {
    | LoadedSavedCards(savedPaymentMethods, _) => {
        let defaultPaymentMethod =
          savedPaymentMethods->Array.find(savedCard => savedCard.defaultPaymentMethodSet)

        let savedCardsWithoutDefaultPaymentMethod = savedPaymentMethods->Array.filter(savedCard => {
          !savedCard.defaultPaymentMethodSet
        })

        let finalSavedPaymentMethods = switch defaultPaymentMethod {
        | Some(defaultPaymentMethod) =>
          [defaultPaymentMethod]->Array.concat(savedCardsWithoutDefaultPaymentMethod)
        | None => savedCardsWithoutDefaultPaymentMethod
        }

        setSavedMethods(_ => finalSavedPaymentMethods)
        setIsLoading(_ => false)
      }
    | LoadingSavedCards => setIsLoading(_ => true)
    | NoResult(_) => setIsLoading(_ => false)
    }

    None
  }, (savedPaymentMethods, displaySavedPaymentMethods))

  React.useEffect(() => {
    let cardError = switch (
      isCardSupported->Option.getOr(true),
      isCardValid->Option.getOr(true),
      cardNumber->String.length == 0,
    ) {
    | (_, _, true) => ""
    | (true, true, _) => ""
    | (true, _, _) => localeString.inValidCardErrorText
    | (_, _, _) => CardUtils.getCardBrandInvalidError(~cardNumber, ~localeString)
    }
    let cardError = isCardValid->Option.isSome ? cardError : ""
    setCardError(_ => cardError)
    None
  }, [isCardValid, isCardSupported])

  React.useEffect(() => {
    setCvcError(_ => isCVCValid->Option.getOr(true) ? "" : localeString.inCompleteCVCErrorText)
    None
  }, [isCVCValid])

  React.useEffect(() => {
    setSavedMethodsV2(_ => savedPaymentMethodsV2.customerPaymentMethods)
    None
  }, (savedPaymentMethodsV2, displaySavedPaymentMethods))

  React.useEffect(() => {
    setExpiryError(_ =>
      switch (isExpiryValid, CardUtils.isExpiryComplete(cardExpiry)) {
      | (Some(true), true) => ""
      | (Some(false), true) => localeString.pastExpiryErrorText
      | (Some(_), false) => localeString.inCompleteExpiryErrorText
      | (None, _) => ""
      }
    )
    None
  }, (isExpiryValid, CardUtils.isExpiryComplete(cardExpiry)))

  <>
    <RenderIf condition={showAddScreen}>
      <button
        className="p-2 text-sm font-medium text-gray-600 hover:text-gray-900 hover:underline "
        onClick={handleBack}>
        {React.string("Back")}
      </button>
      <PaymentElementRendererLazy paymentType cardProps cvcProps expiryProps />
      <div className="mt-4">
        <PayNowButton label="Save card" onClickHandler=handleConfirmClick />
      </div>
    </RenderIf>
    <RenderIf condition={!showAddScreen}>
      <RenderIf condition={!isLoading}>
        <SavedPaymentManagement savedMethods setSavedMethods savedMethodsV2 setSavedMethodsV2 />
      </RenderIf>
      <RenderIf condition={isLoading}>
        <PaymentElementShimmer.SavedPaymentShimmer />
      </RenderIf>
      <RenderIf condition={GlobalVars.sdkVersionEnum == V2}>
        <div className="mt-4">
          <AddButton onClickHandler={handleOnClick} />
        </div>
      </RenderIf>
    </RenderIf>
    <PoweredBy />
  </>
}

let default = make
