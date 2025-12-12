@react.component
let make = (
  ~savedMethods: array<PaymentType.customerMethods>,
  ~setPaymentToken,
  ~cvcProps,
  ~children,
  ~paymentToken,
  ~sessions,
  ~loadSavedCards,
  ~isClickToPayAuthenticateError,
  ~setIsClickToPayAuthenticateError,
  ~getVisaCards,
  ~closeComponentIfSavedMethodsAreEmpty,
  ~isShowPaymentMethodsDependingOnClickToPay,
) => {
  let selectedOption = Recoil.useRecoilValueFromAtom(RecoilAtoms.selectedOptionAtom)
  let savedMethodsGroupedByType = savedMethods->Array.reduce(Dict.make(), (acc, savedMethod) => {
    let paymentTypeKey = PaymentHelpers.getConstructedPaymentMethodName(
      ~paymentMethod=savedMethod.paymentMethod,
      ~paymentMethodType={savedMethod.paymentMethodType->Option.getOr("other")},
    )
    switch acc->Dict.get(paymentTypeKey) {
    | Some(existingMethods) =>
      acc->Dict.set(paymentTypeKey, Array.concat(existingMethods, [savedMethod]))
    | None => acc->Dict.set(paymentTypeKey, [savedMethod])
    }
    acc
  })

  let savedMethodsForSelectedOption =
    savedMethodsGroupedByType->Dict.get(selectedOption)->Option.getOr([])

  let savedMethodsCount = savedMethodsForSelectedOption->Array.length
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (showPaymentMethodsScreen, setShowPaymentMethodsScreen) = Recoil.useRecoilState(
    RecoilAtoms.showPaymentMethodsScreen,
  )

  let selectedToken: RecoilAtomTypes.paymentToken = switch savedMethodsForSelectedOption->Array.get(
    0,
  ) {
  | Some(firstSavedMethod) => {
      paymentToken: firstSavedMethod.paymentToken,
      customerId: firstSavedMethod.customerId,
    }
  | None => RecoilAtomTypes.defaultPaymentToken
  }

  React.useEffect(() => {
    setPaymentToken(_ => selectedToken)
    None
  }, (showPaymentMethodsScreen, selectedOption))

  React.useEffect(() => {
    let shouldShowForm = savedMethodsCount == 0
    let shouldShowClickToPayCards =
      isShowPaymentMethodsDependingOnClickToPay && selectedOption == "card"
    setShowPaymentMethodsScreen(_ => !shouldShowClickToPayCards && shouldShowForm)

    None
  }, (selectedOption, savedMethodsCount, isShowPaymentMethodsDependingOnClickToPay))

  {
    showPaymentMethodsScreen
      ? <>
          children
          <RenderIf condition={savedMethodsCount > 0 || isShowPaymentMethodsDependingOnClickToPay}>
            <SwitchViewButton
              onClick={_ => setShowPaymentMethodsScreen(_ => false)}
              icon={<Icon name="circle_dots" size=20 width=19 />}
              title={localeString.useExistingPaymentMethods}
              ariaLabel="Click to use existing payment methods"
              onKeyDown={event => {
                let key = JsxEvent.Keyboard.key(event)
                let keyCode = JsxEvent.Keyboard.keyCode(event)
                if key == "Enter" || keyCode == 13 {
                  setShowPaymentMethodsScreen(_ => false)
                }
              }}
            />
          </RenderIf>
        </>
      : <SavedMethods
          paymentToken
          setPaymentToken
          savedMethods=savedMethodsForSelectedOption
          loadSavedCards
          cvcProps
          sessions
          isClickToPayAuthenticateError
          setIsClickToPayAuthenticateError
          getVisaCards
          closeComponentIfSavedMethodsAreEmpty
        />
  }
}
