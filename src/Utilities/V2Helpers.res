open UnifiedPaymentsTypesV2
open Utils
open PaymentMethodsRecord

let itemToPMMCustomerMapper = customerArray => {
  let customerMethods =
    customerArray
    ->Belt.Array.keepMap(JSON.Decode.object)
    ->Array.map(dict => {
      let cardDict =
        getJsonObjectFromDict(dict, "payment_method_data")
        ->getDictFromJson
        ->getJsonObjectFromDict("card")
        ->getDictFromJson
      {
        id: getString(dict, "id", ""),
        customerId: getString(dict, "customer_id", ""),
        paymentMethodType: getString(dict, "payment_method_type", ""),
        paymentMethodSubType: getString(dict, "payment_method_subtype", ""),
        recurringEnabled: getBool(dict, "recurring_enabled", false),
        paymentMethodData: {
          card: {
            network: getOptionString(cardDict, "card_network"),
            issuerCountry: getOptionString(cardDict, "card_issuer"),
            last4Digits: getString(cardDict, "last4_digits", ""),
            expiryMonth: getString(cardDict, "expiry_month", ""),
            expiryYear: getString(cardDict, "expiry_year", ""),
            cardHolderName: getOptionString(cardDict, "card_holder_name"),
            nickname: getOptionString(cardDict, "nick_name"),
            cardFingerprint: getString(cardDict, "card_fingerprint", ""),
            cardIsin: getString(cardDict, "card_isin", ""),
            cardType: getString(cardDict, "card_type", ""),
            savedToLocker: getBool(cardDict, "saved_to_locker", false),
            cardIssuer: getString(cardDict, "card_issuer", ""),
          },
        },
        isDefault: getBool(dict, "is_default", false),
        requiresCvv: getBool(dict, "reuires_cvv", false),
        created: getString(dict, "created", ""),
        lastUsedAt: getString(dict, "last_used_at", ""),
        bank: {mask: ""},
      }
    })
  customerMethods
}

let getDynamicFieldsFromJsonDictV2 = (dict, isBancontact) => {
  let requiredFields = getArray(dict, "required_fields")
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

let getCardNetworks = networksArr => {
  networksArr
  ->Belt.Array.keepMap(JSON.Decode.object)
  ->Array.map(dict => {
    {
      cardNetwork: getString(dict, "card_network", "")->CardUtils.getCardType,
      eligibleConnectors: getStrArray(dict, "eligible_connectors"),
      surchargeDetails: dict->getSurchargeDetails,
    }
  })
}

let itemToPaymentsEnabledMapper = methodsArray => {
  let enabledMethods =
    methodsArray
    ->Belt.Array.keepMap(JSON.Decode.object)
    ->Array.map(dict => {
      let paymentMethodSubtype = getString(dict, "payment_method_subtype", "")
      {
        cardNetworks: dict->getArray("card_networks")->getCardNetworks,
        surchargeDetails: dict->getSurchargeDetails,
        paymentMethodType: getString(dict, "payment_method_type", ""),
        paymentMethodSubtype,
        requiredFields: dict->getDynamicFieldsFromJsonDictV2(
          paymentMethodSubtype == "bancontact_card",
        ),
      }
    })
  enabledMethods
}

let itemToPMMObjMapper = customerDict => {
  {
    paymentMethodsEnabled: customerDict
    ->getArray("payment_methods_enabled")
    ->itemToPaymentsEnabledMapper,
    customerPaymentMethods: customerDict
    ->getArray("customer_payment_methods")
    ->itemToPMMCustomerMapper,
  }
}

let createCustomerObjArr = (dict, key) => {
  let customerDict =
    dict
    ->Dict.get(key)
    ->Option.flatMap(JSON.Decode.object)
    ->Option.getOr(Dict.make())
  let finalList = customerDict->itemToPMMObjMapper
  LoadedV2(finalList)
}

let itemToPaymentDetails = cust => {
  let cardDict =
    getJsonObjectFromDict(cust, "payment_method_data")
    ->getDictFromJson
    ->getJsonObjectFromDict("card")
    ->getDictFromJson
  {
    id: getString(cust, "id", ""),
    customerId: getString(cust, "customer_id", ""),
    paymentMethodType: getString(cust, "payment_method_type", ""),
    paymentMethodSubType: getString(cust, "payment_method_subtype", ""),
    recurringEnabled: getBool(cust, "recurring_enabled", false),
    paymentMethodData: {
      card: {
        network: getOptionString(cardDict, "card_network"),
        issuerCountry: getOptionString(cardDict, "card_issuer"),
        last4Digits: getString(cardDict, "last4_digits", ""),
        expiryMonth: getString(cardDict, "expiry_month", ""),
        expiryYear: getString(cardDict, "expiry_year", ""),
        cardHolderName: getOptionString(cardDict, "card_holder_name"),
        nickname: getOptionString(cardDict, "nick_name"),
        cardFingerprint: getString(cardDict, "card_fingerprint", ""),
        cardIsin: getString(cardDict, "card_isin", ""),
        cardType: getString(cardDict, "card_type", ""),
        savedToLocker: getBool(cardDict, "saved_to_locker", false),
        cardIssuer: getString(cardDict, "card_issuer", ""),
      },
    },
    isDefault: getBool(cust, "is_default", false),
    requiresCvv: getBool(cust, "reuires_cvv", false),
    created: getString(cust, "created", ""),
    lastUsedAt: getString(cust, "last_used_at", ""),
    bank: {mask: ""},
  }
}
