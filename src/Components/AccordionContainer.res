open RecoilAtoms
module Loader = {
  @react.component
  let make = (~cardShimmerCount) => {
    let list = Recoil.useRecoilValueFromAtom(RecoilAtoms.list)
    let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
    let {layout} = Recoil.useRecoilValueFromAtom(optionAtom)
    let layoutClass = CardUtils.getLayoutClass(layout)
    open PaymentType
    open PaymentElementShimmer
    switch list {
    | SemiLoaded =>
      Array.make(~length=cardShimmerCount - 1, "")
      ->Array.mapWithIndex((_, i) => {
        let borderStyle = layoutClass.spacedAccordionItems
          ? themeObj.borderRadius
          : i == cardShimmerCount - 2
          ? `0px 0px ${themeObj.borderRadius} ${themeObj.borderRadius}`
          : ""
        <div
          className={`AccordionItem flex flex-row gap-3 animate-pulse cursor-default place-items-center`}
          key={i->Belt.Int.toString}
          style={ReactDOMStyle.make(
            ~minWidth="80px",
            ~minHeight="60px",
            ~overflowWrap="hidden",
            ~borderRadius={borderStyle},
            ~border=`1px solid ${themeObj.borderColor}`,
            ~borderBottomStyle={
              (i == cardShimmerCount - 2 && !layoutClass.spacedAccordionItems) ||
                layoutClass.spacedAccordionItems
                ? "solid"
                : "hidden"
            },
            ~borderTopStyle={i == 0 && !layoutClass.spacedAccordionItems ? "hidden" : "solid"},
            ~width="100%",
            ~paddingLeft="25px",
            ~marginBottom=layoutClass.spacedAccordionItems ? themeObj.spacingAccordionItem : "",
            ~cursor="pointer",
            (),
          )}>
          <Shimmer classname="opacity-50 h-5 w-[10%] rounded-full">
            <div
              className="w-full h-full animate-pulse"
              style={ReactDOMStyle.make(~backgroundColor=themeObj.colorPrimary, ~opacity="10%", ())}
            />
          </Shimmer>
          <Shimmer classname="opacity-50 h-2 w-[30%] rounded-full">
            <div
              className="w-full h-full animate-pulse"
              style={ReactDOMStyle.make(~backgroundColor=themeObj.colorPrimary, ~opacity="10%", ())}
            />
          </Shimmer>
        </div>
      })
      ->React.array
    | _ => React.null
    }
  }
}
@react.component
let make = (~paymentOptions: array<string>, ~checkoutEle: React.element) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let list = Recoil.useRecoilValueFromAtom(RecoilAtoms.list)
  let {layout} = Recoil.useRecoilValueFromAtom(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let (showMore, setShowMore) = React.useState(_ => false)
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(selectedOptionAtom)

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
      list == SemiLoaded &&
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
      style={ReactDOMStyle.make(
        ~marginTop=themeObj.spacingAccordionItem,
        ~width="-webkit-fill-available",
        ~marginBottom=themeObj.spacingAccordionItem,
        (),
      )}>
      {cardOptionDetails
      ->Array.mapWithIndex((payOption, i) => {
        let isActive = payOption.paymentMethodName == selectedOption
        let borderRadiusStyle = getBorderRadiusStyleForCardOptionDetails(i)
        <Accordion
          key={i->Belt.Int.toString}
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
      <Loader cardShimmerCount=layoutClass.maxAccordionItems />
      <RenderIf condition={showMore}>
        {dropDownOptionsDetails
        ->Array.mapWithIndex((payOption, i) => {
          let isActive = payOption.paymentMethodName == selectedOption
          let borderRadiusStyle = getBorderRadiusStyleForDropDownOptionDetails(i)
          <Accordion
            key={i->Belt.Int.toString}
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
        style={ReactDOMStyle.make(
          ~borderRadius=themeObj.borderRadius,
          ~marginTop=themeObj.spacingUnit,
          ~columnGap=themeObj.spacingUnit,
          ~minHeight="60px",
          ~minWidth="150px",
          ~width="100%",
          ~padding="20px",
          ~cursor="pointer",
          (),
        )}>
        <div
          className="flex flex-row" style={ReactDOMStyle.make(~columnGap=themeObj.spacingUnit, ())}>
          <div className="m-2">
            <Icon size=10 name="arrow-down" />
          </div>
          <div className="AccordionItemLabel"> {React.string("More")} </div>
        </div>
      </button>
    </RenderIf>
  </div>
}
