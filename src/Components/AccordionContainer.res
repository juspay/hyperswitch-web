open RecoilAtoms

@react.component
let make = (
  ~paymentOptions: array<string>,
  ~checkoutEle: React.element,
  ~cardProps: CardUtils.cardProps,
) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {layout} = Recoil.useRecoilValueFromAtom(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let (showMore, setShowMore) = React.useState(_ => false)
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(selectedOptionAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let {cardBrand} = cardProps

  PaymentUtils.useEmitPaymentMethodInfo(
    ~paymentMethodName=selectedOption,
    ~paymentMethods=paymentMethodListValue.payment_methods,
    ~cardBrand,
  )

  let cardOptionDetails =
    paymentOptions
    ->PaymentMethodsRecord.getPaymentDetails
    ->Array.slice(~start=0, ~end=layoutClass.maxAccordionItems)
  let dropDownOptionsDetails =
    paymentOptions
    ->PaymentMethodsRecord.getPaymentDetails
    ->Array.sliceToEnd(~start=layoutClass.maxAccordionItems)

  let getBorderRadiusStyleForCardOptionDetails = index => {
    if (
      !showMore &&
      !layoutClass.spacedAccordionItems &&
      index == 0 &&
      cardOptionDetails->Array.length == 1
    ) {
      `${themeObj.borderRadius} ${themeObj.borderRadius} 0px 0px`
    } else if (
      !showMore &&
      !layoutClass.spacedAccordionItems &&
      index == 0 &&
      cardOptionDetails->Array.length == 1
    ) {
      themeObj.borderRadius
    } else if (
      !showMore && !layoutClass.spacedAccordionItems && index == cardOptionDetails->Array.length - 1
    ) {
      `0px 0px ${themeObj.borderRadius} ${themeObj.borderRadius}`
    } else if !layoutClass.spacedAccordionItems && index == 0 {
      `${themeObj.borderRadius} ${themeObj.borderRadius} 0px 0px`
    } else if layoutClass.spacedAccordionItems {
      themeObj.borderRadius
    } else {
      "0px"
    }
  }

  let getBorderRadiusStyleForDropDownOptionDetails = index => {
    if !layoutClass.spacedAccordionItems && index == dropDownOptionsDetails->Array.length - 1 {
      `0px 0px ${themeObj.borderRadius} ${themeObj.borderRadius}`
    } else if layoutClass.spacedAccordionItems {
      themeObj.borderRadius
    } else {
      "0px"
    }
  }

  React.useEffect0(() => {
    layoutClass.defaultCollapsed ? setSelectedOption(_ => "") : ()
    None
  })
  <div className="w-full">
    <div
      className="AccordionContainer flex flex-col overflow-auto no-scrollbar"
      style={
        marginTop: themeObj.spacingAccordionItem,
        width: "-webkit-fill-available",
        marginBottom: themeObj.spacingAccordionItem,
      }>
      {cardOptionDetails
      ->Array.mapWithIndex((payOption, i) => {
        let isActive = payOption.paymentMethodName == selectedOption
        let borderRadiusStyle = getBorderRadiusStyleForCardOptionDetails(i)
        <Accordion
          key={i->Int.toString}
          paymentOption=payOption
          isActive
          checkoutEle
          borderRadiusStyle={borderRadiusStyle}
          borderBottom={(!showMore &&
          i == cardOptionDetails->Array.length - 1 &&
          !layoutClass.spacedAccordionItems) || layoutClass.spacedAccordionItems}
        />
      })
      ->React.array}
      <RenderIf condition={showMore}>
        {dropDownOptionsDetails
        ->Array.mapWithIndex((payOption, i) => {
          let isActive = payOption.paymentMethodName == selectedOption
          let borderRadiusStyle = getBorderRadiusStyleForDropDownOptionDetails(i)
          <Accordion
            key={i->Int.toString}
            paymentOption=payOption
            isActive
            checkoutEle
            borderRadiusStyle={borderRadiusStyle}
            borderBottom={(i == dropDownOptionsDetails->Array.length - 1 &&
              !layoutClass.spacedAccordionItems) || layoutClass.spacedAccordionItems}
          />
        })
        ->React.array}
      </RenderIf>
    </div>
    <RenderIf condition={!showMore && dropDownOptionsDetails->Array.length > 0}>
      <button
        className="AccordionMore flex overflow-auto no-scrollbar"
        onClick={_ => setShowMore(_ => !showMore)}
        style={
          borderRadius: themeObj.borderRadius,
          marginTop: themeObj.spacingUnit,
          columnGap: themeObj.spacingUnit,
          minHeight: "60px",
          minWidth: "150px",
          width: "100%",
          padding: "20px",
          cursor: "pointer",
        }>
        <div className="flex flex-row" style={columnGap: themeObj.spacingUnit}>
          <div className="m-2">
            <Icon size=10 name="arrow-down" />
          </div>
          <div className="AccordionItemLabel"> {React.string("More")} </div>
        </div>
      </button>
    </RenderIf>
  </div>
}
