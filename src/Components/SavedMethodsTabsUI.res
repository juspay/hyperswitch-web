@react.component
let make = (
  ~savedMethods: array<PaymentType.customerMethods>,
  ~paymentToken: RecoilAtomTypes.paymentToken,
  ~setPaymentToken,
  ~cvcProps,
  ~cardProps,
  ~setRequiredFieldsBody,
  ~isClickToPayAuthenticateError,
  ~setIsClickToPayAuthenticateError,
  ~getVisaCards,
  ~closeComponentIfSavedMethodsAreEmpty,
  ~loggerState,
) => {
  open CardUtils

  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)
  let {paymentMethodOrder} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {layout} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let optionAtomValue = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)

  let (selectedSavedOption, setSelectedSavedOption) = Recoil.useRecoilState(
    RecoilAtoms.selectedSavedOptionAtom,
  )
  let (cardsContainerWidth, setCardsContainerWidth) = React.useState(_ => 0)
  let (cardOptions, setCardOptions) = React.useState(_ => [])
  let (dropDownOptions, setDropDownOptions) = React.useState(_ => [])

  let {paymentToken: paymentTokenVal} = paymentToken

  let cardShimmerCount = React.useMemo(() => {
    Utils.cardsToRender(cardsContainerWidth)
  }, [cardsContainerWidth])

  let groupedMethods = React.useMemo(() => {
    let groupedMethods = Dict.make()
    let addToGroup = (dict, key, value) => {
      switch dict->Dict.get(key) {
      | Some(arr) => dict->Dict.set(key, Array.concat(arr, [value]))
      | None => dict->Dict.set(key, [value])
      }
    }
    savedMethods->Array.forEach(savedMethod => {
      let key = PaymentMethodsRecord.getConstructedPaymentMethodName(
        ~paymentMethod=savedMethod.paymentMethod,
        ~paymentMethodType={savedMethod.paymentMethodType->Option.getOr("other")},
      )
      groupedMethods->addToGroup(key, savedMethod)
    })
    groupedMethods
  }, [savedMethods])

  let keyArr = React.useMemo(() => {
    let keys = groupedMethods->Dict.keysToArray
    let paymentOrder = paymentMethodOrder->Utils.getOptionalArr->Utils.removeDuplicate
    let sortedKeys = keys->Utils.sortBasedOnPriority(paymentOrder)

    switch keys->Array.includes("card") {
    | true => ["card", ...sortedKeys->Array.filter(key => key !== "card")]
    | false => sortedKeys
    }
  }, [groupedMethods])

  let arr = groupedMethods->Dict.get(selectedSavedOption)->Option.getOr([])

  let bottomElement = {
    <div
      className="PickerItemContainer" tabIndex={0} role="region" ariaLabel="Saved payment methods">
      {arr
      ->Array.mapWithIndex((obj, i) =>
        <SavedCardItem
          key={i->Int.toString}
          setPaymentToken
          isActive={paymentTokenVal == obj.paymentToken}
          paymentItem=obj
          brandIcon={obj->getPaymentMethodBrand}
          index=i
          savedCardlength={savedMethods->Array.length}
          cvcProps
          setRequiredFieldsBody
        />
      )
      ->React.array}
      <RenderIf condition={clickToPayConfig.isReady == Some(true) && selectedSavedOption == "card"}>
        <ClickToPayAuthenticate
          loggerState
          savedMethods
          isClickToPayAuthenticateError
          setIsClickToPayAuthenticateError
          setPaymentToken
          paymentTokenVal
          cvcProps
          getVisaCards
          setIsClickToPayRememberMe={React.useState(_ => false)->snd}
          closeComponentIfSavedMethodsAreEmpty
        />
      </RenderIf>
    </div>
  }

  React.useEffect(() => {
    if selectedSavedOption !== "" {
      loggerState.setLogInfo(
        ~value="",
        ~eventName=PAYMENT_METHOD_CHANGED,
        ~paymentMethod=selectedSavedOption->String.toUpperCase,
      )
    }
    None
  }, [selectedSavedOption])

  React.useEffect(() => {
    if selectedSavedOption === "" && keyArr->Array.length > 0 {
      setSelectedSavedOption(_ => keyArr->Array.get(0)->Option.getOr(""))
    }
    None
  }, (keyArr, selectedSavedOption))

  React.useEffect(() => {
    let currentTabMethods = groupedMethods->Dict.get(selectedSavedOption)->Option.getOr([])

    let defaultSelectedPaymentMethod = optionAtomValue.displayDefaultSavedPaymentIcon
      ? currentTabMethods->Array.find(savedMethod => savedMethod.defaultPaymentMethodSet)
      : currentTabMethods->Array.get(0)

    let isCurrentTabEmpty = currentTabMethods->Array.length === 0

    let tokenObj = switch (isCurrentTabEmpty, defaultSelectedPaymentMethod) {
    | (false, Some(defaultSelectedPaymentMethod)) => Some(defaultSelectedPaymentMethod)
    | (false, None) =>
      Some(currentTabMethods->Array.get(0)->Option.getOr(PaymentType.defaultCustomerMethods))
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
  }, (savedMethods, selectedSavedOption, groupedMethods))

  React.useEffect(() => {
    let cardsCount = Utils.cardsToRender(cardsContainerWidth)
    let cardOpts = Array.slice(~start=0, ~end=cardsCount, keyArr)
    let dropOpts = keyArr->Array.sliceToEnd(~start=cardsCount)
    let isCard = cardOpts->Array.includes(selectedSavedOption)
    if !isCard && selectedSavedOption !== "" && keyArr->Array.includes(selectedSavedOption) {
      let (cardArr, dropdownArr) = CardUtils.swapCardOption(cardOpts, dropOpts, selectedSavedOption)
      setCardOptions(_ => cardArr)
      setDropDownOptions(_ => dropdownArr)
    } else {
      setCardOptions(_ => cardOpts)
      setDropDownOptions(_ => dropOpts)
    }
    None
  }, (cardsContainerWidth, keyArr, selectedSavedOption))

  React.useEffect(() => {
    if layoutClass.\"type" == Tabs {
      let isCard = cardOptions->Array.includes(selectedSavedOption)
      if !isCard {
        let (cardArr, dropdownArr) = CardUtils.swapCardOption(
          cardOptions,
          dropDownOptions,
          selectedSavedOption,
        )
        setCardOptions(_ => cardArr)
        setDropDownOptions(_ => dropdownArr)
      }
    }
    None
  }, (selectedSavedOption, layoutClass.\"type", cardOptions, dropDownOptions))

  <PaymentOptions
    setCardsContainerWidth
    cardOptions
    dropDownOptions
    checkoutEle=bottomElement
    cardShimmerCount
    cardProps
    selectedOption=selectedSavedOption
    setSelectedOption=setSelectedSavedOption
  />
}
