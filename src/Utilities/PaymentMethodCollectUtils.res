open CardUtils
open ErrorUtils
open PaymentMethodCollectTypes
open Utils

type t = Dict.t<JSON.t>

// Function to get a nested value
let getNestedValue = (dict: t, key: string): option<JSON.t> => {
  let keys = String.split(key, ".")
  let length = Array.length(keys)

  let rec traverse = (currentDict, index): option<JSON.t> => {
    if index === length - 1 {
      Dict.get(currentDict, Array.getUnsafe(keys, index))
    } else {
      let keyPart = Array.getUnsafe(keys, index)
      switch Dict.get(currentDict, keyPart) {
      | Some(subDict) =>
        switch JSON.Decode.object(subDict) {
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
  switch Dict.get(dict, key) {
  | Some(subDict) =>
    switch JSON.Decode.object(subDict) {
    | Some(innerDict) => innerDict
    | None => {
        let newSubDict = Dict.make()
        Dict.set(dict, key, JSON.Encode.object(newSubDict))
        newSubDict
      }
    }
  | None => {
      let newSubDict = Dict.make()
      Dict.set(dict, key, JSON.Encode.object(newSubDict))
      newSubDict
    }
  }
}

// Function to set a nested value
let setNestedValue = (dict: t, key: string, value: JSON.t): unit => {
  let keys = String.split(key, ".")
  let rec traverse = (currentDict, index) => {
    if index === Array.length(keys) - 1 {
      Dict.set(currentDict, Array.getUnsafe(keys, index), value)
    } else {
      let keyPart = Array.getUnsafe(keys, index)
      let subDict = getOrCreateSubDict(currentDict, keyPart)
      traverse(subDict, index + 1)
    }
  }

  traverse(dict, 0)
}

let setValue = (dict, key, value): Dict.t<JSON.t> => {
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

let getPaymentMethodForPayoutsConfirm = (paymentMethod: paymentMethod): string => {
  switch paymentMethod {
  | Card => "card"
  | BankTransfer => "bank"
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

let getPaymentMethodLabel = (paymentMethod: paymentMethod): string => {
  switch paymentMethod {
  | Card => "Card"
  | BankTransfer => "Bank"
  | Wallet => "Wallet"
  }
}

let getPaymentMethodTypeLabel = (paymentMethodType: paymentMethodType): string => {
  switch paymentMethodType {
  | Card(cardType) =>
    switch cardType {
    | Credit
    | Debit => "Card"
    }
  | BankTransfer(bankTransferType) =>
    switch bankTransferType {
    | ACH => "ACH"
    | Bacs => "Bacs"
    | Sepa => "SEPA"
    }
  | Wallet(walletType) =>
    switch walletType {
    | Paypal => "PayPal"
    | Pix => "Pix"
    | Venmo => "Venmo"
    }
  }
}

let getPaymentMethodDataFieldKey = (key: paymentMethodDataField): string =>
  switch key {
  | CardNumber => "card.cardNumber"
  | CardExpDate => "card.cardExp"
  | CardHolderName => "card.cardHolder"
  | CardBrand => "card.brand"
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
  | PixBankAccountNumber => "pix.account"
  | PixBankName => "pix.bankName"
  | VenmoMobNumber => "venmo.phoneNumber"
  }

let getPaymentMethodDataFieldLabel = (
  key: paymentMethodDataField,
  localeString: LocaleStringTypes.localeStrings,
): string =>
  switch key {
  | CardNumber => localeString.cardNumberLabel
  | CardExpDate => localeString.validThruText
  | CardHolderName => localeString.cardHolderName
  | ACHRoutingNumber => localeString.formFieldACHRoutingNumberLabel
  | ACHAccountNumber | BacsAccountNumber => localeString.accountNumberText
  | BacsSortCode => localeString.sortCodeText
  | SepaIban => localeString.formFieldSepaIbanLabel
  | SepaBic => localeString.formFieldSepaBicLabel
  | PixId => localeString.formFieldPixIdLabel
  | PixBankAccountNumber => localeString.formFieldBankAccountNumberLabel
  | PaypalMail => localeString.emailLabel
  | PaypalMobNumber | VenmoMobNumber => localeString.formFieldPhoneNumberLabel
  | SepaCountryCode => localeString.formFieldCountryCodeLabel
  | ACHBankName
  | BacsBankName
  | PixBankName
  | SepaBankName =>
    localeString.formFieldBankNameLabel
  | ACHBankCity
  | BacsBankCity
  | SepaBankCity =>
    localeString.formFieldBankCityLabel
  | CardBrand => "Misc."
  }

let getPaymentMethodDataFieldPlaceholder = (
  key: paymentMethodDataField,
  locale: LocaleStringTypes.localeStrings,
  constant: LocaleStringTypes.constantStrings,
): string => {
  switch key {
  | CardNumber => constant.formFieldCardNumberPlaceholder
  | CardExpDate => locale.expiryPlaceholder
  | CardHolderName => locale.formFieldCardHoldernamePlaceholder
  | ACHRoutingNumber => constant.formFieldACHRoutingNumberPlaceholder
  | ACHAccountNumber => constant.formFieldAccountNumberPlaceholder
  | BacsSortCode => constant.formFieldSortCodePlaceholder
  | BacsAccountNumber => constant.formFieldAccountNumberPlaceholder
  | SepaIban => constant.formFieldSepaIbanPlaceholder
  | SepaBic => constant.formFieldSepaBicPlaceholder
  | SepaCountryCode => locale.countryLabel
  | PixId => constant.formFieldPixIdPlaceholder
  | PixBankAccountNumber => constant.formFieldBankAccountNumberPlaceholder
  | ACHBankName
  | BacsBankName
  | PixBankName
  | SepaBankName =>
    locale.formFieldBankNamePlaceholder
  | ACHBankCity
  | BacsBankCity
  | SepaBankCity =>
    locale.formFieldBankCityPlaceholder
  | PaypalMail => locale.formFieldEmailPlaceholder
  | PaypalMobNumber | VenmoMobNumber => locale.formFieldPhoneNumberPlaceholder
  | CardBrand => "Misc."
  }
}

let getPaymentMethodDataFieldMaxLength = (key: paymentMethodDataField): int =>
  switch key {
  | CardNumber => 23
  | CardExpDate => 7
  | ACHRoutingNumber => 9
  | ACHAccountNumber => 12
  | BacsSortCode => 6
  | BacsAccountNumber => 18
  | SepaBic => 8
  | SepaIban => 34
  | _ => 32
  }

let getPaymentMethodDataFieldCharacterPattern = (key: paymentMethodDataField): option<Js.Re.t> =>
  switch key {
  | ACHAccountNumber => Some(%re("/^\d{1,17}$/"))
  | ACHRoutingNumber => Some(%re("/^\d{1,9}$/"))
  | BacsAccountNumber => Some(%re("/^\d{1,18}$/"))
  | BacsSortCode => Some(%re("/^\d{1,6}$/"))
  | CardHolderName => Some(%re("/^([a-zA-Z]| ){1,32}$/"))
  | CardNumber => Some(%re("/^\d{1,18}$/"))
  | PaypalMail => Some(%re("/^[a-zA-Z0-9._%+-]*[a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]*$/"))
  | PaypalMobNumber => Some(%re("/^[0-9]{1,12}$/"))
  | SepaBic => Some(%re("/^([A-Z0-9]| ){1,8}$/"))
  | SepaIban => Some(%re("/^([A-Z0-9]| ){1,34}$/"))
  | _ => None
  }

let getPaymentMethodDataFieldInputType = (key: paymentMethodDataField): string =>
  switch key {
  | ACHAccountNumber => "tel"
  | ACHRoutingNumber => "tel"
  | BacsAccountNumber => "tel"
  | BacsSortCode => "tel"
  | CardExpDate => "tel"
  | CardNumber => "tel"
  | PaypalMail => "email"
  | PaypalMobNumber => "tel"
  | VenmoMobNumber => "tel"
  | _ => "text"
  }

let getPayoutImageSource = (payoutStatus: payoutStatus): string => {
  switch payoutStatus {
  | Success => "https://live.hyperswitch.io/payment-link-assets/success.png"
  | Initiated
  | Pending
  | RequiresFulfillment => "https://live.hyperswitch.io/payment-link-assets/pending.png"
  | Cancelled
  | Failed
  | Ineligible
  | Expired
  | RequiresCreation
  | Reversed
  | RequiresConfirmation
  | RequiresPayoutMethodData
  | RequiresVendorAccountCreation => "https://live.hyperswitch.io/payment-link-assets/failed.png"
  }
}

let getPayoutReadableStatus = (
  payoutStatus: payoutStatus,
  localeString: LocaleStringTypes.localeStrings,
): string =>
  switch payoutStatus {
  | Success => localeString.payoutStatusSuccessText
  | Initiated
  | Pending
  | RequiresFulfillment =>
    localeString.payoutStatusPendingText
  | Cancelled
  | Failed
  | Ineligible
  | Expired
  | RequiresCreation
  | Reversed
  | RequiresConfirmation
  | RequiresPayoutMethodData
  | RequiresVendorAccountCreation =>
    localeString.payoutStatusFailedText
  }

let getPayoutStatusString = (payoutStatus: payoutStatus): string =>
  switch payoutStatus {
  | Success => "success"
  | Initiated => "initiated"
  | Pending => "pending"
  | RequiresFulfillment => "requires_fulfillment"
  | Cancelled => "expired"
  | Failed => "failed"
  | Ineligible => "ineligible"
  | Expired => "cancelled"
  | RequiresCreation => "requires_creation"
  | Reversed => "reversed"
  | RequiresConfirmation => "requires_confirmation"
  | RequiresPayoutMethodData => "requires_payout_method_data"
  | RequiresVendorAccountCreation => "requires_vendor_account_creation"
  }

let getPayoutStatusMessage = (
  payoutStatus: payoutStatus,
  localeString: LocaleStringTypes.localeStrings,
): string =>
  switch payoutStatus {
  | Success => localeString.payoutStatusSuccessMessage
  | Initiated
  | Pending
  | RequiresFulfillment =>
    localeString.payoutStatusPendingMessage
  | Cancelled
  | Failed
  | Ineligible
  | Expired
  | RequiresCreation
  | Reversed
  | RequiresConfirmation
  | RequiresPayoutMethodData
  | RequiresVendorAccountCreation =>
    localeString.payoutStatusFailedMessage
  }

let getPaymentMethodDataErrorString = (
  key: paymentMethodDataField,
  value,
  localeString: LocaleStringTypes.localeStrings,
): string => {
  let len = value->String.length
  let notEmptyAndComplete = len <= 0 || len === key->getPaymentMethodDataFieldMaxLength
  switch (key, notEmptyAndComplete) {
  | (CardNumber, _) => localeString.inValidCardErrorText
  | (CardExpDate, false) => localeString.inCompleteExpiryErrorText
  | (CardExpDate, true) => localeString.pastExpiryErrorText
  | (ACHRoutingNumber, false) => localeString.formFieldInvalidRoutingNumber
  | _ => ""
  }
}

let getPaymentMethodIcon = (paymentMethod: paymentMethod) =>
  switch paymentMethod {
  | Card => <Icon name="default-card" size=20 />
  | BankTransfer => <Icon name="bank" size=20 />
  | Wallet => <Icon name="wallet-generic-line" size=20 />
  }

let getBankTransferIcon = (bankTransfer: bankTransfer) =>
  switch bankTransfer {
  | ACH => <Icon name="ach_bank_transfer" size=20 />
  | Bacs => <Icon name="bank" size=20 />
  | Sepa => <Icon name="bank" size=20 />
  }

let getWalletIcon = (wallet: wallet) =>
  switch wallet {
  | Paypal => <Icon name="wallet-paypal" size=20 />
  | Pix => <Icon name="wallet-pix" size=20 />
  | Venmo => <Icon name="wallet-venmo" size=20 />
  }

let getPaymentMethodTypeIcon = (paymentMethodType: paymentMethodType) =>
  switch paymentMethodType {
  | Card(_) => Card->getPaymentMethodIcon
  | BankTransfer(b) => b->getBankTransferIcon
  | Wallet(w) => w->getWalletIcon
  }

// Defaults
let defaultFormLayout: formLayout = Tabs
let defaultPaymentMethodCollectFlow: paymentMethodCollectFlow = PayoutLinkInitiate
let defaultAmount = "0.01"
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
  payoutId: "",
  customerId: "",
  theme: "#1A1A1A",
  collectorName: "HyperSwitch",
  logo: "",
  returnUrl: None,
  amount: defaultAmount,
  currency: defaultCurrency,
  flow: defaultPaymentMethodCollectFlow,
  sessionExpiry: "",
  formLayout: defaultFormLayout,
}
let defaultOptionsLimitInTabLayout = 2
let defaultAvailablePaymentMethods: array<paymentMethod> = []
let defaultAvailablePaymentMethodTypes: array<paymentMethodType> = []
let defaultSelectedPaymentMethod: option<paymentMethod> = None
let defaultSelectedPaymentMethodType: option<paymentMethodType> = None
let defaultStatusInfo = {
  status: Success,
  payoutId: "",
  message: EnglishLocale.localeStrings.payoutStatusSuccessMessage,
  code: None,
  errorMessage: None,
  reason: None,
}

let itemToObjMapper = (dict, logger) => {
  unknownKeysWarning(
    [
      "enabledPaymentMethods",
      "linkId",
      "payoutId",
      "customerId",
      "theme",
      "collectorName",
      "logo",
      "returnUrl",
      "amount",
      "currency",
      "flow",
      "sessionExpiry",
      "formLayout",
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
    payoutId: getString(dict, "payoutId", ""),
    customerId: getString(dict, "customerId", ""),
    theme: getString(dict, "theme", ""),
    collectorName: getString(dict, "collectorName", ""),
    logo: getString(dict, "logo", ""),
    returnUrl: dict->Dict.get("returnUrl")->Option.flatMap(JSON.Decode.string),
    amount: dict->decodeAmount(defaultAmount),
    currency: getString(dict, "currency", defaultCurrency),
    flow: dict->decodeFlow(defaultPaymentMethodCollectFlow),
    sessionExpiry: getString(dict, "sessionExpiry", ""),
    formLayout: dict->decodeFormLayout(defaultFormLayout),
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
        value->String.charAt(0)->Int.fromString,
        value->String.charAt(3)->Int.fromString,
        value->String.charAt(6)->Int.fromString,
      ) {
      | (Some(a), Some(b), Some(c)) => Some(3 * (a + b + c))
      | _ => None
      }

      let p2 = switch (
        value->String.charAt(1)->Int.fromString,
        value->String.charAt(4)->Int.fromString,
        value->String.charAt(7)->Int.fromString,
      ) {
      | (Some(a), Some(b), Some(c)) => Some(7 * (a + b + c))
      | _ => None
      }

      let p3 = switch (
        value->String.charAt(2)->Int.fromString,
        value->String.charAt(5)->Int.fromString,
        value->String.charAt(8)->Int.fromString,
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

let formPaymentMethodData = (
  paymentMethodType: option<paymentMethodType>,
  paymentMethodDataDict,
  fieldValidityDict,
): option<paymentMethodData> => {
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
      | true =>
        Some((
          Card,
          Card(Debit),
          [(CardHolderName, nameOnCard), (CardNumber, cardNumber), (CardExpDate, expiryDate)],
        ))
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
        let pmd = [(ACHRoutingNumber, routingNumber), (ACHAccountNumber, accountNumber)]
        bankName->Option.forEach(bankName => pmd->Array.push((ACHBankName, bankName)))
        city->Option.forEach(city => pmd->Array.push((ACHBankCity, city)))
        Some(BankTransfer, BankTransfer(ACH), pmd)
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
        let pmd = [(BacsSortCode, sortCode), (BacsAccountNumber, accountNumber)]
        bankName->Option.forEach(bankName => pmd->Array.push((BacsBankName, bankName)))
        city->Option.forEach(city => pmd->Array.push((BacsBankCity, city)))
        Some(BankTransfer, BankTransfer(Bacs), pmd)
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
    | (Some(iban), bic, bankName, city, countryCode) =>
      switch [
        SepaIban->getPaymentMethodDataFieldKey,
        SepaBic->getPaymentMethodDataFieldKey,
        SepaBankName->getPaymentMethodDataFieldKey,
        SepaBankCity->getPaymentMethodDataFieldKey,
        SepaCountryCode->getPaymentMethodDataFieldKey,
      ]->checkValidity(fieldValidityDict) {
      | false => None
      | true =>
        let pmd = [(SepaIban, iban)]
        bic->Option.forEach(bic => pmd->Array.push((SepaBic, bic)))
        bankName->Option.forEach(bankName => pmd->Array.push((SepaBankName, bankName)))
        city->Option.forEach(city => pmd->Array.push((SepaBankCity, city)))
        countryCode->Option.forEach(countryCode => pmd->Array.push((SepaCountryCode, countryCode)))
        Some(BankTransfer, BankTransfer(Sepa), pmd)
      }
    | _ => None
    }

  // Wallets
  // PayPal
  | Some(Wallet(Paypal)) =>
    switch paymentMethodDataDict->getValue(PaypalMail->getPaymentMethodDataFieldKey) {
    | Some(email) => Some(Wallet, Wallet(Paypal), [(PaypalMail, email)])
    | _ => None
    }
  // TODO: handle Pix and Venmo
  | _ => None
  }
}

let formBody = (flow: paymentMethodCollectFlow, paymentMethodData: paymentMethodData) => {
  let (paymentMethod, paymentMethodType, fields) = paymentMethodData
  let pmdApiFields = []

  fields->Array.forEach(field => {
    let (key, value) = field
    switch key {
    // Card
    | CardHolderName => pmdApiFields->Array.push(("card_holder_name", value))
    | CardNumber => pmdApiFields->Array.push(("card_number", value))
    | CardExpDate => {
        let split = value->String.split("/")
        switch (split->Array.get(0), split->Array.get(1)) {
        | (Some(month), Some(year)) => {
            pmdApiFields->Array.push(("expiry_month", month))
            pmdApiFields->Array.push(("expiry_year", `20${year}`))
          }
        | _ => ()
        }
      }

    // Banks
    | ACHRoutingNumber => pmdApiFields->Array.push(("bank_routing_number", value))
    | ACHAccountNumber | BacsAccountNumber | PixBankAccountNumber =>
      pmdApiFields->Array.push(("bank_account_number", value))
    | ACHBankName | BacsBankName | PixBankName | SepaBankName =>
      pmdApiFields->Array.push(("bank_name", value))
    | ACHBankCity | BacsBankCity | SepaBankCity => pmdApiFields->Array.push(("bank_city", value))
    | BacsSortCode => pmdApiFields->Array.push(("bank_sort_code", value))
    | PixId => pmdApiFields->Array.push(("pix_key", value))
    | SepaIban => pmdApiFields->Array.push(("iban", value))
    | SepaBic => pmdApiFields->Array.push(("bic", value))
    | SepaCountryCode => pmdApiFields->Array.push(("bank_country_code", value))

    // Wallets
    | PaypalMail => pmdApiFields->Array.push(("email", value))
    | PaypalMobNumber | VenmoMobNumber => pmdApiFields->Array.push(("telephone_number", value))

    // Misc.
    | CardBrand => pmdApiFields->Array.push(("card_brand", value))
    }
  })

  let paymentMethod = paymentMethod->switch flow {
  | PayoutLinkInitiate => getPaymentMethodForPayoutsConfirm
  | PayoutMethodCollect => getPaymentMethod
  }
  let pmdBody =
    pmdApiFields
    ->Array.map(((k, v)) => (k, v->JSON.Encode.string))
    ->getJsonFromArrayOfJson

  let body: array<(string, JSON.t)> = []

  switch flow {
  | PayoutMethodCollect => {
      body->Array.push(("payment_method", paymentMethod->JSON.Encode.string))
      body->Array.push((
        "payment_method_type",
        paymentMethodType->getPaymentMethodType->JSON.Encode.string,
      ))
      body->Array.push((paymentMethod, pmdBody))
    }
  | PayoutLinkInitiate => {
      let pmd = Dict.make()
      pmd->Dict.set(paymentMethod, pmdBody)
      let pmd = pmd->JSON.Encode.object
      body->Array.push(("payout_type", paymentMethod->JSON.Encode.string))
      body->Array.push(("payout_method_data", pmd))
    }
  }

  body
}
