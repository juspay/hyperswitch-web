open Utils

type paymentFlow = InvokeSDK | RedirectToURL | QrFlow

type paymentFlowWithConnector = array<(paymentFlow, array<string>)>
type paymentMethodsFields =
  | Email
  | FullName
  | InfoElement
  | Country
  | Bank
  | BankList(array<string>)
  | SpecialField(React.element)
  | None
  | BillingName
  | PhoneNumber
  | PhoneCountryCode
  | PhoneNumberAndCountryCode
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
  | CryptoCurrencyNetworks
  | DateOfBirth
  | VpaId
  | PixKey
  | PixCPF
  | PixCNPJ
  | LanguagePreference(array<string>)
  | BankAccountNumber
  | IBAN
  | SourceBankAccountId
  | GiftCardNumber
  | GiftCardCvc

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
  | StateAndCity => 7
  | AddressCountry(_) => 8
  | CountryAndPincode(_) => 8
  | PixKey => 8
  | AddressPincode => 9
  | PixCPF => 9
  | CryptoCurrencyNetworks => 10
  | PixCNPJ => 10
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

let icon = (~size=22, ~width=size, name) => <Icon size width name />

let getPaymentMethodsFields = (~localeString: LocaleStringTypes.localeStrings) => [
  {
    paymentMethodName: "afterpay_clearpay",
    fields: [InfoElement],
    icon: Some(icon("afterpay", ~size=19)),
    displayName: localeString.payment_methods_afterpay_clearpay,
    miniIcon: None,
  },
  {
    paymentMethodName: "google_pay",
    fields: [],
    icon: Some(icon("google_pay", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_google_pay,
    miniIcon: None,
  },
  {
    paymentMethodName: "apple_pay",
    fields: [],
    icon: Some(icon("apple_pay", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_apple_pay,
    miniIcon: None,
  },
  {
    paymentMethodName: "mb_way",
    fields: [SpecialField(<PhoneNumberPaymentInput />), InfoElement],
    icon: Some(icon("mbway", ~size=19)),
    displayName: localeString.payment_methods_mb_way,
    miniIcon: None,
  },
  {
    paymentMethodName: "mobile_pay",
    fields: [InfoElement],
    icon: Some(icon("mobilepay", ~size=19)),
    displayName: localeString.payment_methods_mobile_pay,
    miniIcon: None,
  },
  {
    paymentMethodName: "ali_pay",
    fields: [InfoElement],
    icon: Some(icon("alipay", ~size=19)),
    displayName: localeString.payment_methods_ali_pay,
    miniIcon: None,
  },
  {
    paymentMethodName: "ali_pay_hk",
    fields: [InfoElement],
    icon: Some(icon("alipayhk", ~size=19)),
    displayName: localeString.payment_methods_ali_pay_hk,
    miniIcon: None,
  },
  {
    paymentMethodName: "we_chat_pay",
    fields: [InfoElement],
    icon: Some(icon("wechatpay", ~size=19)),
    displayName: localeString.payment_methods_we_chat_pay,
    miniIcon: None,
  },
  {
    paymentMethodName: "duit_now",
    fields: [InfoElement],
    icon: Some(icon("duitNow", ~size=20)),
    displayName: localeString.payment_methods_duit_now,
    miniIcon: None,
  },
  {
    paymentMethodName: "revolut_pay",
    fields: [InfoElement],
    icon: Some(icon("revolut", ~size=20)),
    displayName: localeString.payment_methods_revolut_pay,
    miniIcon: None,
  },
  {
    paymentMethodName: "affirm",
    fields: [InfoElement],
    icon: Some(icon("affirm", ~size=20)),
    displayName: localeString.payment_methods_affirm,
    miniIcon: None,
  },
  {
    paymentMethodName: "pay_safe_card",
    fields: [InfoElement],
    icon: Some(icon("pay_safe_card", ~size=19)),
    displayName: localeString.payment_methods_pay_safe_card,
    miniIcon: None,
  },
  {
    paymentMethodName: "crypto_currency",
    fields: [InfoElement],
    icon: Some(icon("crypto", ~size=19)),
    displayName: localeString.payment_methods_crypto_currency,
    miniIcon: None,
  },
  {
    paymentMethodName: "card",
    icon: Some(icon("default-card", ~size=19)),
    fields: [],
    displayName: localeString.payment_methods_card,
    miniIcon: None,
  },
  {
    paymentMethodName: "klarna",
    icon: Some(icon("klarna", ~size=19)),
    fields: [InfoElement],
    displayName: localeString.payment_methods_klarna,
    miniIcon: None,
  },
  {
    paymentMethodName: "sofort",
    icon: Some(icon("sofort", ~size=19)),
    fields: [InfoElement],
    displayName: localeString.payment_methods_sofort,
    miniIcon: None,
  },
  {
    paymentMethodName: "flexiti",
    icon: Some(icon("flexiti", ~size=19)),
    fields: [InfoElement],
    displayName: "Flixiti",
    miniIcon: None,
  },
  {
    paymentMethodName: "breadpay",
    icon: Some(icon("breadpay", ~size=19)),
    fields: [InfoElement],
    displayName: "Breadpay",
    miniIcon: None,
  },
  {
    paymentMethodName: "ach_transfer",
    icon: Some(icon("ach", ~size=19)),
    fields: [],
    displayName: localeString.payment_methods_ach_transfer,
    miniIcon: None,
  },
  {
    paymentMethodName: "bacs_transfer",
    icon: Some(icon("bank", ~size=19)),
    fields: [],
    displayName: localeString.payment_methods_bacs_transfer,
    miniIcon: None,
  },
  {
    paymentMethodName: "sepa_bank_transfer",
    icon: Some(icon("sepa", ~size=19)),
    fields: [],
    displayName: localeString.payment_methods_sepa_bank_transfer,
    miniIcon: None,
  },
  {
    paymentMethodName: "instant_bank_transfer",
    icon: Some(icon("bank", ~size=19)),
    fields: [],
    displayName: localeString.payment_methods_instant_bank_transfer,
    miniIcon: None,
  },
  {
    paymentMethodName: "instant_bank_transfer_finland",
    icon: Some(icon("bank", ~size=19)),
    fields: [],
    displayName: localeString.payment_methods_instant_bank_transfer_finland,
    miniIcon: None,
  },
  {
    paymentMethodName: "instant_bank_transfer_poland",
    icon: Some(icon("bank", ~size=19)),
    fields: [],
    displayName: localeString.payment_methods_instant_bank_transfer_poland,
    miniIcon: None,
  },
  {
    paymentMethodName: "sepa_debit",
    icon: Some(icon("sepa", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_sepa_debit,
    fields: [],
    miniIcon: None,
  },
  {
    paymentMethodName: "giropay",
    icon: Some(icon("giropay", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_giropay,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "eps",
    icon: Some(icon("eps", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_eps,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "walley",
    icon: Some(icon("walley", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_walley,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "pay_bright",
    icon: Some(icon("paybright", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_pay_bright,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "ach_debit",
    icon: Some(icon("ach", ~size=19)),
    displayName: localeString.payment_methods_ach_debit,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "bacs_debit",
    icon: Some(icon("bank", ~size=21)),
    displayName: localeString.payment_methods_bacs_debit,
    fields: [InfoElement],
    miniIcon: Some(icon("bank", ~size=19)),
  },
  {
    paymentMethodName: "becs_debit",
    icon: Some(icon("bank", ~size=21)),
    displayName: localeString.payment_methods_becs_debit,
    fields: [InfoElement],
    miniIcon: Some(icon("bank", ~size=19)),
  },
  {
    paymentMethodName: "blik",
    icon: Some(icon("blik", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_blik,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "trustly",
    icon: Some(icon("trustly", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_trustly,
    fields: [Country, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "bancontact_card",
    icon: Some(icon("bancontact", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_bancontact_card,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "online_banking_czech_republic",
    icon: Some(icon("bank", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_online_banking_czech_republic,
    fields: [Bank, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "online_banking_slovakia",
    icon: Some(icon("bank", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_online_banking_slovakia,
    fields: [Bank, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "online_banking_finland",
    icon: Some(icon("bank", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_online_banking_finland,
    fields: [Bank, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "online_banking_poland",
    icon: Some(icon("bank", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_online_banking_poland,
    fields: [Bank, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "ideal",
    icon: Some(icon("ideal", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_ideal,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "ban_connect",
    icon: None,
    displayName: localeString.payment_methods_ban_connect,
    fields: [],
    miniIcon: None,
  },
  {
    paymentMethodName: "ach_bank_debit",
    icon: Some(icon("ach-bank-debit", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_ach_bank_debit,
    fields: [],
    miniIcon: None,
  },
  {
    paymentMethodName: "przelewy24",
    icon: Some(icon("p24", ~size=19)),
    displayName: localeString.payment_methods_przelewy24,
    fields: [Email, Bank, InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "interac",
    icon: Some(icon("interac", ~size=19)),
    displayName: localeString.payment_methods_interac,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "twint",
    icon: Some(icon("twint", ~size=19)),
    displayName: localeString.payment_methods_twint,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "vipps",
    icon: Some(icon("vipps", ~size=19)),
    displayName: localeString.payment_methods_vipps,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "dana",
    icon: Some(icon("dana", ~size=19)),
    displayName: localeString.payment_methods_dana,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "go_pay",
    icon: Some(icon("go_pay", ~size=19)),
    displayName: localeString.payment_methods_go_pay,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "kakao_pay",
    icon: Some(icon("kakao_pay", ~size=19)),
    displayName: localeString.payment_methods_kakao_pay,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "gcash",
    icon: Some(icon("gcash", ~size=19)),
    displayName: localeString.payment_methods_gcash,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "momo",
    icon: Some(icon("momo", ~size=19)),
    displayName: localeString.payment_methods_momo,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "touch_n_go",
    icon: Some(icon("touch_n_go", ~size=19)),
    displayName: localeString.payment_methods_touch_n_go,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "bizum",
    icon: Some(icon("bizum", ~size=19)),
    displayName: localeString.payment_methods_bizum,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "classic",
    icon: Some(icon("cash_voucher", ~size=19, ~width=50)),
    displayName: localeString.payment_methods_classic,
    fields: [InfoElement],
    miniIcon: Some(icon("cash_voucher", ~size=19)),
  },
  {
    paymentMethodName: "online_banking_fpx",
    icon: Some(icon("online_banking_fpx", ~size=19)),
    displayName: localeString.payment_methods_online_banking_fpx,
    fields: [Bank, InfoElement], // add more fields for these payment methods
    miniIcon: None,
  },
  {
    paymentMethodName: "online_banking_thailand",
    icon: Some(icon("online_banking_thailand", ~size=19)),
    displayName: localeString.payment_methods_online_banking_thailand,
    fields: [Bank, InfoElement], // add more fields for these payment methods
    miniIcon: None,
  },
  {
    paymentMethodName: "alma",
    icon: Some(icon("alma", ~size=19)),
    displayName: localeString.payment_methods_alma,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "atome",
    icon: Some(icon("atome", ~size=19)),
    displayName: localeString.payment_methods_atome,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "multibanco_transfer",
    icon: Some(icon("multibanco", ~size=19)),
    displayName: localeString.payment_methods_multibanco_transfer,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "card_redirect",
    icon: Some(icon("default-card", ~size=19)),
    displayName: localeString.payment_methods_card_redirect,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "open_banking_uk",
    icon: Some(icon("bank", ~size=19)),
    displayName: localeString.payment_methods_pay_by_bank,
    fields: [InfoElement],
    miniIcon: Some(icon("bank", ~size=19)),
  },
  {
    paymentMethodName: "open_banking_pis",
    icon: Some(icon("bank", ~size=19)),
    displayName: localeString.payment_methods_open_banking_pis,
    fields: [InfoElement],
    miniIcon: Some(icon("bank", ~size=19)),
  },
  {
    paymentMethodName: "evoucher",
    icon: Some(icon("cash_voucher", ~size=19, ~width=50)),
    displayName: localeString.payment_methods_evoucher,
    fields: [InfoElement],
    miniIcon: Some(icon("cash_voucher", ~size=19)),
  },
  {
    paymentMethodName: "pix_transfer",
    fields: [InfoElement],
    icon: Some(icon("pix", ~size=26, ~width=40)),
    displayName: localeString.payment_methods_pix_transfer,
    miniIcon: None,
  },
  {
    paymentMethodName: "boleto",
    icon: Some(icon("boleto", ~size=21, ~width=25)),
    displayName: localeString.payment_methods_boleto,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "paypal",
    icon: Some(icon("paypal", ~size=21, ~width=25)),
    displayName: localeString.payment_methods_paypal,
    fields: [],
    miniIcon: None,
  },
  {
    paymentMethodName: "local_bank_transfer_transfer",
    fields: [InfoElement],
    icon: Some(icon("union-pay", ~size=19, ~width=30)),
    displayName: localeString.payment_methods_local_bank_transfer_transfer,
    miniIcon: None,
  },
  {
    paymentMethodName: "mifinity",
    fields: [InfoElement],
    icon: Some(icon("mifinity")),
    displayName: localeString.payment_methods_mifinity,
    miniIcon: None,
  },
  {
    paymentMethodName: "skrill",
    fields: [InfoElement],
    icon: Some(icon("skrill", ~size=19)),
    displayName: "Skrill",
    miniIcon: None,
  },
  {
    paymentMethodName: "bluecode",
    fields: [InfoElement],
    icon: Some(icon("bluecode")),
    displayName: "Bluecode",
    miniIcon: None,
  },
  {
    paymentMethodName: "upi_collect",
    fields: [InfoElement],
    icon: Some(icon("bhim_upi", ~size=19)),
    displayName: localeString.payment_methods_upi_collect,
    miniIcon: None,
  },
  {
    paymentMethodName: "upi_intent",
    fields: [InfoElement],
    icon: Some(icon("bhim_upi", ~size=19)),
    displayName: "UPI Intent",
    miniIcon: None,
  },
  {
    paymentMethodName: "eft",
    icon: Some(icon("eft", ~size=19)),
    fields: [InfoElement],
    displayName: localeString.payment_methods_eft,
    miniIcon: None,
  },
  {
    paymentMethodName: "givex",
    icon: Some(icon("givex", ~size=19, ~width=25)),
    displayName: localeString.payment_methods_givex,
    fields: [InfoElement],
    miniIcon: None,
  },
  {
    paymentMethodName: "open_banking",
    icon: Some(icon("bank", ~size=19)),
    displayName: localeString.payment_methods_pay_by_bank,
    fields: [InfoElement],
    miniIcon: Some(icon("bank", ~size=19)),
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
  | ("user_gift_card_number", _) => GiftCardNumber
  | ("user_card_expiry_month", true) => CardExpiryMonth
  | ("user_card_expiry_year", true) => CardExpiryYear
  | ("user_card_cvc", true) => CardCvc
  | ("user_shipping_name", _) => ShippingName
  | ("user_shipping_address_line1", _) => ShippingAddressLine1
  | ("user_shipping_address_line2", _) => ShippingAddressLine2
  | ("user_shipping_address_city", _) => ShippingAddressCity
  | ("user_shipping_address_pincode", _) => ShippingAddressPincode
  | ("user_shipping_address_state", _) => ShippingAddressState
  | ("user_crypto_currency_network", _) => CryptoCurrencyNetworks
  | ("user_date_of_birth", _) => DateOfBirth
  | ("user_gift_card_pin", _) => GiftCardCvc
  | ("user_phone_number_country_code", _) => PhoneCountryCode
  | ("user_vpa_id", _) => VpaId
  | ("user_cpf", _) => PixCPF
  | ("user_cnpj", _) => PixCNPJ
  | ("user_pix_key", _) => PixKey
  | ("user_bank_account_number", _) => BankAccountNumber
  | ("user_iban", _) => BankAccountNumber
  | ("user_source_bank_account_id", _) => SourceBankAccountId
  | _ => None
  }
}

let countryData = CountryStateDataRefs.countryDataRef.contents

let getOptionsFromPaymentMethodFieldType = (dict, key, ~isAddressCountry=true) => {
  let options = dict->getArrayValFromJsonDict(key, "options")
  switch options->Array.get(0)->Option.getOr("") {
  | "" => None
  | "ALL" => {
      let countryArr = countryData->Array.map(item => item.countryName)
      isAddressCountry ? AddressCountry(countryArr) : ShippingAddressCountry(countryArr)
    }
  | _ => {
      let countryArr = countryData->Array.reduce([], (acc, country) => {
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
      let options = dict->getArrayValFromJsonDict("user_currency", "options")
      Currency(options)
    }
  | "user_country" => dict->getOptionsFromPaymentMethodFieldType("user_country")
  | "user_address_country" => dict->getOptionsFromPaymentMethodFieldType("user_address_country")
  | "user_shipping_address_country" =>
    dict->getOptionsFromPaymentMethodFieldType(
      "user_shipping_address_country",
      ~isAddressCountry=false,
    )
  | "language_preference" => {
      let options = dict->getArrayValFromJsonDict("language_preference", "options")
      LanguagePreference(options)
    }
  | "user_bank_options" => {
      let options = dict->getArrayValFromJsonDict("user_bank_options", "options")
      BankList(options)
    }
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
  ~localeString,
  ~isSavedCardFlow=false,
  ~isAllStoredCardsHaveName=false,
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
      getPaymentMethodsFields(~localeString)
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

let getPaymentDetails = (arr: array<string>, ~localeString) => {
  let finalArr = []
  let paymentMethodsFields = getPaymentMethodsFields(~localeString)
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

type cardType = Credit | Debit

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
  pm_auth_connector: option<string>,
}

type methods = {
  payment_method: string,
  payment_method_types: array<paymentMethodTypes>,
}

let defaultMethods = {
  payment_method: "card",
  payment_method_types: [],
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
  collect_billing_details_from_wallets: bool,
  is_tax_calculation_enabled: bool,
  isGuestCustomer: option<bool>,
}

let defaultPaymentMethodType = {
  payment_method_type: "",
  payment_experience: [],
  card_networks: [],
  bank_names: [],
  bank_debits_connectors: [],
  bank_transfers_connectors: [],
  required_fields: [],
  surcharge_details: None,
  pm_auth_connector: None,
}

let defaultList = {
  redirect_url: "",
  currency: "",
  payment_methods: [],
  mandate_payment: None,
  payment_type: NONE,
  merchant_name: "",
  collect_billing_details_from_wallets: true,
  is_tax_calculation_enabled: false,
  isGuestCustomer: None,
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
    getJsonFromDict(dict, "required_fields", JSON.Encode.null)
    ->getDictFromJson
    ->Dict.valuesToArray

  requiredFields->Array.map(requiredField => {
    let requiredFieldsDict = requiredField->getDictFromJson
    {
      required_field: requiredFieldsDict->getString("required_field", ""),
      display_name: requiredFieldsDict->getString("display_name", ""),
      field_type: requiredFieldsDict->getFieldType(isBancontact),
      value: requiredFieldsDict->getString("value", ""),
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
      pm_auth_connector: getOptionString(jsonDict, "pm_auth_connector"),
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
    collect_billing_details_from_wallets: getBool(
      dict,
      "collect_billing_details_from_wallets",
      true,
    ),
    is_tax_calculation_enabled: getBool(dict, "is_tax_calculation_enabled", false),
    isGuestCustomer: getOptionBool(dict, "is_guest_customer"),
  }
}

let buildFromPaymentList = (pList, ~localeString) => {
  let paymentMethodArr = pList.payment_methods

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
          ~localeString,
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
    ->Option.getOr(defaultMethods)
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

let getPaymentExperienceTypeFromPML = (
  ~paymentMethodList: paymentMethodList,
  ~paymentMethodName,
  ~paymentMethodType,
) => {
  paymentMethodList.payment_methods
  ->Array.filter(paymentMethod => paymentMethod.payment_method === paymentMethodName)
  ->Array.get(0)
  ->Option.flatMap(method =>
    method.payment_method_types
    ->Array.filter(methodTypes => methodTypes.payment_method_type === paymentMethodType)
    ->Array.get(0)
  )
  ->Option.flatMap(paymentMethodTypes =>
    paymentMethodTypes.payment_experience
    ->Array.map(paymentExperience => paymentExperience.payment_experience_type)
    ->Some
  )
  ->Option.getOr([])
}
