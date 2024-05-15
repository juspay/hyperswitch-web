open RecoilAtoms
@react.component
let make = (~paymentOption: PaymentMethodsRecord.paymentFieldsInfo, ~isActive: bool) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly, customMethodNames} = Recoil.useRecoilValueFromAtom(optionAtom)
  let setSelectedOption = Recoil.useSetRecoilState(selectedOptionAtom)
  let setIsPayNowButtonDisable = Recoil.useSetRecoilState(payNowButtonDisable)
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
    setIsPayNowButtonDisable(_ => true)
    setSelectedOption(_ => paymentOption.paymentMethodName)
  }
  <button
    className={`Tab ${tabClass} flex flex-col animate-slowShow`}
    type_="button"
    disabled=readOnly
    style={
      minWidth: "5rem",
      overflowWrap: "anywhere",
      width: "100%",
      padding: themeObj.spacingUnit,
      cursor: "pointer",
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
