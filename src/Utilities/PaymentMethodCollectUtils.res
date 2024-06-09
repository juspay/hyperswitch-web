open CardUtils
open ErrorUtils
open PaymentMethodCollectTypes
open Utils

type t = Js.Dict.t<Js.Json.t>

// Function to get a nested value
let getNestedValue = (dict: t, key: string): option<Js.Json.t> => {
  let keys = "."->Js.String.split(key)
  let length = Array.length(keys)

  let rec traverse = (currentDict, index): option<Js.Json.t> => {
    if index === length - 1 {
      Js.Dict.get(currentDict, Array.getUnsafe(keys, index))
    } else {
      let keyPart = Array.getUnsafe(keys, index)
      switch Js.Dict.get(currentDict, keyPart) {
      | Some(subDict) =>
        switch Js.Json.decodeObject(subDict) {
        | Some(innerDict) => traverse(innerDict, index + 1)
        | None => None
        }
      | None => None
      }
    }
  }

  traverse(dict, 0)
}

// Helper function to get or create a sub-dictionary
let getOrCreateSubDict = (dict: t, key: string): t => {
  switch Js.Dict.get(dict, key) {
  | Some(subDict) =>
    switch Js.Json.decodeObject(subDict) {
    | Some(innerDict) => innerDict
    | None => {
        let newSubDict = Js.Dict.empty()
        Js.Dict.set(dict, key, Js.Json.object_(newSubDict))
        newSubDict
      }
    }
  | None => {
      let newSubDict = Js.Dict.empty()
      Js.Dict.set(dict, key, Js.Json.object_(newSubDict))
      newSubDict
    }
  }
}

// Function to set a nested value
let setNestedValue = (dict: t, key: string, value: Js.Json.t): unit => {
  let keys = "."->Js.String.split(key)
  let length = Array.length(keys)
  let rec traverse = (currentDict, index) => {
    if index === length - 1 {
      Js.Dict.set(currentDict, Array.getUnsafe(keys, index), value)
    } else {
      let keyPart = Array.getUnsafe(keys, index)
      let subDict = getOrCreateSubDict(currentDict, keyPart)
      traverse(subDict, index + 1)
    }
  }

  traverse(dict, 0)
}

let setValue = (dict, key, value): Js.Dict.t<Js.Json.t> => {
  let pmdCopy = Dict.copy(dict)
  pmdCopy->setNestedValue(key, value->JSON.Encode.string)
  pmdCopy
}

let getValue = (dict, key) =>
  dict
  ->getNestedValue(key)
  ->Option.flatMap(JSON.Decode.string)

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

let getPaymentMethodDataFieldKey = (key: paymentMethodDataField): string =>
  switch key {
  | CardNumber => "card.cardNumber"
  | CardExpDate => "card.cardExp"
  | CardHolderName => "card.cardHolder"
  | ACHRoutingNumber => "ach.routing"
  | ACHAccountNumber => "ach.account"
  | ACHBankName => "ach.bankName"
  | ACHBankCity => "ach.bankCity"
  | BacsSortCode => "bacs.sort"
  | BacsAccountNumber => "bacs.account"
  | BacsBankName => "bacs.bankName"
  | BacsBankCity => "bacs.bankCity"
  | SepaIban => "sepa.iban"
  | SepaBic => "sepa.bic"
  | SepaBankName => "sepa.bankName"
  | SepaBankCity => "sepa.bankCity"
  | SepaCountryCode => "sepa.countryCode"
  | PaypalMail => "paypal.email"
  | PaypalMobNumber => "paypal.phoneNumber"
  | PixId => "pix.id"
  | VenmoMail => "venmo.email"
  | VenmoMobNumber => "venmo.phoneNumber"
  }

let getPaymentMethodDataFieldLabel = (key: paymentMethodDataField): string =>
  switch key {
  | CardNumber => "Card Number"
  | CardExpDate => "Expiry Date"
  | CardHolderName => "Cardholder Name"
  | ACHRoutingNumber => "Routing Number"
  | ACHAccountNumber | BacsAccountNumber => "Account Number"
  | BacsSortCode => "Sort Code"
  | SepaIban => "International Bank Account Number (IBAN)"
  | SepaBic => "Bank Identifier Code (BIC)"
  | PixId => "Pix ID"

  | PaypalMail | VenmoMail => "Email"
  | PaypalMobNumber | VenmoMobNumber => "Phone Number"

  | SepaCountryCode => "Country Code (Optional)"

  | ACHBankName
  | BacsBankName
  | SepaBankName => "Bank Name (Optional)"

  | ACHBankCity
  | BacsBankCity
  | SepaBankCity => "Bank City (Optional)"
  }

let getPaymentMethodDataFieldPlaceholder = (key: paymentMethodDataField): string =>
  switch key {
  | CardNumber => "****** 4242"
  | CardExpDate => "MM / YY"
  | CardHolderName => "Your Name"
  | ACHRoutingNumber => "110000000"
  | ACHAccountNumber => "**** 6789"
  | BacsSortCode => "11000"
  | BacsAccountNumber => "**** 1822"
  | SepaIban => "NL **** 6789"
  | SepaBic => "ABNANL2A"
  | SepaCountryCode => "Country"
  | PixId => "**** 3251"

  | BacsBankName
  | SepaBankName => "Bank Name"

  | ACHBankName
  | ACHBankCity
  | BacsBankCity
  | SepaBankCity => "Bank City"

  | PaypalMail | VenmoMail => "Your Email"
  | PaypalMobNumber | VenmoMobNumber => "Your Phone"
  }

let getPaymentMethodDataFieldMaxLength = (key: paymentMethodDataField): int =>
  switch key {
  | CardNumber => 18
  | CardExpDate => 7
  | ACHRoutingNumber => 9
  | ACHAccountNumber => 12
  | BacsSortCode => 5
  | BacsAccountNumber => 8
  | SepaIban => 18
  | SepaBic => 8
  | _ => 32
  }

// Defaults
let defaultPaymentMethodCollectFlow: paymentMethodCollectFlow = PayoutLinkInitiate
let defaultAmount = 100
let defaultCurrency = "EUR"

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
  amount: defaultAmount,
  currency: defaultCurrency,
  flow: defaultPaymentMethodCollectFlow,
}

let defaultAvailablePaymentMethods: array<paymentMethod> = []
let defaultAvailablePaymentMethodTypes = {
  card: [],
  bankTransfer: [],
  wallet: [],
}
let defaultSelectedPaymentMethod: option<paymentMethod> = None
let defaultSelectedPaymentMethodType: option<paymentMethodType> = None

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
      "amount",
      "currency",
      "flow",
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
    amount: dict->decodeAmount(defaultAmount),
    currency: getString(dict, "currency", defaultCurrency),
    flow: dict->decodeFlow(defaultPaymentMethodCollectFlow),
  }
}

let calculateValidity = (dict, key) => {
  let value =
    dict
    ->getValue(key->getPaymentMethodDataFieldKey)
    ->Option.getOr("")

  switch key {
  | CardNumber =>
    if cardNumberInRange(value)->Array.includes(true) && calculateLuhn(value) {
      Some(true)
    } else if value->String.length == 0 {
      None
    } else {
      Some(false)
    }
  | CardExpDate =>
    if value->String.length > 0 && getExpiryValidity(value) {
      Some(true)
    } else if value->String.length == 0 {
      None
    } else {
      Some(false)
    }
  | ACHRoutingNumber =>
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
      Some(false)
    }
  | _ => None
  }
}

let checkValidity = (keys, fieldValidityDict) => {
  keys->Array.reduce(true, (acc, key) => {
    switch fieldValidityDict->Dict.get(key) {
    | Some(validity) => acc && validity->Option.getOr(true)
    | None => acc
    }
  })
}

let formCreatePaymentMethodRequestBody = (
  paymentMethodType: option<paymentMethodType>,
  paymentMethodDataDict,
  fieldValidityDict,
) => {
  Js.Console.log3("DEBUGG", fieldValidityDict, paymentMethodDataDict)
  switch paymentMethodType {
  | None => None
  // Card
  | Some(Card(_)) =>
    switch (
      paymentMethodDataDict->getValue(CardHolderName->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(CardNumber->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(CardExpDate->getPaymentMethodDataFieldKey),
    ) {
    | (Some(nameOnCard), Some(cardNumber), Some(expiryDate)) =>
      switch [
        CardHolderName->getPaymentMethodDataFieldKey,
        CardNumber->getPaymentMethodDataFieldKey,
        CardExpDate->getPaymentMethodDataFieldKey,
      ]->checkValidity(fieldValidityDict) {
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
      paymentMethodDataDict->getValue(ACHRoutingNumber->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(ACHAccountNumber->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(ACHBankName->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(ACHBankCity->getPaymentMethodDataFieldKey),
    ) {
    | (Some(routingNumber), Some(accountNumber), bankName, city) =>
      switch [
        ACHRoutingNumber->getPaymentMethodDataFieldKey,
        ACHAccountNumber->getPaymentMethodDataFieldKey,
        ACHBankName->getPaymentMethodDataFieldKey,
        ACHBankCity->getPaymentMethodDataFieldKey,
      ]->checkValidity(fieldValidityDict) {
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
      paymentMethodDataDict->getValue(BacsSortCode->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(BacsAccountNumber->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(BacsBankName->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(BacsBankCity->getPaymentMethodDataFieldKey),
    ) {
    | (Some(sortCode), Some(accountNumber), bankName, city) =>
      switch [
        BacsSortCode->getPaymentMethodDataFieldKey,
        BacsAccountNumber->getPaymentMethodDataFieldKey,
        BacsBankName->getPaymentMethodDataFieldKey,
        BacsBankCity->getPaymentMethodDataFieldKey,
      ]->checkValidity(fieldValidityDict) {
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
      paymentMethodDataDict->getValue(SepaIban->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(SepaBic->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(SepaBankName->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(SepaBankCity->getPaymentMethodDataFieldKey),
      paymentMethodDataDict->getValue(SepaCountryCode->getPaymentMethodDataFieldKey),
    ) {
    | (Some(iban), Some(bic), bankName, city, countryCode) =>
      switch [
        SepaIban->getPaymentMethodDataFieldKey,
        SepaBic->getPaymentMethodDataFieldKey,
        SepaBankName->getPaymentMethodDataFieldKey,
        SepaBankCity->getPaymentMethodDataFieldKey,
        SepaCountryCode->getPaymentMethodDataFieldKey,
      ]->checkValidity(fieldValidityDict) {
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
    switch paymentMethodDataDict->getValue(PaypalMail->getPaymentMethodDataFieldKey) {
    | Some(email) => Some([("email", email)])
    | _ => None
    }
  // TODO: handle Pix and Venmo
  | _ => None
  }
}
