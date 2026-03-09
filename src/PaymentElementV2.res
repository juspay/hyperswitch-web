open PaymentType
open RecoilAtoms
open Utils
open PaymentUtils

let cardsToRender = (width: int) => {
  let minWidth = 130
  let noOfCards = (width - 40) / minWidth
  noOfCards
}
@react.component
let make = (~cardProps, ~expiryProps, ~cvcProps, ~paymentType: CardThemeType.mode) => {
  let divRef = React.useRef(Nullable.null)
  let {layout} = Recoil.useRecoilValueFromAtom(optionAtom)
  let optionAtomValue = Recoil.useRecoilValueFromAtom(optionAtom)
  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let (paymentManagementListValue, setPaymentManagementListValue) = Recoil.useRecoilState(
    paymentManagementListValue,
  )
  let (paymentOptions, setPaymentOptions) = React.useState(_ => [])

  let (cardsContainerWidth, setCardsContainerWidth) = React.useState(_ => 0)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(selectedOptionAtom)
  let (dropDownOptions: array<string>, setDropDownOptions) = React.useState(_ => [])
  let (cardOptions: array<string>, setCardOptions) = React.useState(_ => [])
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let setShowPaymentMethodsScreen = Recoil.useSetRecoilState(RecoilAtoms.showPaymentMethodsScreen)

  let (paymentOptionsList, actualList) = PaymentUtilsV2.useGetPaymentMethodListV2(
    ~paymentOptions,
    ~paymentType,
  )

  React.useEffect0(() => {
    setShowPaymentMethodsScreen(_ => true)
    None
  })

  React.useEffect(() => {
    switch paymentManagementList {
    | LoadedV2(paymentlist) =>
      setPaymentOptions(_ => [...paymentOptionsList]->removeDuplicate)
      setPaymentManagementListValue(_ => paymentlist)

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
            paymentOptions->Array.includes(selectedOption)
              ? selectedOption
              : paymentOptions->Array.get(0)->Option.getOr("")
          | _ => paymentOptions->Array.get(0)->Option.getOr("")
          }
    )
    None
  }, (layoutClass.defaultCollapsed, paymentOptions, paymentManagementList, selectedOption))

  let checkoutEle = {
    <ErrorBoundary key={selectedOption} componentName="PaymentElement">
      {switch selectedOption->PaymentModeType.paymentMode {
      | Card => <CardPayment cardProps expiryProps cvcProps />
      | _ => React.null
      }}
    </ErrorBoundary>
  }

  let paymentLabel = optionAtomValue.paymentMethodsHeaderText

  React.useEffect(() => {
    let evalMethodsList = () =>
      switch paymentManagementList {
      | SemiLoadedV2
      | LoadErrorV2(_)
      | LoadedV2(_) =>
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
    <RenderIf condition={paymentOptions->Array.length > 0}>
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
            expiryProps
          />
        | Accordion => <AccordionContainer paymentOptions checkoutEle cardProps expiryProps />
        }}
      </div>
    </RenderIf>
    {switch paymentManagementList {
    | LoadErrorV2(_) =>
      <RenderIf condition={paymentManagementListValue.paymentMethodsEnabled->Array.length === 0}>
        <ErrorBoundary.ErrorTextAndImage divRef level={Top} />
      </RenderIf>
    | _ =>
      <RenderIf condition={paymentOptions->Array.length == 0}>
        <PaymentElementShimmer />
      </RenderIf>
    }}
    <RenderIf condition={paymentType !== PaymentMethodsManagement}>
      <PoweredBy />
    </RenderIf>
  </>
}
