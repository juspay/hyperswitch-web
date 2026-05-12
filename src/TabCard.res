open RecoilAtoms
@react.component
let make = (~paymentOption: PaymentMethodsRecord.paymentFieldsInfo, ~isActive: bool) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly, customMethodNames, layout} = Recoil.useRecoilValueFromAtom(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)
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
    {let logoCustomization = layoutClass.logoContainerCustomization
    let logoContainerStyle: JsxDOMStyle.t = switch logoCustomization.shape {
    | PaymentType.Default => {position: "relative"}
    | shape => {
        let borderRadius = switch shape {
        | Circle => "50%"
        | Square => "0px"
        | Rounded => "4px"
        | Default => ""
        }
        {
          position: "relative",
          width: logoCustomization.width->Option.getOr("40px"),
          height: logoCustomization.height->Option.getOr("40px"),
          borderRadius,
          border: `${logoCustomization.borderWidth->Option.getOr("1px")} solid ${logoCustomization.borderColor->Option.getOr(themeObj.borderColor)}`,
          backgroundColor: logoCustomization.backgroundColor->Option.getOr("transparent"),
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }
      }
    }
    <div className={`TabIcon ${tabIconClass}`} style=logoContainerStyle>
      {switch icon {
      | Some(ele) => ele
      | None => <Icon name="default-card" size=19 />
      }}
      <RenderIf condition={layoutClass.showCheckedIconForSelection && isActive}>
        {let offset = switch logoCustomization.shape {
        | PaymentType.Default => "-6px"
        | _ => "-3px"
        }
        <div
          style={
            position: "absolute",
            bottom: offset,
            right: offset,
          }>
          <Icon name="checked-selection" size=14 />
        </div>}
      </RenderIf>
    </div>}
    <div className={`TabLabel ${tabLabelClass}`}>
      {React.string(paymentOption.paymentMethodName === "card" ? localeString.card : displayName)}
    </div>
  </button>
}
