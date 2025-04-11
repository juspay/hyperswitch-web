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
  let (paymentManagementListValue, setPaymentManagementListValue) = Recoil.useRecoilState(
    PaymentUtils.paymentManagementListValue,
  )
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
    switch paymentManagementList {
    | LoadedV2(paymentlist) =>
      let plist = paymentlist

      setPaymentOptions(_ => [...paymentOptionsList]->removeDuplicate)
      setPaymentManagementListValue(_ => plist)

    | LoadErrorV2(_)
    | SemiLoadedV2 =>
      setPaymentOptions(_ => ["card"])
    | _ => ()
    }
    None
  }, (paymentManagementList, paymentOptionsList, actualList))

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
      | Card => <CardPayment cardProps expiryProps cvcProps />
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
      switch paymentManagementList {
      | SemiLoadedV2 | LoadErrorV2(_) | LoadedV2(_) =>
        messageParentWindow([("ready", true->JSON.Encode.bool)])
      | _ => ()
      }
    evalMethodsList()

    None
  }, [paymentManagementList])

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
    {switch paymentManagementList {
    | LoadErrorV2(_) =>
      <RenderIf condition={paymentManagementListValue.paymentMethodsEnabled->Array.length === 0}>
        <ErrorBoundary.ErrorTextAndImage divRef level={Top} />
      </RenderIf>
    | _ =>
      <RenderIf condition={paymentOptions->Array.length == 0 && walletOptions->Array.length == 0}>
        <PaymentElementShimmer />
      </RenderIf>
    }}
  </>
}
