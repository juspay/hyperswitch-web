open VGSTypes

let vgsScriptURL = `https://js.verygoodvault.com/vgs-collect/2.27.2/vgs-collect.js`

let cardNumberOptions = {
  type_: "card-number",
  name: "card_number",
  placeholder: "1234 1234 1234 1234",
  validations: ["required", "validCardNumber"],
  showCardIcon: true,
}

let cardExpiryOptions = (~expiryPlaceholder, ~vault) => {
  type_: "card-expiration-date",
  name: "card_exp",
  placeholder: expiryPlaceholder,
  validations: ["required", "validCardExpirationDate"],
  yearLength: 2,
  showCardIcon: false,
  serializers: [VGS.separate({monthName: "card_exp_month", yearName: "card_exp_year"})],
}

let cardCvcOptions = {
  type_: "card-security-code",
  name: "card_cvc",
  placeholder: "123",
  validations: ["required", "validCardSecurityCode"],
  showCardIcon: true,
}
