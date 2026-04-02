@react.component
let make = (
  ~setSelectedInstallmentPlan,
  ~showInstallments,
  ~setShowInstallments,
  ~paymentMethod,
  ~errorString,
  ~setErrorString,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let installmentOptions = paymentMethodListValue.intent_data.installment_options->Option.getOr([])
  let currency = paymentMethodListValue.intent_data.currency

  let (selectedIndex, setSelectedIndex) = React.useState(_ => None)
  let (isDropdownOpen, setIsDropdownOpen) = React.useState(_ => false)
  let (itemHeight, setItemHeight) = React.useState(_ => None)
  let (thumbTop, setThumbTop) = React.useState(_ => 0.0)
  let (thumbHeightPct, setThumbHeightPct) = React.useState(_ => 100.0)
  let scrollContainerRef = React.useRef(Nullable.null)

  let allPlans =
    installmentOptions->PaymentUtils.filterInstallmentPlansByPaymentMethod(paymentMethod)

  let needsScroll = allPlans->Array.length > 3

  let selectedPlan = selectedIndex->Option.flatMap(i => allPlans->Array.get(i))

  React.useEffect2(() => {
    let timerId = ref(None)
    let scrollHandler = ref(None)

    if needsScroll && isDropdownOpen {
      switch scrollContainerRef.current->Nullable.toOption {
      | Some(container) => {
          let updateScrollbar = () => {
            let scrollHeight = container->Window.Element.scrollHeight
            let clientHeight = container->Window.Element.clientHeight
            if scrollHeight > 0.0 && clientHeight > 0.0 && scrollHeight > clientHeight {
              let ratio = clientHeight /. scrollHeight
              setThumbHeightPct(_ => ratio *. 100.0)
              let maxScroll = scrollHeight -. clientHeight
              let currentScroll = container->Window.Element.scrollTop
              let scrollPos = if maxScroll > 0.0 {
                currentScroll /. maxScroll
              } else {
                0.0
              }
              let trackAvailable = 100.0 -. ratio *. 100.0
              setThumbTop(_ => scrollPos *. trackAvailable)
            }
          }

          switch container->Window.Element.firstElementChild->Nullable.toOption {
          | Some(firstChild) => {
              let height = firstChild->Window.Element.offsetHeight
              if height > 0.0 {
                setItemHeight(_ => Some(height))
              }
            }
          | None => ()
          }

          scrollHandler := Some(updateScrollbar)
          container->Window.Element.addScrollListener(updateScrollbar)
          timerId := Some(setTimeout(() => updateScrollbar(), 50))
        }
      | None => ()
      }
    }

    Some(
      () => {
        switch timerId.contents {
        | Some(id) => clearTimeout(id)
        | None => ()
        }
        switch (scrollContainerRef.current->Nullable.toOption, scrollHandler.contents) {
        | (Some(container), Some(handler)) =>
          container->Window.Element.removeScrollListener(handler)
        | _ => ()
        }
      },
    )
  }, (isDropdownOpen, needsScroll))

  let handleToggle = isChecked => {
    setShowInstallments(_ => isChecked)
    setErrorString(_ => "")
    if isChecked {
      setIsDropdownOpen(_ => true)
    } else {
      setSelectedInstallmentPlan(_ => None)
      setSelectedIndex(_ => None)
      setIsDropdownOpen(_ => false)
    }
  }

  let handlePlanSelect = (plan: PaymentMethodsRecord.installmentPlan, index) => {
    setSelectedInstallmentPlan(_ => Some(plan))
    setSelectedIndex(_ => Some(index))
    setErrorString(_ => "")
    setIsDropdownOpen(_ => false)
  }

  let isPlanSelected = index =>
    selectedIndex
    ->Option.map(selected => selected == index)
    ->Option.getOr(false)

  let cleanUpStates = () => {
    setSelectedInstallmentPlan(_ => None)
    setSelectedIndex(_ => None)
    setShowInstallments(_ => false)
    setErrorString(_ => "")
    setIsDropdownOpen(_ => false)
  }

  React.useEffect0(() => {
    cleanUpStates()
    Some(cleanUpStates)
  })

  React.useEffect2(() => {
    switch (selectedIndex, selectedPlan) {
    | (Some(_), None) => {
        setSelectedInstallmentPlan(_ => None)
        setSelectedIndex(_ => None)
      }
    | _ => ()
    }
    None
  }, (selectedIndex, selectedPlan))

  let toggleDropdown = _ => {
    setIsDropdownOpen(prev => !prev)
  }

  let scrollContainerMaxHeight =
    (needsScroll ? itemHeight : None)->Option.mapOr("none", height =>
      `${(height *. 3.5)->Float.toString}px`
    )

  let fadeHeight = switch itemHeight {
  | Some(height) => `${(height *. 0.25)->Float.toString}px`
  | None => "24px"
  }

  let renderDropdownTrigger = () => {
    switch (isDropdownOpen, selectedPlan) {
    | (false, Some(plan)) =>
      <div className="flex items-center gap-2 flex-1 min-w-0">
        <InstallmentPlanDetails plan currency />
      </div>
    | _ =>
      <span
        className="flex-1 text-left opacity-50"
        style={
          fontSize: themeObj.fontSizeLg,
          color: themeObj.colorText,
        }>
        {localeString.installmentSelectPlanPlaceholder->React.string}
      </span>
    }
  }

  <RenderIf condition={allPlans->Array.length != 0}>
    <div
      className="w-full flex flex-col"
      style={
        color: themeObj.colorText,
        fontWeight: themeObj.fontWeightNormal,
        fontSize: themeObj.fontSizeLg,
      }>
      <div className="flex items-center">
        <Checkbox
          isChecked=showInstallments
          onChange=handleToggle
          label={localeString.installmentPayInInstallments}
        />
      </div>
      <RenderIf condition={showInstallments}>
        <div
          style={
            marginTop: themeObj.spacingUnit,
            border: `1px solid ${themeObj.borderColor}`,
            borderRadius: themeObj.borderRadius,
          }
          className="overflow-hidden">
          <div
            onClick=toggleDropdown
            style={
              padding: `calc(${themeObj.spacingUnit} * 0.8) ${themeObj.spacingUnit}`,
              backgroundColor: themeObj.colorBackground,
            }
            className="flex items-center gap-2 cursor-pointer w-full">
            {renderDropdownTrigger()}
            <div
              style={
                color: themeObj.colorTextSecondary,
              }
              className={`shrink-0 flex items-center ml-0.5 transition-transform duration-200 ease-in-out ${isDropdownOpen
                  ? "rotate-180"
                  : "rotate-0"}`}>
              <Icon name="arrow-down" size=12 />
            </div>
          </div>
          <RenderIf condition=isDropdownOpen>
            <div
              style={
                borderTop: `1px solid ${themeObj.borderColor}`,
                backgroundColor: themeObj.colorBackground,
              }
              className="relative">
              <div
                ref={scrollContainerRef->ReactDOM.Ref.domRef}
                style={
                  maxHeight: scrollContainerMaxHeight,
                }
                className={`flex flex-col ${needsScroll ? "overflow-y-auto no-scrollbar" : ""}`}>
                {allPlans
                ->Array.mapWithIndex((plan, i) => {
                  let isLastItem = allPlans->Array.length - 1 == i
                  <InstallmentOptionItem
                    key={i->Int.toString}
                    plan
                    isSelected={isPlanSelected(i)}
                    onSelect={() => handlePlanSelect(plan, i)}
                    isLastItem
                    currency
                  />
                })
                ->React.array}
              </div>
              <RenderIf condition=needsScroll>
                <div
                  style={
                    background: `linear-gradient(to top, ${themeObj.colorBackground}, transparent)`,
                    height: fadeHeight,
                    borderRadius: `0 0 ${themeObj.borderRadius} ${themeObj.borderRadius}`,
                  }
                  className="absolute bottom-0 left-0 right-0 pointer-events-none"
                />
                <div
                  style={
                    width: "3px",
                    borderRadius: themeObj.borderRadius,
                  }
                  className="absolute top-0 bottom-0 right-0 pointer-events-none mr-px">
                  <div
                    style={
                      top: `${thumbTop->Float.toString}%`,
                      height: `${thumbHeightPct->Float.toString}%`,
                      backgroundColor: `color-mix(in srgb, ${themeObj.colorText} 15%, transparent)`,
                      borderRadius: themeObj.borderRadius,
                    }
                    className="absolute left-0 right-0 min-h-4"
                  />
                </div>
              </RenderIf>
            </div>
          </RenderIf>
        </div>
      </RenderIf>
      <RenderIf condition={errorString != ""}>
        <div
          className="Error pt-1"
          style={
            color: themeObj.colorDangerText,
            fontSize: themeObj.fontSizeSm,
            alignSelf: "start",
            textAlign: "left",
          }>
          {React.string(errorString)}
        </div>
      </RenderIf>
    </div>
  </RenderIf>
}
