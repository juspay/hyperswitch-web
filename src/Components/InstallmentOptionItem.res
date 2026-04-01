@react.component
let make = (
  ~plan: PaymentMethodsRecord.installmentPlan,
  ~currency,
  ~isSelected,
  ~onSelect,
  ~isLastItem,
) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let radioBorderColor = isSelected ? themeObj.colorPrimary : themeObj.borderColor

  <div
    onClick={_ => onSelect()}
    style={
      padding: `calc(${themeObj.spacingUnit} * 0.8) ${themeObj.spacingUnit}`,
      borderColor: themeObj.borderColor,
      backgroundColor: isSelected
        ? `color-mix(in srgb, ${themeObj.colorPrimary} 6%, ${themeObj.colorBackground})`
        : themeObj.colorBackground,
    }
    className={`flex items-center gap-2 w-full ${isLastItem ? "" : "border-b"} cursor-pointer`}>
    <div
      style={
        width: "16px",
        height: "16px",
        border: `1.5px solid ${radioBorderColor}`,
      }
      className="rounded-full shrink-0 flex items-center justify-center">
      <RenderIf condition=isSelected>
        <div
          style={
            backgroundColor: themeObj.colorPrimary,
          }
          className="w-2 h-2 rounded-full"
        />
      </RenderIf>
    </div>
    <InstallmentPlanDetails plan currency />
  </div>
}
