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

let getPaymentMethodForPmt = (paymentMethodType: paymentMethodType): paymentMethod => {
  switch paymentMethodType {
  | Card(_) => Card
  | BankRedirect(_) => BankRedirect
  | BankTransfer(_) => BankTransfer
  | Wallet(_) => Wallet
  }
}

let getPaymentMethod = (paymentMethod: paymentMethod): string => {
  switch paymentMethod {
  | Card => "card"
  | BankRedirect => "bank_redirect"
  | BankTransfer => "bank_transfer"
  | Wallet => "wallet"
  }
}

let getPaymentMethodForPayoutsConfirm = (paymentMethod: paymentMethod): string => {
  switch paymentMethod {
  | Card => "card"
  | BankRedirect => "bank_redirect"
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
    | Pix => "pix"
    | Sepa => "sepa_bank_transfer"
    }
  | Wallet(walletType) =>
    switch walletType {
    | Paypal => "paypal"
    | Venmo => "venmo"
    }
  | BankRedirect(bankRedirectType) =>
    switch bankRedirectType {
    | Interac => "interac"
    }
  }
}

let getPaymentMethodLabel = (paymentMethod: paymentMethod): string => {
  switch paymentMethod {
  | Card => "Card"
  | BankRedirect
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
    | Bacs => "BACS"
    | Pix => "Pix"
    | Sepa => "SEPA"
    }
  | Wallet(walletType) =>
    switch walletType {
    | Paypal => "PayPal"
    | Venmo => "Venmo"
    }
  | BankRedirect(bankRedirectType) =>
    switch bankRedirectType {
    | Interac => "Interac"
    }
  }
}

let getPaymentMethodDataFieldKey = (key): string =>
  switch key {
  | PayoutMethodData(p) =>
    switch p {
    | CardNumber => "card.cardNumber"
    | CardExpDate(_) => "card.cardExp"
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
    | PixKey => "pix.key"
    | PixBankAccountNumber => "pix.account"
    | PixBankName => "pix.bankName"
    | VenmoMobNumber => "venmo.phoneNumber"
    | InteracEmail => "interac.email"
    }
  | BillingAddress(b) =>
    switch b {
    | Email => "billing.address.email"
    | FullName(FirstName) => "billing.address.firstName"
    | FullName(LastName) => "billing.address.lastName"
    | CountryCode => "billing.address.countryCode"
    | PhoneNumber => "billing.address.phoneNumber"
    | PhoneCountryCode => "billing.address.phoneCountryCode"
    | AddressLine1 => "billing.address.addressLine1"
    | AddressLine2 => "billing.address.addressLine2"
    | AddressCity => "billing.address.addressCity"
    | AddressState => "billing.address.addressState"
    | AddressPincode => "billing.address.addressPincode"
    | AddressCountry(_) => "billing.address.addressCountry"
    }
  }

let getPaymentMethodDataFieldLabel = (key, localeString: LocaleStringTypes.localeStrings): string =>
  switch key {
  | PayoutMethodData(CardNumber) => localeString.cardNumberLabel
  | PayoutMethodData(CardExpDate(_)) => localeString.validThruText
  | PayoutMethodData(CardHolderName) => localeString.cardHolderName
  | PayoutMethodData(ACHRoutingNumber) => localeString.formFieldACHRoutingNumberLabel
  | PayoutMethodData(ACHAccountNumber) | PayoutMethodData(BacsAccountNumber) =>
    localeString.accountNumberText
  | PayoutMethodData(BacsSortCode) => localeString.sortCodeText
  | PayoutMethodData(SepaIban) => localeString.formFieldSepaIbanLabel
  | PayoutMethodData(SepaBic) => localeString.formFieldSepaBicLabel
  | PayoutMethodData(PixKey) => localeString.formFieldPixIdLabel
  | PayoutMethodData(PixBankAccountNumber) => localeString.formFieldBankAccountNumberLabel
  | PayoutMethodData(InteracEmail)
  | PayoutMethodData(PaypalMail) =>
    localeString.emailLabel
  | PayoutMethodData(PaypalMobNumber) | PayoutMethodData(VenmoMobNumber) =>
    localeString.formFieldPhoneNumberLabel
  | PayoutMethodData(SepaCountryCode) => localeString.formFieldCountryCodeLabel
  | PayoutMethodData(ACHBankName)
  | PayoutMethodData(BacsBankName)
  | PayoutMethodData(PixBankName)
  | PayoutMethodData(SepaBankName) =>
    localeString.formFieldBankNameLabel
  | PayoutMethodData(ACHBankCity)
  | PayoutMethodData(BacsBankCity)
  | PayoutMethodData(SepaBankCity) =>
    localeString.formFieldBankCityLabel
  | PayoutMethodData(CardBrand) => "Misc."

  // Address details
  | BillingAddress(Email) => localeString.emailLabel
  | BillingAddress(FullName(_)) => localeString.fullNameLabel
  | BillingAddress(CountryCode) => localeString.formFieldCountryCodeRequiredLabel
  | BillingAddress(PhoneNumber) => localeString.formFieldPhoneNumberLabel
  | BillingAddress(PhoneCountryCode) => localeString.formFieldCountryCodeRequiredLabel
  | BillingAddress(AddressLine1) => localeString.line1Label
  | BillingAddress(AddressLine2) => localeString.line2Label
  | BillingAddress(AddressCity) => localeString.cityLabel
  | BillingAddress(AddressState) => localeString.stateLabel
  | BillingAddress(AddressPincode) => localeString.postalCodeLabel
  | BillingAddress(AddressCountry(_)) => localeString.countryLabel
  }

let getPaymentMethodDataFieldPlaceholder = (
  key,
  locale: LocaleStringTypes.localeStrings,
  constant: LocaleStringTypes.constantStrings,
): string => {
  switch key {
  | PayoutMethodData(CardNumber) => constant.formFieldCardNumberPlaceholder
  | PayoutMethodData(CardExpDate(_)) => locale.expiryPlaceholder
  | PayoutMethodData(CardHolderName) => locale.formFieldCardHoldernamePlaceholder
  | PayoutMethodData(ACHRoutingNumber) => constant.formFieldACHRoutingNumberPlaceholder
  | PayoutMethodData(ACHAccountNumber) => constant.formFieldAccountNumberPlaceholder
  | PayoutMethodData(BacsSortCode) => constant.formFieldSortCodePlaceholder
  | PayoutMethodData(BacsAccountNumber) => constant.formFieldAccountNumberPlaceholder
  | PayoutMethodData(SepaIban) => constant.formFieldSepaIbanPlaceholder
  | PayoutMethodData(SepaBic) => constant.formFieldSepaBicPlaceholder
  | PayoutMethodData(SepaCountryCode) => locale.countryLabel
  | PayoutMethodData(PixKey) => constant.formFieldPixIdPlaceholder
  | PayoutMethodData(PixBankAccountNumber) => constant.formFieldBankAccountNumberPlaceholder
  | PayoutMethodData(ACHBankName)
  | PayoutMethodData(BacsBankName)
  | PayoutMethodData(PixBankName)
  | PayoutMethodData(SepaBankName) =>
    locale.formFieldBankNamePlaceholder
  | PayoutMethodData(ACHBankCity)
  | PayoutMethodData(BacsBankCity)
  | PayoutMethodData(SepaBankCity) =>
    locale.formFieldBankCityPlaceholder
  | PayoutMethodData(InteracEmail)
  | PayoutMethodData(PaypalMail) =>
    locale.formFieldEmailPlaceholder
  | PayoutMethodData(PaypalMobNumber) | PayoutMethodData(VenmoMobNumber) =>
    locale.formFieldPhoneNumberPlaceholder
  | PayoutMethodData(CardBrand) => "Misc."
  | BillingAddress(AddressCity) => locale.cityLabel
  | BillingAddress(AddressPincode) => locale.postalCodeLabel
  | BillingAddress(AddressLine1) => locale.line1Placeholder
  | BillingAddress(AddressLine2) => locale.line2Placeholder
  | BillingAddress(AddressState) => locale.stateLabel
  | BillingAddress(CountryCode) => locale.formFieldCountryCodeRequiredLabel
  | BillingAddress(FullName(_)) => locale.fullNamePlaceholder
  | BillingAddress(AddressCountry(_)) => locale.countryLabel
  | BillingAddress(PhoneNumber) => locale.formFieldPhoneNumberPlaceholder
  | BillingAddress(PhoneCountryCode) => locale.formFieldCountryCodeRequiredLabel
  | BillingAddress(Email) => locale.formFieldEmailPlaceholder
  }
}

let getPaymentMethodDataFieldMaxLength = (key): int =>
  switch key {
  | PayoutMethodData(CardNumber) => 23
  | PayoutMethodData(CardExpDate(_)) => 7
  | PayoutMethodData(ACHRoutingNumber) => 9
  | PayoutMethodData(ACHAccountNumber) => 17
  | PayoutMethodData(BacsSortCode) => 6
  | PayoutMethodData(BacsAccountNumber) => 18
  | PayoutMethodData(SepaBic) => 11
  | PayoutMethodData(SepaIban) => 34
  | _ => 32
  }

let getPaymentMethodDataFieldCharacterPattern = (key): option<Js.Re.t> =>
  switch key {
  | PayoutMethodData(ACHAccountNumber) => Some(%re("/^\d{1,17}$/"))
  | PayoutMethodData(ACHRoutingNumber) => Some(%re("/^\d{1,9}$/"))
  | PayoutMethodData(BacsAccountNumber) => Some(%re("/^\d{1,18}$/"))
  | PayoutMethodData(BacsSortCode) => Some(%re("/^\d{1,6}$/"))
  | PayoutMethodData(CardHolderName) => Some(%re("/^([a-zA-Z]| ){1,32}$/"))
  | PayoutMethodData(CardNumber) => Some(%re("/^\d{1,18}$/"))
  | PayoutMethodData(PaypalMobNumber) => Some(%re("/^[0-9]{1,12}$/"))
  | PayoutMethodData(SepaBic) => Some(%re("/^([A-Z0-9]| ){1,11}$/"))
  | PayoutMethodData(SepaIban) => Some(%re("/^([A-Z0-9]| ){1,34}$/"))
  | BillingAddress(AddressPincode) => Some(%re("/^([0-9A-Z]| ){1,10}$/"))
  | BillingAddress(PhoneNumber) => Some(%re("/^[0-9]{1,12}$/"))
  | BillingAddress(PhoneCountryCode) => Some(%re("/^[0-9]{1,3}$/"))
  | _ => None
  }

let getPaymentMethodDataFieldInputType = (key): string =>
  switch key {
  | PayoutMethodData(InteracEmail)
  | PayoutMethodData(PaypalMail) => "email"
  | PayoutMethodData(ACHAccountNumber)
  | PayoutMethodData(ACHRoutingNumber)
  | PayoutMethodData(BacsAccountNumber)
  | PayoutMethodData(BacsSortCode)
  | PayoutMethodData(CardExpDate(_))
  | PayoutMethodData(CardNumber)
  | PayoutMethodData(PaypalMobNumber)
  | PayoutMethodData(VenmoMobNumber) => "tel"
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
  key,
  value,
  localeString: LocaleStringTypes.localeStrings,
): string => {
  let len = value->String.length
  let notEmptyAndComplete = len >= 0 && len === key->getPaymentMethodDataFieldMaxLength
  switch (key, notEmptyAndComplete) {
  | (PayoutMethodData(CardNumber), _) => localeString.inValidCardErrorText
  | (PayoutMethodData(CardExpDate(_)), false) => localeString.inCompleteExpiryErrorText
  | (PayoutMethodData(CardExpDate(_)), true) => localeString.pastExpiryErrorText
  | (PayoutMethodData(ACHRoutingNumber), false) => localeString.formFieldInvalidRoutingNumber
  | (PayoutMethodData(ACHAccountNumber), _) =>
    if value->String.trim->String.length === 0 {
      localeString.accountNumberText->localeString.nameEmptyText
    } else {
      localeString.accountNumberInvalidText
    }
  | (PayoutMethodData(BacsSortCode), _) =>
    if value->String.trim->String.length === 0 {
      localeString.sortCodeText->localeString.nameEmptyText
    } else {
      localeString.sortCodeInvalidText
    }
  | (PayoutMethodData(BacsAccountNumber), _) =>
    if value->String.trim->String.length === 0 {
      localeString.accountNumberText->localeString.nameEmptyText
    } else {
      localeString.accountNumberInvalidText
    }
  | (PayoutMethodData(InteracEmail), _) =>
    if value->String.trim->String.length === 0 {
      localeString.emailEmptyText
    } else {
      localeString.emailInvalidText
    }
  | (PayoutMethodData(CardHolderName), _) =>
    if value->String.trim->String.length === 0 {
      localeString.cardHolderName->localeString.nameEmptyText
    } else {
      localeString.cardHolderName->localeString.completeNameEmptyText
    }
  | (PayoutMethodData(SepaIban), _) =>
    if value->String.trim->String.length === 0 {
      localeString.ibanEmptyText
    } else {
      localeString.ibanInvalidText
    }
  | (BillingAddress(AddressState), _) => localeString.stateEmptyText
  | (BillingAddress(AddressCity), _) => localeString.cityEmptyText
  | (BillingAddress(AddressPincode), _) =>
    if value->String.trim->String.length === 0 {
      localeString.postalCodeEmptyText
    } else {
      localeString.postalCodeInvalidText
    }
  | (BillingAddress(PhoneNumber), _) =>
    localeString.formFieldPhoneNumberLabel->localeString.nameEmptyText
  | (BillingAddress(PhoneCountryCode), _) =>
    localeString.formFieldCountryCodeRequiredLabel->localeString.nameEmptyText
  | (BillingAddress(CountryCode), _) =>
    localeString.formFieldCountryCodeRequiredLabel->localeString.nameEmptyText
  | (BillingAddress(FullName(_)), _) => localeString.fullNameLabel->localeString.nameEmptyText
  | (BillingAddress(AddressCountry(_)), _) => localeString.countryLabel->localeString.nameEmptyText
  | (BillingAddress(Email), _) =>
    if value->String.trim->String.length === 0 {
      localeString.emailEmptyText
    } else {
      localeString.emailInvalidText
    }
  | (BillingAddress(AddressLine1), _) => localeString.line1EmptyText
  | (BillingAddress(AddressLine2), _) => localeString.line2EmptyText

  | (PayoutMethodData(PaypalMobNumber), _) | (PayoutMethodData(VenmoMobNumber), _) =>
    localeString.formFieldPhoneNumberLabel->localeString.nameEmptyText
  | _ => ""
  }
}

let getPaymentMethodIcon = (paymentMethod: paymentMethod) =>
  switch paymentMethod {
  | Card => <Icon name="default-card" size=20 />
  | BankRedirect
  | BankTransfer =>
    <Icon name="bank" size=20 />
  | Wallet => <Icon name="wallet-generic-line" size=20 />
  }

let getBankTransferIcon = (bankTransfer: bankTransfer) =>
  switch bankTransfer {
  | ACH => <Icon name="ach_bank_transfer" size=20 />
  | Bacs => <Icon name="bank" size=20 />
  | Pix => <Icon name="wallet-pix" size=20 />
  | Sepa => <Icon name="bank" size=20 />
  }

let getWalletIcon = (wallet: wallet) =>
  switch wallet {
  | Paypal => <Icon name="wallet-paypal" size=20 />
  | Venmo => <Icon name="wallet-venmo" size=20 />
  }

let getBankRedirectIcon = (bankRedirect: bankRedirect) =>
  switch bankRedirect {
  | Interac => <Icon name="interac" size=20 />
  }

let getPaymentMethodTypeIcon = (paymentMethodType: paymentMethodType) =>
  switch paymentMethodType {
  | Card(_) => Card->getPaymentMethodIcon
  | BankRedirect(br) => br->getBankRedirectIcon
  | BankTransfer(b) => b->getBankTransferIcon
  | Wallet(w) => w->getWalletIcon
  }

// Defaults
let defaultFormDataDict: Dict.t<string> = Dict.make()
let defaultValidityDict: Dict.t<option<bool>> = Dict.make()
let defaultOptionsLimitInTabLayout = 2
let defaultAvailablePaymentMethods: array<paymentMethod> = []
let defaultAvailablePaymentMethodTypes: array<paymentMethodType> = []
let defaultPm: paymentMethod = Card
let defaultPmt = (~pm=defaultPm): paymentMethodType => {
  switch pm {
  | Card => Card(Debit)
  | BankRedirect => BankRedirect(Interac)
  | BankTransfer => BankTransfer(ACH)
  | Wallet => Wallet(Paypal)
  }
}
let defaultCardFields: array<dynamicFieldForPaymentMethodData> = [
  {
    pmdMap: "payout_method_data.card.card_number",
    displayName: "user_card_number",
    fieldType: CardNumber,
    value: None,
  },
  {
    pmdMap: "payout_method_data.card.expiry_month",
    displayName: "user_card_exp_month",
    fieldType: CardExpDate(CardExpMonth),
    value: None,
  },
  {
    pmdMap: "payout_method_data.card.expiry_year",
    displayName: "user_card_exp_year",
    fieldType: CardExpDate(CardExpYear),
    value: None,
  },
]
let defaultAchFields = [
  {
    pmdMap: "payout_method_data.ach.bank_routing_number",
    displayName: "user_routing_number",
    fieldType: ACHRoutingNumber,
    value: None,
  },
  {
    pmdMap: "payout_method_data.ach.bank_account_number",
    displayName: "user_bank_account_number",
    fieldType: ACHAccountNumber,
    value: None,
  },
]
let defaultBacsFields = [
  {
    pmdMap: "payout_method_data.bank.bank_sort_code",
    displayName: "user_sort_code",
    fieldType: BacsSortCode,
    value: None,
  },
  {
    pmdMap: "payout_method_data.bank.bank_account_number",
    displayName: "user_bank_account_number",
    fieldType: BacsAccountNumber,
    value: None,
  },
]
let defaultPixTransferFields = [
  {
    pmdMap: "payout_method_data.bank.bank_account_number",
    displayName: "user_bank_account_number",
    fieldType: PixBankAccountNumber,
    value: None,
  },
  {
    pmdMap: "payout_method_data.bank.pix_key",
    displayName: "user_pix_key",
    fieldType: PixKey,
    value: None,
  },
]
let defaultSepaFields = [
  {
    pmdMap: "payout_method_data.bank.iban",
    displayName: "user_iban",
    fieldType: SepaIban,
    value: None,
  },
]
let defaultPaypalFields = [
  {
    pmdMap: "payout_method_data.wallet.paypal.telephone_number",
    displayName: "user_phone_number",
    fieldType: PaypalMobNumber,
    value: None,
  },
]
let defaultInteracFields = [
  {
    pmdMap: "payout_method_data.bank_redirect.interac.email",
    displayName: "email",
    fieldType: InteracEmail,
    value: None,
  },
]
let defaultDynamicPmdFields = (~pmt: paymentMethodType=defaultPmt()): array<
  dynamicFieldForPaymentMethodData,
> => {
  switch pmt {
  | Card(_) => defaultCardFields
  | BankRedirect(Interac) => defaultInteracFields
  | BankTransfer(ACH) => defaultAchFields
  | BankTransfer(Bacs) => defaultBacsFields
  | BankTransfer(Pix) => defaultPixTransferFields
  | BankTransfer(Sepa) => defaultSepaFields
  | Wallet(Paypal) => defaultPaypalFields
  | Wallet(Venmo) => []
  }
}
let defaultPayoutDynamicFields = (~pmt: paymentMethodType=defaultPmt()): payoutDynamicFields => {
  {
    address: None,
    payoutMethodData: defaultDynamicPmdFields(~pmt),
  }
}
let defaultFormLayout: formLayout = Tabs
let defaultJourneyView: journeyViews = SelectPM
let defaultTabView: tabViews = DetailsForm
let defaultView = (layout: formLayout) => {
  switch layout {
  | Journey => Journey(SelectPM)
  | Tabs => Tabs(defaultTabView)
  }
}
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
let defaultEnabledPaymentMethodsWithDynamicFields: array<paymentMethodTypeWithDynamicFields> = [
  Card((Credit, defaultPayoutDynamicFields(~pmt=Card(Credit)))),
  Card((Debit, defaultPayoutDynamicFields(~pmt=Card(Debit)))),
  BankTransfer((ACH, defaultPayoutDynamicFields(~pmt=BankTransfer(ACH)))),
  BankTransfer((Bacs, defaultPayoutDynamicFields(~pmt=BankTransfer(Bacs)))),
  BankTransfer((Sepa, defaultPayoutDynamicFields(~pmt=BankTransfer(Sepa)))),
  Wallet((Paypal, defaultPayoutDynamicFields(~pmt=Wallet(Paypal)))),
]
let defaultPaymentMethodCollectOptions = {
  enabledPaymentMethods: defaultEnabledPaymentMethods,
  enabledPaymentMethodsWithDynamicFields: defaultEnabledPaymentMethodsWithDynamicFields,
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
let defaultStatusInfo = {
  status: Success,
  payoutId: "",
  message: EnglishLocale.localeStrings.payoutStatusSuccessMessage,
  code: None,
  errorMessage: None,
  reason: None,
}

let itemToObjMapper = dict => {
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
  )
  let (enabledPaymentMethods, enabledPaymentMethodsWithDynamicFields) = switch dict->Dict.get(
    "enabledPaymentMethods",
  ) {
  | Some(json) => json->decodePaymentMethodTypeArray(defaultDynamicPmdFields)
  | None => (defaultEnabledPaymentMethods, defaultEnabledPaymentMethodsWithDynamicFields)
  }
  {
    enabledPaymentMethodsWithDynamicFields,
    enabledPaymentMethods,
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

let calculateValidity = (key, value, cardBrand, ~default=None) => {
  switch key {
  | PayoutMethodData(CardNumber) =>
    if cardNumberInRange(value, cardBrand)->Array.includes(true) && calculateLuhn(value) {
      Some(true)
    } else if value->String.length == 0 {
      default
    } else {
      Some(false)
    }
  | PayoutMethodData(CardExpDate(_)) =>
    if value->String.length > 0 && getExpiryValidity(value) {
      Some(true)
    } else if value->String.length == 0 {
      default
    } else {
      Some(false)
    }
  | PayoutMethodData(CardHolderName) =>
    if value->String.trim->String.includes(" ") {
      Some(true)
    } else if value->String.length == 0 {
      default
    } else {
      Some(false)
    }
  | PayoutMethodData(ACHRoutingNumber) =>
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
  | PayoutMethodData(SepaIban) => Some(value->String.length > 13 && value->String.length < 34)

  // Sepa BIC is optional
  | PayoutMethodData(SepaBic) => Some(true)

  | PayoutMethodData(InteracEmail)
  | PayoutMethodData(PaypalMail)
  | BillingAddress(Email) =>
    if RegExp.test(emailValidationRegex, value) {
      Some(true)
    } else if value->String.length == 0 {
      default
    } else {
      Some(false)
    }

  // Defaults
  | PayoutMethodData(_)
  | BillingAddress(_) =>
    value->String.length > 0 ? Some(true) : Some(false)
  }
}

let checkValidity = (keys, fieldValidityDict, ~defaultValidity=true) => {
  keys->Array.reduce(true, (acc, key) => {
    switch fieldValidityDict->Dict.get(key) {
    | Some(validity) => acc && validity->Option.getOr(defaultValidity)
    | None => defaultValidity
    }
  })
}

let processPaymentMethodDataFields = (
  dynamicFieldsInfo: array<dynamicFieldForPaymentMethodData>,
  paymentMethodDataDict,
  fieldValidityDict,
) => {
  let (dynamicFieldsData, dynamicFieldKeys) = dynamicFieldsInfo->Array.reduce(([], []), (
    (dataArr, keys),
    dynamicFieldInfo,
  ) => {
    switch dynamicFieldInfo.fieldType {
    | CardExpDate(CardExpMonth) => {
        let key = PayoutMethodData(CardExpDate(CardExpMonth))
        let info: dynamicFieldInfo = PayoutMethodData(dynamicFieldInfo)
        let fieldKey = key->getPaymentMethodDataFieldKey
        paymentMethodDataDict
        ->Dict.get(fieldKey)
        ->Option.map(value => {
          value
          ->String.split("/")
          ->Array.get(0)
          ->Option.map(month => dataArr->Array.push((info, month->String.trim)))
        })
        ->ignore
        keys->Array.push(fieldKey)
        (dataArr, keys)
      }
    | CardExpDate(CardExpYear) => {
        let key = PayoutMethodData(CardExpDate(CardExpMonth))
        let info: dynamicFieldInfo = PayoutMethodData(dynamicFieldInfo)
        let fieldKey = key->getPaymentMethodDataFieldKey
        paymentMethodDataDict
        ->Dict.get(fieldKey)
        ->Option.map(value => {
          value
          ->String.split("/")
          ->Array.get(1)
          ->Option.map(year => dataArr->Array.push((info, `20${year->String.trim}`)))
        })
        ->ignore
        keys->Array.push(fieldKey)
        (dataArr, keys)
      }
    | _ => {
        let key = PayoutMethodData(dynamicFieldInfo.fieldType)
        let info: dynamicFieldInfo = PayoutMethodData(dynamicFieldInfo)
        let fieldKey = key->getPaymentMethodDataFieldKey
        paymentMethodDataDict
        ->Dict.get(fieldKey)
        ->Option.map(value => dataArr->Array.push((info, value->String.trim)))
        ->ignore
        keys->Array.push(fieldKey)
        (dataArr, keys)
      }
    }
  })

  dynamicFieldKeys->checkValidity(fieldValidityDict, ~defaultValidity=false)
    ? Some(dynamicFieldsData)
    : None
}

let processAddressFields = (
  dynamicFieldsInfo: array<dynamicFieldForAddress>,
  paymentMethodDataDict,
  fieldValidityDict,
) => {
  let (dynamicFieldsData, dynamicFieldKeys) = dynamicFieldsInfo->Array.reduce(([], []), (
    (dataArr, keys),
    dynamicFieldInfo,
  ) => {
    switch dynamicFieldInfo.fieldType {
    | FullName(FirstName) => {
        let key = BillingAddress(FullName(FirstName))
        let info: dynamicFieldInfo = BillingAddress(dynamicFieldInfo)
        let fieldKey = key->getPaymentMethodDataFieldKey
        paymentMethodDataDict
        ->Dict.get(fieldKey)
        ->Option.map(value => {
          value
          ->String.split(" ")
          ->Array.get(0)
          ->Option.map(firstName => dataArr->Array.push((info, firstName)))
        })
        ->ignore
        keys->Array.push(fieldKey)
        (dataArr, keys)
      }
    | FullName(LastName) => {
        let lastNameKey = BillingAddress(FullName(LastName))
        let info: dynamicFieldInfo = BillingAddress(dynamicFieldInfo)
        let lastNameFieldKey = lastNameKey->getPaymentMethodDataFieldKey

        // First try to get lastName from direct lastName field
        let lastNameValue =
          paymentMethodDataDict->Dict.get(lastNameFieldKey)->Option.getOr("")->String.trim
        if lastNameValue->String.length > 0 {
          dataArr->Array.push((info, lastNameValue))
        }
        keys->Array.push(lastNameFieldKey)
        (dataArr, keys)
      }
    | _ => {
        let key = BillingAddress(dynamicFieldInfo.fieldType)
        let info: dynamicFieldInfo = BillingAddress(dynamicFieldInfo)
        let fieldKey = key->getPaymentMethodDataFieldKey
        paymentMethodDataDict
        ->Dict.get(fieldKey)
        ->Option.map(value => dataArr->Array.push((info, value)))
        ->ignore
        keys->Array.push(fieldKey)
        (dataArr, keys)
      }
    }
  })

  dynamicFieldKeys->checkValidity(fieldValidityDict, ~defaultValidity=false)
    ? Some(dynamicFieldsData)
    : None
}

let formPaymentMethodData = (paymentMethodDataDict, fieldValidityDict, requiredFields): option<
  array<(dynamicFieldInfo, string)>,
> => {
  let collectedFields = {
    let addressFields =
      requiredFields.address->Option.flatMap(address =>
        processAddressFields(address, paymentMethodDataDict, fieldValidityDict)
      )
    processPaymentMethodDataFields(
      requiredFields.payoutMethodData,
      paymentMethodDataDict,
      fieldValidityDict,
    )->Option.flatMap(fields => {
      addressFields
      ->Option.map(address => address->Array.concat(fields))
      ->Option.orElse(Some(fields))
    })
  }

  collectedFields
}

let formBody = (flow: paymentMethodCollectFlow, paymentMethodData: paymentMethodData) => {
  let (paymentMethodType, fields) = paymentMethodData

  // Helper function to create nested structure from pmdMap
  let createNestedStructure = (dict, key, value) => {
    let keys = key->String.split(".")
    let rec addToDict = (dict, keys) => {
      switch keys {
      | [] => ()
      | [lastKey] => dict->Dict.set(lastKey, JSON.Encode.string(value))
      | _ => {
          let head = keys->Array.get(0)->Option.getOr("")
          let nestedDict = dict->Dict.get(head)->Option.getOr(Dict.make()->JSON.Encode.object)
          let newNestedDict = switch nestedDict {
          | Object(d) => d
          | _ => Dict.make()
          }
          addToDict(newNestedDict, keys->Array.sliceToEnd(~start=1))
          dict->Dict.set(head, newNestedDict->JSON.Encode.object)
        }
      }
    }
    addToDict(dict, keys)
  }

  // Process fields
  let pmdDict = Dict.make()
  fields->Array.forEach(((fieldInfo, value)) => {
    switch fieldInfo {
    | BillingAddress(addressInfo) => createNestedStructure(pmdDict, addressInfo.pmdMap, value)
    | PayoutMethodData(paymentMethodInfo) =>
      createNestedStructure(pmdDict, paymentMethodInfo.pmdMap, value)
    }
  })

  let body: array<(string, JSON.t)> = []

  // Required fields
  pmdDict
  ->Dict.toArray
  ->Array.map(((key, val)) => {
    body->Array.push((key, val))
  })
  ->ignore

  let paymentMethod = paymentMethodType->getPaymentMethodForPmt

  // Add browser info for Interac bank redirect payments
  let body = switch paymentMethodType {
  | BankRedirect(Interac) => body->Array.concat(BrowserSpec.broswerInfo())
  | _ => body
  }

  // Flow specific fields
  switch flow {
  | PayoutMethodCollect => {
      body->Array.push(("payment_method", paymentMethod->getPaymentMethod->JSON.Encode.string))
      body->Array.push((
        "payment_method_type",
        paymentMethodType->getPaymentMethodType->JSON.Encode.string,
      ))
    }
  | PayoutLinkInitiate =>
    body->Array.push((
      "payout_type",
      paymentMethod->getPaymentMethodForPayoutsConfirm->JSON.Encode.string,
    ))
  }

  body
}

let getPayoutDynamicFields = (
  enabledPaymentMethodsWithDynamicFields: array<paymentMethodTypeWithDynamicFields>,
  reqPmt,
): option<payoutDynamicFields> =>
  enabledPaymentMethodsWithDynamicFields
  ->Array.find(pmtr => {
    switch (pmtr, reqPmt) {
    | (Card(_), Card(_))
    | (BankRedirect(Interac, _), BankRedirect(Interac))
    | (BankTransfer(ACH, _), BankTransfer(ACH))
    | (BankTransfer(Bacs, _), BankTransfer(Bacs))
    | (BankTransfer(Pix, _), BankTransfer(Pix))
    | (BankTransfer(Sepa, _), BankTransfer(Sepa))
    | (Wallet(Paypal, _), Wallet(Paypal))
    | (Wallet(Venmo, _), Wallet(Venmo)) => true
    | _ => false
    }
  })
  ->Option.map(pmt => {
    switch pmt {
    | Card(_, payoutDynamicFields)
    | BankRedirect(_, payoutDynamicFields)
    | BankTransfer(_, payoutDynamicFields)
    | Wallet(_, payoutDynamicFields) => payoutDynamicFields
    }
  })

let getErrorStringAndClasses = (
  field: dynamicFieldType,
  formData: Dict.t<string>,
  validityDict: Dict.t<option<bool>>,
  localeString: LocaleStringTypes.localeStrings,
) => {
  let key = field->getPaymentMethodDataFieldKey
  let value = formData->Dict.get(key)->Option.getOr("")
  let isValid = validityDict->Dict.get(key)->Option.flatMap(key => key)

  switch field {
  | BillingAddress(FullName(FirstName)) => {
      // Check both FirstName and LastName validity and merge error messages
      let firstNameKey = BillingAddress(FullName(FirstName))->getPaymentMethodDataFieldKey
      let lastNameKey = BillingAddress(FullName(LastName))->getPaymentMethodDataFieldKey
      let firstNameValid = validityDict->Dict.get(firstNameKey)->Option.flatMap(key => key)
      let lastNameValid = validityDict->Dict.get(lastNameKey)->Option.flatMap(key => key)

      // since error message for both first name and last name is the same, we can just use one of them
      let fullNameError = switch (
        firstNameValid->Option.getOr(true),
        lastNameValid->Option.getOr(true),
      ) {
      | (true, true) => ""
      | _ => BillingAddress(FullName(FirstName))->getPaymentMethodDataErrorString("", localeString)
      }

      let fullNameErrorClass = fullNameError !== "" ? "text-xs text-red-950" : ""
      (fullNameError, fullNameErrorClass)
    }
  | _ =>
    // Default behavior for other fields
    switch isValid {
    | Some(false) => (
        field->getPaymentMethodDataErrorString(value, localeString),
        "text-xs text-red-950",
      )
    | _ => ("", "")
    }
  }
}

let getDefaultsAndValidity = (payoutDynamicFields, supportedCardBrands) => {
  payoutDynamicFields.address
  ->Option.map(address => {
    address->Array.reduce((Dict.make(), Dict.make()), ((values, validity), field) => {
      switch (field.fieldType, field.value) {
      | (AddressCountry(countries), None) => countries->Array.get(0)
      | _ => field.value
      }
      ->Option.map(
        value => {
          let key = BillingAddress(field.fieldType)
          let validCardBrand = getFirstValidCardSchemeFromPML(
            ~cardNumber=value,
            ~enabledCardSchemes=supportedCardBrands->Option.getOr([]),
          )
          let newCardBrand = switch validCardBrand {
          | Some(brand) => brand
          | None => value->CardUtils.getCardBrand
          }
          let isValid = calculateValidity(key, value, newCardBrand)
          let keyStr = key->getPaymentMethodDataFieldKey
          values->Dict.set(keyStr, value)
          validity->Dict.set(keyStr, isValid)
          (values, validity)
        },
      )
      ->Option.getOr({(values, validity)})
    })
  })
  ->Option.map(((addressValues, addressValidity)) => {
    payoutDynamicFields.payoutMethodData->Array.reduce((addressValues, addressValidity), (
      (values, validity),
      field,
    ) => {
      switch field.value {
      | Some(value) => {
          let key = PayoutMethodData(field.fieldType)
          let validCardBrand = getFirstValidCardSchemeFromPML(
            ~cardNumber=value,
            ~enabledCardSchemes=supportedCardBrands->Option.getOr([]),
          )
          let newCardBrand = switch validCardBrand {
          | Some(brand) => brand
          | None => value->CardUtils.getCardBrand
          }
          let isValid = calculateValidity(key, value, newCardBrand)
          let keyStr = key->getPaymentMethodDataFieldKey
          values->Dict.set(keyStr, value)
          validity->Dict.set(keyStr, isValid)
        }
      | None => ()
      }
      (values, validity)
    })
  })
}
