open Utils

type wallet = Gpay | Paypal | Klarna | ApplePay | Paze | NONE

type tokenCategory = ApplePayObject | GooglePayThirdPartyObject | PazeObject | Others

type paymentType = Wallet | Others

type token = {
  walletName: wallet,
  token: string,
  sessionId: string,
  allowed_payment_methods: array<JSON.t>,
  transaction_info: JSON.t,
  merchant_info: JSON.t,
  shippingAddressRequired: bool,
  emailRequired: bool,
  shippingAddressParameters: JSON.t,
  orderDetails: JSON.t,
  connector: string,
  clientId: string,
  clientName: string,
  clientProfileId: string,
}

type tokenType =
  | ApplePayToken(array<JSON.t>)
  | GooglePayThirdPartyToken(array<JSON.t>)
  | PazeToken(array<JSON.t>)
  | OtherToken(array<token>)

type optionalTokenType =
  | ApplePayTokenOptional(option<JSON.t>)
  | GooglePayThirdPartyTokenOptional(option<JSON.t>)
  | PazeTokenOptional(option<JSON.t>)
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
  transaction_info: Dict.make()->JSON.Encode.object,
  merchant_info: Dict.make()->JSON.Encode.object,
  shippingAddressRequired: false,
  emailRequired: false,
  shippingAddressParameters: Dict.make()->JSON.Encode.object,
  orderDetails: Dict.make()->JSON.Encode.object,
  connector: "",
  clientId: "",
  clientName: "",
  clientProfileId: "",
}
let getWallet = str => {
  switch str {
  | "apple_pay" => ApplePay
  | "paypal" => Paypal
  | "klarna" => Klarna
  | "google_pay" => Gpay
  | "paze" => Paze
  | _ => NONE
  }
}

let getSessionsToken = (dict, str) =>
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.array)
  ->Option.map(arr => {
    arr->Array.map(json => {
      let dict = json->getDictFromJson
      {
        walletName: getString(dict, "wallet_name", "")->getWallet,
        token: getString(dict, "session_token", ""),
        sessionId: getString(dict, "session_id", ""),
        allowed_payment_methods: getArray(dict, "allowed_payment_methods"),
        transaction_info: getJsonObjectFromDict(dict, "transaction_info"),
        merchant_info: getJsonObjectFromDict(dict, "merchant_info"),
        shippingAddressRequired: getBool(dict, "shipping_address_required", false),
        emailRequired: getBool(dict, "email_required", false),
        shippingAddressParameters: getJsonObjectFromDict(dict, "shipping_address_parameters"),
        orderDetails: getJsonObjectFromDict(dict, "order_details"),
        connector: getString(dict, "connector", ""),
        clientId: getString(dict, "client_id", ""),
        clientName: getString(dict, "client_name", ""),
        clientProfileId: getString(dict, "client_profile_id", ""),
      }
    })
  })
  ->Option.getOr([defaultToken])
let getSessionsTokenJson = (dict, str) =>
  dict->Dict.get(str)->Option.flatMap(JSON.Decode.array)->Option.getOr([])

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

  | PazeObject => {
      paymentId: getString(dict, "payment_id", ""),
      clientSecret: getString(dict, "client_secret", ""),
      sessionsToken: PazeToken(getSessionsTokenJson(dict, "session_token")),
    }

  | Others => {
      paymentId: getString(dict, "payment_id", ""),
      clientSecret: getString(dict, "client_secret", ""),
      sessionsToken: OtherToken(getSessionsToken(dict, "session_token")),
    }
  }
}

let getWalletFromTokenType = (arr, val) =>
  arr->Array.find(item =>
    item
    ->JSON.Decode.object
    ->Option.flatMap(x => x->Dict.get("wallet_name"))
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("")
    ->getWallet === val
  )

let getPaymentSessionObj = (tokenType, val) =>
  switch tokenType {
  | ApplePayToken(arr) => ApplePayTokenOptional(getWalletFromTokenType(arr, val))
  | GooglePayThirdPartyToken(arr) =>
    GooglePayThirdPartyTokenOptional(getWalletFromTokenType(arr, val))
  | PazeToken(arr) => PazeTokenOptional(getWalletFromTokenType(arr, val))
  | OtherToken(arr) => OtherTokenOptional(arr->Array.find(item => item.walletName == val))
  }
