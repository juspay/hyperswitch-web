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
        <option key={Int.toString(i)} value=item className="opacity-0 w-0 h-0">
          {item->React.string}
        </option>
      })
      ->React.array}
    </select>
  }
}

@react.component
let make = (~cardNumber, ~paymentType, ~cardBrand, ~setCardBrand) => {
  let cardType = React.useMemo1(_ => cardBrand->CardUtils.getCardType, [cardBrand])
  let animate = cardType == NOTFOUND ? "animate-slideLeft" : "animate-slideRight"
  let isCardCoBadged = Recoil.useRecoilValueFromAtom(RecoilAtoms.isCardCoBadged)
  let setIsCardCoBadged = Recoil.useSetRecoilState(RecoilAtoms.isCardCoBadged)
  let cardBrandIcon = React.useMemo1(
    _ => CardUtils.getCardBrandIcon(cardType, paymentType),
    [cardBrand],
  )

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let enabledCardSchemes =
    paymentMethodListValue->PaymentUtils.getSupportedCardBrands->Option.getOr([])

  let matchedCardSchemes = cardNumber->CardUtils.getAllMatchedCardSchemes

  let eligibleCardSchemes = CardUtils.getEligibleCoBadgedCardSchemes(
    ~matchedCardSchemes,
    ~enabledCardSchemes,
  )

  React.useEffect1(() => {
    setIsCardCoBadged(_ => eligibleCardSchemes->Array.length > 1)
    None
  }, [[eligibleCardSchemes]])

  <div className={`${animate} flex items-center`}>
    cardBrandIcon
    <RenderIf condition={isCardCoBadged}>
      <CoBadgeCardSchemeDropDown eligibleCardSchemes setCardBrand />
    </RenderIf>
  </div>
}
