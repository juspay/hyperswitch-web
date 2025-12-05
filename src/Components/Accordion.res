open RecoilAtoms
@react.component
let make = (
  ~paymentOption: PaymentMethodsRecord.paymentFieldsInfo,
  ~isActive: bool,
  ~checkoutEle: React.element,
  ~borderBottom: bool,
  ~borderRadiusStyle,
  ~isDisabled=false,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {layout, customMethodNames} = Recoil.useRecoilValueFromAtom(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(selectedOptionAtom)
  let (
    accordionClass,
    accordionItemLabelClass,
    accordionItemIconClass,
    radioClass,
  ) = React.useMemo(
    () =>
      isActive
        ? (
            "AccordionItem--selected",
            "AccordionItemLabel--selected",
            "AccordionItemIcon--selected",
            true,
          )
        : ("", "", "", false),
    [isActive],
  )
  let (displayName, icon) = PaymentUtils.getDisplayNameAndIcon(
    customMethodNames,
    paymentOption.paymentMethodName,
    paymentOption.displayName,
    paymentOption.icon,
  )

  let onClick = _ => {
    if !isDisabled {
      setSelectedOption(_ => paymentOption.paymentMethodName)
    }
  }

  <div
    className={`AccordionItem flex flex-col ${isDisabled ? "cursor-not-allowed" : ""}`}
    style={
      minHeight: "60px",
      width: "-webkit-fill-available",
      cursor: isDisabled ? "not-allowed" : "pointer",
      opacity: isDisabled ? "0.5" : "1.0",
      marginBottom: layoutClass.spacedAccordionItems ? themeObj.spacingAccordionItem : "",
      border: `1px solid ${themeObj.borderColor}`,
      borderRadius: {borderRadiusStyle},
      borderBottomStyle: borderBottom ? "solid" : "hidden",
    }
    onClick>
    <div
      className={`flex flex-row items-center ${accordionClass}`}
      style={columnGap: themeObj.spacingUnit}>
      <RenderIf condition=layoutClass.radios>
        <Radio checked=radioClass />
      </RenderIf>
      <div className={`AccordionItemIcon ${accordionItemIconClass} flex items-center`}>
        {switch icon {
        | Some(ele) => ele
        | None => React.string("<icon>")
        }}
      </div>
      <div className={`AccordionItemLabel ${accordionItemLabelClass} flex items-center`}>
        {React.string(paymentOption.paymentMethodName === "card" ? localeString.card : displayName)}
      </div>
    </div>
    <RenderIf condition={selectedOption == paymentOption.paymentMethodName}>
      <div className="mt-4 w-full"> {checkoutEle} </div>
    </RenderIf>
  </div>
}
