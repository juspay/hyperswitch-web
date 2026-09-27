type walletType =
  | GooglePay
  | ApplePay
  | SamsungPay
  | Paypal
  | PaypalSdk
  | Paze

type payLaterType = Klarna

type openBankingType = Plaid

type paymentMethod =
  | Card
  | Wallet(walletType)
  | PayLater(payLaterType)
  | OpenBanking(openBankingType)
  | Dynamic(string)

let fromPair = (~method, ~methodType) =>
  switch (method->String.trim, methodType->String.trim) {
  | ("", _) => None
  | ("card", _) => Some(Card)
  | (method, "") => Some(Dynamic(method))
  | (method, methodType) => Some(Dynamic(`${method}.${methodType}`))
  }

let fromRequestBody = bodyStr =>
  switch bodyStr->JSON.parseExn->JSON.Decode.object {
  | Some(body) =>
    let field = key => body->Dict.get(key)->Option.flatMap(JSON.Decode.string)->Option.getOr("")
    fromPair(~method=field("payment_method"), ~methodType=field("payment_method_type"))
  | None => None
  | exception _ => None
  }

let qualifiedName = value => {
  let family = value->LoggerUtils.variantName
  let qualify = subtype => `${family}.${subtype->LoggerUtils.variantName}`
  switch value {
  | Dynamic(raw) => raw->LoggerUtils.snakeCase
  | Card => family
  | Wallet(subtype) => subtype->qualify
  | PayLater(subtype) => subtype->qualify
  | OpenBanking(subtype) => subtype->qualify
  }
}
