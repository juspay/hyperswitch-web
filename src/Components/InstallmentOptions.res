@react.component
let make = (
  ~setSelectedInstallmentPlan,
  ~showInstallments,
  ~setShowInstallments,
  ~paymentMethod,
  ~errorString,
  ~setErrorString,
) => {
  let {themeObj, localeString, config} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let {innerLayout} = config.appearance

  let installmentOptions = paymentMethodListValue.intent_data.installment_options->Option.getOr([])
  let currency = paymentMethodListValue.intent_data.currency

  let (selectedIndex, setSelectedIndex) = React.useState(_ => None)

  let allPlans =
    installmentOptions->PaymentUtils.filterInstallmentPlansByPaymentMethod(paymentMethod)

  let needsScroll = allPlans->Array.length > 4

  let handleCheckboxClick = isChecked => {
    setShowInstallments(_ => isChecked)
    setErrorString(_ => "")
    if !isChecked {
      setSelectedInstallmentPlan(_ => None)
      setSelectedIndex(_ => None)
    }
  }

  let handlePlanSelect = (plan: PaymentMethodsRecord.installmentPlan, index) => {
    setSelectedInstallmentPlan(_ => Some(plan))
    setSelectedIndex(_ => Some(index))
    setErrorString(_ => "")
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

  <RenderIf condition={allPlans->Array.length != 0}>
    <div className="w-full flex flex-col">
      <Checkbox
        isChecked=showInstallments
        onChange=handleCheckboxClick
        label={localeString.installmentPayInInstallments}
      />
      <RenderIf condition={showInstallments}>
        <div
          style={
            color: themeObj.colorText,
            fontWeight: themeObj.fontWeightNormal,
            fontSize: themeObj.fontSizeLg,
          }
          className="flex flex-col gap-3 mt-4">
          <span className="text-left"> {localeString.installmentChoosePlan->React.string} </span>
          <div
            style={
              borderRadius: themeObj.borderRadius,
              borderColor: themeObj.borderColor,
              padding: themeObj.spacingUnit,
            }
            className={`flex flex-col border !py-0 ${needsScroll
                ? "max-h-64 overflow-y-auto"
                : ""}`}>
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
        </div>
      </RenderIf>
      <RenderIf condition={innerLayout === Spaced && errorString != ""}>
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
