open Utils

type installmentAmountDetails = {
  amount_per_installment: float,
  total_amount: float,
}

type installmentPlan = {
  interest_rate: float,
  number_of_installments: int,
  billing_frequency: string,
  amount_details: installmentAmountDetails,
}

type installmentOption = {
  payment_method: string,
  available_plans: array<installmentPlan>,
}

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
  | DocumentType(array<string>)
  | DocumentNumber
  | LanguagePreference(array<string>)
  | BankAccountNumber
  | IBAN
  | SourceBankAccountId
  | GiftCardNumber
  | GiftCardPin

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

// Tells the SDK whether a newly-entered payment method of this type can be
// saved for the customer, as reported by the paymentMethods list response.
// - "supported": eligible to be saved (checkbox reads "Save details")
// - "partially_supported": save eligible subject to routing (checkbox reads
//   "Save details wherever possible")
// - "unsupported": cannot be saved (no checkbox)
// Absent / unknown: treated like unsupported (no checkbox).
type customerAcceptanceSupport = Supported | PartiallySupported | Unsupported

let getCustomerAcceptanceSupport = (dict, str) => {
  switch dict->getString(str, "") {
  | "supported" => Some(Supported)
  | "partially_supported" => Some(PartiallySupported)
  | "unsupported" => Some(Unsupported)
  | _ => None
  }
}

type paymentMethodsContent = {
  paymentMethodName: string,
  paymentFlow: paymentFlowWithConnector,
  handleUserError: bool,
  methodType: string,
  bankNames: array<string>,
  customerAcceptanceSupport: option<customerAcceptanceSupport>,
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
  paymentFlow: [],
  handleUserError: false,
  methodType: "",
  bankNames: [],
  customerAcceptanceSupport: None,
}
let defaultPaymentMethodFields = {
  paymentMethodName: "",
  fields: [],
  icon: None,
  displayName: "",
  miniIcon: None,
}

let icon = (~size=22, ~width=size, name) => <Icon size width name />

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
  | ("user_gift_card_pin", _) => GiftCardPin
  | ("user_phone_number_country_code", _) => PhoneCountryCode
  | ("user_vpa_id", _) => VpaId
  | ("user_cpf", _) => PixCPF
  | ("user_cnpj", _) => PixCNPJ
  | ("user_pix_key", _) => PixKey
  | ("user_bank_account_number", _) => BankAccountNumber
  | ("user_iban", _) => BankAccountNumber
  | ("user_source_bank_account_id", _) => SourceBankAccountId
  | ("user_social_security_number", _) => DocumentNumber
  | _ => None
  }
}

let getOptionsFromPaymentMethodFieldType = (dict, key, ~isAddressCountry=true) => {
  /* Read at call time, like every other consumer of this ref: the list is filled in by
     S3Utils.initializeCountryData, which LoaderController awaits before render */
  let countryData = CountryStateDataRefs.countryDataRef.contents
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
  | "user_document_type" => {
      let options = dict->getArrayValFromJsonDict("user_document_type", "options")
      DocumentType(options)
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
  surcharge_details: option<surchargeDetails>,
  pm_auth_connector: option<string>,
  customer_acceptance_support: option<customerAcceptanceSupport>,
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

type intentData = {
  installment_options: option<array<installmentOption>>,
  currency: string,
  intentDataObject: JSON.t,
}

type paymentMethodList = {
  redirect_url: string,
  currency: string,
  payment_methods: array<methods>,
  mandate_payment: option<mandate>,
  payment_type: payment_type,
  merchant_name: string,
  is_tax_calculation_enabled: bool,
  isGuestCustomer: option<bool>,
  intent_data: intentData,
  sdk_next_action: option<string>,
  should_block_confirm: bool,
}

let defaultPaymentMethodType = {
  payment_method_type: "",
  payment_experience: [],
  card_networks: [],
  bank_names: [],
  bank_debits_connectors: [],
  bank_transfers_connectors: [],
  surcharge_details: None,
  pm_auth_connector: None,
  customer_acceptance_support: None,
}

let defaultIntentData = {
  installment_options: None,
  currency: "",
  intentDataObject: JSON.Encode.null,
}

let defaultList = {
  redirect_url: "",
  currency: "",
  payment_methods: [],
  mandate_payment: None,
  payment_type: NONE,
  merchant_name: "",
  is_tax_calculation_enabled: false,
  isGuestCustomer: None,
  intent_data: defaultIntentData,
  sdk_next_action: None,
  should_block_confirm: false,
}

let getPaymentExperienceType = str => {
  switch str {
  | "redirect_to_url" => RedirectToURL
  | "invoke_sdk_client" => InvokeSDK
  | "display_qr_code" => QrFlow
  | _ => RedirectToURL
  }
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

let getAmountDetails = dict => {
  amount_per_installment: getFloat(dict, "amount_per_installment", 0.0),
  total_amount: getFloat(dict, "total_amount", 0.0),
}

let getInstallmentPlan = dict => {
  interest_rate: getFloat(dict, "interest_rate", 0.0),
  number_of_installments: getInt(dict, "number_of_installments", 0),
  billing_frequency: getString(dict, "billing_frequency", ""),
  amount_details: dict->getDictFromDict("amount_details")->getAmountDetails,
}

let getInstallmentOptions = dict => {
  let installmentOptions = dict->getArray("installment_options")
  installmentOptions->Array.length > 0
    ? Some(
        installmentOptions
        ->Array.filterMap(JSON.Decode.object)
        ->Array.map(json => {
          payment_method: getString(json, "payment_method", ""),
          available_plans: json
          ->getArrayOfObjectsFromDict("available_plans")
          ->Array.map(getInstallmentPlan),
        }),
      )
    : None
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

let getIntentData = dict => {
  let intentDataDict = dict->getDictFromDict("intent_data")
  {
    installment_options: intentDataDict->getInstallmentOptions,
    currency: intentDataDict->getString("currency", ""),
    intentDataObject: intentDataDict->JSON.Encode.object,
  }
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

// --- clientList (`fetchClientList`, `payments/{id}/client`) decoder ---
//
// clientList returns a *flat* `payment_methods_enabled` array (one entry per
// `(payment_method, payment_method_type)` combo), unlike the old nested
// `payment_methods` tree. This section groups the flat list back into the
// existing `methods`/`paymentMethodTypes` shape so the rest of the SDK keeps
// reading the same `paymentMethodList` type unchanged.
let getCardNetworksFromFlatList = (jsonDict, str) => {
  jsonDict
  ->getStrArray(str)
  ->Array.map(cardNetworkStr => {
    {
      card_network: cardNetworkStr->CardUtils.getCardType,
      eligible_connectors: [],
      // clientList's card_networks[i] is a plain string, not a dict — there is
      // no per-network object to decode a surcharge from at this granularity.
      surcharge_details: None,
    }
  })
}

let getPaymentExperienceFromFlatList = (jsonDict, str) => {
  jsonDict
  ->getStrArray(str)
  ->Array.map(experienceStr => {
    {
      payment_experience_type: experienceStr->getPaymentExperienceType,
      // clientList's flat payment_experience is array<string>, with no
      // per-experience eligible_connectors — known, accepted gap (wallet/
      // PayLater connector-restricted routing), see migration plan.
      eligible_connectors: [],
    }
  })
}

let getPaymentMethodTypesFromFlatList = (paymentMethodsEnabled: array<JSON.t>) => {
  let methodsDict = Dict.make()

  paymentMethodsEnabled
  ->Belt.Array.keepMap(JSON.Decode.object)
  ->Array.forEach(jsonDict => {
    let paymentMethod = getString(jsonDict, "payment_method", "")
    let paymentMethodType = getString(jsonDict, "payment_method_type", "")

    let paymentMethodTypeRecord: paymentMethodTypes = {
      payment_method_type: paymentMethodType,
      payment_experience: getPaymentExperienceFromFlatList(jsonDict, "payment_experience"),
      card_networks: getCardNetworksFromFlatList(jsonDict, "card_networks"),
      bank_names: [],
      bank_debits_connectors: [],
      bank_transfers_connectors: [],
      // Forward-compatible: clientList doesn't send `surcharge_details` today
      // (confirmed via full-file grep), but this is a real, callable decode
      // path against a real dict — it will activate automatically the day the
      // backend adds the key, with no further SDK changes.
      surcharge_details: jsonDict->getSurchargeDetails,
      // Forward-compatible, same dormant-decode-on-arrival treatment as
      // surcharge_details above (per explicit codebase-owner decision): always
      // None today since clientList doesn't send pm_auth_connector, but will
      // "just work" if/when it does. Known, accepted gap until then (Plaid
      // bank-debit auth eligibility unavailable from clientList).
      pm_auth_connector: getOptionString(jsonDict, "pm_auth_connector"),
      customer_acceptance_support: getCustomerAcceptanceSupport(
        jsonDict,
        "customer_acceptance_support",
      ),
    }

    switch methodsDict->Dict.get(paymentMethod) {
    | Some(existingTypes: array<paymentMethodTypes>) =>
      methodsDict->Dict.set(paymentMethod, existingTypes->Array.concat([paymentMethodTypeRecord]))
    | None => methodsDict->Dict.set(paymentMethod, [paymentMethodTypeRecord])
    }
  })

  methodsDict
  ->Dict.toArray
  ->Array.map(((paymentMethod, paymentMethodTypesArr)) => {
    payment_method: paymentMethod,
    payment_method_types: paymentMethodTypesArr,
  })
}

let itemToObjMapperFromClientList = dict => {
  let intentDataDict = dict->getDictFromDict("intent_data")
  {
    redirect_url: "",
    // clientList has no top-level `currency` key, only `intent_data.currency`
    // — read it from intentDataDict here, and getIntentData below does the
    // same for its own `currency` sub-field (it has exactly one caller, this
    // one, so it was fixed in place rather than duplicated).
    currency: intentDataDict->getString("currency", ""),
    payment_methods: getPaymentMethodTypesFromFlatList(dict->getArray("payment_methods_enabled")),
    mandate_payment: intentDataDict->getMandate("mandate_payment"),
    payment_type: intentDataDict->getString("payment_type", "")->paymentTypeMapper,
    merchant_name: intentDataDict->getString("merchant_name", ""),
    is_tax_calculation_enabled: intentDataDict->getBool("is_tax_calculation_enabled", false),
    isGuestCustomer: intentDataDict->getOptionBool("is_guest_customer"),
    intent_data: dict->getIntentData,
    sdk_next_action: dict->getDictFromDict("sdk_next_action")->getOptionString("next_action"),
    should_block_confirm: dict
    ->getDictFromDict("sdk_next_action")
    ->getBool("should_block_confirm", false),
  }
}

let buildFromPaymentList = pList => {
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
        paymentFlow: paymentExperience,
        handleUserError,
        methodType,
        bankNames,
        customerAcceptanceSupport: individualPaymentMethod.customer_acceptance_support,
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
