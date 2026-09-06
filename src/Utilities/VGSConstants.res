open VGSTypes

let vgsScriptURL = `https://js.verygoodvault.com/vgs-collect/2.27.2/vgs-collect.js`

let vgsScriptIntegrity = "sha384-ddxU1XAc77oB4EIpKOgJQ3FN2a6STYPK0JipRqg1x/eW+n5MFn1XbbZa7+KRjkqc"

let cardNumberOptions = {
  \"type": "card-number",
  name: "card_number",
  placeholder: "1234 1234 1234 1234",
  validations: ["required", "validCardNumber"],
  showCardIcon: true,
}

let cardExpiryOptions = expiryPlaceholder => {
  \"type": "card-expiration-date",
  name: "card_exp",
  placeholder: expiryPlaceholder,
  validations: ["required", "validCardExpirationDate"],
  showCardIcon: false,
  yearLength: 2,
}

let cardCvcOptions = {
  \"type": "card-security-code",
  name: "card_cvc",
  placeholder: "123",
  validations: ["required", "validCardSecurityCode"],
  showCardIcon: true,
}

// CSS for the secure CVC field in the saved-card (return user) flow. Keeps the
// VGS input compact (≈ the native 1.8rem cvc input) so it matches the non-vault
// saved-card cvc field rather than the taller new-card field.
let savedCardCvcCss =
  [
    ("padding", "0px"),
    ("margin", "0px"),
    ("line-height", SavedCardCvcStyles.fieldHeight),
    ("height", SavedCardCvcStyles.fieldHeight),
    ("box-sizing", "border-box"),
  ]
  ->Array.map(((key, value)) => (key, value->JSON.Encode.string))
  ->Dict.fromArray
  ->JSON.Encode.object

let savedCardCvcValidations = savedCardBrand => {
  let exactLengthPatterns =
    CardValidations.getobjFromCardPattern(savedCardBrand).cvcLength
    ->Array.map(length => `\\d{${length->Int.toString}}`)
    ->Array.join("|")
  ["required", `/^(?:${exactLengthPatterns})$/`]
}

// Without a card-number field VGS cannot infer the card brand, so use the saved
// card's exact legacy CVC lengths instead of generic validCardSecurityCode.
let savedCardCvcOptions = savedCardBrand => {
  ...cardCvcOptions,
  validations: savedCardCvcValidations(savedCardBrand),
  showCardIcon: false,
  css: savedCardCvcCss,
}
