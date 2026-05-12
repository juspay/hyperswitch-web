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
  let {layout, customMethodNames, redirectionText} = Recoil.useRecoilValueFromAtom(optionAtom)
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
  <div
    className={`AccordionItem flex flex-col`}
    style={
      minHeight: "60px",
      width: "-webkit-fill-available",
      cursor: "pointer",
      marginBottom: layoutClass.spacedAccordionItems ? themeObj.spacingAccordionItem : "",
      border: `1px solid ${themeObj.borderColor}`,
      borderRadius: {borderRadiusStyle},
      borderBottomStyle: borderBottom ? "solid" : "hidden",
    }
    onClick={_ => setSelectedOption(_ => paymentOption.paymentMethodName)}>
    <div
      className={`flex flex-row items-center ${accordionClass}`}
      style={columnGap: themeObj.spacingUnit}>
      <RenderIf condition=layoutClass.radios>
        <Radio checked=radioClass />
      </RenderIf>
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
      <div
        className={`AccordionItemIcon ${accordionItemIconClass} flex items-center`}
        style=logoContainerStyle>
        {switch icon {
        | Some(ele) => ele
        | None => React.string("<icon>")
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
      <div className={`AccordionItemLabel ${accordionItemLabelClass} flex items-center`}>
        {React.string(paymentOption.paymentMethodName === "card" ? localeString.card : displayName)}
      </div>
    </div>
    {let hasVisibleContent = if redirectionText.hide {
      paymentOption.fields->Array.length == 0 ||
        paymentOption.fields->Array.some(field => field !== PaymentMethodsRecord.InfoElement)
    } else {
      true
    }
    <RenderIf condition={selectedOption == paymentOption.paymentMethodName && hasVisibleContent}>
      <div className="mt-4 w-full"> {checkoutEle} </div>
    </RenderIf>}
  </div>
}
