open PaymentMethodCollectTypes
open ErrorUtils
open Utils

let getPaymentMethod = (paymentMethod: paymentMethod): string => {
  switch paymentMethod {
  | Card => "card"
  | BankTransfer => "bank_transfer"
  | Wallet => "wallet"
  }
}

let getPaymentMethodType = (paymentMethodType: paymentMethodType): string => {
  switch paymentMethodType {
  | Card(cardType) =>
    switch cardType {
    | Credit => "credit"
    | Debit => "debit"
    }
  | BankTransfer(bankTransferType) =>
    switch bankTransferType {
    | ACH => "ach"
    | Bacs => "bacs"
    | Sepa => "sepa"
    }
  | Wallet(walletType) =>
    switch walletType {
    | Paypal => "paypal"
    }
  }
}

// Defaults
let defaultEnabledPaymentMethods: array<paymentMethodType> = [
  Card(Credit),
  Card(Debit),
  BankTransfer(ACH),
  BankTransfer(Bacs),
  BankTransfer(Sepa),
  Wallet(Paypal),
]

let defaultPaymentMethodCollectOptions = {
  enabledPaymentMethods: defaultEnabledPaymentMethods,
  linkId: "",
  customerId: "",
  theme: "#1A1A1A",
  collectorName: "HyperSwitch",
  logo: "",
  returnUrl: None,
}

let defaultAvailablePaymentMethods: array<paymentMethod> = []
let defaultAvailablePaymentMethodTypes = {
  card: [],
  bankTransfer: [],
  wallet: [],
}
let defaultSelectedPaymentMethod: paymentMethod = Card
let defaultSelectedPaymentMethodType: option<paymentMethodType> = Some(Card(Debit))

let itemToObjMapper = (dict, logger) => {
  unknownKeysWarning(
    [
      "enabledPaymentMethods",
      "linkId",
      "customerId",
      "theme",
      "collectorName",
      "logo",
      "returnUrl",
    ],
    dict,
    "options",
    ~logger,
  )
  {
    enabledPaymentMethods: switch dict->Dict.get("enabledPaymentMethods") {
    | Some(json) => json->decodePaymentMethodTypeArray
    | None => defaultEnabledPaymentMethods
    },
    linkId: getString(dict, "linkId", ""),
    customerId: getString(dict, "customerId", ""),
    theme: getString(dict, "theme", ""),
    collectorName: getString(dict, "collectorName", ""),
    logo: getString(dict, "logo", ""),
    returnUrl: dict->Dict.get("returnUrl")->Option.flatMap(JSON.Decode.string),
  }
}
