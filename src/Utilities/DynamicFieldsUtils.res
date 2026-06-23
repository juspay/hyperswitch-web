type fieldTexts = {
  label: string,
  placeholder: string,
}

let billingPrefix = "payment_method_data.billing."

let lookupLocaleKey = (key: string, locale: LocaleStringTypes.localeStrings): option<string> =>
  locale
  ->Identity.anyTypeToJson
  ->JSON.Decode.object
  ->Option.flatMap(dict => dict->Dict.get(key))
  ->Option.flatMap(JSON.Decode.string)

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
    let defaultPlaceholder =
      field.defaultPlaceholderText->String.length > 0 ? field.defaultPlaceholderText : label
    field.placeholderLocalizationKey
    ->Option.flatMap(key => lookupLocaleKey(key, localeObject))
    ->Option.getOr(defaultPlaceholder)
  }

  {label, placeholder}
}

let emptyMessageForField = (
  ~field: SuperpositionTypes.fieldConfig,
  ~localeObject: LocaleStringTypes.localeStrings,
): option<string> =>
  switch field.labelLocalizationKey {
  | Some("line1Label") => Some(localeObject.line1EmptyText)
  | Some("line2Label") => Some(localeObject.line2EmptyText)
  | Some("cityLabel") => Some(localeObject.cityEmptyText)
  | Some("stateLabel") => Some(localeObject.stateEmptyText)
  | Some("postalCodeLabel") => Some(localeObject.postalCodeEmptyText)
  | Some("sourceBankAccountIdLabel") => Some(localeObject.sourceBankAccountIdEmptyText)
  | Some("vpaIdLabel") => Some(localeObject.vpaIdEmptyText)
  | Some("emailLabel") => Some(localeObject.emailEmptyText)
  | _ => None
  }

let resolveValidator = (
  ~field: SuperpositionTypes.fieldConfig,
  ~localeObject: LocaleStringTypes.localeStrings,
) => {
  let requiredRule = field.isRequired
    ? [Validation.Required(emptyMessageForField(~field, ~localeObject))]
    : []

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
  | Some("email") => [Validation.Email]
  | Some("first_name") => [Validation.FirstName]
  | Some("last_name") => [Validation.LastName]
  | Some("bank_account_number") => [Validation.BankAccountNumber]
  | Some("date_of_birth") => [Validation.DateOfBirth]
  | Some("regex") =>
    switch field.validationRegexPattern {
    | Some(pattern) => Array.concat(requiredRule, [Validation.Generic(pattern)])
    | None => requiredRule
    }
  | None => requiredRule
  | Some(_) => []
  }

  let maxLengthRule = [Validation.MaxLength(field.maxInputLength->Option.getOr(255))]

  let rules = [...requiredRule, ...semanticRule, ...maxLengthRule]

  Validation.createFieldValidator(
    rules,
    ~enabledCardSchemes=[],
    ~localeObject=localeObject->LocaleStringTypes.toValidationLocale,
  )
}

let findCryptoCurrencyField = (~allFields: array<SuperpositionTypes.fieldConfig>) =>
  allFields->Array.find(field => field.fieldRenderType === SuperpositionTypes.CryptoCurrency)

let isCombinedPhoneRow = (~items: array<SuperpositionTypes.fieldConfig>) =>
  items->Array.some(field => field.fieldRenderType === SuperpositionTypes.Phone) &&
    items->Array.some(field => field.fieldRenderType === SuperpositionTypes.PhoneCountryCode)

let getCombinedPhoneRowLabel = (
  ~items: array<SuperpositionTypes.fieldConfig>,
  ~localeObject: LocaleStringTypes.localeStrings,
) =>
  items
  ->Array.find(field => field.fieldRenderType === SuperpositionTypes.Phone)
  ->Option.map(phoneField => resolveFieldTexts(~field=phoneField, ~localeObject).label)
  ->Option.getOr("")

let getComputedLanguagePreferenceValue = (~locale: string, ~options: array<string>): string =>
  options->Array.includes(locale->String.toUpperCase->String.split("-")->Array.join("_"))
    ? locale
    : "en"

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
      !(requiredField.confirmRequestWritePath->String.startsWith(billingPrefix))
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
  ~accountConfig: option<SdkConfigTypes.accountConfig>,
) => {
  let mandateType = switch paymentMethodListValue.payment_type {
  | NEW_MANDATE => "new_mandate"
  | SETUP_MANDATE => "setup_mandate"
  | NORMAL => "non_mandate"
  | NONE => "non_mandate"
  }

  let profile = accountConfig->Option.flatMap(ac => ac.profile)
  let collectBilling = SdkConfigParser.getCollectBillingDetailsFromWalletConnector(profile)
    ? "true"
    : "false"
  let collectShipping = SdkConfigParser.getCollectShippingDetailsFromWalletConnector(profile)
    ? "true"
    : "false"

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

let applyBillingDetailsOverride = (
  initialValues: Dict.t<JSON.t>,
  billingDetails: PaymentType.billingDetails,
) => {
  let set = (path, value) =>
    if value !== "" {
      SuperpositionHelper.setValueAtNestedPath(
        initialValues,
        path->String.split("."),
        value,
      )->ignore
    }

  let name = billingDetails.name
  if name !== "" {
    let (firstName, lastName) = name->Utils.splitFullName
    set("payment_method_data.billing.address.first_name", firstName)
    set("payment_method_data.billing.address.last_name", lastName)
  }

  set("payment_method_data.billing.email", billingDetails.email)
  set("payment_method_data.billing.phone.number", billingDetails.phone)
  set("payment_method_data.billing.address.line1", billingDetails.address.line1)
  set("payment_method_data.billing.address.line2", billingDetails.address.line2)
  set("payment_method_data.billing.address.city", billingDetails.address.city)
  set("payment_method_data.billing.address.state", billingDetails.address.state)
  set("payment_method_data.billing.address.country", billingDetails.address.country)
  set("payment_method_data.billing.address.zip", billingDetails.address.postal_code)

  initialValues
}

// TODO: refactor event emitters to use react-final-forms
let useSyncEmitAddressAtoms = () => {
  let country = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let setUserAddressState = Recoil.useSetRecoilState(RecoilAtoms.userAddressState)
  let setUserAddressPincode = Recoil.useSetRecoilState(RecoilAtoms.userAddressPincode)

  (flatValues: Dict.t<JSON.t>) => {
    let readBillingValue = path =>
      flatValues->Dict.get(path)->Option.map(json => json->JSON.Decode.string->Option.getOr(""))

    let countryFromForm =
      readBillingValue("payment_method_data.billing.address.country")->Option.getOr("")
    let countryIso =
      countryFromForm !== "" ? countryFromForm : Utils.getCountryCode(country).isoAlpha2

    switch readBillingValue("payment_method_data.billing.address.state") {
    | Some(stateCode) =>
      let stateName =
        stateCode->String.trim === "" ? "" : Utils.getStateNameFromCode(stateCode, countryIso)
      setUserAddressState(prev => prev.value === stateName ? prev : {...prev, value: stateName})
    | None => ()
    }

    switch readBillingValue("payment_method_data.billing.address.zip") {
    | Some(zip) => setUserAddressPincode(prev => prev.value === zip ? prev : {...prev, value: zip})
    | None => ()
    }
  }
}
