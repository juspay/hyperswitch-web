@get external offsetHeight: Dom.element => float = "offsetHeight"
@get external firstElementChild: Dom.element => Nullable.t<Dom.element> = "firstElementChild"
@get external scrollHeight: Dom.element => float = "scrollHeight"
@get external clientHeight: Dom.element => float = "clientHeight"
@get external scrollTop: Dom.element => float = "scrollTop"
@set external setScrollTop: (Dom.element, float) => unit = "scrollTop"
@send
external addScrollListener: (Dom.element, @as("scroll") _, unit => unit) => unit =
  "addEventListener"
@send
external removeScrollListener: (Dom.element, @as("scroll") _, unit => unit) => unit =
  "removeEventListener"

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

  let updateScrollbar = () => {
    switch scrollContainerRef.current->Nullable.toOption {
    | Some(container) => {
        let sH = container->scrollHeight
        let cH = container->clientHeight
        if sH > 0.0 && cH > 0.0 && sH > cH {
          let ratio = cH /. sH
          setThumbHeightPct(_ => ratio *. 100.0)
          let maxScroll = sH -. cH
          let sT = container->scrollTop
          let scrollPos = if maxScroll > 0.0 {
            sT /. maxScroll
          } else {
            0.0
          }
          let trackAvailable = 100.0 -. ratio *. 100.0
          setThumbTop(_ => scrollPos *. trackAvailable)
        }
      }
    | None => ()
    }
  }

  React.useEffect1(() => {
    if needsScroll && isDropdownOpen {
      switch scrollContainerRef.current->Nullable.toOption {
      | Some(container) => {
          switch container->firstElementChild->Nullable.toOption {
          | Some(firstChild) => {
              let height = firstChild->offsetHeight
              if height > 0.0 {
                setItemHeight(_ => Some(height))
              }
            }
          | None => ()
          }
          container->addScrollListener(updateScrollbar)
          let _ = setTimeout(() => updateScrollbar(), 50)
        }
      | None => ()
      }
    }
    Some(
      () => {
        switch scrollContainerRef.current->Nullable.toOption {
        | Some(container) => container->removeScrollListener(updateScrollbar)
        | None => ()
        }
      },
    )
  }, [isDropdownOpen])

  let handleToggle = isChecked => {
    setShowInstallments(_ => isChecked)
    setErrorString(_ => "")
    if !isChecked {
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
    setShowInstallments(_ => false)
    setErrorString(_ => "")
    setIsDropdownOpen(_ => false)
  }

  React.useEffect0(() => {
    cleanUpStates()
    Some(cleanUpStates)
  })

  let toggleDropdown = _ => {
    setIsDropdownOpen(prev => !prev)
  }

  let totalLabel = localeString.installmentTotal

  let scrollContainerMaxHeight = switch itemHeight {
  | Some(h) => `${(h *. 3.5)->Float.toString}px`
  | None => "none"
  }

  let fadeHeight = switch itemHeight {
  | Some(h) => `${(h *. 0.25)->Float.toString}px`
  | None => "24px"
  }

  let renderDropdownTrigger = () => {
    switch selectedPlan {
    | Some(plan) => {
        let interestLabel =
          plan.interest_rate == 0.0
            ? localeString.installmentInterestFree
            : localeString.installmentWithInterest
        let amountPerInstallment = Utils.formatAmountWithTwoDecimals(
          plan.amount_details.amount_per_installment,
        )
        let totalAmount = Utils.formatAmountWithTwoDecimals(plan.amount_details.total_amount)
        let mainLabel = localeString.installmentPaymentLabel(
          plan.number_of_installments,
          currency,
          amountPerInstallment,
        )

        <div className="flex items-center gap-2 flex-1 min-w-0">
          <div
            style={
              width: "16px",
              height: "16px",
              border: `1.5px solid ${themeObj.colorPrimary}`,
            }
            className="rounded-full shrink-0 flex items-center justify-center">
            <div
              style={
                width: "8px",
                height: "8px",
                backgroundColor: themeObj.colorPrimary,
              }
              className="rounded-full"
            />
          </div>
          <div className="flex flex-col flex-1 min-w-0">
          <div className="flex items-center justify-between w-full">
            <span
              style={
                fontSize: themeObj.fontSizeLg,
                color: themeObj.colorText,
              }>
              {mainLabel->React.string}
            </span>
            <span
              style={
                fontSize: themeObj.fontSizeSm,
                color: themeObj.colorTextSecondary,
              }>
              {totalLabel->React.string}
            </span>
          </div>
          <div className="flex items-center justify-between w-full mt-px">
            <span
              style={
                fontSize: themeObj.fontSizeSm,
                color: themeObj.colorTextSecondary,
              }>
              {interestLabel->React.string}
            </span>
            <span
              style={
                fontSize: themeObj.fontSizeLg,
                color: themeObj.colorText,
              }>
              {`${currency} ${totalAmount}`->React.string}
            </span>
          </div>
          </div>
        </div>
      }
    | None =>
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
                transition: "transform 0.2s ease",
                transform: isDropdownOpen ? "rotate(180deg)" : "rotate(0deg)",
              }
              className="shrink-0 flex items-center ml-0.5">
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
                  maxHeight: if needsScroll {
                    scrollContainerMaxHeight
                  } else {
                    "none"
                  },
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
              </RenderIf>
              <RenderIf condition=needsScroll>
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
                      minHeight: "16px",
                    }
                    className="absolute left-0 right-0"
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
