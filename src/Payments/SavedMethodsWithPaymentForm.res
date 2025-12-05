@react.component
let make = (
  ~savedMethods: array<PaymentType.customerMethods>,
  ~selectedOption,
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

  let savedMethodsForSelectedTab =
    savedMethodsGroupedByType->Dict.get(selectedOption)->Option.getOr([])

  let savedMethodsCount = savedMethodsForSelectedTab->Array.length
  let selectedOption = Recoil.useRecoilValueFromAtom(RecoilAtoms.selectedOptionAtom)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (showPaymentMethodsScreen, setShowPaymentMethodsScreen) = Recoil.useRecoilState(
    RecoilAtoms.showPaymentMethodsScreen,
  )
  React.useEffect(() => {
    setPaymentToken(_ => {
      let selectedToken: RecoilAtomTypes.paymentToken = switch savedMethodsForSelectedTab[0] {
      | Some(firstSavedMethod) => {
          paymentToken: firstSavedMethod.paymentToken,
          customerId: firstSavedMethod.customerId,
        }
      | None => {
          paymentToken: "",
          customerId: "",
        }
      }
      selectedToken
    })
    None
  }, (showPaymentMethodsScreen, selectedOption))

  React.useEffect(() => {
    let shouldShowForm = savedMethodsCount == 0
    let shouldShowClickToPayCards =
      isShowPaymentMethodsDependingOnClickToPay && selectedOption == "card"
    setShowPaymentMethodsScreen(_ => !shouldShowClickToPayCards && shouldShowForm)

    None
  }, (selectedOption, savedMethodsCount))

  <>
    {showPaymentMethodsScreen
      ? <>
          children
          <RenderIf condition={savedMethodsCount > 0 || isShowPaymentMethodsDependingOnClickToPay}>
            <SwitchViewButton
              onClick={_ => setShowPaymentMethodsScreen(_ => false)}
              icon={<Icon name="circle_dots" size=20 width=19 />}
              title={localeString.useExistingPaymentMethods}
              ariaLabel="Click to use existing payment methods"
            />
          </RenderIf>
        </>
      : <SavedMethods
          paymentToken
          setPaymentToken
          savedMethods=savedMethodsForSelectedTab
          loadSavedCards
          cvcProps
          sessions
          isClickToPayAuthenticateError
          setIsClickToPayAuthenticateError
          getVisaCards
          closeComponentIfSavedMethodsAreEmpty
        />}
  </>
}
