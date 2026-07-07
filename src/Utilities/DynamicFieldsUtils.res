type fieldTexts = {
  label: string,
  placeholder: string,
}

type superpositionResolutionContext = {
  rawConfigs: option<JSON.t>,
  configPaymentMethodType: string,
  eligibleConnectors: array<JSON.t>,
  superpositionBaseContext: SuperpositionTypes.superpositionBaseContext,
}

let billingPrefix = "payment_method_data.billing."

// Derive a stable, locale-independent test id from a field's write path,
// e.g. "payment_method_data.billing.address.line1" -> "line1".
let getFieldTestId = (path: string): string => {
  let parts = path->String.split(".")
  parts->Array.get(parts->Array.length - 1)->Option.getOr(path)
}

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

  let rules = [...semanticRule, ...requiredRule, ...maxLengthRule]

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
  ~platform: string,
  ~country: string,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
  ~accountConfig: option<SdkConfigTypes.accountConfig>,
  ~contextUsed: option<SdkConfigTypes.contextUsed>,
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
  let (profileId, processorMerchantId, organizationId) = SdkConfigParser.getProfileContext(
    contextUsed,
  )

  let context: SuperpositionTypes.superpositionBaseContext = {
    payment_method: paymentMethod,
    payment_method_type: paymentMethodType,
    country,
    mandate_type: mandateType,
    collect_shipping_details_from_wallet_connector: collectShipping,
    collect_billing_details_from_wallet_connector: collectBilling,
    profile_id: ?profileId,
    processor_merchant_id: ?processorMerchantId,
    organization_id: ?organizationId,
    platform,
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

let useSuperpositionRequiredFields = (~paymentMethod, ~paymentMethodType) => {
  let sdkConfigsValue = Recoil.useRecoilValueFromAtom(PaymentUtils.sdkConfigsValue)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let userCountryName = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let country = Utils.getCountryCode(userCountryName).isoAlpha2

  let rawConfigs = sdkConfigsValue.raw_configs
  let getSuperpositionFinalFields = ConfigurationService.useConfigurationService(~rawConfigs)

  let configPaymentMethodType = PaymentUtils.getPaymentMethodName(
    ~paymentMethodType=paymentMethod,
    ~paymentMethodName=paymentMethodType,
  )

  let eligibleConnectors = React.useMemo(() => {
    SdkConfigParser.getEligibleConnectorsFromPaymentMethods(
      sdkConfigsValue.payment_methods,
      paymentMethod,
      configPaymentMethodType,
    )->Array.map(JSON.Encode.string)
  }, (sdkConfigsValue.payment_methods, paymentMethod, configPaymentMethodType))

  let intentData = paymentMethodListValue.intent_data.intentDataObject

  let superpositionBaseContext = React.useMemo(() => {
    buildSuperpositionBaseContext(
      ~paymentMethod,
      ~paymentMethodType=configPaymentMethodType,
      ~platform="web",
      ~country,
      ~paymentMethodListValue,
      ~accountConfig=sdkConfigsValue.account_config,
      ~contextUsed=sdkConfigsValue.context_used,
    )
  }, (
    paymentMethod,
    configPaymentMethodType,
    country,
    paymentMethodListValue,
    sdkConfigsValue.account_config,
    sdkConfigsValue.context_used,
  ))

  let (requiredFields, missingRequiredFields, initialValues) = React.useMemo(() => {
    getSuperpositionFinalFields(eligibleConnectors, superpositionBaseContext, intentData)
  }, (getSuperpositionFinalFields, eligibleConnectors, superpositionBaseContext, intentData))

  let resolutionContext = React.useMemo(() => {
    {
      rawConfigs,
      configPaymentMethodType,
      eligibleConnectors,
      superpositionBaseContext,
    }
  }, (rawConfigs, configPaymentMethodType, eligibleConnectors, superpositionBaseContext))

  (requiredFields, missingRequiredFields, initialValues, resolutionContext)
}

let useAreWalletRequiredFieldsPrefilled = (~paymentMethodType) => {
  let {billingAddress} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let (_, missingRequiredFields, _, _) = useSuperpositionRequiredFields(
    ~paymentMethod="wallet",
    ~paymentMethodType,
  )
  removeBillingDetailsIfUseBillingAddress(missingRequiredFields, billingAddress)->Array.length == 0
}

let splitName = (str: option<string>) => {
  switch str {
  | None => ("", "")
  | Some(s) =>
    if s == "" {
      ("", "")
    } else {
      let lastSpaceIndex = String.lastIndexOf(s, " ")
      if lastSpaceIndex === -1 {
        (s, "")
      } else {
        let first = String.slice(s, ~start=0, ~end=lastSpaceIndex)
        let last = String.slice(s, ~start=lastSpaceIndex + 1, ~end=s->String.length)
        (first, last)
      }
    }
  }
}

let defaultWalletRequiredFieldPaths: array<string> = [
  "email",
  "payment_method_data.billing.address.first_name",
  "payment_method_data.billing.address.last_name",
  "payment_method_data.billing.address.city",
  "payment_method_data.billing.address.state",
  "payment_method_data.billing.address.country",
  "payment_method_data.billing.address.line1",
  "payment_method_data.billing.address.zip",
]

let getApplePayRequiredFields = (
  ~billingContact: ApplePayTypes.billingContact,
  ~shippingContact: ApplePayTypes.shippingContact,
  ~requiredFieldPaths=defaultWalletRequiredFieldPaths,
) => {
  let billingCountryCode = billingContact.countryCode->String.toUpperCase
  let shippingCountryCode = shippingContact.countryCode->String.toUpperCase
  requiredFieldPaths->Array.reduce(Dict.make(), (acc, path) => {
    let fieldVal = switch path {
    | "payment_method_data.billing.address.first_name" => billingContact.givenName
    | "payment_method_data.billing.address.last_name" => billingContact.familyName
    | "payment_method_data.billing.address.line1" =>
      billingContact.addressLines->Array.get(0)->Option.getOr("")
    | "payment_method_data.billing.address.line2" =>
      billingContact.addressLines->Array.get(1)->Option.getOr("")
    | "payment_method_data.billing.address.city" => billingContact.locality
    | "payment_method_data.billing.address.state" => billingContact.administrativeArea
    | "payment_method_data.billing.address.country" => billingCountryCode
    | "payment_method_data.billing.address.zip" => billingContact.postalCode
    | "email"
    | "payment_method_data.email"
    | "payment_method_data.billing.email" =>
      shippingContact.emailAddress
    | "payment_method_data.billing.phone.number" => shippingContact.phoneNumber
    | "shipping.address.first_name" => shippingContact.givenName
    | "shipping.address.last_name" => shippingContact.familyName
    | "shipping.address.line1" => shippingContact.addressLines->Array.get(0)->Option.getOr("")
    | "shipping.address.line2" => shippingContact.addressLines->Array.get(1)->Option.getOr("")
    | "shipping.address.city" => shippingContact.locality
    | "shipping.address.state" => shippingContact.administrativeArea
    | "shipping.address.country" => shippingCountryCode
    | "shipping.address.zip" => shippingContact.postalCode
    | _ => ""
    }

    if fieldVal !== "" {
      acc->Dict.set(path, fieldVal->JSON.Encode.string)
    }

    acc
  })
}

let getGooglePayRequiredFields = (
  ~billingContact: GooglePayType.billingContact,
  ~shippingContact: GooglePayType.billingContact,
  ~requiredFieldPaths=defaultWalletRequiredFieldPaths,
  ~email,
) => {
  let (billingFirstName, billingLastName) = splitName(Some(billingContact.name))
  let (shippingFirstName, shippingLastName) = splitName(Some(shippingContact.name))
  requiredFieldPaths->Array.reduce(Dict.make(), (acc, path) => {
    let fieldVal = switch path {
    | "payment_method_data.billing.address.first_name" => billingFirstName
    | "payment_method_data.billing.address.last_name" => billingLastName
    | "payment_method_data.billing.address.line1" => billingContact.address1
    | "payment_method_data.billing.address.line2" => billingContact.address2
    | "payment_method_data.billing.address.city" => billingContact.locality
    | "payment_method_data.billing.address.state" => billingContact.administrativeArea
    | "payment_method_data.billing.address.country" => billingContact.countryCode
    | "payment_method_data.billing.address.zip" => billingContact.postalCode
    | "email"
    | "payment_method_data.email"
    | "payment_method_data.billing.email" => email
    | "payment_method_data.billing.phone.number" =>
      shippingContact.phoneNumber->String.replaceAll(" ", "")->String.replaceAll("-", "")
    | "shipping.address.first_name" => shippingFirstName
    | "shipping.address.last_name" => shippingLastName
    | "shipping.address.line1" => shippingContact.address1
    | "shipping.address.line2" => shippingContact.address2
    | "shipping.address.city" => shippingContact.locality
    | "shipping.address.state" => shippingContact.administrativeArea
    | "shipping.address.country" => shippingContact.countryCode
    | "shipping.address.zip" => shippingContact.postalCode
    | _ => ""
    }

    if fieldVal !== "" {
      acc->Dict.set(path, fieldVal->JSON.Encode.string)
    }

    acc
  })
}

let getPaypalRequiredFields = (
  ~details: PaypalSDKTypes.details,
  ~requiredFields: array<SuperpositionTypes.fieldConfig>,
) => {
  let (shippingFirstName, shippingLastName) = splitName(details.shippingAddress.recipientName)
  requiredFields->Array.reduce(Dict.make(), (acc, fieldConfig) => {
    let fieldVal = switch fieldConfig.confirmRequestWritePath {
    | "shipping.address.first_name" => Some(shippingFirstName)
    | "shipping.address.last_name" => Some(shippingLastName)
    | "shipping.address.line1" => details.shippingAddress.line1
    | "shipping.address.line2" => details.shippingAddress.line2
    | "shipping.address.city" => details.shippingAddress.city
    | "shipping.address.state" => details.shippingAddress.state->Option.getOr("")->Some
    | "shipping.address.country" => details.shippingAddress.countryCode
    | "shipping.address.zip" => details.shippingAddress.postalCode
    | "payment_method_data.email"
    | "payment_method_data.billing.email"
    | "shipping.email" =>
      details.email->Some
    | "payment_method_data.billing.phone.number"
    | "shipping.phone.number" =>
      details.phone
    | _ => None
    }

    fieldVal->Option.mapOr((), fieldVal =>
      acc->Dict.set(fieldConfig.confirmRequestWritePath, fieldVal->JSON.Encode.string)
    )

    acc
  })
}

let getKlarnaRequiredFields = (
  ~shippingContact: KlarnaSDKTypes.collected_shipping_address,
  ~requiredFields: array<SuperpositionTypes.fieldConfig>,
) => {
  requiredFields->Array.reduce(Dict.make(), (acc, fieldConfig) => {
    let fieldVal = switch fieldConfig.confirmRequestWritePath {
    | "shipping.address.first_name" => shippingContact.given_name
    | "shipping.address.last_name" => shippingContact.family_name
    | "shipping.address.line1" => shippingContact.street_address
    | "shipping.address.city" => shippingContact.city
    | "shipping.address.state" => shippingContact.region
    | "shipping.address.country" => shippingContact.country
    | "shipping.address.zip" => shippingContact.postal_code
    | "payment_method_data.email"
    | "payment_method_data.billing.email"
    | "shipping.email" =>
      shippingContact.email
    | "payment_method_data.billing.phone.number"
    | "shipping.phone.number" =>
      shippingContact.phone
    | _ => ""
    }

    if fieldVal !== "" {
      acc->Dict.set(fieldConfig.confirmRequestWritePath, fieldVal->JSON.Encode.string)
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

let useLogDynamicFieldsRendered = (
  ~fields: array<SuperpositionTypes.fieldConfig>,
  ~paymentMethod: string,
  ~resolutionContext,
  ~isSavedCardFlow=false,
) => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let lastLoggedKey = React.useRef("")
  let {
    rawConfigs,
    configPaymentMethodType,
    eligibleConnectors,
    superpositionBaseContext,
  } = resolutionContext

  // Log which dynamic fields are being rendered for the current payment method.
  // Fires once per (paymentMethod, configPaymentMethodType) combination; the
  // dedupeKey guard prevents re-logging when unrelated state (e.g. billingAddress
  // toggle) causes the fields array to change identity.
  React.useEffect(() => {
    if !isSavedCardFlow && rawConfigs->Option.isSome {
      let dedupeKey = paymentMethod ++ "|" ++ configPaymentMethodType
      if lastLoggedKey.current !== dedupeKey {
        lastLoggedKey.current = dedupeKey
        let fieldsJson =
          fields
          ->Array.map(field =>
            [
              ("field_type", (field.fieldRenderType :> string)->JSON.Encode.string),
              ("write_path", field.confirmRequestWritePath->JSON.Encode.string),
              (
                "intent_data_read_path",
                field.intentDataReadPath
                ->Option.map(JSON.Encode.string)
                ->Option.getOr(JSON.Null),
              ),
              ("is_required", field.isRequired->JSON.Encode.bool),
              (
                "validation_rule_type",
                field.validationRuleType->Option.map(JSON.Encode.string)->Option.getOr(JSON.Null),
              ),
              (
                "validation_regex_pattern",
                field.validationRegexPattern
                ->Option.map(JSON.Encode.string)
                ->Option.getOr(JSON.Null),
              ),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object
          )
          ->JSON.Encode.array
        let payload =
          [
            ("superposition_base_context", superpositionBaseContext->Identity.anyTypeToJson),
            ("eligible_connectors", eligibleConnectors->JSON.Encode.array),
            ("field_count", fields->Array.length->JSON.Encode.int),
            ("fields", fieldsJson),
          ]
          ->Dict.fromArray
          ->JSON.Encode.object
          ->JSON.stringify
        loggerState.setLogInfo(
          ~value=payload,
          ~eventName=HyperLoggerTypes.DYNAMIC_FIELDS_RENDERED,
          ~paymentMethod,
        )
      }
    }
    None
  }, (
    fields,
    paymentMethod,
    configPaymentMethodType,
    rawConfigs,
    isSavedCardFlow,
    eligibleConnectors,
    superpositionBaseContext,
    loggerState,
  ))
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
