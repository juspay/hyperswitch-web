@react.component
let make = (
  ~plan: PaymentMethodsRecord.installmentPlan,
  ~currency,
  ~isSelected,
  ~onSelect,
  ~isLastItem,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  <div
    onClick={_ => onSelect()}
    role="button"
    tabIndex=0
    ariaLabel={localeString.selectInstallmentPlanLabel(plan.number_of_installments->Int.toString)}
    onKeyDown={AccessibilityUtils.onActivateKeyDown(~onActivate=() => onSelect())}
    style={
      padding: `calc(${themeObj.spacingUnit} * 0.8) ${themeObj.spacingUnit}`,
      borderColor: themeObj.borderColor,
      backgroundColor: themeObj.colorBackground,
    }
    className={`relative flex items-center gap-2 w-full ${isLastItem
        ? ""
        : "border-b"} cursor-pointer`}>
    <RenderIf condition=isSelected>
      <div
        style={backgroundColor: themeObj.colorPrimary}
        className="absolute inset-0 opacity-[0.06] pointer-events-none"
      />
    </RenderIf>
    <RadioIndicator isSelected />
    <InstallmentPlanDetails plan currency />
  </div>
}
