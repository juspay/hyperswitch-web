let updateCardBody = (~paymentMethodToken, ~nickName, ~cardHolderName) => {
  let cardDetails =
    [
      ("card_holder_name", cardHolderName->JSON.Encode.string),
      ("nick_name", nickName->JSON.Encode.string),
    ]->Utils.getJsonFromArrayOfJson
  let paymentMethodData = [("card", cardDetails)]->Utils.getJsonFromArrayOfJson

  [
    ("payment_method_token", paymentMethodToken->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
  ]
}

let updateCVVBody = (~paymentMethodToken, ~cvcNumber) => {
  let cardDetails = [("card_cvc", cvcNumber->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson
  let paymentMethodData = [("card", cardDetails)]->Utils.getJsonFromArrayOfJson

  [
    ("payment_method_token", paymentMethodToken->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
  ]
}

let saveCardBody = (
  ~cardNumber,
  ~month,
  ~year,
  ~cardHolderName=None,
  ~cvcNumber,
  ~cardBrand,
  ~nickname="",
) => {
  let cardBody = [
    ("card_number", cardNumber->CardValidations.clearSpaces->JSON.Encode.string),
    ("card_exp_month", month->JSON.Encode.string),
    ("card_exp_year", year->JSON.Encode.string),
    ("card_cvc", cvcNumber->JSON.Encode.string),
    ("card_issuer", ""->JSON.Encode.string),
  ]

  cardHolderName
  ->Option.map(name => cardBody->Array.push(("card_holder_name", name->JSON.Encode.string))->ignore)
  ->ignore

  if nickname != "" {
    cardBody->Array.push(("nick_name", nickname->JSON.Encode.string))->ignore
  }

  [
    ("payment_method_type", "card"->JSON.Encode.string),
    ("payment_method_subtype", "card"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        ("card", cardBody->Array.concat(cardBrand)->Utils.getJsonFromArrayOfJson),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ]
}

let vgsCardBody = (~cardNumber, ~month, ~year, ~cvcNumber) => {
  let cardBody = [
    ("card_number", cardNumber->JSON.Encode.string),
    ("card_exp_month", month->JSON.Encode.string),
    ("card_exp_year", year->JSON.Encode.string),
    ("card_cvc", cvcNumber->JSON.Encode.string),
  ]

  let paymentMethodData = [("vault_data_card", cardBody->Utils.getJsonFromArrayOfJson)]

  [
    ("payment_method_type", "card"->JSON.Encode.string),
    ("payment_method_subtype", "debit"->JSON.Encode.string),
    ("payment_method_data", paymentMethodData->Utils.getJsonFromArrayOfJson),
  ]
}

let hyperswitchVaultBody = token => {
  let paymentMethodData =
    [("card_token", Dict.make()->JSON.Encode.object)]->Utils.getJsonFromArrayOfJson

  [
    ("payment_method_type", "card"->JSON.Encode.string),
    ("payment_method_subtype", "debit"->JSON.Encode.string),
    ("payment_token", token->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
  ]
}
