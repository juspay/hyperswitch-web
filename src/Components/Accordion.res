open RecoilAtoms
@react.component
let make = (
  ~paymentOption: PaymentMethodsRecord.paymentFieldsInfo,
  ~isActive: bool,
  ~checkoutEle: React.element,
  ~borderBottom: bool,
  ~borderRadiusStyle,
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
  ) = React.useMemo1(
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
  <div
    className={`AccordionItem flex flex-col`}
    style={ReactDOMStyle.make(
      ~minHeight="60px",
      ~width="-webkit-fill-available",
      ~padding="20px",
      ~cursor="pointer",
      ~marginBottom=layoutClass.spacedAccordionItems ? themeObj.spacingAccordionItem : "",
      ~border=`1px solid ${themeObj.borderColor}`,
      ~borderRadius={borderRadiusStyle},
      ~borderBottomStyle=borderBottom ? "solid" : "hidden",
      (),
    )}
    onClick={_ => setSelectedOption(._ => paymentOption.paymentMethodName)}>
    <div
      className={`flex flex-row items-center ${accordionClass}`}
      style={ReactDOMStyle.make(~columnGap=themeObj.spacingUnit, ())}>
      <RenderIf condition=layoutClass.radios> <Radio checked=radioClass /> </RenderIf>
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
