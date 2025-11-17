@react.component
let make = (
  ~paymentToken: RecoilAtomTypes.paymentToken,
  ~setPaymentToken,
  ~savedMethods: array<PaymentType.customerMethods>,
  ~loadSavedCards: PaymentType.savedCardsLoadState,
  ~cvcProps,
  ~sessions,
  ~isClickToPayAuthenticateError,
  ~setIsClickToPayAuthenticateError,
  ~getVisaCards,
  ~closeComponentIfSavedMethodsAreEmpty,
  ~isClickToPayRememberMe,
  ~setIsClickToPayRememberMe,
  ~requiredFieldsBody,
  ~setRequiredFieldsBody,
) => {
  open CardUtils
  open UtilityHooks

  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)
  let {clickToPayProvider} = clickToPayConfig
  let customerMethods =
    clickToPayConfig.clickToPayCards
    ->Option.getOr([])
    ->Array.map(obj => obj->PaymentType.convertClickToPayCardToCustomerMethod(clickToPayProvider))

  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (showPaymentMethodsScreen, setShowPaymentMethodsScreen) = Recoil.useRecoilState(
    RecoilAtoms.showPaymentMethodsScreen,
  )
  let {
    displaySavedPaymentMethodsCheckbox,
    savedPaymentMethodsCheckboxCheckedByDefault,
  } = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ =>
    savedPaymentMethodsCheckboxCheckedByDefault
  )
  let isGuestCustomer = useIsGuestCustomer()

  let savedCardlength = savedMethods->Array.length
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let {paymentToken: paymentTokenVal} = paymentToken

  SavedMethodsSubmit.useSavedMethodsPayment(
    ~savedMethods,
    ~paymentToken,
    ~cvcProps,
    ~isClickToPayRememberMe,
    ~requiredFieldsBody,
    ~sessions,
  )

  let customerMethod = React.useMemo(_ =>
    savedMethods
    ->Array.concat(customerMethods)
    ->Array.filter(savedMethod => savedMethod.paymentToken === paymentTokenVal)
    ->Array.get(0)
    ->Option.getOr(PaymentType.defaultCustomerMethods)
  , [paymentTokenVal])

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  let bottomElement = {
    <div
      className="PickerItemContainer" tabIndex={0} role="region" ariaLabel="Saved payment methods">
      {savedMethods
      ->Array.mapWithIndex((obj, i) =>
        <SavedCardItem
          key={i->Int.toString}
          setPaymentToken
          isActive={paymentTokenVal == obj.paymentToken}
          paymentItem=obj
          brandIcon={obj->getPaymentMethodBrand}
          index=i
          savedCardlength
          cvcProps
          setRequiredFieldsBody
        />
      )
      ->React.array}
      <RenderIf condition={clickToPayConfig.isReady == Some(true)}>
        <ClickToPayAuthenticate
          loggerState
          savedMethods
          isClickToPayAuthenticateError
          setIsClickToPayAuthenticateError
          setPaymentToken
          paymentTokenVal
          cvcProps
          getVisaCards
          setIsClickToPayRememberMe
          closeComponentIfSavedMethodsAreEmpty
        />
      </RenderIf>
    </div>
  }

  let conditionsForShowingSaveCardCheckbox = React.useMemo(() => {
    !isGuestCustomer &&
    paymentMethodListValue.payment_type === NEW_MANDATE &&
    displaySavedPaymentMethodsCheckbox &&
    customerMethod.requiresCvv
  }, (
    isGuestCustomer,
    paymentMethodListValue.payment_type,
    displaySavedPaymentMethodsCheckbox,
    customerMethod,
  ))

  let enableSavedPaymentShimmer = React.useMemo(() => {
    savedCardlength === 0 &&
    !showPaymentMethodsScreen &&
    (loadSavedCards === PaymentType.LoadingSavedCards || clickToPayConfig.isReady->Option.isNone)
  }, (savedCardlength, loadSavedCards, showPaymentMethodsScreen, clickToPayConfig.isReady))

  <div className="flex flex-col overflow-auto h-auto no-scrollbar animate-slowShow">
    {if enableSavedPaymentShimmer {
      <PaymentElementShimmer.SavedPaymentCardShimmer />
    } else {
      <RenderIf condition={!showPaymentMethodsScreen}> {bottomElement} </RenderIf>
    }}
    <RenderIf condition={conditionsForShowingSaveCardCheckbox}>
      <div className="pt-4 pb-2 flex items-center justify-start">
        <SaveDetailsCheckbox isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked />
      </div>
    </RenderIf>
    <RenderIf
      condition={displaySavedPaymentMethodsCheckbox &&
      paymentMethodListValue.payment_type === SETUP_MANDATE}>
      <Terms
        mode={Card}
        styles={
          marginTop: themeObj.spacingGridColumn,
        }
      />
    </RenderIf>
    <RenderIf condition={!enableSavedPaymentShimmer}>
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
        onKeyDown={event => {
          let key = JsxEvent.Keyboard.key(event)
          let keyCode = JsxEvent.Keyboard.keyCode(event)
          if key == "Enter" || keyCode == 13 {
            setShowPaymentMethodsScreen(_ => true)
          }
        }}
        dataTestId={TestUtils.addNewCardIcon}
        onClick={_ => setShowPaymentMethodsScreen(_ => true)}>
        <Icon name="circle-plus" size=22 />
        {React.string(localeString.newPaymentMethods)}
      </div>
    </RenderIf>
  </div>
}
