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
      backgroundColor: themeObj.colorBackground,
    }
    className={`relative flex items-center gap-2 w-full ${isLastItem ? "" : "border-b"} cursor-pointer`}>
    <RenderIf condition=isSelected>
      <div
        style={backgroundColor: themeObj.colorPrimary}
        className="absolute inset-0 opacity-[0.06] pointer-events-none"
      />
    </RenderIf>
    <div
      style={
        border: `1.5px solid ${radioBorderColor}`,
      }
      className="w-4 h-4 rounded-full shrink-0 flex items-center justify-center">
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
