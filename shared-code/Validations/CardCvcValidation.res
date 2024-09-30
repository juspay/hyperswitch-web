open ValidationUtils

let cvcNumberInRange = (val, cardBrand) => {
  let clearValue = val->clearSpaces
  let obj = getobjFromCardPattern(cardBrand)
  let cvcLengthInRange =
    obj.cvcLength
    ->Array.find(item => {
      clearValue->String.length == item
    })
    ->Option.isSome
  cvcLengthInRange
}
let checkCardCVC = (cvcNumber, cardBrand) => {
  cvcNumber->String.length > 0 && cvcNumberInRange(cvcNumber, cardBrand)
}
