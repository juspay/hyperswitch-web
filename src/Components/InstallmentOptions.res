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
  let (itemHeight, setItemHeight) = React.useState(_ => None)
  let (thumbTop, setThumbTop) = React.useState(_ => 0.0)
  let (thumbHeightPct, setThumbHeightPct) = React.useState(_ => 100.0)
  let scrollContainerRef = React.useRef(Nullable.null)

  let allPlans =
    installmentOptions->PaymentUtils.filterInstallmentPlansByPaymentMethod(paymentMethod)

  let needsScroll = allPlans->Array.length > 4

  let selectedPlan = selectedIndex->Option.flatMap(i => allPlans->Array.get(i))
  let hasSelection = selectedPlan->Option.isSome

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

  let handleScroll = () => updateScrollbar()

  // Measure first item height, attach scroll listener, compute initial thumb
  React.useEffect1(() => {
    if needsScroll && showInstallments && !hasSelection {
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
          container->addScrollListener(handleScroll)
          // Compute initial scrollbar metrics after a frame so layout is settled
          let _ = setTimeout(() => updateScrollbar(), 50)
        }
      | None => ()
      }
    }
    Some(
      () => {
        switch scrollContainerRef.current->Nullable.toOption {
        | Some(container) => container->removeScrollListener(handleScroll)
        | None => ()
        }
      },
    )
  }, [showInstallments])

  let handleToggle = isToggled => {
    setShowInstallments(_ => isToggled)
    setErrorString(_ => "")
    if !isToggled {
      setSelectedInstallmentPlan(_ => None)
      setSelectedIndex(_ => None)
    }
  }

  let handlePlanSelect = (plan: PaymentMethodsRecord.installmentPlan, index) => {
    setSelectedInstallmentPlan(_ => Some(plan))
    setSelectedIndex(_ => Some(index))
    setErrorString(_ => "")
  }

  let handleRemoveSelection = () => {
    setSelectedInstallmentPlan(_ => None)
    setSelectedIndex(_ => None)
  }

  let isPlanSelected = index =>
    selectedIndex
    ->Option.map(selected => selected == index)
    ->Option.getOr(false)

  let cleanUpStates = () => {
    setSelectedInstallmentPlan(_ => None)
    setShowInstallments(_ => false)
    setErrorString(_ => "")
  }

  React.useEffect0(() => {
    cleanUpStates()
    Some(cleanUpStates)
  })

  let listMaxHeight = if showInstallments && !hasSelection {
    "500px"
  } else {
    "0px"
  }

  let scrollContainerMaxHeight = switch itemHeight {
  | Some(h) => `${(h *. 4.5)->Float.toString}px`
  | None => "none"
  }

  let fadeHeight = switch itemHeight {
  | Some(h) => `${(h *. 0.25)->Float.toString}px`
  | None => "24px"
  }

  let renderSelectedSummary = (plan: PaymentMethodsRecord.installmentPlan) => {
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

    <div
      style={
        borderColor: themeObj.borderColor,
      }
      className="border-t">
      <div
        style={
          padding: `calc(${themeObj.spacingUnit} + 0.2rem)`,
        }
        className="flex flex-col gap-2 w-full">
        // Selected plan pill
        <Pill
          text=localeString.installmentSelectedPlan
          bgColor={`color-mix(in srgb, ${themeObj.colorPrimary} 12%, transparent)`}
          textColor=themeObj.colorPrimary
          fontSize=themeObj.fontSizeXs
          fontWeight=themeObj.fontWeightMedium
        />
        // Plan details row
        <div className="flex items-center justify-between w-full gap-2 flex-wrap">
          <div className="flex items-center gap-1">
            <span
              style={
                fontWeight: themeObj.fontWeightMedium,
              }>
              {mainLabel->React.string}
            </span>
            <span className="opacity-40"> {`\u2022`->React.string} </span>
            <span className="opacity-50"> {interestLabel->React.string} </span>
          </div>
          <div className="flex items-center gap-1 text-nowrap">
            <span className="opacity-50"> {localeString.installmentTotal->React.string} </span>
            <span
              style={
                fontWeight: themeObj.fontWeightMedium,
              }>
              {`${currency} ${totalAmount}`->React.string}
            </span>
            // Remove button
            <button
              type_="button"
              onClick={_ => handleRemoveSelection()}
              ariaLabel="Remove selection"
              style={
                marginLeft: `calc(${themeObj.spacingUnit} / 2)`,
                backgroundColor: `color-mix(in srgb, ${themeObj.colorDanger} 10%, transparent)`,
                borderColor: themeObj.colorDanger,
                color: themeObj.colorDanger,
              }
              className="flex items-center justify-center rounded-full border cursor-pointer p-0.5">
              <Icon name="cross" size=14 />
            </button>
          </div>
        </div>
      </div>
    </div>
  }

  <RenderIf condition={allPlans->Array.length != 0}>
    <div className="w-full flex flex-col">
      <div
        style={
          borderRadius: themeObj.borderRadius,
          borderColor: themeObj.borderColor,
          color: themeObj.colorText,
          fontWeight: themeObj.fontWeightNormal,
          fontSize: themeObj.fontSizeLg,
        }
        className="flex flex-col border">
        <div style={padding: themeObj.spacingUnit}>
          <Toggle
            isToggled=showInstallments
            onToggle=handleToggle
            label={localeString.installmentPayInInstallments}
          />
        </div>
        // Selected summary view
        {switch selectedPlan {
        | Some(plan) if showInstallments => renderSelectedSummary(plan)
        | _ => React.null
        }}
        // Expandable list (hidden when a plan is selected)
        <div
          style={
            maxHeight: listMaxHeight,
            transition: "max-height 0.15s ease-in-out",
            overflow: "hidden",
          }>
          <div
            style={
              borderColor: themeObj.borderColor,
            }
            className="border-t">
            <div className="relative">
              // Scrollable list (native scrollbar hidden)
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
              // Fade overlay at bottom
              <RenderIf condition=needsScroll>
                <div
                  style={
                    background: `linear-gradient(to top, ${themeObj.colorBackground}, transparent)`,
                    height: fadeHeight,
                    pointerEvents: "none",
                    borderRadius: `0 0 ${themeObj.borderRadius} ${themeObj.borderRadius}`,
                  }
                  className="absolute bottom-0 left-0 right-0"
                />
              </RenderIf>
              // Custom scrollbar — overlays on top of content and fade
              <RenderIf condition=needsScroll>
                <div
                  style={
                    width: "3px",
                    pointerEvents: "none",
                    borderRadius: themeObj.borderRadius,
                    marginRight: "1px",
                  }
                  className="absolute top-0 bottom-0 right-0">
                  // Thumb
                  <div
                    style={
                      position: "absolute",
                      top: `${thumbTop->Float.toString}%`,
                      left: "0",
                      right: "0",
                      height: `${thumbHeightPct->Float.toString}%`,
                      backgroundColor: `color-mix(in srgb, ${themeObj.colorText} 15%, transparent)`,
                      borderRadius: themeObj.borderRadius,
                      minHeight: "16px",
                    }
                  />
                </div>
              </RenderIf>
            </div>
          </div>
        </div>
      </div>
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
