open RecoilAtoms

module Loader = {
  @react.component
  let make = (~cardShimmerCount) => {
    let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
    let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
    let {layout} = Recoil.useRecoilValueFromAtom(optionAtom)
    let layoutClass = CardUtils.getLayoutClass(layout)
    open PaymentType
    open PaymentElementShimmer
    switch paymentMethodList {
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
          key={i->Int.toString}
          style={
            minWidth: "80px",
            minHeight: "60px",
            overflowWrap: "hidden",
            borderRadius: {borderStyle},
            border: `1px solid ${themeObj.borderColor}`,
            borderBottomStyle: {
              (i == cardShimmerCount - 2 && !layoutClass.spacedAccordionItems) ||
                layoutClass.spacedAccordionItems
                ? "solid"
                : "hidden"
            },
            borderTopStyle: {i == 0 && !layoutClass.spacedAccordionItems ? "hidden" : "solid"},
            width: "100%",
            marginBottom: layoutClass.spacedAccordionItems ? themeObj.spacingAccordionItem : "",
            cursor: "pointer",
          }>
          <Shimmer classname="opacity-50 h-5 w-[10%] rounded-full">
            <div
              className="w-full h-full animate-pulse"
              style={backgroundColor: themeObj.colorPrimary, opacity: "10%"}
            />
          </Shimmer>
          <Shimmer classname="opacity-50 h-2 w-[30%] rounded-full">
            <div
              className="w-full h-full animate-pulse"
              style={backgroundColor: themeObj.colorPrimary, opacity: "10%"}
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
let make = (
  ~paymentOptions: array<string>,
  ~checkoutEle: React.element,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let {layout} = Recoil.useRecoilValueFromAtom(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let (showMore, setShowMore) = React.useState(_ => false)
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(selectedOptionAtom)

  // Roving-tabindex focus management for the radiogroup. The primary list and the
  // "more" dropdown list are each treated as their own roving group: arrow keys move
  // DOM focus within the rendered list and wrap at its ends. `-1` means "nothing has
  // been focused yet", in which case the roving-tabbable item falls back to the
  // selected item (else the first item).
  let (cardFocusedIndex, setCardFocusedIndex) = React.useState(_ => -1)
  let (dropDownFocusedIndex, setDropDownFocusedIndex) = React.useState(_ => -1)
  let cardItemRefs = React.useRef([])
  let dropDownItemRefs = React.useRef([])
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let {
    displayInSeparateScreen,
    groupByPaymentMethods,
  } = layoutClass.savedMethodCustomization.groupingBehavior
  let groupSavedMethodsSeparately = !displayInSeparateScreen && !groupByPaymentMethods

  PaymentUtils.useEmitPaymentMethodInfo(
    ~paymentMethodName=selectedOption,
    ~paymentMethods=paymentMethodListValue.payment_methods,
    ~cardProps,
    ~expiryProps,
    ~cvcProps,
  )
  SubscriptionEventHooks.useEmitPaymentMethodStatus(
    ~paymentMethodName=selectedOption,
    ~paymentMethods=paymentMethodListValue.payment_methods,
    ~isSavedPaymentMethod=false,
    ~isOneClickWallet=false,
  )
  SubscriptionEventHooks.useEmitBillingAddress()

  let cardOptionDetails =
    paymentOptions
    ->PaymentMethodsRecord.getPaymentDetails(~localeString)
    ->Array.slice(~start=0, ~end=layoutClass.maxAccordionItems)
  let dropDownOptionsDetails =
    paymentOptions
    ->PaymentMethodsRecord.getPaymentDetails(~localeString)
    ->Array.sliceToEnd(~start=layoutClass.maxAccordionItems)

  let getBorderRadiusStyleForCardOptionDetails = index => {
    if (
      !showMore &&
      !layoutClass.spacedAccordionItems &&
      index == 0 &&
      paymentMethodList == SemiLoaded &&
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

  // Store/clear an item's DOM element in a list's ref registry at its index.
  let registerItemRef = (refs: React.ref<array<Nullable.t<Dom.element>>>, index, el) => {
    while refs.current->Array.length <= index {
      refs.current->Array.push(Nullable.null)->ignore
    }
    refs.current[index] = el
  }

  // The roving-tabbable index for a list: the explicitly-focused item if any,
  // otherwise the selected item, otherwise the first item.
  let getRovingIndex = (focusedIndex, list: array<PaymentMethodsRecord.paymentFieldsInfo>) =>
    if focusedIndex >= 0 {
      focusedIndex
    } else {
      switch list->Array.findIndex(o => o.paymentMethodName == selectedOption) {
      | -1 => 0
      | selectedIndex => selectedIndex
      }
    }

  // Move DOM focus within a single list (wrapping at the ends) and update its
  // focused-index state so the roving tabindex follows.
  let moveFocus = (
    refs: React.ref<array<Nullable.t<Dom.element>>>,
    setFocusedIndex,
    length,
    index,
    delta,
  ) =>
    if length > 0 {
      let nextIndex = mod(mod(index + delta, length) + length, length)
      setFocusedIndex(_ => nextIndex)
      refs.current
      ->Array.get(nextIndex)
      ->Option.flatMap(Nullable.toOption)
      ->Option.forEach(el => el->AccessibilityUtils.focus)
    }

  React.useEffect0(() => {
    let shouldAutoOpenSavedMethods =
      !layoutClass.savedMethodCustomization.defaultCollapsed &&
      groupSavedMethodsSeparately &&
      paymentOptions->Array.includes("saved_methods")
    if layoutClass.defaultCollapsed {
      setSelectedOption(_ => shouldAutoOpenSavedMethods ? "saved_methods" : "")
    } else {
      ()
    }
    None
  })
  <div className="w-full">
    <div
      className="AccordionContainer flex flex-col overflow-auto no-scrollbar"
      role="radiogroup"
      ariaLabel={localeString.paymentMethodsGroupLabel}
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
          index=i
          isFocused={i == getRovingIndex(cardFocusedIndex, cardOptionDetails)}
          registerItemRef={registerItemRef(cardItemRefs, ...)}
          onArrowNav={(index, delta) =>
            moveFocus(
              cardItemRefs,
              setCardFocusedIndex,
              cardOptionDetails->Array.length,
              index,
              delta,
            )}
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
            key={i->Int.toString}
            paymentOption=payOption
            isActive
            checkoutEle
            borderRadiusStyle={borderRadiusStyle}
            borderBottom={(i == dropDownOptionsDetails->Array.length - 1 &&
              !layoutClass.spacedAccordionItems) || layoutClass.spacedAccordionItems}
            index=i
            isFocused={i == getRovingIndex(dropDownFocusedIndex, dropDownOptionsDetails)}
            registerItemRef={registerItemRef(dropDownItemRefs, ...)}
            onArrowNav={(index, delta) =>
              moveFocus(
                dropDownItemRefs,
                setDropDownFocusedIndex,
                dropDownOptionsDetails->Array.length,
                index,
                delta,
              )}
          />
        })
        ->React.array}
      </RenderIf>
    </div>
    <RenderIf condition={!showMore && dropDownOptionsDetails->Array.length > 0}>
      <button
        className="AccordionMore flex overflow-auto no-scrollbar"
        type_="button"
        ariaExpanded=false
        ariaLabel={localeString.morePaymentMethodsLabel}
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
