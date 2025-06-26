open PaymentType
open RecoilAtoms
open Utils

let cardsToRender = (width: int) => {
  let minWidth = 130
  let noOfCards = (width - 40) / minWidth
  noOfCards
}
@react.component
let make = (~cardProps, ~expiryProps, ~cvcProps, ~paymentType: CardThemeType.mode) => {
  let divRef = React.useRef(Nullable.null)
  let {showCardFormByDefault, layout} = Recoil.useRecoilValueFromAtom(optionAtom)
  let optionAtomValue = Recoil.useRecoilValueFromAtom(optionAtom)
  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let paymentMethodsListV2 = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentMethodsListV2)
  let (paymentManagementListValue, setPaymentManagementListValue) = Recoil.useRecoilState(
    PaymentUtils.paymentManagementListValue,
  )
  let sessionToken = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let (vaultMode, setVaultMode) = Recoil.useRecoilState(RecoilAtomsV2.vaultMode)
  let setPaymentsListValue = Recoil.useSetRecoilState(RecoilAtomsV2.paymentsListValue)
  let (paymentOptions, setPaymentOptions) = React.useState(_ => [])
  let (walletOptions, _setWalletOptions) = React.useState(_ => [])

  let (cardsContainerWidth, setCardsContainerWidth) = React.useState(_ => 0)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(selectedOptionAtom)
  let (dropDownOptions: array<string>, setDropDownOptions) = React.useState(_ => [])
  let (cardOptions: array<string>, setCardOptions) = React.useState(_ => [])
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let setShowFields = Recoil.useSetRecoilState(RecoilAtoms.showCardFieldsAtom)

  let (paymentOptionsList, actualList) = PaymentUtilsV2.useGetPaymentMethodListV2(
    ~paymentOptions,
    ~paymentType,
  )

  React.useEffect0(() => {
    setShowFields(_ => true)
    None
  })

  React.useEffect(() => {
    let vaultName = VaultHelpers.getVaultName(sessionToken)
    setVaultMode(_ => vaultName->VaultHelpers.getVaultModeFromName)
    None
  }, [sessionToken])

  React.useEffect(() => {
    let updatePaymentOptions = () => {
      setPaymentOptions(_ => [...paymentOptionsList]->removeDuplicate)
    }

    switch (paymentManagementList, paymentMethodsListV2) {
    | (LoadedV2(paymentlist), _) =>
      updatePaymentOptions()
      setPaymentManagementListValue(_ => paymentlist)
    | (_, LoadedV2(paymentlist)) =>
      updatePaymentOptions()
      setPaymentsListValue(_ => paymentlist)
    | (LoadErrorV2(_), _)
    | (_, LoadErrorV2(_))
    | (SemiLoadedV2, _)
    | (_, SemiLoadedV2) =>
      // TODO - For Payments CheckPriorityList && ShowCardFormByDefault
      // TODO - For PaymentMethodsManagement Cards
      setPaymentOptions(_ => [])
    | _ => ()
    }

    None
  }, (paymentManagementList, paymentOptionsList, actualList, paymentMethodsListV2))

  React.useEffect(() => {
    if layoutClass.\"type" == Tabs {
      let isCard = cardOptions->Array.includes(selectedOption)
      if !isCard {
        let (cardArr, dropdownArr) = CardUtils.swapCardOption(
          cardOptions,
          dropDownOptions,
          selectedOption,
        )
        setCardOptions(_ => cardArr)
        setDropDownOptions(_ => dropdownArr)
      }
    }
    if selectedOption !== "" {
      loggerState.setLogInfo(
        ~value="",
        ~eventName=PAYMENT_METHOD_CHANGED,
        ~paymentMethod=selectedOption->String.toUpperCase,
      )
    }
    None
  }, (selectedOption, cardOptions, dropDownOptions))

  React.useEffect(() => {
    let cardsCount: int = cardsToRender(cardsContainerWidth)
    let cardOpts = Array.slice(~start=0, ~end=cardsCount, paymentOptions)
    let dropOpts = paymentOptions->Array.sliceToEnd(~start=cardsCount)
    let isCard: bool = cardOpts->Array.includes(selectedOption)
    if !isCard && selectedOption !== "" && paymentOptions->Array.includes(selectedOption) {
      let (cardArr, dropdownArr) = CardUtils.swapCardOption(cardOpts, dropOpts, selectedOption)
      setCardOptions(_ => cardArr)
      setDropDownOptions(_ => dropdownArr)
    } else {
      setCardOptions(_ => cardOpts)
      setDropDownOptions(_ => dropOpts)
    }
    None
  }, (cardsContainerWidth, paymentOptions))
  let cardShimmerCount = React.useMemo(() => {
    cardsToRender(cardsContainerWidth)
  }, [cardsContainerWidth])
  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit && selectedOption == "" {
      postFailedSubmitResponse(~errortype="validation_error", ~message="Select a payment method")
    }
  }, [selectedOption])

  useSubmitPaymentData(submitCallback)

  React.useEffect(() => {
    setSelectedOption(prev =>
      selectedOption !== ""
        ? prev
        : layoutClass.defaultCollapsed
        ? ""
        : switch paymentManagementList {
          | SemiLoadedV2
          | LoadErrorV2(_) => "card"
          | LoadedV2(_) =>
            paymentOptions->Array.includes(selectedOption) && showCardFormByDefault
              ? selectedOption
              : paymentOptions->Array.get(0)->Option.getOr("")
          | _ => paymentOptions->Array.get(0)->Option.getOr("")
          }
    )
    None
  }, (
    layoutClass.defaultCollapsed,
    paymentOptions,
    paymentManagementList,
    selectedOption,
    showCardFormByDefault,
    paymentMethodsListV2,
  ))

  let loader = () => {
    handlePostMessageEvents(
      ~complete=false,
      ~empty=false,
      ~paymentType=selectedOption,
      ~loggerState,
    )
    <PaymentShimmer />
  }

  let checkoutEle = {
    <ErrorBoundary key={selectedOption} componentName="PaymentElement">
      {switch selectedOption->PaymentModeType.paymentMode {
      | Card =>
        switch vaultMode {
        | VeryGoodSecurity => <VGSVault />
        | Hyperswitch => <CardIframeContainer />
        | None => <CardPayment cardProps expiryProps cvcProps />
        }
      | _ =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="PaymentMethodsWrapperLazy">
          <PaymentMethodsWrapperLazy paymentMethodName=selectedOption />
        </ReusableReactSuspense>
      }}
    </ErrorBoundary>
  }

  let paymentLabel = optionAtomValue.paymentMethodsHeaderText

  React.useEffect(() => {
    let evalMethodsList = () =>
      switch (paymentManagementList, paymentMethodsListV2) {
      | (SemiLoadedV2, _)
      | (LoadErrorV2(_), _)
      | (LoadedV2(_), _)
      | (_, LoadErrorV2(_))
      | (_, SemiLoadedV2)
      | (_, LoadedV2(_)) =>
        messageParentWindow([("ready", true->JSON.Encode.bool)])
      | _ => ()
      }
    evalMethodsList()

    None
  }, [paymentManagementList, paymentMethodsListV2])

  <>
    <RenderIf condition={paymentLabel->Option.isSome}>
      <div className="text-2xl font-semibold text-[#151619] mb-6">
        {paymentLabel->Option.getOr("")->React.string}
      </div>
    </RenderIf>
    <RenderIf condition={paymentOptions->Array.length > 0 || walletOptions->Array.length > 0}>
      <div className="flex flex-col place-items-center">
        {switch layoutClass.\"type" {
        | Tabs =>
          <PaymentOptions
            setCardsContainerWidth
            cardOptions
            dropDownOptions
            checkoutEle
            cardShimmerCount
            cardProps
          />
        | Accordion => <AccordionContainer paymentOptions checkoutEle cardProps />
        }}
      </div>
    </RenderIf>
    {switch (paymentManagementList, paymentMethodsListV2) {
    | (LoadErrorV2(_), _) =>
      <RenderIf condition={paymentManagementListValue.paymentMethodsEnabled->Array.length === 0}>
        <ErrorBoundary.ErrorTextAndImage divRef level={Top} />
      </RenderIf>
    | (_, LoadErrorV2(_)) => <ErrorBoundary.ErrorTextAndImage divRef level={Top} />
    | _ =>
      <RenderIf condition={paymentOptions->Array.length == 0 && walletOptions->Array.length == 0}>
        <PaymentElementShimmer />
      </RenderIf>
    }}
    <PoweredBy />
  </>
}
