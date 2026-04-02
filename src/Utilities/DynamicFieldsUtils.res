open RecoilAtoms
open SuperpositionTypes

let countryList = CountryStateDataRefs.countryDataRef.contents
let countryNames = Utils.getCountryNames(countryList)

let getBillingAddressPathFromFieldType = (fieldType: PaymentMethodsRecord.paymentMethodsFields) => {
  switch fieldType {
  | AddressLine1 => "payment_method_data.billing.address.line1"
  | AddressLine2 => "payment_method_data.billing.address.line2"
  | AddressCity => "payment_method_data.billing.address.city"
  | AddressState => "payment_method_data.billing.address.state"
  | AddressCountry(_) => "payment_method_data.billing.address.country"
  | AddressPincode => "payment_method_data.billing.address.zip"
  | _ => ""
  }
}

let isClickToPayFieldType = (fieldType: PaymentMethodsRecord.paymentMethodsFields) => {
  switch fieldType {
  | Email
  | PhoneNumber => true
  | _ => false
  }
}

let removeClickToPayFieldsIfSaveDetailsWithClickToPay = (
  requiredFields: array<PaymentMethodsRecord.required_fields>,
  isSaveDetailsWithClickToPay,
) => {
  if isSaveDetailsWithClickToPay {
    requiredFields->Array.filter(requiredField => {
      !(requiredField.field_type->isClickToPayFieldType)
    })
  } else {
    requiredFields
  }
}

let addClickToPayFieldsIfSaveDetailsWithClickToPay = (
  fieldsArr,
  isSaveDetailsWithClickToPay,
  clickToPayConfig,
) => {
  open ClickToPayHelpers
  open PaymentMethodsRecord
  let isRecognizedClickToPayPayment =
    clickToPayConfig.clickToPayCards->Option.getOr([])->Array.length != 0
  let defaultCtpFields = [...fieldsArr, Email, PhoneNumber]
  switch (
    isSaveDetailsWithClickToPay,
    clickToPayConfig.clickToPayProvider,
    isRecognizedClickToPayPayment,
  ) {
  | (true, MASTERCARD, _) => defaultCtpFields
  | (true, VISA, _)
  | (false, VISA, true) =>
    [...defaultCtpFields, FullName]
  | _ => fieldsArr
  }
}

let useSubmitCallback = (~onConfirm: option<unit => unit>=?) => {
  let (line1, setLine1) = Recoil.useRecoilState(userAddressline1)
  let (line2, setLine2) = Recoil.useRecoilState(userAddressline2)
  let (state, setState) = Recoil.useRecoilState(userAddressState)
  let (postalCode, setPostalCode) = Recoil.useRecoilState(userAddressPincode)
  let (city, setCity) = Recoil.useRecoilState(userAddressCity)
  let {billingAddress} = Recoil.useRecoilValueFromAtom(optionAtom)

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  React.useCallback((ev: Window.event) => {
    let json = ev.data->Utils.safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      // Trigger RFF submit so all fields are marked as touched and validation
      // errors become visible on every field that has not been interacted with.
      switch onConfirm {
      | Some(submitFn) => submitFn()
      | None => ()
      }

      if line1.value == "" {
        setLine1(prev => {
          ...prev,
          errorString: localeString.line1EmptyText,
        })
      }
      if line2.value == "" {
        setLine2(prev => {
          ...prev,
          errorString: billingAddress.isUseBillingAddress ? "" : localeString.line2EmptyText,
        })
      }
      if state.value == "" {
        setState(prev => {
          ...prev,
          errorString: localeString.stateEmptyText,
        })
      }
      if postalCode.value == "" {
        setPostalCode(prev => {
          ...prev,
          errorString: localeString.postalCodeEmptyText,
        })
      }
      if city.value == "" {
        setCity(prev => {
          ...prev,
          errorString: localeString.cityEmptyText,
        })
      }
    }
  }, (line1, line2, state, city, postalCode))
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

let getGiftCardDataFromRequiredFieldsBody = requiredFieldsBody => {
  open Utils
  let giftCardTuples = []->mergeAndFlattenToTuples(requiredFieldsBody)
  let data =
    giftCardTuples
    ->getJsonFromArrayOfJson
    ->getDictFromJson
    ->getDictFromDict("payment_method_data")
  data
}

let getEligibleConnectors = (
  paymentMethodTypes: PaymentMethodsRecord.paymentMethodTypes,
  paymentMethod: string,
): array<JSON.t> => {
  if paymentMethod === "card" {
    // For cards, get connectors from card_networks
    paymentMethodTypes.card_networks
    ->Array.flatMap(cn => cn.eligible_connectors)
    ->Array.map(c => c->JSON.Encode.string)
  } else {
    // For other payment methods, get from payment_experience
    paymentMethodTypes.payment_experience
    ->Array.flatMap(pe => pe.eligible_connectors)
    ->Array.map(c => c->JSON.Encode.string)
  }
}

let buildSuperpositionContext = (
  ~paymentMethod,
  ~paymentMethodType,
  ~userCountry,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
): SuperpositionTypes.superpositionBaseContext => {
  let mandateType = switch paymentMethodListValue.payment_type {
  | NEW_MANDATE => "new_mandate"
  | SETUP_MANDATE => "setup_mandate"
  | NORMAL => "non_mandate"
  | NONE => "non_mandate"
  }

  {
    payment_method: paymentMethod,
    payment_method_type: paymentMethodType,
    country: userCountry,
    mandate_type: mandateType,
    collect_shipping_details_from_wallet_connector: "false",
    collect_billing_details_from_wallet_connector: paymentMethodListValue.collect_billing_details_from_wallets
      ? "true"
      : "false",
  }
}

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

// Get field type from outputPath when superposition fieldType is generic
let getFieldTypeFromConfig = (fc: SuperpositionTypes.fieldConfig): SuperpositionTypes.fieldType => {
  let p = fc.outputPath->String.toLowerCase

  if p->String.includes("card.card_cvc") || p->String.includes("card.cvc") {
    CvcPasswordInput
  } else if p->String.includes("card.card_number") || p->String.includes("card.number") {
    CardNumberTextInput
  } else if p->String.includes("card.card_exp_month") || p->String.includes("card.exp_month") {
    MonthSelect
  } else if p->String.includes("card.card_exp_year") || p->String.includes("card.exp_year") {
    YearSelect
  } else if (
    p->String.includes("billing.address.first_name") ||
      p->String.includes("billing.address.last_name")
  ) {
    FullNameInput({firstName: None, lastName: None})
  } else if p->String.includes("billing.address.line1") {
    AddressLine1Input
  } else if p->String.includes("billing.address.line2") {
    AddressLine2Input
  } else if p->String.includes("billing.address.city") {
    AddressCityInput
  } else if p->String.includes("billing.address.state") {
    AddressStateInput
  } else if p->String.includes("billing.address.country") {
    AddressCountryInput
  } else if (
    p->String.includes("billing.address.zip") || p->String.includes("billing.address.postal")
  ) {
    AddressPostalCodeInput
  } else if p->String.includes("billing.email") {
    EmailInput
  } else if p->String.includes("billing.phone.country_code") {
    CountryCodeSelect
  } else if p->String.includes("billing.phone") {
    PhoneInput
  } else if p->String.includes("crypto") {
    CryptoNetworkSelect
  } else if p->String.includes("vpa") {
    VpaTextInput
  } else if p->String.includes("pix.key") {
    PixKeyInput
  } else if p->String.includes("pix.cpf") {
    PixCpfInput
  } else if p->String.includes("pix.cnpj") {
    PixCnpjInput
  } else if p->String.includes("blik") {
    BlikCodeInput
  } else if p->String.includes("bank_account_number") {
    BankAccountNumberInput
  } else if p->String.includes("iban") {
    IbanInput
  } else if p->String.includes("source_bank_account_id") {
    SourceBankAccountIdInput
  } else if p->String.includes("gift_card.number") {
    GiftCardNumberInput
  } else if p->String.includes("gift_card.pin") {
    GiftCardPinInput
  } else if p->String.includes("document.type") {
    DocumentTypeSelect
  } else if p->String.includes("document.number") {
    DocumentNumberInput
  } else if p->String.includes("date_of_birth") {
    DatePicker
  } else {
    fc.fieldType
  }
}

// Check if a fieldConfig is a billing address field
let isBillingAddressFieldConfig = (fc: SuperpositionTypes.fieldConfig) => {
  switch fc.fieldType {
  // | BillingNameInput
  | AddressLine1Input
  | AddressLine2Input
  | AddressCityInput
  | AddressStateInput
  | AddressPostalCodeInput
  | AddressCountryInput => true
  | _ =>
    // Also check outputPath for billing address fields
    fc.outputPath->String.includes("billing.address")
  }
}

// Check if a fieldConfig is a ClickToPay field (Email or Phone)
let isClickToPayFieldConfig = (fc: SuperpositionTypes.fieldConfig) => {
  switch fc.fieldType {
  | EmailInput
  | PhoneInput
  | CountryCodeSelect => true
  | _ => false
  }
}

// Remove billing address fields if useBillingAddress is enabled
let removeBillingDetailsFromFieldConfigs = (
  fields: array<SuperpositionTypes.fieldConfig>,
  billingAddress: PaymentType.billingAddress,
) => {
  if billingAddress.isUseBillingAddress {
    fields->Array.filter(fc => !(fc->isBillingAddressFieldConfig))
  } else {
    fields
  }
}

// Remove ClickToPay fields if saveDetailsWithClickToPay is enabled
let removeClickToPayFieldsFromFieldConfigs = (
  fields: array<SuperpositionTypes.fieldConfig>,
  isSaveDetailsWithClickToPay,
) => {
  if isSaveDetailsWithClickToPay {
    fields->Array.filter(fc => !(fc->isClickToPayFieldConfig))
  } else {
    fields
  }
}

// Sort fieldConfig array by priority
let sortFieldConfigsByPriority = (fields: array<SuperpositionTypes.fieldConfig>) => {
  fields->Array.toSorted((a, b) => {
    let diff = a.priority - b.priority
    if diff < 0 {
      -1.0
    } else if diff > 0 {
      1.0
    } else {
      0.0
    }
  })
}

// Process field configs: sort by priority only.
let processFieldConfigs = (
  fields: array<SuperpositionTypes.fieldConfig>,
  _billingAddress: PaymentType.billingAddress,
  _isSaveDetailsWithClickToPay: bool,
) => {
  fields->sortFieldConfigsByPriority
}

// Check if a field type should be rendered outside billing section
let isFieldTypeToRenderOutsideBillingConfig = (fc: SuperpositionTypes.fieldConfig) => {
  switch fc.fieldType {
  | CardNumberTextInput
  | CvcPasswordInput
  | MonthSelect
  | YearSelect
  | FullNameInput(_)
  | CryptoNetworkSelect
  | VpaTextInput
  | PixKeyInput
  | PixCpfInput
  | PixCnpjInput
  | BlikCodeInput
  | BankAccountNumberInput
  | IbanInput
  | SourceBankAccountIdInput
  | GiftCardNumberInput
  | GiftCardPinInput
  | DocumentNumberInput
  | DatePicker
  | CurrencySelect
  | BankListSelect
  | InfoElementType => true
  | _ => false
  }
}

// Check if a field is a card field (card number, expiry, cvc)
let isCardField = (fc: SuperpositionTypes.fieldConfig) => {
  switch fc.fieldType {
  | CardNumberTextInput
  | MonthSelect
  | YearSelect
  | CvcPasswordInput => true
  | _ => false
  }
}

// Remove card fields from field configs (when they're already rendered by parent)
let removeCardFieldsFromFieldConfigs = (
  fields: array<SuperpositionTypes.fieldConfig>,
  shouldRemoveCardFields,
) => {
  if shouldRemoveCardFields {
    fields->Array.filter(fc => !(fc->isCardField))
  } else {
    fields
  }
}

let useSuperpositionFields = (
  ~paymentMethod,
  ~paymentMethodType,
  ~paymentMethodTypes: PaymentMethodsRecord.paymentMethodTypes,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
) => {
  let userCountry = Recoil.useRecoilValueFromAtom(userCountry)
  let getSuperpositionFinalFields = ConfigurationService.useConfigurationServiceWeb()

  let (superpositionMissingFields, setSuperpositionMissingFields) = React.useState(_ => [])
  let (initialValues, setInitialValues) = React.useState(_ => Dict.make())
  let (isLoading, setIsLoading) = React.useState(_ => false)

  React.useEffect(() => {
    setSuperpositionMissingFields(_ => [])
    setInitialValues(_ => Dict.make())
    setIsLoading(_ => true)

    let eligibleConnectors = getEligibleConnectors(paymentMethodTypes, paymentMethod)

    let configParams = buildSuperpositionContext(
      ~paymentMethod,
      ~paymentMethodType,
      ~userCountry,
      ~paymentMethodListValue,
    )

    let requiredFieldsFromPML = extractValuesFromPMLRequiredFields(
      paymentMethodTypes.required_fields,
    )

    getSuperpositionFinalFields(eligibleConnectors, configParams, requiredFieldsFromPML)
    ->Promise.then(((_requiredFields, missingRequiredFields, superpositionInitialValues)) => {
      // Constants for path suffixes
      let firstNameSuffix = "first_name"
      let lastNameSuffix = "last_name"
      let defaultFullNamePath = "payment_method_data.billing.address.first_name"

      // Enhance fields with inferred types
      let enhancedFields = missingRequiredFields->Array.map(
        fc => {
          {...fc, fieldType: fc->getFieldTypeFromConfig}
        },
      )

      // Extract name fields from the list
      let extractNameFields = fields => {
        let firstName = fields->Array.find(fc => fc.outputPath->String.endsWith(firstNameSuffix))
        let lastName = fields->Array.find(fc => fc.outputPath->String.endsWith(lastNameSuffix))
        (firstName, lastName)
      }

      // Check if field is a name field
      let isNameField = (fc: SuperpositionTypes.fieldConfig) => {
        let p = fc.outputPath
        p->String.endsWith(firstNameSuffix) || p->String.endsWith(lastNameSuffix)
      }

      // Get a string key for fieldType to enable deduplication
      let fieldTypeToKey = (ft: SuperpositionTypes.fieldType) => {
        switch ft {
        | CardNumberTextInput => "card_number"
        | CvcPasswordInput => "cvc"
        | MonthSelect => "month"
        | YearSelect => "year"
        | EmailInput => "email"
        | PhoneInput => "phone"
        | CountryCodeSelect => "country_code"
        | FullNameInput(_) => "full_name"
        | AddressLine1Input => "address_line1"
        | AddressLine2Input => "address_line2"
        | AddressCityInput => "address_city"
        | AddressStateInput => "address_state"
        | AddressPostalCodeInput => "address_postal"
        | AddressCountryInput => "address_country"
        | CryptoNetworkSelect => "crypto"
        | VpaTextInput => "vpa"
        | PixKeyInput => "pix_key"
        | PixCpfInput => "pix_cpf"
        | PixCnpjInput => "pix_cnpj"
        | BlikCodeInput => "blik"
        | BankAccountNumberInput => "bank_account"
        | IbanInput => "iban"
        | SourceBankAccountIdInput => "source_bank"
        | GiftCardNumberInput => "gift_card_number"
        | GiftCardPinInput => "gift_card_pin"
        | DocumentTypeSelect => "document_type"
        | DocumentNumberInput => "document_number"
        | DatePicker => "date_of_birth"
        | CurrencySelect => "currency"
        | BankListSelect => "bank_list"
        | InfoElementType => "info"
        | TextInput => "text"
        | PasswordInput => "password"
        | StateSelect => "state"
        | CountrySelect => "country"
        | DropdownSelect => "dropdown"
        | BankSelect => "bank"
        | _ => "unknown"
        }
      }

      let deduplicateByFieldType = fields => {
        let seen = Set.make()
        fields->Array.filter(
          fc => {
            let key = fc.fieldType->fieldTypeToKey
            if seen->Set.has(key) {
              false
            } else {
              seen->Set.add(key)
              true
            }
          },
        )
      }

      let createFullNameField = (firstName, lastName) => {
        let fullNameConfig = {firstName, lastName}

        let baseField =
          firstName
          ->Option.orElse(lastName)
          ->Option.getOr({
            name: "full_name",
            displayName: "Full Name",
            fieldType: FullNameInput(fullNameConfig),
            priority: 0,
            required: true,
            options: [],
            outputPath: defaultFullNamePath,
          })

        {...baseField, fieldType: FullNameInput(fullNameConfig)}
      }

      let (firstNameField, lastNameField) = enhancedFields->extractNameFields

      let nonNameFields = enhancedFields->Array.filter(fc => !(fc->isNameField))
      let deduplicatedFields = nonNameFields->deduplicateByFieldType

      let finalFields = switch (firstNameField, lastNameField) {
      | (None, None) => deduplicatedFields
      | _ => {
          let fullNameField = createFullNameField(firstNameField, lastNameField)
          [fullNameField, ...deduplicatedFields]
        }
      }

      setSuperpositionMissingFields(_ => finalFields)
      setInitialValues(_ => superpositionInitialValues)
      setIsLoading(_ => false)
      Promise.resolve()
    })
    ->Promise.catch(_ => {
      setIsLoading(_ => false)
      Promise.resolve()
    })
    ->ignore

    None
  }, (paymentMethod, paymentMethodType, userCountry, paymentMethodTypes))

  (superpositionMissingFields, initialValues, isLoading)
}

// Utility function to find output path for a specific field type
let getOutputPathForFieldType = (
  processedFieldConfigs: array<SuperpositionTypes.fieldConfig>,
  fieldType: SuperpositionTypes.fieldType,
): string => {
  processedFieldConfigs
  ->Array.find(fc => fc.fieldType === fieldType)
  ->Option.map(fc => fc.outputPath)
  ->Option.getOr("")
}

// Utility function to check if field type exists in configs
let hasFieldType = (
  processedFieldConfigs: array<SuperpositionTypes.fieldConfig>,
  fieldType: SuperpositionTypes.fieldType,
): bool => {
  processedFieldConfigs->Array.some(fc => fc.fieldType === fieldType)
}

// Utility function to check if both field types exist in configs
let hasBothFieldTypes = (
  processedFieldConfigs: array<SuperpositionTypes.fieldConfig>,
  fieldType1: SuperpositionTypes.fieldType,
  fieldType2: SuperpositionTypes.fieldType,
): bool => {
  processedFieldConfigs->hasFieldType(fieldType1) && processedFieldConfigs->hasFieldType(fieldType2)
}

// [TO DEPRECATE]: Convert SuperpositionTypes.fieldType to PaymentMethodsRecord.paymentMethodsFields
let fieldTypeToPaymentMethodsField = (
  fieldType: SuperpositionTypes.fieldType,
  options: array<string>,
): PaymentMethodsRecord.paymentMethodsFields => {
  switch fieldType {
  | CardNumberTextInput => CardNumber
  | CvcPasswordInput => CardCvc
  | MonthSelect => CardExpiryMonth
  | YearSelect => CardExpiryYear
  | EmailInput => Email
  | PhoneInput => PhoneNumber
  | CountryCodeSelect => PhoneCountryCode
  | FullNameInput(_) => FullName
  // | ShippingNameInput => ShippingName
  | AddressLine1Input => AddressLine1
  | AddressLine2Input => AddressLine2
  | AddressCityInput => AddressCity
  | AddressStateInput => AddressState
  | AddressPostalCodeInput => AddressPincode
  | AddressCountryInput => AddressCountry(options)
  | CryptoNetworkSelect => CryptoCurrencyNetworks
  | VpaTextInput => VpaId
  | PixKeyInput => PixKey
  | PixCpfInput => PixCPF
  | PixCnpjInput => PixCNPJ
  | BlikCodeInput => BlikCode
  | BankAccountNumberInput => BankAccountNumber
  | IbanInput => IBAN
  | SourceBankAccountIdInput => SourceBankAccountId
  | GiftCardNumberInput => GiftCardNumber
  | GiftCardPinInput => GiftCardPin
  | DocumentNumberInput => DocumentNumber
  | DocumentTypeSelect => DocumentType(options)
  | DatePicker => DateOfBirth
  | CurrencySelect => Currency(options)
  | BankListSelect => BankList(options)
  | InfoElementType => InfoElement
  | _ => None
  }
}
