module CoBadgeCardSchemeDropDown = {
  @react.component
  let make = (~cardNumber, ~setCardBrand) => {
    <select
      className="w-4"
      onChange={ev => {
        let target = ev->ReactEvent.Form.target
        let value = target["value"]
        setCardBrand(_ => value)
      }}>
      <option disabled=true> {"Select a card brand"->React.string} </option>
      {cardNumber
      ->CardUtils.getCoBadgesCardSchemes
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
let make = (~cardNumber, ~paymentType, ~cardBrand, ~setCardBrand, ~isCardCoBadged=false) => {
  let cardType = React.useMemo1(_ => cardBrand->CardUtils.getCardType, [cardBrand])
  let animate = cardType == NOTFOUND ? "animate-slideLeft" : "animate-slideRight"

  let cardBrandIcon = React.useMemo1(
    _ => CardUtils.getCardBrandIcon(cardType, paymentType),
    [cardBrand],
  )
  <div className={`${animate} flex items-center`}>
    cardBrandIcon
    <RenderIf condition={isCardCoBadged}>
      <CoBadgeCardSchemeDropDown cardNumber setCardBrand />
    </RenderIf>
  </div>
}
