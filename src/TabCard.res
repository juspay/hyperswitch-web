open RecoilAtoms
@react.component
let make = (~paymentOption: PaymentMethodsRecord.paymentFieldsInfo, ~isActive: bool) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly, customMethodNames} = Recoil.useRecoilValueFromAtom(optionAtom)
  let setSelectedOption = Recoil.useSetRecoilState(selectedOptionAtom)
  let (tabClass, tabLabelClass, tabIconClass) = React.useMemo1(
    () => isActive ? ("Tab--selected", "TabLabel--selected", "TabIcon--selected") : ("", "", ""),
    [isActive],
  )
  <button
    className={`Tab ${tabClass} flex flex-col animate-slowShow`}
    type_="button"
    disabled=readOnly
    style={ReactDOMStyle.make(
      ~minWidth="5rem",
      ~overflowWrap="anywhere",
      ~width="100%",
      ~padding=themeObj.spacingUnit,
      ~cursor="pointer",
      (),
    )}
    onClick={_ => setSelectedOption(._ => paymentOption.paymentMethodName)}>
    <div className={`TabIcon ${tabIconClass}`}>
      {switch paymentOption.icon {
      | Some(ele) => ele
      | None => <Icon name="default-card" size=19 />
      }}
    </div>
    <div className={`TabLabel ${tabLabelClass}`}>
      {React.string(
        paymentOption.paymentMethodName === "card"
          ? localeString.card
          : PaymentUtils.getDisplayName(
              customMethodNames,
              paymentOption.paymentMethodName,
              paymentOption.displayName,
            ),
      )}
    </div>
  </button>
}
