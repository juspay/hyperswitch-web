open PaymentType
open Utils
open PaymentUtils

let cardsToRender = (width: int) => {
  let minWidth = 130
  let noOfCards = (width - 40) / minWidth
  noOfCards
}

@react.component
let make = (
  ~paymentType: CardThemeType.mode,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
) => {
  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)
  let (isClickToPayAuthenticateError, setIsClickToPayAuthenticateError) = React.useState(_ => false)
  let (areClickToPayUIScriptsLoaded, setAreClickToPayUIScriptsLoaded) = React.useState(_ => false)
  let optionAtomValue = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)

  let (sessions, setSessions) = React.useState(_ => Dict.make()->JSON.Encode.object)
  let (savedMethods, setSavedMethods) = React.useState(_ => [])

  let (paymentToken, setPaymentToken) = Recoil.useRecoilState(RecoilAtoms.paymentTokenAtom)

  let (
    loadSavedCards: savedCardsLoadState,
    setLoadSavedCards: (savedCardsLoadState => savedCardsLoadState) => unit,
  ) = React.useState(_ => LoadingSavedCards)

  let (getVisaCards, closeComponentIfSavedMethodsAreEmpty) = ClickToPayHook.useClickToPay(
    ~areClickToPayUIScriptsLoaded,
    ~setSessions,
    ~setAreClickToPayUIScriptsLoaded,
    ~savedMethods,
    ~loadSavedCards,
    ~isSavedCardElement=true,
    ~setIsClickToPayAuthenticateError,
  )

  let isShowPaymentMethodsDependingOnClickToPay = React.useMemo(() => {
    (clickToPayConfig.clickToPayCards->Option.getOr([])->Array.length > 0 ||
    clickToPayConfig.isReady->Option.getOr(false) &&
      clickToPayConfig.clickToPayCards->Option.isNone ||
    clickToPayConfig.email !== "") && !isClickToPayAuthenticateError
  }, (clickToPayConfig, isClickToPayAuthenticateError))

  React.useEffect(() => {
    let defaultSelectedPaymentMethod = optionAtomValue.displayDefaultSavedPaymentIcon
      ? savedMethods->Array.find(savedMethod => savedMethod.defaultPaymentMethodSet)
      : savedMethods->Array.get(0)

    let isSavedMethodsEmpty = savedMethods->Array.length === 0

    let tokenObj = switch (isSavedMethodsEmpty, defaultSelectedPaymentMethod) {
    | (false, Some(defaultSelectedPaymentMethod)) => Some(defaultSelectedPaymentMethod)
    | (false, None) => Some(savedMethods->Array.get(0)->Option.getOr(defaultCustomerMethods))
    | _ => None
    }

    switch tokenObj {
    | Some(obj) =>
      setPaymentToken(_ => {
        paymentToken: obj.paymentToken,
        customerId: obj.customerId,
      })
    | None => ()
    }
    None
  }, [savedMethods])

  // React.useEffect(() => {
  //   switch (true, customerPaymentMethods) {
  //   // switch (displaySavedPaymentMethods, customerPaymentMethods) {
  //   | (false, _) => {
  //       setShowPaymentMethodsScreen(_ => isShowPaymentMethodsDependingOnClickToPay->not)
  //       setLoadSavedCards(_ => LoadedSavedCards([], true))
  //     }
  //   | (_, LoadingSavedCards) => ()
  //   | (_, LoadedSavedCards(savedPaymentMethods, isGuestCustomer)) => {
  //       let displayDefaultSavedPaymentIcon = optionAtomValue.displayDefaultSavedPaymentIcon
  //       let sortSavedPaymentMethods = (a, b) => {
  //         let defaultCompareVal = compareLogic(
  //           Date.fromString(a.lastUsedAt),
  //           Date.fromString(b.lastUsedAt),
  //         )
  //         if displayDefaultSavedPaymentIcon {
  //           if a.defaultPaymentMethodSet {
  //             -1.
  //           } else if b.defaultPaymentMethodSet {
  //             1.
  //           } else {
  //             defaultCompareVal
  //           }
  //         } else {
  //           defaultCompareVal
  //         }
  //       }

  //       let finalSavedPaymentMethods =
  //         savedPaymentMethods
  //         ->Array.copy
  //         ->Array.filter(savedMethod => {
  //           switch savedMethod.paymentMethodType {
  //           | Some("apple_pay") => isApplePayReady
  //           | Some("google_pay") => isGPayReady
  //           | _ => true
  //           }
  //         })
  //       finalSavedPaymentMethods->Array.sort(sortSavedPaymentMethods)

  //       let paymentOrder = paymentMethodOrder->getOptionalArr->removeDuplicate

  //       let sortSavedMethodsBasedOnPriority =
  //         finalSavedPaymentMethods->sortCustomerMethodsBasedOnPriority(
  //           paymentOrder,
  //           ~displayDefaultSavedPaymentIcon,
  //         )

  //       setSavedMethods(_ => sortSavedMethodsBasedOnPriority)
  //       setLoadSavedCards(_ =>
  //         finalSavedPaymentMethods->Array.length == 0
  //           ? NoResult(isGuestCustomer)
  //           : LoadedSavedCards(finalSavedPaymentMethods, isGuestCustomer)
  //       )
  //       setShowPaymentMethodsScreen(_ =>
  //         finalSavedPaymentMethods->Array.length == 0 &&
  //           isShowPaymentMethodsDependingOnClickToPay->not
  //       )
  //     }
  //   | (_, NoResult(isGuestCustomer)) => {
  //       setLoadSavedCards(_ => NoResult(isGuestCustomer))
  //       setShowPaymentMethodsScreen(_ => true && isShowPaymentMethodsDependingOnClickToPay->not)
  //     }
  //   }

  //   None
  // }, (
  //   customerPaymentMethods,
  //   displaySavedPaymentMethods,
  //   optionAtomValue,
  //   isApplePayReady,
  //   isGPayReady,
  //   clickToPayConfig.isReady,
  //   isShowPaymentMethodsDependingOnClickToPay,
  // ))

  let showPaymentMethodsScreen = false
  let displaySavedPaymentMethods = true

  {
    if clickToPayConfig.isReady->Option.isNone {
      if areClickToPayUIScriptsLoaded {
        <ClickToPayHelpers.SrcLoader />
      } else {
        <PaymentElementShimmer.SavedPaymentCardShimmer />
      }
    } else {
      <RenderIf
        condition={!showPaymentMethodsScreen &&
        (displaySavedPaymentMethods || isShowPaymentMethodsDependingOnClickToPay)}>
        <SavedMethods
          paymentToken
          setPaymentToken
          savedMethods
          loadSavedCards
          cvcProps
          sessions
          isClickToPayAuthenticateError
          setIsClickToPayAuthenticateError
          getVisaCards
          closeComponentIfSavedMethodsAreEmpty
          isSavedCardElement=true
        />
      </RenderIf>
    }
  }
}

let default = make
