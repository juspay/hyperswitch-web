type paymentFlow = InvokeSDK | RedirectToURL | QrFlow

type paymentFlowWithConnector = array<(paymentFlow, array<string>)>
type paymentMethodsFields =
  | Email
  | FullName
  | InfoElement
  | Country
  | Bank
  | SpecialField(React.element)
  | None
  | BillingName
  | PhoneNumber
  | AddressLine1
  | AddressLine2
  | AddressCity
  | StateAndCity
  | CountryAndPincode(array<string>)
  | AddressPincode
  | AddressState
  | AddressCountry(array<string>)
  | BlikCode
  | Currency(array<string>)
  | CardNumber
  | CardExpiryMonth
  | CardExpiryYear
  | CardExpiryMonthAndYear
  | CardCvc
  | CardExpiryAndCvc
  | ShippingName
  | ShippingAddressLine1
  | ShippingAddressLine2
  | ShippingAddressCity
  | ShippingAddressPincode
  | ShippingAddressState
  | ShippingAddressCountry(array<string>)

let getPaymentMethodsFieldsOrder = paymentMethodField => {
  switch paymentMethodField {
  | CardNumber => 0
  | CardExpiryMonth => 1
  | CardExpiryYear => 1
  | CardExpiryMonthAndYear => 1
  | CardCvc => 2
  | CardExpiryAndCvc => 2
  | AddressLine1 => 4
  | AddressLine2 => 5
  | AddressCity => 6
  | AddressState => 7
  | AddressCountry(_) => 8
  | AddressPincode => 9
  | StateAndCity => 7
  | CountryAndPincode(_) => 8
  | InfoElement => 99
  | _ => 3
  }
}

let sortPaymentMethodFields = (firstPaymentMethodField, secondPaymentMethodField) => {
  firstPaymentMethodField->getPaymentMethodsFieldsOrder -
    secondPaymentMethodField->getPaymentMethodsFieldsOrder
}

type bankNames = {
  bank_name: array<string>,
  eligible_connectors: array<string>,
}

type surchargeDetails = {displayTotalSurchargeAmount: float}

type paymentMethodsContent = {
  paymentMethodName: string,
  fields: array<paymentMethodsFields>,
  paymentFlow: paymentFlowWithConnector,
  handleUserError: bool,
  methodType: string,
  bankNames: array<string>,
}
type paymentMethods = array<paymentMethodsContent>
type paymentFieldsInfo = {
  paymentMethodName: string,
  fields: array<paymentMethodsFields>,
  icon: option<React.element>,
  displayName: string,
  miniIcon: option<React.element>,
}

let defaultPaymentFieldsInfo = {
  paymentMethodName: "",
  fields: [],
  icon: None,
  displayName: "",
  miniIcon: None,
}

let defaultPaymentMethodContent = {
  paymentMethodName: "",
  fields: [],
  paymentFlow: [],
  handleUserError: false,
  methodType: "",
  bankNames: [],
}
let defaultPaymentMethodFields = {
  paymentMethodName: "",
  fields: [],
  icon: None,
  displayName: "",
  miniIcon: None,
}

let icon = (~size=22, ~width=size, name) => {
  <Icon size width name />
}

let paymentMethodsFields = [
  {
    paymentMethodName: "afterpay_clearpay",
    fields: [Email, FullName, InfoElement],
    icon: Some(icon("afterpay", ~size=19)),
    displayName: "After Pay",
    miniIcon: None,
  },
  {
    paymentMethodName: "google_pay",
    fields: [],
    icon: Some(icon("google_pay", ~size=19, ~width=25)),
    displayName: "Google Pay",
    miniIcon: None,
  },
  {
    paymentMethodName: "apple_pay",
    fields: [],
    icon: Some(icon("apple_pay", ~size=19, ~width=25)),
    displayName: "Apple Pay",
    miniIcon: None,
  },
  {
    paymentMethodName: "mb_way",
    fields: [SpecialField(<PhoneNumberPaymentInput />), InfoElement],
    icon: Some(icon("mbway", ~size=19)),
    displayName: "Mb Way",
    miniIcon: None,
  },
  {
    paymentMethodName: "mobile_pay",
    fields: [InfoElement],
    icon: Some(icon("mobilepay", ~size=19)),
    displayName: "Mobile Pay",
    miniIcon: None,
  },
  {
    paymentMethodName: "ali_pay",
    fields: [InfoElement],
    icon: Some(icon("alipay", ~size=19)),
    displayName: "Ali Pay",
    miniIcon: None,
  },
  {
    paymentMethodName: "we_chat_pay",
    fields: [InfoElement],
    icon: Some(icon("wechatpay", ~size=19)),
    displayName: "WeChat",
    miniIcon: None,
  },
  {
    paymentMethodName: "affirm",
    fields: [InfoElement],
    icon: Some(icon("affirm", ~size=20)),
    displayName: "Affirm",
    miniIcon: None,
  },
  {
    paymentMethodName: "crypto_currency",
    fields: [InfoElement],
    icon: Some(icon("crypto", ~size=19)),
    displayName: "Crypto",
    miniIcon: None,
  },
  {
    paymentMethodName: "card",
    icon: Some(icon("default-card", ~size=19)),
    fields: [],
    displayName: "Card",
    miniIcon: None,
  },
  {
    paymentMethodName: "klarna",
    icon: Some(icon("klarna", ~size=19)),
    fields: [Email, FullName, InfoElement],
    displayName: "Klarna",
    miniIcon: None,
  },
  {
    paymentMethodName: "sofort",
    icon: Some(icon("sofort", ~size=19)),
    fields: [InfoElement],
    displayName: "Sofort",
    miniIcon: None,
  },
  {
    paymentMethodName: "ach_transfer",
    icon: Some(icon("ach", ~size=19)),
    fields: [],
    displayName: "ACH Bank Transfer",
    miniIcon: None,
  },
  {
    paymentMethodName: "bacs_transfer",
    icon: Some(icon("bank", ~size=19)),
    fields: [],
    displayName: "BACS Bank Transfer",
    miniIcon: None,
  },
  {
    paymentMethodName: "sepa_transfer",
    icon: Some(icon("sepa", ~size=19)),
    fields: [],
    displayName: "SEPA Bank Transfer",
    miniIcon: None,
  },
  {
    paymentMethodName: "sepa_debit",
    icon: Some(icon("sepa", ~size=19, ~width=25)),
    displayName: "SEPA Debit",
    fields: [],
    miniIcon: None,
  },
  {
    paymentMethodName: "giropay",
    icon: Some(icon("giropay", ~size=19, ~width=25)),
    displayName: "GiroPay",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "eps",
    icon: Some(icon("eps", ~size=19, ~width=25)),
    displayName: "EPS",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "walley",
    icon: Some(icon("walley", ~size=19, ~width=25)),
    displayName: "Walley",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "pay_bright",
    icon: Some(icon("paybright", ~size=19, ~width=25)),
    displayName: "Pay Bright",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "ach_debit",
    icon: Some(icon("ach", ~size=19)),
    displayName: "ACH Debit",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "bacs_debit",
    icon: Some(icon("bank", ~size=21)),
    displayName: "BACS Debit",
    fields: [InfoElement],
    miniIcon: Some(icon("bank", ~size=19)),
  },
  {
    paymentMethodName: "becs_debit",
    icon: Some(icon("bank", ~size=21)),
    displayName: "BECS Debit",
    fields: [InfoElement],
    miniIcon: Some(icon("bank", ~size=19)),
  },
  {
    paymentMethodName: "blik",
    icon: Some(icon("blik", ~size=19, ~width=25)),
    displayName: "Blik",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "trustly",
    icon: Some(icon("trustly", ~size=19, ~width=25)),
    displayName: "Trustly",
    fields: [Country, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "bancontact_card",
    icon: Some(icon("bancontact", ~size=19, ~width=25)),
    displayName: "Bancontact Card",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "online_banking_czech_republic",
    icon: Some(icon("bank", ~size=19, ~width=25)),
    displayName: "Online Banking CzechR",
    fields: [Bank, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "online_banking_slovakia",
    icon: Some(icon("bank", ~size=19, ~width=25)),
    displayName: "Online Banking Slovakia",
    fields: [Bank, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "online_banking_finland",
    icon: Some(icon("bank", ~size=19, ~width=25)),
    displayName: "Online Banking Finland",
    fields: [Bank, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "online_banking_poland",
    icon: Some(icon("bank", ~size=19, ~width=25)),
    displayName: "Online Banking Poland",
    fields: [Bank, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "ideal",
    icon: Some(icon("ideal", ~size=19, ~width=25)),
    displayName: "iDEAL",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "ban_connect",
    icon: None,
    displayName: "Ban Connect",
    fields: [],
    miniIcon: None,
  },
  {
    paymentMethodName: "ach_bank_debit",
    icon: Some(icon("ach-bank-debit", ~size=19, ~width=25)),
    displayName: "ACH Direct Debit",
    fields: [],
    miniIcon: None,
  },
  {
    paymentMethodName: "przelewy24",
    icon: Some(icon("p24", ~size=19)),
    displayName: "Przelewy24",
    fields: [Email, Bank, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "interac",
    icon: Some(icon("interac", ~size=19)),
    displayName: "Interac",
    fields: [Email, Country, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "twint",
    icon: Some(icon("twint", ~size=19)),
    displayName: "Twint",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "vipps",
    icon: Some(icon("vipps", ~size=19)),
    displayName: "Vipps",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "dana",
    icon: Some(icon("dana", ~size=19)),
    displayName: "Dana",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "go_pay",
    icon: Some(icon("go_pay", ~size=19)),
    displayName: "Go Pay",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "kakao_pay",
    icon: Some(icon("kakao_pay", ~size=19)),
    displayName: "Kakao Pay",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "gcash",
    icon: Some(icon("gcash", ~size=19)),
    displayName: "GCash",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "momo",
    icon: Some(icon("momo", ~size=19)),
    displayName: "Momo",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "touch_n_go",
    icon: Some(icon("touch_n_go", ~size=19)),
    displayName: "Touch N Go",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "bizum",
    icon: Some(icon("bizum", ~size=19)),
    displayName: "Bizum",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "classic",
    icon: Some(icon("cashtocode", ~size=50)),
    displayName: "Cash / Voucher",
    fields: [InfoElement],
    miniIcon: Some(icon("cashtocode", ~size=19)),
  },
  {
    paymentMethodName: "online_banking_fpx",
    icon: Some(icon("online_banking_fpx", ~size=19)),
    displayName: "Online Banking Fpx",
    fields: [Bank, InfoElement], // add more fields for these payment methods
    miniIcon: None,
  },
  {
    paymentMethodName: "online_banking_thailand",
    icon: Some(icon("online_banking_thailand", ~size=19)),
    displayName: "Online Banking Thailand",
    fields: [Bank, InfoElement], // add more fields for these payment methods
    miniIcon: None,
  },
  {
    paymentMethodName: "alma",
    icon: Some(icon("alma", ~size=19)),
    displayName: "Alma",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "atome",
    icon: Some(icon("atome", ~size=19)),
    displayName: "Atome",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "multibanco",
    icon: Some(icon("multibanco", ~size=19)),
    displayName: "Multibanco",
    fields: [Email, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "card_redirect",
    icon: Some(icon("default-card", ~size=19)),
    displayName: "Card",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "open_banking_uk",
    icon: Some(icon("bank", ~size=19)),
    displayName: "Pay by Bank",
    fields: [InfoElement],
    miniIcon: Some(icon("bank", ~size=19)),
  },
  {
    paymentMethodName: "evoucher",
    icon: Some(icon("cashtocode", ~size=50)),
    displayName: "E-Voucher",
    fields: [InfoElement],
    miniIcon: Some(icon("cashtocode", ~size=19)),
  },
  {
    paymentMethodName: "pix_transfer",
    fields: [InfoElement],
    icon: Some(icon("pix", ~size=26, ~width=40)),
    displayName: "Pix",
    miniIcon: None,
  },
  {
    paymentMethodName: "boleto",
    icon: Some(icon("boleto", ~size=21, ~width=25)),
    displayName: "Boleto",
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "local_bank_transfer_transfer",
    fields: [InfoElement],
    icon: Some(icon("bank", ~size=19)),
    displayName: "Local Bank Transfer",
    miniIcon: None,
  },
]

type required_fields = {
  required_field: string,
  display_name: string,
  field_type: paymentMethodsFields,
  value: string,
}

let getPaymentMethodsFieldTypeFromString = (str, isBancontact) => {
  switch (str, isBancontact) {
  | ("user_email_address", _) => Email
  | ("user_full_name", _) => FullName
  | ("user_country", _) => Country
  | ("user_bank", _) => Bank
  | ("user_phone_number", _) => PhoneNumber
  | ("user_address_line1", _) => AddressLine1
  | ("user_address_line2", _) => AddressLine2
  | ("user_address_city", _) => AddressCity
  | ("user_address_pincode", _) => AddressPincode
  | ("user_address_state", _) => AddressState
  | ("user_blik_code", _) => BlikCode
  | ("user_billing_name", _) => BillingName
  | ("user_card_number", true) => CardNumber
  | ("user_card_expiry_month", true) => CardExpiryMonth
  | ("user_card_expiry_year", true) => CardExpiryYear
  | ("user_card_cvc", true) => CardCvc
  | ("user_shipping_name", _) => ShippingName
  | ("user_shipping_address_line1", _) => ShippingAddressLine1
  | ("user_shipping_address_line2", _) => ShippingAddressLine2
  | ("user_shipping_address_city", _) => ShippingAddressCity
  | ("user_shipping_address_pincode", _) => ShippingAddressPincode
  | ("user_shipping_address_state", _) => ShippingAddressState
  | _ => None
  }
}

let getOptionsFromPaymentMethodFieldType = (dict, key, ~isAddressCountry=true) => {
  let options = dict->Utils.getArrayValFromJsonDict(key, "options")
  switch options->Array.get(0)->Option.getOr("") {
  | "" => None
  | "ALL" => {
      let countryArr = Country.country->Array.map(item => item.countryName)
      isAddressCountry ? AddressCountry(countryArr) : ShippingAddressCountry(countryArr)
    }
  | _ => {
      let countryArr = Country.country->Array.reduce([], (acc, country) => {
        if options->Array.includes(country.isoAlpha2) {
          acc->Array.push(country.countryName)
        }
        acc
      })
      isAddressCountry ? AddressCountry(countryArr) : ShippingAddressCountry(countryArr)
    }
  }
}

let getPaymentMethodsFieldTypeFromDict = dict => {
  let keysArr = dict->Dict.keysToArray
  let key = keysArr->Array.get(0)->Option.getOr("")
  switch key {
  | "user_currency" => {
      let options = dict->Utils.getArrayValFromJsonDict("user_currency", "options")
      Currency(options)
    }
  | "user_country" => dict->getOptionsFromPaymentMethodFieldType("user_country")
  | "user_address_country" => dict->getOptionsFromPaymentMethodFieldType("user_address_country")
  | "user_shipping_address_country" =>
    dict->getOptionsFromPaymentMethodFieldType(
      "user_shipping_address_country",
      ~isAddressCountry=false,
    )
  | _ => None
  }
}

let getFieldType = (dict, isBancontact) => {
  let fieldClass =
    dict
    ->Dict.get("field_type")
    ->Option.getOr(Dict.make()->JSON.Encode.object)
    ->JSON.Classify.classify
  switch fieldClass {
  | Bool(_)
  | Null =>
    None
  | Number(_val) => None
  | Array(_arr) => None
  | String(val) => val->getPaymentMethodsFieldTypeFromString(isBancontact)
  | Object(dict) => dict->getPaymentMethodsFieldTypeFromDict
  }
}

let dynamicFieldsEnabledPaymentMethods = [
  "crypto_currency",
  "debit",
  "credit",
  "blik",
  "google_pay",
  "apple_pay",
  "bancontact_card",
  "open_banking_uk",
  "eps",
  "ideal",
  "sofort",
  "pix_transfer",
  "giropay",
  "local_bank_transfer_transfer",
]

let getIsBillingField = requiredFieldType => {
  switch requiredFieldType {
  | AddressLine1
  | AddressLine2
  | AddressCity
  | AddressPincode
  | AddressState
  | AddressCountry(_) => true
  | _ => false
  }
}

let getIsAnyBillingDetailEmpty = (requiredFields: array<required_fields>) => {
  requiredFields->Array.reduce(false, (acc, requiredField) => {
    if getIsBillingField(requiredField.field_type) {
      requiredField.value === "" || acc
    } else {
      acc
    }
  })
}

let getPaymentMethodFields = (
  paymentMethod,
  requiredFields: array<required_fields>,
  ~isSavedCardFlow=false,
  ~isAllStoredCardsHaveName=false,
  (),
) => {
  let isAnyBillingDetailEmpty = requiredFields->getIsAnyBillingDetailEmpty
  let requiredFieldsArr = requiredFields->Array.map(requiredField => {
    let isShowBillingField = getIsBillingField(requiredField.field_type) && isAnyBillingDetailEmpty
    if requiredField.value === "" || isShowBillingField {
      if (
        isSavedCardFlow &&
        requiredField.display_name === "card_holder_name" &&
        isAllStoredCardsHaveName
      ) {
        None
      } else {
        requiredField.field_type
      }
    } else {
      None
    }
  })
  requiredFieldsArr->Array.concat(
    (
      paymentMethodsFields
      ->Array.find(x => x.paymentMethodName === paymentMethod)
      ->Option.getOr({
        paymentMethodName: "",
        fields: [],
        icon: Some(icon("", ~size=19, ~width=25)),
        displayName: "",
        miniIcon: Some(icon("", ~size=19, ~width=25)),
      })
    ).fields,
  )
}

let getPaymentDetails = (arr: array<string>) => {
  let finalArr = []
  arr
  ->Array.map(item => {
    let optionalVal = paymentMethodsFields->Array.find(i => i.paymentMethodName == item)
    switch optionalVal {
    | Some(val) => finalArr->Array.push(val)->ignore
    | None => ()
    }
  })
  ->ignore
  finalArr
}

type paymentMethod =
  Cards | Wallets | PayLater | BankRedirect | BankTransfer | BankDebit | Crypto | Voucher | NONE

type cardType = Credit | Debit
type paymentMethodType =
  Card(cardType) | Klarna | Affirm | AfterPay | Gpay | Paypal | ApplePay | CryptoCurrency | NONE

type paymentExperience = {
  payment_experience_type: paymentFlow,
  eligible_connectors: array<string>,
}

type cardNetworks = {
  card_network: CardUtils.cardIssuer,
  eligible_connectors: array<string>,
  surcharge_details: option<surchargeDetails>,
}

let defaultCardNetworks = {
  card_network: CardUtils.NOTFOUND,
  eligible_connectors: [],
  surcharge_details: None,
}

type paymentMethodTypes = {
  payment_method_type: string,
  payment_experience: array<paymentExperience>,
  card_networks: array<cardNetworks>,
  bank_names: array<string>,
  bank_debits_connectors: array<string>,
  bank_transfers_connectors: array<string>,
  required_fields: array<required_fields>,
  surcharge_details: option<surchargeDetails>,
}

type methods = {
  payment_method: string,
  payment_method_types: array<paymentMethodTypes>,
}

type mandateType = {
  amount: int,
  currency: string,
}

type mandate = {
  single_use: option<mandateType>,
  multi_use: option<mandateType>,
}
type payment_type = NORMAL | NEW_MANDATE | SETUP_MANDATE | NONE

type paymentMethodList = {
  redirect_url: string,
  currency: string,
  payment_methods: array<methods>,
  mandate_payment: option<mandate>,
  payment_type: payment_type,
  merchant_name: string,
}

open Utils

let defaultPaymentMethodType = {
  payment_method_type: "",
  payment_experience: [],
  card_networks: [],
  bank_names: [],
  bank_debits_connectors: [],
  bank_transfers_connectors: [],
  required_fields: [],
  surcharge_details: None,
}

let defaultList = {
  redirect_url: "",
  currency: "",
  payment_methods: [],
  mandate_payment: None,
  payment_type: NONE,
  merchant_name: "",
}
let getMethod = str => {
  switch str {
  | "card" => Cards
  | "wallet" => Wallets
  | "pay_later" => PayLater
  | "bank_redirect" => BankRedirect
  | "bank_transfer" => BankTransfer
  | "bank_debit" => BankDebit
  | "crypto" => Crypto
  | "voucher" => Voucher
  | _ => NONE
  }
}

let getPaymentMethodType = str => {
  switch str {
  | "afterpay_clearpay" => AfterPay
  | "klarna" => Klarna
  | "affirm" => Affirm
  | "apple_pay" => ApplePay
  | "google_pay" => Gpay
  | "credit" => Card(Credit)
  | "debit" => Card(Debit)
  | "crypto_currency" => CryptoCurrency
  | _ => NONE
  }
}
let getPaymentExperienceType = str => {
  switch str {
  | "redirect_to_url" => RedirectToURL
  | "invoke_sdk_client" => InvokeSDK
  | "display_qr_code" => QrFlow
  | _ => RedirectToURL
  }
}

let getPaymentExperience = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.array)
  ->Option.getOr([])
  ->Belt.Array.keepMap(JSON.Decode.object)
  ->Array.map(json => {
    {
      payment_experience_type: getString(
        json,
        "payment_experience_type",
        "",
      )->getPaymentExperienceType,
      eligible_connectors: getStrArray(json, "eligible_connectors"),
    }
  })
}

let getSurchargeDetails = dict => {
  let surchargDetails =
    dict
    ->Dict.get("surcharge_details")
    ->Option.flatMap(JSON.Decode.object)
    ->Option.getOr(Dict.make())

  let displayTotalSurchargeAmount =
    surchargDetails
    ->Dict.get("display_total_surcharge_amount")
    ->Option.flatMap(JSON.Decode.float)
    ->Option.getOr(0.0)

  if displayTotalSurchargeAmount !== 0.0 {
    Some({
      displayTotalSurchargeAmount: displayTotalSurchargeAmount,
    })
  } else {
    None
  }
}

let getCardNetworks = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.array)
  ->Option.getOr([])
  ->Belt.Array.keepMap(JSON.Decode.object)
  ->Array.map(json => {
    {
      card_network: getString(json, "card_network", "")->CardUtils.getCardType,
      eligible_connectors: getStrArray(json, "eligible_connectors"),
      surcharge_details: json->getSurchargeDetails,
    }
  })
}

let getBankNames = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.array)
  ->Option.getOr([])
  ->Belt.Array.keepMap(JSON.Decode.object)
  ->Array.map(json => {
    getStrArray(json, "bank_name")
  })
  ->Array.reduce([], (acc, item) => {
    item->Array.forEach(obj => acc->Array.push(obj)->ignore)
    acc
  })
}

let getAchConnectors = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.getOr(Dict.make())
  ->getStrArray("elligible_connectors")
}

let getDynamicFieldsFromJsonDict = (dict, isBancontact) => {
  let requiredFields =
    Utils.getJsonFromDict(dict, "required_fields", JSON.Encode.null)
    ->Utils.getDictFromJson
    ->Dict.valuesToArray

  requiredFields->Array.map(requiredField => {
    let requiredFieldsDict = requiredField->Utils.getDictFromJson
    {
      required_field: requiredFieldsDict->Utils.getString("required_field", ""),
      display_name: requiredFieldsDict->Utils.getString("display_name", ""),
      field_type: requiredFieldsDict->getFieldType(isBancontact),
      value: requiredFieldsDict->Utils.getString("value", ""),
    }
  })
}

let getPaymentMethodTypes = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.array)
  ->Option.getOr([])
  ->Belt.Array.keepMap(JSON.Decode.object)
  ->Array.map(jsonDict => {
    let paymentMethodType = getString(jsonDict, "payment_method_type", "")
    {
      payment_method_type: paymentMethodType,
      payment_experience: getPaymentExperience(jsonDict, "payment_experience"),
      card_networks: getCardNetworks(jsonDict, "card_networks"),
      bank_names: getBankNames(jsonDict, "bank_names"),
      bank_debits_connectors: getAchConnectors(jsonDict, "bank_debit"),
      bank_transfers_connectors: getAchConnectors(jsonDict, "bank_transfer"),
      required_fields: jsonDict->getDynamicFieldsFromJsonDict(
        paymentMethodType === "bancontact_card",
      ),
      surcharge_details: jsonDict->getSurchargeDetails,
    }
  })
}

let getMethodsArr = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.array)
  ->Option.getOr([])
  ->Belt.Array.keepMap(JSON.Decode.object)
  ->Array.map(json => {
    {
      payment_method: getString(json, "payment_method", ""),
      payment_method_types: getPaymentMethodTypes(json, "payment_method_types"),
    }
  })
}

let getOptionalMandateType = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      amount: getInt(json, "amount", 0),
      currency: getString(json, "currency", ""),
    }
  })
}

let getMandate = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      single_use: getOptionalMandateType(json, "single_use"),
      multi_use: getOptionalMandateType(json, "multi_use"),
    }
  })
}

let paymentTypeMapper = payment_type => {
  switch payment_type {
  | "normal" => NORMAL
  | "new_mandate" => NEW_MANDATE
  | "setup_mandate" => SETUP_MANDATE
  | _ => NONE
  }
}

let paymentTypeToStringMapper = payment_type => {
  switch payment_type {
  | NORMAL => "normal"
  | NEW_MANDATE => "new_mandate"
  | SETUP_MANDATE => "setup_mandate"
  | NONE => ""
  }
}

let itemToObjMapper = dict => {
  {
    redirect_url: getString(dict, "redirect_url", ""),
    currency: getString(dict, "currency", ""),
    payment_methods: getMethodsArr(dict, "payment_methods"),
    mandate_payment: getMandate(dict, "mandate_payment"),
    payment_type: getString(dict, "payment_type", "")->paymentTypeMapper,
    merchant_name: getString(dict, "merchant_name", ""),
  }
}

let buildFromPaymentList = (plist: paymentMethodList) => {
  let paymentMethodArr = plist.payment_methods

  paymentMethodArr
  ->Array.map(paymentMethodObject => {
    let methodType = paymentMethodObject.payment_method
    let handleUserError = methodType === "wallet"
    paymentMethodObject.payment_method_types->Array.map(individualPaymentMethod => {
      let paymentMethodName = individualPaymentMethod.payment_method_type
      let bankNames = individualPaymentMethod.bank_names
      let paymentExperience = individualPaymentMethod.payment_experience->Array.map(
        experience => {
          (experience.payment_experience_type, experience.eligible_connectors)
        },
      )
      {
        paymentMethodName,
        fields: getPaymentMethodFields(
          paymentMethodName,
          individualPaymentMethod.required_fields,
          (),
        ),
        paymentFlow: paymentExperience,
        handleUserError,
        methodType,
        bankNames,
      }
    })
  })
  ->Array.reduce([], (acc, item) => {
    item->Array.forEach(obj => acc->Array.push(obj)->ignore)
    acc
  })
}

let getPaymentMethodTypeFromList = (
  ~paymentMethodListValue,
  ~paymentMethod,
  ~paymentMethodType,
) => {
  (
    paymentMethodListValue.payment_methods
    ->Array.find(item => {
      item.payment_method == paymentMethod
    })
    ->Option.getOr({
      payment_method: "card",
      payment_method_types: [],
    })
  ).payment_method_types->Array.find(item => {
    item.payment_method_type == paymentMethodType
  })
}

let getCardNetwork = (~paymentMethodType, ~cardBrand) => {
  paymentMethodType.card_networks
  ->Array.filter(cardNetwork => cardNetwork.card_network === cardBrand)
  ->Array.get(0)
  ->Option.getOr(defaultCardNetworks)
}

let paymentMethodFieldToStrMapper = (field: paymentMethodsFields) => {
  switch field {
  | Email => "Email"
  | FullName => "FullName"
  | InfoElement => "InfoElement"
  | Country => "Country"
  | Bank => "Bank"
  | SpecialField(_) => "SpecialField"
  | None => "None"
  | BillingName => "BillingName"
  | PhoneNumber => "PhoneNumber"
  | AddressLine1 => "AddressLine1"
  | AddressLine2 => "AddressLine2"
  | AddressCity => "AddressCity"
  | StateAndCity => "StateAndCity"
  | CountryAndPincode(_) => "CountryAndPincode"
  | AddressPincode => "AddressPincode"
  | AddressState => "AddressState"
  | AddressCountry(_) => "AddressCountry"
  | BlikCode => "BlikCode"
  | Currency(_) => "Currency"
  | CardNumber => "CardNumber"
  | CardExpiryMonth => "CardExpiryMonth"
  | CardExpiryYear => "CardExpiryYear"
  | CardExpiryMonthAndYear => "CardExpiryMonthAndYear"
  | CardCvc => "CardCvc"
  | CardExpiryAndCvc => "CardExpiryAndCvc"
  | ShippingName => "ShippingName"
  | ShippingAddressLine1 => "ShippingAddressLine1"
  | ShippingAddressLine2 => "ShippingAddressLine2"
  | ShippingAddressCity => "ShippingAddressCity"
  | ShippingAddressPincode => "ShippingAddressPincode"
  | ShippingAddressState => "ShippingAddressState"
  | ShippingAddressCountry(_) => "ShippingAddressCountry"
  }
}
