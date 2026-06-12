type fieldTexts = {
  label: string,
  placeholder: string,
}

let lookupLocaleKey = (key: string, locale: LocaleStringTypes.localeStrings): option<string> =>
  switch key {
  | "cardNumberLabel" => Some(locale.cardNumberLabel)
  | "localeDirection" => Some(locale.localeDirection)
  | "sortCodeText" => Some(locale.sortCodeText)
  | "cvcTextLabel" => Some(locale.cvcTextLabel)
  | "emailLabel" => Some(locale.emailLabel)
  | "ibanEmptyText" => Some(locale.ibanEmptyText)
  | "ibanInvalidText" => Some(locale.ibanInvalidText)
  | "emailEmptyText" => Some(locale.emailEmptyText)
  | "emailInvalidText" => Some(locale.emailInvalidText)
  | "accountNumberText" => Some(locale.accountNumberText)
  | "accountNumberInvalidText" => Some(locale.accountNumberInvalidText)
  | "sortCodeInvalidText" => Some(locale.sortCodeInvalidText)
  | "fullNameLabel" => Some(locale.fullNameLabel)
  | "line1Label" => Some(locale.line1Label)
  | "line1Placeholder" => Some(locale.line1Placeholder)
  | "line1EmptyText" => Some(locale.line1EmptyText)
  | "line2Label" => Some(locale.line2Label)
  | "line2Placeholder" => Some(locale.line2Placeholder)
  | "line2EmptyText" => Some(locale.line2EmptyText)
  | "cityLabel" => Some(locale.cityLabel)
  | "cityEmptyText" => Some(locale.cityEmptyText)
  | "postalCodeLabel" => Some(locale.postalCodeLabel)
  | "postalCodeEmptyText" => Some(locale.postalCodeEmptyText)
  | "postalCodeInvalidText" => Some(locale.postalCodeInvalidText)
  | "stateLabel" => Some(locale.stateLabel)
  | "stateEmptyText" => Some(locale.stateEmptyText)
  | "fullNamePlaceholder" => Some(locale.fullNamePlaceholder)
  | "countryLabel" => Some(locale.countryLabel)
  | "currencyLabel" => Some(locale.currencyLabel)
  | "bankLabel" => Some(locale.bankLabel)
  | "documentTypeLabel" => Some(locale.documentTypeLabel)
  | "redirectText" => Some(locale.redirectText)
  | "bankDetailsText" => Some(locale.bankDetailsText)
  | "orPayUsing" => Some(locale.orPayUsing)
  | "addNewCard" => Some(locale.addNewCard)
  | "useExisitingSavedCards" => Some(locale.useExisitingSavedCards)
  | "saveCardDetails" => Some(locale.saveCardDetails)
  | "addBankAccount" => Some(locale.addBankAccount)
  | "becsDebitTerms" => Some(locale.becsDebitTerms)
  | "payNowButton" => Some(locale.payNowButton)
  | "cardNumberEmptyText" => Some(locale.cardNumberEmptyText)
  | "cardExpiryDateEmptyText" => Some(locale.cardExpiryDateEmptyText)
  | "cvcNumberEmptyText" => Some(locale.cvcNumberEmptyText)
  | "enterFieldsText" => Some(locale.enterFieldsText)
  | "enterValidDetailsText" => Some(locale.enterValidDetailsText)
  | "selectPaymentMethodText" => Some(locale.selectPaymentMethodText)
  | "card" => Some(locale.card)
  | "surchargeMsgAmountForOneClickWallets" => Some(locale.surchargeMsgAmountForOneClickWallets)
  | "billingNameLabel" => Some(locale.billingNameLabel)
  | "billingNamePlaceholder" => Some(locale.billingNamePlaceholder)
  | "cardHolderName" => Some(locale.cardHolderName)
  | "on" => Some(locale.on)
  | "and" => Some(locale.\"and")
  | "billingDetailsText" => Some(locale.billingDetailsText)
  | "socialSecurityNumberLabel" => Some(locale.socialSecurityNumberLabel)
  | "saveWalletDetails" => Some(locale.saveWalletDetails)
  | "newPaymentMethods" => Some(locale.newPaymentMethods)
  | "useExistingPaymentMethods" => Some(locale.useExistingPaymentMethods)
  | "cardNickname" => Some(locale.cardNickname)
  | "nicknamePlaceholder" => Some(locale.nicknamePlaceholder)
  | "cardExpiredText" => Some(locale.cardExpiredText)
  | "cardHeader" => Some(locale.cardHeader)
  | "cardNotEligibleText" => Some(locale.cardNotEligibleText)
  | "currencyNetwork" => Some(locale.currencyNetwork)
  | "expiryPlaceholder" => Some(locale.expiryPlaceholder)
  | "dateOfBirth" => Some(locale.dateOfBirth)
  | "vpaIdLabel" => Some(locale.vpaIdLabel)
  | "vpaIdEmptyText" => Some(locale.vpaIdEmptyText)
  | "vpaIdInvalidText" => Some(locale.vpaIdInvalidText)
  | "dateofBirthRequiredText" => Some(locale.dateofBirthRequiredText)
  | "dateOfBirthInvalidText" => Some(locale.dateOfBirthInvalidText)
  | "dateOfBirthPlaceholderText" => Some(locale.dateOfBirthPlaceholderText)
  | "formFundsInfoText" => Some(locale.formFundsInfoText)
  | "formEditText" => Some(locale.formEditText)
  | "formSaveText" => Some(locale.formSaveText)
  | "formSubmitText" => Some(locale.formSubmitText)
  | "formSubmittingText" => Some(locale.formSubmittingText)
  | "formSubheaderBillingDetailsText" => Some(locale.formSubheaderBillingDetailsText)
  | "formSubheaderCardText" => Some(locale.formSubheaderCardText)
  | "formHeaderReviewText" => Some(locale.formHeaderReviewText)
  | "formHeaderEnterCardText" => Some(locale.formHeaderEnterCardText)
  | "formHeaderSelectBankText" => Some(locale.formHeaderSelectBankText)
  | "formHeaderSelectWalletText" => Some(locale.formHeaderSelectWalletText)
  | "formHeaderSelectAccountText" => Some(locale.formHeaderSelectAccountText)
  | "formFieldACHRoutingNumberLabel" => Some(locale.formFieldACHRoutingNumberLabel)
  | "formFieldSepaIbanLabel" => Some(locale.formFieldSepaIbanLabel)
  | "formFieldSepaBicLabel" => Some(locale.formFieldSepaBicLabel)
  | "formFieldPixIdLabel" => Some(locale.formFieldPixIdLabel)
  | "formFieldBankAccountNumberLabel" => Some(locale.formFieldBankAccountNumberLabel)
  | "formFieldPhoneNumberLabel" => Some(locale.formFieldPhoneNumberLabel)
  | "formFieldCountryCodeLabel" => Some(locale.formFieldCountryCodeLabel)
  | "formFieldCountryCodeRequiredLabel" => Some(locale.formFieldCountryCodeRequiredLabel)
  | "formFieldBankNameLabel" => Some(locale.formFieldBankNameLabel)
  | "formFieldBankCityLabel" => Some(locale.formFieldBankCityLabel)
  | "formFieldCardHoldernamePlaceholder" => Some(locale.formFieldCardHoldernamePlaceholder)
  | "formFieldBankNamePlaceholder" => Some(locale.formFieldBankNamePlaceholder)
  | "formFieldBankCityPlaceholder" => Some(locale.formFieldBankCityPlaceholder)
  | "formFieldEmailPlaceholder" => Some(locale.formFieldEmailPlaceholder)
  | "formFieldPhoneNumberPlaceholder" => Some(locale.formFieldPhoneNumberPlaceholder)
  | "formFieldInvalidRoutingNumber" => Some(locale.formFieldInvalidRoutingNumber)
  | "infoCardRefId" => Some(locale.infoCardRefId)
  | "infoCardErrCode" => Some(locale.infoCardErrCode)
  | "infoCardErrMsg" => Some(locale.infoCardErrMsg)
  | "infoCardErrReason" => Some(locale.infoCardErrReason)
  | "payoutFromText" => Some(locale.payoutFromText(""))
  | "payoutStatusFailedMessage" => Some(locale.payoutStatusFailedMessage)
  | "payoutStatusPendingMessage" => Some(locale.payoutStatusPendingMessage)
  | "payoutStatusSuccessMessage" => Some(locale.payoutStatusSuccessMessage)
  | "payoutStatusFailedText" => Some(locale.payoutStatusFailedText)
  | "payoutStatusPendingText" => Some(locale.payoutStatusPendingText)
  | "payoutStatusSuccessText" => Some(locale.payoutStatusSuccessText)
  | "pixCNPJInvalidText" => Some(locale.pixCNPJInvalidText)
  | "pixCNPJEmptyText" => Some(locale.pixCNPJEmptyText)
  | "pixCNPJLabel" => Some(locale.pixCNPJLabel)
  | "pixCNPJPlaceholder" => Some(locale.pixCNPJPlaceholder)
  | "pixCPFInvalidText" => Some(locale.pixCPFInvalidText)
  | "pixCPFEmptyText" => Some(locale.pixCPFEmptyText)
  | "pixCPFLabel" => Some(locale.pixCPFLabel)
  | "pixCPFPlaceholder" => Some(locale.pixCPFPlaceholder)
  | "pixKeyEmptyText" => Some(locale.pixKeyEmptyText)
  | "pixKeyLabel" => Some(locale.pixKeyLabel)
  | "pixKeyPlaceholder" => Some(locale.pixKeyPlaceholder)
  | "sourceBankAccountIdEmptyText" => Some(locale.sourceBankAccountIdEmptyText)
  | "invalidCardHolderNameError" => Some(locale.invalidCardHolderNameError)
  | "invalidNickNameError" => Some(locale.invalidNickNameError)
  | "expiry" => Some(locale.expiry)
  | "payment_methods_afterpay_clearpay" => Some(locale.payment_methods_afterpay_clearpay)
  | "payment_methods_google_pay" => Some(locale.payment_methods_google_pay)
  | "payment_methods_apple_pay" => Some(locale.payment_methods_apple_pay)
  | "payment_methods_samsung_pay" => Some(locale.payment_methods_samsung_pay)
  | "payment_methods_mb_way" => Some(locale.payment_methods_mb_way)
  | "payment_methods_mobile_pay" => Some(locale.payment_methods_mobile_pay)
  | "payment_methods_ali_pay" => Some(locale.payment_methods_ali_pay)
  | "payment_methods_ali_pay_hk" => Some(locale.payment_methods_ali_pay_hk)
  | "payment_methods_we_chat_pay" => Some(locale.payment_methods_we_chat_pay)
  | "payment_methods_duit_now" => Some(locale.payment_methods_duit_now)
  | "payment_methods_revolut_pay" => Some(locale.payment_methods_revolut_pay)
  | "payment_methods_affirm" => Some(locale.payment_methods_affirm)
  | "payment_methods_pay_safe_card" => Some(locale.payment_methods_pay_safe_card)
  | "payment_methods_crypto_currency" => Some(locale.payment_methods_crypto_currency)
  | "payment_methods_card" => Some(locale.payment_methods_card)
  | "payment_methods_klarna" => Some(locale.payment_methods_klarna)
  | "payment_methods_sofort" => Some(locale.payment_methods_sofort)
  | "payment_methods_ach_transfer" => Some(locale.payment_methods_ach_transfer)
  | "payment_methods_bacs_transfer" => Some(locale.payment_methods_bacs_transfer)
  | "payment_methods_sepa_bank_transfer" => Some(locale.payment_methods_sepa_bank_transfer)
  | "payment_methods_instant_bank_transfer" => Some(locale.payment_methods_instant_bank_transfer)
  | "payment_methods_instant_bank_transfer_finland" =>
    Some(locale.payment_methods_instant_bank_transfer_finland)
  | "payment_methods_instant_bank_transfer_poland" =>
    Some(locale.payment_methods_instant_bank_transfer_poland)
  | "payment_methods_sepa_debit" => Some(locale.payment_methods_sepa_debit)
  | "payment_methods_giropay" => Some(locale.payment_methods_giropay)
  | "payment_methods_eps" => Some(locale.payment_methods_eps)
  | "payment_methods_walley" => Some(locale.payment_methods_walley)
  | "payment_methods_pay_bright" => Some(locale.payment_methods_pay_bright)
  | "payment_methods_ach_debit" => Some(locale.payment_methods_ach_debit)
  | "payment_methods_bacs_debit" => Some(locale.payment_methods_bacs_debit)
  | "payment_methods_becs_debit" => Some(locale.payment_methods_becs_debit)
  | "payment_methods_blik" => Some(locale.payment_methods_blik)
  | "payment_methods_trustly" => Some(locale.payment_methods_trustly)
  | "payment_methods_bancontact_card" => Some(locale.payment_methods_bancontact_card)
  | "payment_methods_online_banking_czech_republic" =>
    Some(locale.payment_methods_online_banking_czech_republic)
  | "payment_methods_online_banking_slovakia" =>
    Some(locale.payment_methods_online_banking_slovakia)
  | "payment_methods_online_banking_finland" => Some(locale.payment_methods_online_banking_finland)
  | "payment_methods_online_banking_poland" => Some(locale.payment_methods_online_banking_poland)
  | "payment_methods_ideal" => Some(locale.payment_methods_ideal)
  | "payment_methods_ban_connect" => Some(locale.payment_methods_ban_connect)
  | "payment_methods_ach_bank_debit" => Some(locale.payment_methods_ach_bank_debit)
  | "payment_methods_przelewy24" => Some(locale.payment_methods_przelewy24)
  | "payment_methods_interac" => Some(locale.payment_methods_interac)
  | "payment_methods_twint" => Some(locale.payment_methods_twint)
  | "payment_methods_vipps" => Some(locale.payment_methods_vipps)
  | "payment_methods_dana" => Some(locale.payment_methods_dana)
  | "payment_methods_go_pay" => Some(locale.payment_methods_go_pay)
  | "payment_methods_kakao_pay" => Some(locale.payment_methods_kakao_pay)
  | "payment_methods_gcash" => Some(locale.payment_methods_gcash)
  | "payment_methods_momo" => Some(locale.payment_methods_momo)
  | "payment_methods_touch_n_go" => Some(locale.payment_methods_touch_n_go)
  | "payment_methods_bizum" => Some(locale.payment_methods_bizum)
  | "payment_methods_classic" => Some(locale.payment_methods_classic)
  | "payment_methods_online_banking_fpx" => Some(locale.payment_methods_online_banking_fpx)
  | "payment_methods_online_banking_thailand" =>
    Some(locale.payment_methods_online_banking_thailand)
  | "payment_methods_alma" => Some(locale.payment_methods_alma)
  | "payment_methods_atome" => Some(locale.payment_methods_atome)
  | "payment_methods_multibanco_transfer" => Some(locale.payment_methods_multibanco_transfer)
  | "payment_methods_card_redirect" => Some(locale.payment_methods_card_redirect)
  | "payment_methods_pay_by_bank" => Some(locale.payment_methods_pay_by_bank)
  | "payment_methods_open_banking_pis" => Some(locale.payment_methods_open_banking_pis)
  | "payment_methods_evoucher" => Some(locale.payment_methods_evoucher)
  | "payment_methods_pix_transfer" => Some(locale.payment_methods_pix_transfer)
  | "payment_methods_boleto" => Some(locale.payment_methods_boleto)
  | "payment_methods_paypal" => Some(locale.payment_methods_paypal)
  | "payment_methods_local_bank_transfer_transfer" =>
    Some(locale.payment_methods_local_bank_transfer_transfer)
  | "payment_methods_mifinity" => Some(locale.payment_methods_mifinity)
  | "payment_methods_upi_collect" => Some(locale.payment_methods_upi_collect)
  | "payment_methods_eft" => Some(locale.payment_methods_eft)
  | "payment_methods_givex" => Some(locale.payment_methods_givex)
  | "payment_methods_saved_methods" => Some(locale.payment_methods_saved_methods)
  | "giftCardSectionTitle" => Some(locale.giftCardSectionTitle)
  | "giftCardNumberLabel" => Some(locale.giftCardNumberLabel)
  | "giftCardNumberPlaceholder" => Some(locale.giftCardNumberPlaceholder)
  | "giftCardNumberEmptyText" => Some(locale.giftCardNumberEmptyText)
  | "giftCardNumberInvalidText" => Some(locale.giftCardNumberInvalidText)
  | "giftCardPinLabel" => Some(locale.giftCardPinLabel)
  | "giftCardPinPlaceholder" => Some(locale.giftCardPinPlaceholder)
  | "giftCardPinEmptyText" => Some(locale.giftCardPinEmptyText)
  | "giftCardPinInvalidText" => Some(locale.giftCardPinInvalidText)
  | "cardText" => Some(locale.cardText)
  | "giftCardAppliedText" => Some(locale.giftCardAppliedText)
  | "giftCardPaymentCompleteMessage" => Some(locale.giftCardPaymentCompleteMessage)
  | "installmentPayInInstallments" => Some(locale.installmentPayInInstallments)
  | "installmentInterestFree" => Some(locale.installmentInterestFree)
  | "installmentWithInterest" => Some(locale.installmentWithInterest)
  | "installmentTotal" => Some(locale.installmentTotal)
  | "installmentSelectPlanError" => Some(locale.installmentSelectPlanError)
  | "installmentSelectPlanPlaceholder" => Some(locale.installmentSelectPlanPlaceholder)
  | "showMore" => Some(locale.showMore)
  | "showLess" => Some(locale.showLess)
  | "refreshingText" => Some(locale.refreshingText)
  | _ => None
  }

let resolveFieldTexts = (
  ~field: SuperpositionTypes.fieldConfig,
  ~localeObject: LocaleStringTypes.localeStrings,
): fieldTexts => {
  let label = switch field.merchantProvidedDisplayName {
  | Some(name) => name
  | None =>
    field.labelLocalizationKey
    ->Option.flatMap(key => lookupLocaleKey(key, localeObject))
    ->Option.getOr(field.defaultLabelText)
  }

  let placeholder = switch field.merchantProvidedPlaceholderText {
  | Some(text) => text
  | None =>
    field.placeholderLocalizationKey
    ->Option.flatMap(key => lookupLocaleKey(key, localeObject))
    ->Option.getOr(label)
  }

  {label, placeholder}
}

let resolveValidator = (
  ~field: SuperpositionTypes.fieldConfig,
  ~localeObject: LocaleStringTypes.localeStrings,
) => {
  let requiredRule = field.isRequired ? [Validation.Required] : []

  let semanticRule = switch field.validationRuleType {
  | Some("phone") => [Validation.Phone]
  | Some("iban") => [Validation.IBAN]
  | Some("routing_number") => [Validation.RoutingNumber]
  | Some("blik_code") => [Validation.BlikCode]
  | Some("gift_card_number") => [Validation.GiftCardNumber]
  | Some("gift_card_pin") => [Validation.GiftCardPin]
  | Some("pix_key") => [Validation.PixKey]
  | Some("pix_cpf") => [Validation.PixCPF]
  | Some("pix_cnpj") => [Validation.PixCNPJ]
  | Some("regex") =>
    switch field.validationRegexPattern {
    | Some(pattern) => [Validation.Generic(pattern)]
    | None => []
    }
  | _ => []
  }

  let maxLengthRule = [Validation.MaxLength(field.maxInputLength->Option.getOr(255))]

  let rules = Array.concat(Array.concat(requiredRule, semanticRule), maxLengthRule)

  Validation.createFieldValidator(
    rules,
    ~enabledCardSchemes=[],
    ~localeObject=localeObject->Obj.magic,
  )
}

let findCryptoCurrencyField = (~allFields: array<SuperpositionTypes.fieldConfig>): option<
  SuperpositionTypes.fieldConfig,
> => allFields->Array.find(f => f.fieldRenderType === SuperpositionTypes.CryptoCurrency)

let extractValuesFromPMLRequiredFields = (
  requiredFields: array<PaymentMethodsRecord.required_fields>,
) => {
  requiredFields->Array.reduce(Dict.make(), (acc, field) => {
    if field.required_field !== "" {
      acc->Dict.set(field.required_field, field.value)
    }
    acc
  })
}

let removeBillingDetailsIfUseBillingAddress = (
  missingRequiredFields: array<SuperpositionTypes.fieldConfig>,
  billingAddress: PaymentType.billingAddress,
) => {
  if billingAddress.isUseBillingAddress {
    missingRequiredFields->Array.filter(requiredField => {
      !(requiredField.confirmRequestWritePath->String.startsWith("payment_method_data.billing."))
    })
  } else {
    missingRequiredFields
  }
}

let buildSuperpositionBaseContext = (
  ~paymentMethod: string,
  ~paymentMethodType: string,
  ~country: string,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
) => {
  let mandateType = switch paymentMethodListValue.payment_type {
  | NEW_MANDATE => "new_mandate"
  | SETUP_MANDATE => "setup_mandate"
  | NORMAL => "non_mandate"
  | NONE => "non_mandate"
  }

  let collectBilling = paymentMethodListValue.collect_billing_details_from_wallets
    ? "true"
    : "false"
  let collectShipping = "false"

  let context: SuperpositionTypes.superpositionBaseContext = {
    payment_method: paymentMethod,
    payment_method_type: paymentMethodType,
    country,
    mandate_type: mandateType,
    collect_shipping_details_from_wallet_connector: collectShipping,
    collect_billing_details_from_wallet_connector: collectBilling,
  }
  context
}

let checkIfNameIsValid = (
  requiredFieldsType: array<PaymentMethodsRecord.required_fields>,
  paymentMethodFields,
  field: RecoilAtomTypes.field,
) => {
  requiredFieldsType
  ->Array.filter(required_field => required_field.field_type === paymentMethodFields)
  ->Array.reduce(true, (acc, item) => {
    let fieldNameArr = field.value->String.split(" ")
    let requiredFieldsArr = item.required_field->String.split(".")
    let fieldValue = switch requiredFieldsArr
    ->Array.get(requiredFieldsArr->Array.length - 1)
    ->Option.getOr("") {
    | "first_name" => fieldNameArr->Array.get(0)->Option.getOr("")
    | "last_name" => fieldNameArr->Array.get(1)->Option.getOr("")
    | _ => field.value
    }
    acc && fieldValue !== ""
  })
}

let usePaymentMethodTypeFromList = (
  ~paymentMethodListValue,
  ~paymentMethod,
  ~paymentMethodType,
) => {
  React.useMemo(() => {
    PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~paymentMethodListValue,
      ~paymentMethod,
      ~paymentMethodType=PaymentUtils.getPaymentMethodName(
        ~paymentMethodType=paymentMethod,
        ~paymentMethodName=paymentMethodType,
      ),
    )->Option.getOr(PaymentMethodsRecord.defaultPaymentMethodType)
  }, (paymentMethodListValue, paymentMethod, paymentMethodType))
}

let getNameFromString = (name, requiredFieldsArr) => {
  let nameArr = name->String.split(" ")
  let nameArrLength = nameArr->Array.length
  switch requiredFieldsArr->Array.get(requiredFieldsArr->Array.length - 1)->Option.getOr("") {
  | "first_name" => {
      let end = nameArrLength === 1 ? nameArrLength : nameArrLength - 1
      nameArr
      ->Array.slice(~start=0, ~end)
      ->Array.reduce("", (acc, item) => {
        acc ++ " " ++ item
      })
    }
  | "last_name" =>
    if nameArrLength === 1 {
      ""
    } else {
      nameArr->Array.get(nameArrLength - 1)->Option.getOr(name)
    }
  | _ => name
  }->String.trim
}

let getNameFromFirstAndLastName = (~firstName, ~lastName, ~requiredFieldsArr) => {
  switch requiredFieldsArr->Array.get(requiredFieldsArr->Array.length - 1)->Option.getOr("") {
  | "first_name" => firstName
  | "last_name" => lastName
  | _ => firstName->String.concatMany([" ", lastName])
  }->String.trim
}

let defaultRequiredFieldsArray: array<PaymentMethodsRecord.required_fields> = [
  {
    required_field: "email",
    display_name: "email",
    field_type: Email,
    value: "",
  },
  {
    required_field: "payment_method_data.billing.address.state",
    display_name: "state",
    field_type: AddressState,
    value: "",
  },
  {
    required_field: "payment_method_data.billing.address.first_name",
    display_name: "billing_first_name",
    field_type: BillingName,
    value: "",
  },
  {
    required_field: "payment_method_data.billing.address.city",
    display_name: "city",
    field_type: AddressCity,
    value: "",
  },
  {
    required_field: "payment_method_data.billing.address.country",
    display_name: "country",
    field_type: AddressCountry(["ALL"]),
    value: "",
  },
  {
    required_field: "payment_method_data.billing.address.line1",
    display_name: "line",
    field_type: AddressLine1,
    value: "",
  },
  {
    required_field: "payment_method_data.billing.address.zip",
    display_name: "zip",
    field_type: AddressPincode,
    value: "",
  },
  {
    required_field: "payment_method_data.billing.address.last_name",
    display_name: "billing_last_name",
    field_type: BillingName,
    value: "",
  },
]

let getApplePayRequiredFields = (
  ~billingContact: ApplePayTypes.billingContact,
  ~shippingContact: ApplePayTypes.shippingContact,
  ~requiredFields=defaultRequiredFieldsArray,
) => {
  requiredFields->Array.reduce(Dict.make(), (acc, item) => {
    let requiredFieldsArr = item.required_field->String.split(".")

    let getName = (firstName, lastName) => {
      switch requiredFieldsArr->Array.get(requiredFieldsArr->Array.length - 1)->Option.getOr("") {
      | "first_name" => firstName
      | "last_name" => lastName
      | _ => firstName->String.concatMany([" ", lastName])
      }->String.trim
    }

    let getAddressLine = (addressLines, index) => {
      addressLines->Array.get(index)->Option.getOr("")
    }

    let billingCountryCode = billingContact.countryCode->String.toUpperCase
    let shippingCountryCode = shippingContact.countryCode->String.toUpperCase

    let fieldVal = switch item.field_type {
    | FullName
    | BillingName =>
      getNameFromFirstAndLastName(
        ~firstName=billingContact.givenName,
        ~lastName=billingContact.familyName,
        ~requiredFieldsArr,
      )
    | AddressLine1 => billingContact.addressLines->getAddressLine(0)
    | AddressLine2 => billingContact.addressLines->getAddressLine(1)
    | AddressCity => billingContact.locality
    | AddressState => billingContact.administrativeArea
    | Country
    | AddressCountry(_) => billingCountryCode
    | AddressPincode => billingContact.postalCode
    | Email => shippingContact.emailAddress
    | PhoneNumber => shippingContact.phoneNumber
    | ShippingName => getName(shippingContact.givenName, shippingContact.familyName)
    | ShippingAddressLine1 => shippingContact.addressLines->getAddressLine(0)
    | ShippingAddressLine2 => shippingContact.addressLines->getAddressLine(1)
    | ShippingAddressCity => shippingContact.locality
    | ShippingAddressState => shippingContact.administrativeArea
    | ShippingAddressCountry(_) => shippingCountryCode
    | ShippingAddressPincode => shippingContact.postalCode
    | _ => ""
    }

    if fieldVal !== "" {
      acc->Dict.set(item.required_field, fieldVal->JSON.Encode.string)
    }

    acc
  })
}

let getGooglePayRequiredFields = (
  ~billingContact: GooglePayType.billingContact,
  ~shippingContact: GooglePayType.billingContact,
  ~requiredFields=defaultRequiredFieldsArray,
  ~email,
) => {
  requiredFields->Array.reduce(Dict.make(), (acc, item) => {
    let requiredFieldsArr = item.required_field->String.split(".")

    let fieldVal = switch item.field_type {
    | FullName => billingContact.name->getNameFromString(requiredFieldsArr)
    | BillingName => billingContact.name->getNameFromString(requiredFieldsArr)
    | AddressLine1 => billingContact.address1
    | AddressLine2 => billingContact.address2
    | AddressCity => billingContact.locality
    | AddressState => billingContact.administrativeArea
    | Country
    | AddressCountry(_) =>
      billingContact.countryCode
    | AddressPincode => billingContact.postalCode
    | Email => email
    | PhoneNumber =>
      shippingContact.phoneNumber->String.replaceAll(" ", "")->String.replaceAll("-", "")
    | ShippingName => shippingContact.name->getNameFromString(requiredFieldsArr)
    | ShippingAddressLine1 => shippingContact.address1
    | ShippingAddressLine2 => shippingContact.address2
    | ShippingAddressCity => shippingContact.locality
    | ShippingAddressState => shippingContact.administrativeArea
    | ShippingAddressCountry(_) => shippingContact.countryCode
    | ShippingAddressPincode => shippingContact.postalCode
    | _ => ""
    }

    if fieldVal !== "" {
      acc->Dict.set(item.required_field, fieldVal->JSON.Encode.string)
    }

    acc
  })
}

let getPaypalRequiredFields = (
  ~details: PaypalSDKTypes.details,
  ~paymentMethodTypes: PaymentMethodsRecord.paymentMethodTypes,
) => {
  paymentMethodTypes.required_fields->Array.reduce(Dict.make(), (acc, item) => {
    let requiredFieldsArr = item.required_field->String.split(".")

    let fieldVal = switch item.field_type {
    | ShippingName => {
        let name = details.shippingAddress.recipientName
        name->Option.map(getNameFromString(_, requiredFieldsArr))
      }
    | ShippingAddressLine1 => details.shippingAddress.line1
    | ShippingAddressLine2 => details.shippingAddress.line2
    | ShippingAddressCity => details.shippingAddress.city
    | ShippingAddressState => {
        let administrativeArea = details.shippingAddress.state->Option.getOr("")
        administrativeArea->Some
      }
    | ShippingAddressCountry(_) => details.shippingAddress.countryCode
    | ShippingAddressPincode => details.shippingAddress.postalCode
    | Email => details.email->Some
    | PhoneNumber => details.phone
    | _ => None
    }

    fieldVal->Option.mapOr((), fieldVal =>
      acc->Dict.set(item.required_field, fieldVal->JSON.Encode.string)
    )

    acc
  })
}

let getKlarnaRequiredFields = (
  ~shippingContact: KlarnaSDKTypes.collected_shipping_address,
  ~paymentMethodTypes: PaymentMethodsRecord.paymentMethodTypes,
) => {
  paymentMethodTypes.required_fields->Array.reduce(Dict.make(), (acc, item) => {
    let requiredFieldsArr = item.required_field->String.split(".")

    let fieldVal = switch item.field_type {
    | ShippingName =>
      getNameFromFirstAndLastName(
        ~firstName=shippingContact.given_name,
        ~lastName=shippingContact.family_name,
        ~requiredFieldsArr,
      )
    | ShippingAddressLine1 => shippingContact.street_address
    | ShippingAddressCity => shippingContact.city
    | ShippingAddressState => {
        let administrativeArea = shippingContact.region
        administrativeArea
      }
    | ShippingAddressCountry(_) => shippingContact.country
    | ShippingAddressPincode => shippingContact.postal_code
    | Email => shippingContact.email
    | PhoneNumber => shippingContact.phone
    | _ => ""
    }

    if fieldVal !== "" {
      acc->Dict.set(item.required_field, fieldVal->JSON.Encode.string)
    }

    acc
  })
}
