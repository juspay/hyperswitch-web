open RecoilAtoms
@react.component
let make = (
  ~paymentOption: PaymentMethodsRecord.paymentFieldsInfo,
  ~isActive: bool,
  ~disabled: bool=false,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly, customMethodNames} = Recoil.useRecoilValueFromAtom(optionAtom)
  let setSelectedOption = Recoil.useSetRecoilState(selectedOptionAtom)
  let (tabClass, tabLabelClass, tabIconClass) = React.useMemo(
    () => isActive ? ("Tab--selected", "TabLabel--selected", "TabIcon--selected") : ("", "", ""),
    [isActive],
  )
  let (displayName, icon) = PaymentUtils.getDisplayNameAndIcon(
    customMethodNames,
    paymentOption.paymentMethodName,
    paymentOption.displayName,
    paymentOption.icon,
  )
  let onClick = _ => {
    if !disabled {
      setSelectedOption(_ => paymentOption.paymentMethodName)
    }
  }
  let isDisabled = readOnly || disabled
  <button
    className={`Tab ${tabClass} flex flex-col animate-slowShow ${disabled
        ? "cursor-not-allowed"
        : ""}`}
    type_="button"
    disabled=isDisabled
    style={
      minWidth: "5rem",
      overflowWrap: "anywhere",
      width: "100%",
      padding: themeObj.spacingUnit,
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? "0.5" : "1.0",
    }
    onClick>
    <div className={`TabIcon ${tabIconClass}`}>
      {switch icon {
      | Some(ele) => ele
      | None => <Icon name="default-card" size=19 />
      }}
    </div>
    <div className={`TabLabel ${tabLabelClass}`}>
      {React.string(paymentOption.paymentMethodName === "card" ? localeString.card : displayName)}
    </div>
  </button>
}
