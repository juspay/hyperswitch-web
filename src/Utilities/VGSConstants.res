open VGSTypes

// Pinned VGS Collect.js version — must stay in sync with the script src + integrity
// hash in VGSVault.res and the CSP allow-list in webpack.common.js.
let vgsScriptURL = `https://js.verygoodvault.com/vgs-collect/2.27.2/vgs-collect.js`

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
    ("line-height", "1.8rem"),
    ("height", "1.8rem"),
    ("box-sizing", "border-box"),
  ]
  ->Array.map(((key, value)) => (key, value->JSON.Encode.string))
  ->Dict.fromArray
  ->JSON.Encode.object

// Saved-card cvc field options: like cardCvcOptions but without the card icon and
// with the compact sizing above, to match the non-vault saved-card cvc input.
let savedCardCvcOptions = {
  ...cardCvcOptions,
  showCardIcon: false,
  css: savedCardCvcCss,
}
