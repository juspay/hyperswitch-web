open PMMTypesV2
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
            last4Digits: getString(cardDict, "last4_digits", ""),
            expiryMonth: getString(cardDict, "expiry_month", ""),
            expiryYear: getString(cardDict, "expiry_year", ""),
            cardHolderName: getOptionString(cardDict, "card_holder_name"),
            nickname: getOptionString(cardDict, "nick_name"),
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
        last4Digits: getString(cardDict, "last4_digits", ""),
        expiryMonth: getString(cardDict, "expiry_month", ""),
        expiryYear: getString(cardDict, "expiry_year", ""),
        cardHolderName: getOptionString(cardDict, "card_holder_name"),
        nickname: getOptionString(cardDict, "nick_name"),
      },
    },
    isDefault: getBool(cust, "is_default", false),
    requiresCvv: getBool(cust, "reuires_cvv", false),
    created: getString(cust, "created", ""),
    lastUsedAt: getString(cust, "last_used_at", ""),
    bank: {mask: ""},
  }
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

let itemToPMMEnabledMapper = methodsArray => {
  let enabledMethods =
    methodsArray
    ->Belt.Array.keepMap(JSON.Decode.object)
    ->Array.map(dict => {
      {
        paymentMethodType: getString(dict, "payment_method_type", ""),
        paymentMethodSubType: getString(dict, "payment_method_subtype", ""),
        requiredFields: dict->getDynamicFieldsFromJsonDictV2(false),
      }
    })
  enabledMethods
}

let itemToPMMObjMapper = customerDict => {
  {
    paymentMethodsEnabled: customerDict
    ->getArray("payment_methods_enabled")
    ->itemToPMMEnabledMapper,
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
