open RecoilAtoms
@react.component
let make = (
  ~paymentOption: PaymentMethodsRecord.paymentFieldsInfo,
  ~isActive: bool,
  ~checkoutEle: React.element,
  ~borderBottom: bool,
  ~borderRadiusStyle,
  ~index: int=0,
  ~isFocused: bool=true,
  ~registerItemRef: (int, Nullable.t<Dom.element>) => unit=(_, _) => (),
  ~onArrowNav: (int, int) => unit=(_, _) => (),
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
  let selected = selectedOption == paymentOption.paymentMethodName
  <div
    className={`AccordionItem flex flex-col`}
    style={
      minHeight: "60px",
      width: "-webkit-fill-available",
      marginBottom: layoutClass.spacedAccordionItems ? themeObj.spacingAccordionItem : "",
      border: `1px solid ${themeObj.borderColor}`,
      borderRadius: {borderRadiusStyle},
      borderBottomStyle: borderBottom ? "solid" : "hidden",
    }>
    <div
      className={`flex flex-row items-center ${accordionClass}`}
      role="radio"
      ariaChecked={selected ? #"true" : #"false"}
      tabIndex={isFocused ? 0 : -1}
      ref={ReactDOM.Ref.callbackDomRef(el => registerItemRef(index, el))}
      onKeyDown={event => {
        let key = JsxEvent.Keyboard.key(event)
        switch key {
        | "ArrowDown" | "ArrowRight" =>
          event->JsxEvent.Keyboard.preventDefault
          onArrowNav(index, 1)
        | "ArrowUp" | "ArrowLeft" =>
          event->JsxEvent.Keyboard.preventDefault
          onArrowNav(index, -1)
        | "Enter" | " " =>
          event->JsxEvent.Keyboard.preventDefault
          setSelectedOption(_ => paymentOption.paymentMethodName)
        | _ => ()
        }
      }}
      style={columnGap: themeObj.spacingUnit, minHeight: "60px", cursor: "pointer"}
      onClick={_ => setSelectedOption(_ => paymentOption.paymentMethodName)}>
      <RenderIf condition=layoutClass.radios>
        <Radio checked=radioClass />
      </RenderIf>
      <div className={`AccordionItemIcon ${accordionItemIconClass} flex items-center relative`}>
        {switch icon {
        | Some(ele) => ele
        | None => React.string("<icon>")
        }}
        <RenderIf condition={layoutClass.showCheckedIconForSelection && isActive}>
          <div className="AccordionItemSelectionIcon absolute">
            <Icon name="checked-selection" size=14 />
          </div>
        </RenderIf>
      </div>
      <div className={`AccordionItemLabel ${accordionItemLabelClass} flex items-center`}>
        {React.string(paymentOption.paymentMethodName === "card" ? localeString.card : displayName)}
      </div>
    </div>
    <RenderIf condition={selectedOption == paymentOption.paymentMethodName}>
      <div className="w-full"> {checkoutEle} </div>
    </RenderIf>
  </div>
}
