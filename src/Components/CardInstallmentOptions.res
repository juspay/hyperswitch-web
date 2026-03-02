@react.component
let make = (
  ~installmentOptions: array<InstallmentTypes.installmentOption>,
  ~selectedInstallmentPlan: option<InstallmentTypes.installmentPlan>,
  ~setSelectedInstallmentPlan: (
    option<InstallmentTypes.installmentPlan> => option<InstallmentTypes.installmentPlan>
  ) => unit,
  ~themeObj: CardThemeType.themeClass,
) => {
  let (showInstallments, setShowInstallments) = React.useState(_ => false)
  let (showAllOptions, setShowAllOptions) = React.useState(_ => false)

  let allPlans =
    installmentOptions
    ->Array.get(0)
    ->Option.map(option => option.available_plans)
    ->Option.getOr([])

  let visiblePlans = if showAllOptions || allPlans->Array.length <= 4 {
    allPlans
  } else {
    allPlans->Array.slice(~start=0, ~end=4)
  }

  let hasMoreOptions = allPlans->Array.length > 4

  let handleCheckboxClick = (_isChecked: bool) => {
    let newValue = !showInstallments
    setShowInstallments(_ => newValue)
    if !newValue {
      setSelectedInstallmentPlan(_ => None)
    }
  }

  let handlePlanSelect = (plan: InstallmentTypes.installmentPlan) => {
    setSelectedInstallmentPlan(_ => Some(plan))
  }

  let isPlanSelected = (plan: InstallmentTypes.installmentPlan) => {
    selectedInstallmentPlan
    ->Option.map(selected => selected.number_of_installments == plan.number_of_installments)
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
          className="flex flex-col border !py-0">
          {visiblePlans
          ->Array.mapWithIndex((plan, i) => {
            let isLastItem = visiblePlans->Array.length - 1 == i
            <CardInstallmentOptionItem
              key={i->Int.toString}
              plan
              isSelected={isPlanSelected(plan)}
              onSelect={() => handlePlanSelect(plan)}
              themeObj
              isLastItem
              currency="USD"
            />
          })
          ->React.array}
        </div>
        <RenderIf condition={hasMoreOptions}>
          <button
            className="text-sm mt-2 hover:opacity-80"
            style={color: themeObj.colorPrimary}
            onClick={_ => setShowAllOptions(prev => !prev)}>
            {React.string(showAllOptions ? "Show less" : "Show more options")}
          </button>
        </RenderIf>
      </div>
    </RenderIf>
  </div>
}
