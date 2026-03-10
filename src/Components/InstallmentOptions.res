@react.component
let make = (~setSelectedInstallmentPlan, ~showInstallments, ~setShowInstallments) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let installmentOptions = paymentMethodListValue.intent_data.installment_options->Option.getOr([])
  let currency = paymentMethodListValue.intent_data.currency

  let (selectedIndex, setSelectedIndex) = React.useState(_ => None)

  let allPlans =
    installmentOptions
    ->Array.get(0)
    ->Option.map(option => option.available_plans)
    ->Option.getOr([])

  if allPlans->Array.length == 0 {
    React.null
  } else {
    let needsScroll = allPlans->Array.length > 4

    let handleCheckboxClick = isChecked => {
      setShowInstallments(_ => isChecked)
      if !isChecked {
        setSelectedInstallmentPlan(_ => None)
        setSelectedIndex(_ => None)
      }
    }

    let handlePlanSelect = (plan: PaymentMethodsRecord.installmentPlan, index) => {
      setSelectedInstallmentPlan(_ => Some(plan))
      setSelectedIndex(_ => Some(index))
    }

    let isPlanSelected = index =>
      selectedIndex
      ->Option.map(selected => selected == index)
      ->Option.getOr(false)

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
                themeObj
                isLastItem
                currency
                localeString
              />
            })
            ->React.array}
          </div>
        </div>
      </RenderIf>
    </div>
  }
}
