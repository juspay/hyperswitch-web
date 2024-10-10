open ValidationUtils

let cardValid = (cardNumber, cardBrand) => {
  let clearValueLength = cardNumber->clearSpaces->String.length
  (clearValueLength == maxCardLength(cardBrand) ||
    (cardBrand === "Visa" && clearValueLength == 16)) && calculateLuhn(cardNumber)
}