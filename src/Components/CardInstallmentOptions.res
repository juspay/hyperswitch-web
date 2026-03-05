@react.component
let make = (
  ~installmentOptions: array<InstallmentTypes.installmentOption>,
  ~setSelectedInstallmentPlan: (
    option<InstallmentTypes.installmentPlan> => option<InstallmentTypes.installmentPlan>
  ) => unit,
  ~themeObj: CardThemeType.themeClass,
) => {
  let (showInstallments, setShowInstallments) = React.useState(_ => false)
  let (selectedIndex, setSelectedIndex) = React.useState(_ => None)

  let allPlans =
    installmentOptions
    ->Array.get(0)
    ->Option.map(option => option.available_plans)
    ->Option.getOr([])

  let needsScroll = allPlans->Array.length > 4

  let handleCheckboxClick = isChecked => {
    setShowInstallments(_ => isChecked)
    if !isChecked {
      setSelectedInstallmentPlan(_ => None)
      setSelectedIndex(_ => None)
    }
  }

  let handlePlanSelect = (plan: InstallmentTypes.installmentPlan, index: int) => {
    setSelectedInstallmentPlan(_ => Some(plan))
    setSelectedIndex(_ => Some(index))
  }

  let isPlanSelected = (index: int) => {
    selectedIndex
    ->Option.map(selected => selected == index)
    ->Option.getOr(false)
  }

  <div className="w-full flex flex-col">
    <Checkbox
      isChecked=showInstallments onChange=handleCheckboxClick label={"Pay in installments"}
    />
    <RenderIf condition=showInstallments>
      <div
        style={
          color: themeObj.colorText,
          fontWeight: themeObj.fontWeightNormal,
          fontSize: themeObj.fontSizeLg,
        }
        className="flex flex-col gap-3 mt-4">
        <span className="text-left"> {"Choose an installment plan"->React.string} </span>
        <div
          style={
            borderRadius: themeObj.borderRadius,
            borderColor: themeObj.borderColor,
            padding: themeObj.spacingUnit,
          }
          className={`flex flex-col border !py-0 ${needsScroll ? "max-h-64 overflow-y-auto" : ""}`}>
          {allPlans
          ->Array.mapWithIndex((plan, i) => {
            let isLastItem = allPlans->Array.length - 1 == i
            <CardInstallmentOptionItem
              key={i->Int.toString}
              plan
              isSelected={isPlanSelected(i)}
              onSelect={() => handlePlanSelect(plan, i)}
              themeObj
              isLastItem
              //TODO: remove hardcoded currency
              currency="USD"
            />
          })
          ->React.array}
        </div>
      </div>
    </RenderIf>
  </div>
}
