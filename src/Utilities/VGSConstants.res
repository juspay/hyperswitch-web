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
