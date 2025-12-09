open PaymentType
open RecoilAtoms

@react.component
let make = (
  ~paymentType: CardThemeType.mode,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
) => {
  let divRef = React.useRef(Nullable.null)
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {savedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)
  let (savedMethods, setSavedMethods) = React.useState(_ => [])
  let (savedMethodsV2, setSavedMethodsV2) = Recoil.useRecoilState(RecoilAtomsV2.savedMethodsV2)
  let (isLoading, setIsLoading) = React.useState(_ => false)
  let (showAddScreen, setShowAddScreen) = Recoil.useRecoilState(RecoilAtomsV2.showAddScreen)
  let (cardBrandValue, setCardBrand) = Recoil.useRecoilState(cardBrand)
  let paymentManagementListValue = Recoil.useRecoilValueFromAtom(
    PaymentUtils.paymentManagementListValue,
  )
  let handleBack = _ => {
    setShowAddScreen(_ => false)
  }
  let {isCardValid, isCardSupported, cardNumber, setCardError} = cardProps

  let {isExpiryValid, cardExpiry, setExpiryError} = expiryProps

  let {isCVCValid, setCvcError} = cvcProps

  React.useEffect(() => {
    setCardBrand(_ => cardNumber->CardUtils.getCardBrand)
    None
  }, [cardNumber])

  React.useEffect(() => {
    if savedMethodsV2->Array.length == 0 {
      setShowAddScreen(_ => true)
    }
    None
  }, [savedMethodsV2->Array.length])

  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let (savedPaymentMethodsV2, setSavedPaymentMethodsV2) = Recoil.useRecoilState(
    PaymentUtils.paymentManagementListValue,
  )
  let {displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)
  React.useEffect(() => {
    switch paymentManagementList {
    | LoadedV2(val) =>
      setSavedPaymentMethodsV2(_ => val)
      setIsLoading(_ => false)
    | _ => ()
    }
    None
  }, [paymentManagementList])

  React.useEffect(() => {
    switch savedPaymentMethods {
    | LoadedSavedCards(savedPaymentMethods) => {
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
    | NoResult => setIsLoading(_ => false)
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
    | (_, _, _) => CardUtils.getCardBrandInvalidError(~cardBrand=cardBrandValue, ~localeString)
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
    <RenderIf
      condition={showAddScreen &&
      paymentManagementListValue.paymentMethodsEnabled->Array.length != 0}>
      <div className="flex flex-col gap-3">
        <RenderIf condition={savedMethodsV2->Array.length != 0}>
          <Icon
            size=18
            name="arrow-back"
            style={color: themeObj.colorDanger}
            className="cursor-pointer ml-1 mb-[6px]"
            onClick={_ => {
              handleBack()
            }}
          />
        </RenderIf>
        <PaymentElementRendererLazy paymentType cardProps cvcProps expiryProps />
        <div className="mt-4">
          <PayNowButton label="Save card" />
        </div>
      </div>
    </RenderIf>
    <RenderIf
      condition={showAddScreen &&
      paymentManagementListValue.paymentMethodsEnabled->Array.length == 0}>
      <ErrorBoundary.ErrorTextAndImage divRef level={Top} />
    </RenderIf>
    <RenderIf condition={!showAddScreen}>
      <RenderIf condition={!isLoading}>
        <SavedPaymentManagement savedMethods setSavedMethods />
      </RenderIf>
      <RenderIf condition={isLoading}>
        <PaymentElementShimmer.SavedPaymentShimmer />
      </RenderIf>
      <RenderIf condition={GlobalVars.sdkVersion == V2}>
        <div
          className="Label flex flex-row gap-3 items-end cursor-pointer mt-4"
          style={
            fontSize: "14px",
            float: "left",
            fontWeight: "500",
            width: "fit-content",
            color: themeObj.colorPrimary,
          }
          role="button"
          ariaLabel="Click to use new payment methods"
          tabIndex=0
          onClick={_ => setShowAddScreen(_ => true)}
          dataTestId={TestUtils.addNewCardIcon}>
          <Icon name="plus" size=19 />
          {React.string("Add new card")}
        </div>
      </RenderIf>
    </RenderIf>
    <PoweredBy />
  </>
}

let default = make
