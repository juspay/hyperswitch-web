type wallet = Gpay | Paypal | Klarna | ApplePay | NONE
type tokenCategory = ApplePayObject | GooglePayThirdPartyObject | Others

type paymentType = Wallet | Others

type token = {
  walletName: wallet,
  token: string,
  sessionId: string,
  allowed_payment_methods: array<Js.Json.t>,
  transaction_info: Js.Json.t,
  merchant_info: Js.Json.t,
}

type tokenType =
  | ApplePayToken(array<Js.Json.t>)
  | GooglePayThirdPartyToken(array<Js.Json.t>)
  | OtherToken(array<token>)
type optionalTokenType =
  | ApplePayTokenOptional(option<Js.Json.t>)
  | GooglePayThirdPartyTokenOptional(option<Js.Json.t>)
  | OtherTokenOptional(option<token>)

type sessions = {
  paymentId: string,
  clientSecret: string,
  sessionsToken: tokenType,
}
let defaultToken = {
  walletName: NONE,
  token: "",
  sessionId: "",
  allowed_payment_methods: [],
  transaction_info: Js.Dict.empty()->Js.Json.object_,
  merchant_info: Js.Dict.empty()->Js.Json.object_,
}
let getWallet = str => {
  switch str {
  | "apple_pay" => ApplePay
  | "paypal" => Paypal
  | "klarna" => Klarna
  | "google_pay" => Gpay
  | _ => NONE
  }
}
open Utils

let getSessionsToken = (dict, str) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeArray)
  ->Belt.Option.map(arr => {
    arr->Js.Array2.map(json => {
      let dict = json->getDictFromJson
      {
        walletName: getString(dict, "wallet_name", "")->getWallet,
        token: getString(dict, "session_token", ""),
        sessionId: getString(dict, "session_id", ""),
        allowed_payment_methods: getArray(dict, "allowed_payment_methods"),
        transaction_info: getJsonObjectFromDict(dict, "transaction_info"),
        merchant_info: getJsonObjectFromDict(dict, "merchant_info"),
      }
    })
  })
  ->Belt.Option.getWithDefault([defaultToken])
}
let getSessionsTokenJson = (dict, str) => {
  dict->Js.Dict.get(str)->Belt.Option.flatMap(Js.Json.decodeArray)->Belt.Option.getWithDefault([])
}

let itemToObjMapper = (dict, returnType) => {
  switch returnType {
  | ApplePayObject => {
      paymentId: getString(dict, "payment_id", ""),
      clientSecret: getString(dict, "client_secret", ""),
      sessionsToken: ApplePayToken(getSessionsTokenJson(dict, "session_token")),
    }

  | GooglePayThirdPartyObject => {
      paymentId: getString(dict, "payment_id", ""),
      clientSecret: getString(dict, "client_secret", ""),
      sessionsToken: GooglePayThirdPartyToken(getSessionsTokenJson(dict, "session_token")),
    }

  | Others => {
      paymentId: getString(dict, "payment_id", ""),
      clientSecret: getString(dict, "client_secret", ""),
      sessionsToken: OtherToken(getSessionsToken(dict, "session_token")),
    }
  }
}

let getWalletFromTokenType = (arr, val: wallet) => {
  let x = arr->Js.Array2.find(item =>
    item
    ->Js.Json.decodeObject
    ->Belt.Option.flatMap(x => {
      x->Js.Dict.get("wallet_name")
    })
    ->Belt.Option.flatMap(Js.Json.decodeString)
    ->Belt.Option.getWithDefault("")
    ->getWallet === val
  )
  x
}

let getPaymentSessionObj = (tokenType: tokenType, val: wallet) => {
  switch tokenType {
  | ApplePayToken(arr) => ApplePayTokenOptional(getWalletFromTokenType(arr, val))

  | GooglePayThirdPartyToken(arr) =>
    GooglePayThirdPartyTokenOptional(getWalletFromTokenType(arr, val))

  | OtherToken(arr) => OtherTokenOptional(arr->Js.Array2.find(item => item.walletName == val))
  }
}
