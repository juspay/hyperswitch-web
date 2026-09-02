module CoBadgeCardSchemeDropDown = {
  @react.component
  let make = (~eligibleCardSchemes, ~setCardBrand) => {
    <select
      className="w-4"
      onClick={_ =>
        SdkRuntimeLogger.logUser(~event=CardSchemeSelected, ~message="CardSchemeMenu expanded")}
      onChange={ev => {
        let target = ev->ReactEvent.Form.target
        let value = target["value"]
        setCardBrand(_ => value)
      }}
    >
      <option disabled=true> {"Select a card brand"->React.string} </option>
      {eligibleCardSchemes
      ->Array.mapWithIndex((item, i) => {
        <option key={Int.toString(i)} value=item> {item->React.string} </option>
      })
      ->React.array}
    </select>
  }
}

@react.component
let make = (
  ~cardNumber,
  ~paymentType,
  ~cardBrand,
  ~setCardBrand,
  ~isCoBadgedCardDetectedOnce: React.ref<bool>,
) => {
  let cardType = React.useMemo1(_ => cardBrand->CardUtils.getCardType, [cardBrand])
  let animate = cardType == NOTFOUND ? "animate-slideLeft" : "animate-slideRight"
  let cardBrandIcon = React.useMemo1(
    _ => CardUtils.getCardBrandIcon(cardType, paymentType),
    [cardBrand],
  )

  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let forwardedSupportedCardBrands = Jotai.useAtomValue(JotaiAtoms.supportedCardBrands)
  let enabledCardSchemes = switch forwardedSupportedCardBrands {
  | Some(brands) => brands
  | None => paymentMethodListValue->PaymentUtils.getSupportedCardBrands->Option.getOr([])
  }

  let matchedCardSchemes =
    cardNumber->CardValidations.clearSpaces->CardValidations.getAllMatchedCardSchemes

  let eligibleCardSchemes = CardUtils.getEligibleCoBadgedCardSchemes(
    ~matchedCardSchemes,
    ~enabledCardSchemes,
  )

  let isCardCoBadged = eligibleCardSchemes->Array.length > 1

  let marginLeft = isCardCoBadged ? "-ml-2" : ""

  let {layout} = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let cardBrandIconSetting =
    Jotai.useAtomValue(JotaiAtoms.cardBrandIconOverride)->Option.getOr(
      CardUtils.getLayoutClass(layout).cardBrandIcon,
    )
  let shouldShowCoBadgeCardSchemeDropDown =
    isCardCoBadged && cardNumber->CardValidations.clearSpaces->String.length >= 16
  let showCardBrandIcon = CardUtils.getCardBrandIconVisibility(cardBrandIconSetting, cardType)

  React.useEffect1(() => {
    if shouldShowCoBadgeCardSchemeDropDown && !isCoBadgedCardDetectedOnce.current {
      isCoBadgedCardDetectedOnce.current = true
      SdkRuntimeLogger.logUser(~event=CardSchemeSelected, ~message="Card detected as co-badged")
    }
    None
  }, [shouldShowCoBadgeCardSchemeDropDown])

  <div className={`${animate} flex items-center ${marginLeft} hellow-rodl`}>
    <RenderIf condition={showCardBrandIcon}> cardBrandIcon </RenderIf>
    <RenderIf condition={shouldShowCoBadgeCardSchemeDropDown}>
      <CoBadgeCardSchemeDropDown eligibleCardSchemes setCardBrand />
    </RenderIf>
  </div>
}
