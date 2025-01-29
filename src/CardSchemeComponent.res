module CoBadgeCardSchemeDropDown = {
  @react.component
  let make = (~eligibleCardSchemes, ~setCardBrand) => {
    <select
      className="w-4"
      onChange={ev => {
        let target = ev->ReactEvent.Form.target
        let value = target["value"]
        setCardBrand(_ => value)
      }}>
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
let make = (~cardNumber, ~paymentType, ~cardBrand, ~setCardBrand) => {
  let cardType = React.useMemo1(_ => cardBrand->CardUtils.getCardType, [cardBrand])
  let animate = cardType == NOTFOUND ? "animate-slideLeft" : "animate-slideRight"
  let cardBrandIcon = React.useMemo1(
    _ => CardUtils.getCardBrandIcon(cardType, paymentType),
    [cardBrand],
  )

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let enabledCardSchemes =
    paymentMethodListValue->PaymentUtils.getSupportedCardBrands->Option.getOr([])

  let matchedCardSchemes = cardNumber->CardUtils.clearSpaces->CardUtils.getAllMatchedCardSchemes

  let eligibleCardSchemes = CardUtils.getEligibleCoBadgedCardSchemes(
    ~matchedCardSchemes,
    ~enabledCardSchemes,
  )

  let isCardCoBadged = eligibleCardSchemes->Array.length > 1

  let marginLeft = isCardCoBadged ? "-ml-2" : ""

  <div className={`${animate} flex items-center ${marginLeft} hellow-rodl`}>
    cardBrandIcon
    <RenderIf condition={isCardCoBadged && cardNumber->CardUtils.clearSpaces->String.length >= 16}>
      <CoBadgeCardSchemeDropDown eligibleCardSchemes setCardBrand />
    </RenderIf>
  </div>
}
