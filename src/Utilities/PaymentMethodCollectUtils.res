open CardUtils
open ErrorUtils
open PaymentMethodCollectTypes
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
    | Pix => "pix"
    | Venmo => "venmo"
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

let getValueFromDict = (paymentMethodDataDict, key) => {
  paymentMethodDataDict->Dict.get(key)->Option.getOr("")
}

let setFieldValidity = (key, validity: option<bool>, fieldValidityDict, setFieldValidityDict) => {
  let updatedFieldValidityDict = fieldValidityDict->Dict.copy
  updatedFieldValidityDict->Dict.set(key, validity)
  setFieldValidityDict(_ => updatedFieldValidityDict)
}

let calculateValidity = (paymentMethodDataDict, key) => {
  let value = paymentMethodDataDict->getValueFromDict(key)
  switch key {
  | "cardNumber" =>
    if cardNumberInRange(value)->Array.includes(true) && calculateLuhn(value) {
      Some(true)
    } else if value->String.length == 0 {
      None
    } else {
      Some(false)
    }
  | "expiryDate" =>
    if value->String.length > 0 && getExpiryValidity(value) {
      Some(true)
    } else if value->String.length == 0 {
      None
    } else {
      Some(false)
    }
  | "routingNumber" =>
    if value->String.length === 9 {
      let p1 = switch (
        value->String.charAt(0)->Belt.Int.fromString,
        value->String.charAt(3)->Belt.Int.fromString,
        value->String.charAt(6)->Belt.Int.fromString,
      ) {
      | (Some(a), Some(b), Some(c)) => Some(3 * (a + b + c))
      | _ => None
      }

      let p2 = switch (
        value->String.charAt(1)->Belt.Int.fromString,
        value->String.charAt(4)->Belt.Int.fromString,
        value->String.charAt(7)->Belt.Int.fromString,
      ) {
      | (Some(a), Some(b), Some(c)) => Some(7 * (a + b + c))
      | _ => None
      }

      let p3 = switch (
        value->String.charAt(2)->Belt.Int.fromString,
        value->String.charAt(5)->Belt.Int.fromString,
        value->String.charAt(8)->Belt.Int.fromString,
      ) {
      | (Some(a), Some(b), Some(c)) => Some(a + b + c)
      | _ => None
      }

      switch (p1, p2, p3) {
      | (Some(a), Some(b), Some(c)) => Some(mod(a + b + c, 10) == 0)
      | _ => Some(false)
      }
    } else {
      None
    }
  | _ => None
  }
}

let calculateAndSetValidity = (
  paymentMethodDataDict,
  key,
  fieldValidityDict,
  setFieldValidityDict,
) => {
  let updatedValidity = calculateValidity(paymentMethodDataDict, key)
  setFieldValidity(key, updatedValidity, fieldValidityDict, setFieldValidityDict)
}

let checkValidity = (keys, fieldValidityDict) => {
  keys->Array.reduce(true, (acc, key) => {
    switch fieldValidityDict->Dict.get(key) {
    | Some(validity) => acc && validity->Option.getOr(true)
    | None => false
    }
  })
}

let formCreatePaymentMethodRequestBody = (
  paymentMethodType: option<paymentMethodType>,
  paymentMethodDataDict,
  fieldValidityDict,
) => {
  switch paymentMethodType {
  | None => None
  // Card
  | Some(Card(_)) =>
    switch (
      paymentMethodDataDict->Dict.get("nameOnCard"),
      paymentMethodDataDict->Dict.get("cardNumber"),
      paymentMethodDataDict->Dict.get("expiryDate"),
    ) {
    | (Some(nameOnCard), Some(cardNumber), Some(expiryDate)) =>
      switch ["cardNumber", "nameOnCard", "expiryDate"]->checkValidity(fieldValidityDict) {
      | false => None
      | true => {
          let arr = expiryDate->String.split("/")
          switch (arr->Array.get(0), arr->Array.get(1)) {
          | (Some(month), Some(year)) =>
            Some([
              ("card_holder_name", nameOnCard),
              ("card_number", cardNumber),
              ("card_exp_month", month),
              ("card_exp_year", year),
            ])
          | _ => None
          }
        }
      }
    | _ => None
    }

  // Banks
  // ACH
  | Some(BankTransfer(ACH)) =>
    switch (
      paymentMethodDataDict->Dict.get("routingNumber"),
      paymentMethodDataDict->Dict.get("accountNumber"),
      paymentMethodDataDict->Dict.get("bankName"),
      paymentMethodDataDict->Dict.get("city"),
    ) {
    | (Some(routingNumber), Some(accountNumber), bankName, city) =>
      switch ["routingNumber", "accountNumber", "bankName", "city"]->checkValidity(
        fieldValidityDict,
      ) {
      | false => None
      | true =>
        Some([
          ("bank_routing_number", routingNumber),
          ("bank_account_number", accountNumber),
          ("bank_name", bankName->Option.getOr("")),
          ("bank_city", city->Option.getOr("")),
        ])
      }
    | _ => None
    }

  // Bacs
  | Some(BankTransfer(Bacs)) =>
    switch (
      paymentMethodDataDict->Dict.get("sortCode"),
      paymentMethodDataDict->Dict.get("accountNumber"),
      paymentMethodDataDict->Dict.get("bankName"),
      paymentMethodDataDict->Dict.get("city"),
    ) {
    | (Some(sortCode), Some(accountNumber), bankName, city) =>
      switch ["sortCode", "accountNumber", "bankName", "city"]->checkValidity(fieldValidityDict) {
      | false => None
      | true =>
        Some([
          ("bank_sort_code", sortCode),
          ("bank_account_number", accountNumber),
          ("bank_name", bankName->Option.getOr("")),
          ("bank_city", city->Option.getOr("")),
        ])
      }
    | _ => None
    }

  // Sepa
  | Some(BankTransfer(Sepa)) =>
    switch (
      paymentMethodDataDict->Dict.get("iban"),
      paymentMethodDataDict->Dict.get("bic"),
      paymentMethodDataDict->Dict.get("bankName"),
      paymentMethodDataDict->Dict.get("city"),
      paymentMethodDataDict->Dict.get("countryCode"),
    ) {
    | (Some(iban), Some(bic), bankName, city, countryCode) =>
      switch ["iban", "bic", "bankName", "city", "countryCode"]->checkValidity(fieldValidityDict) {
      | false => None
      | true =>
        Some([
          ("iban", iban),
          ("bic", bic),
          ("bank_name", bankName->Option.getOr("")),
          ("bank_city", city->Option.getOr("")),
          ("bank_country_code", countryCode->Option.getOr("")),
        ])
      }
    | _ => None
    }

  // Wallets
  // PayPal
  | Some(Wallet(Paypal)) =>
    switch paymentMethodDataDict->Dict.get("email") {
    | Some(email) => Some([("email", email)])
    | _ => None
    }
  // TODO: handle Pix and Venmo
  | _ => None
  }
}
