open RecoilAtoms

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
  "afterpay_clearpay",
  "mifinity",
  "bluecode",
  "upi_collect",
  "upi_intent",
  "sepa",
  "sepa_bank_transfer",
  "instant_bank_transfer",
  "affirm",
  "walley",
  "ach",
  "bacs",
  "pay_bright",
  "multibanco_transfer",
  "paypal",
  "instant_bank_transfer_finland",
  "instant_bank_transfer_poland",
  "klarna",
  "skrill",
  "flexiti",
  "breadpay",
  "givex",
  "pay_safe_card",
  "interac",
  "open_banking",
]

let getName = (item: PaymentMethodsRecord.required_fields, field: RecoilAtomTypes.field) => {
  let fieldNameArr = field.value->String.split(" ")
  let requiredFieldsArr = item.required_field->String.split(".")
  switch requiredFieldsArr->Array.get(requiredFieldsArr->Array.length - 1)->Option.getOr("") {
  | "first_name" => fieldNameArr->Array.get(0)->Option.getOr(field.value)
  | "last_name" =>
    fieldNameArr
    ->Array.sliceToEnd(~start=1)
    ->Array.reduce("", (acc, item) => acc === "" ? item : `${acc} ${item}`)
  | _ => field.value
  }
}

let countryList = CountryStateDataRefs.countryDataRef.contents
let countryNames = Utils.getCountryNames(countryList)

let billingAddressFields: array<PaymentMethodsRecord.paymentMethodsFields> = [
  BillingName,
  AddressLine1,
  AddressLine2,
  AddressCity,
  AddressState,
  AddressCountry(countryNames),
  AddressPincode,
]

let isBillingAddressFieldType = (fieldType: PaymentMethodsRecord.paymentMethodsFields) => {
  switch fieldType {
  | BillingName
  | AddressLine1
  | AddressLine2
  | AddressCity
  | AddressState
  | AddressCountry(_)
  | AddressPincode => true
  | _ => false
  }
}

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

let removeBillingDetailsIfUseBillingAddress = (
  requiredFields: array<PaymentMethodsRecord.required_fields>,
  billingAddress: PaymentType.billingAddress,
) => {
  if billingAddress.isUseBillingAddress {
    requiredFields->Array.filter(requiredField => {
      !(requiredField.field_type->isBillingAddressFieldType)
    })
  } else {
    requiredFields
  }
}

let addBillingAddressIfUseBillingAddress = (
  fieldsArr,
  billingAddress: PaymentType.billingAddress,
) => {
  if billingAddress.isUseBillingAddress {
    fieldsArr->Array.concat(billingAddressFields)
  } else {
    fieldsArr
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

let useRequiredFieldsEmptyAndValid = (
  ~requiredFields,
  ~fieldsArr: array<PaymentMethodsRecord.paymentMethodsFields>,
  ~countryNames,
  ~bankNames,
  ~isCardValid,
  ~isExpiryValid,
  ~isCVCValid,
  ~cardNumber,
  ~cardExpiry,
  ~cvcNumber,
  ~isSavedCardFlow,
  ~setAreRequiredFieldsValid,
  ~setAreRequiredFieldsEmpty,
) => {
  let email = Recoil.useRecoilValueFromAtom(userEmailAddress)
  let vpaId = Recoil.useRecoilValueFromAtom(userVpaId)
  let pixCNPJ = Recoil.useRecoilValueFromAtom(userPixCNPJ)
  let pixCPF = Recoil.useRecoilValueFromAtom(userPixCPF)
  let pixKey = Recoil.useRecoilValueFromAtom(userPixKey)
  let fullName = Recoil.useRecoilValueFromAtom(userFullName)
  let billingName = Recoil.useRecoilValueFromAtom(userBillingName)
  let line1 = Recoil.useRecoilValueFromAtom(userAddressline1)
  let line2 = Recoil.useRecoilValueFromAtom(userAddressline2)
  let phone = Recoil.useRecoilValueFromAtom(userPhoneNumber)
  let state = Recoil.useRecoilValueFromAtom(userAddressState)
  let city = Recoil.useRecoilValueFromAtom(userAddressCity)
  let postalCode = Recoil.useRecoilValueFromAtom(userAddressPincode)
  let blikCode = Recoil.useRecoilValueFromAtom(userBlikCode)
  let country = Recoil.useRecoilValueFromAtom(userCountry)
  let selectedBank = Recoil.useRecoilValueFromAtom(userBank)
  let currency = Recoil.useRecoilValueFromAtom(userCurrency)
  let giftCardNumber = Recoil.useRecoilValueFromAtom(userGiftCardNumber)
  let giftCardCvc = Recoil.useRecoilValueFromAtom(userGiftCardCvc)
  let (areRequiredFieldsValidLocal, setAreRequiredFieldsValidLocal) = React.useState(_ => true)
  let {billingAddress} = Recoil.useRecoilValueFromAtom(optionAtom)
  let cryptoCurrencyNetworks = Recoil.useRecoilValueFromAtom(cryptoCurrencyNetworks)
  let dateOfBirth = Recoil.useRecoilValueFromAtom(dateOfBirth)
  let bankAccountNumber = Recoil.useRecoilValueFromAtom(userBankAccountNumber)
  let sourceBankAccountId = Recoil.useRecoilValueFromAtom(sourceBankAccountId)

  let fieldsArrWithBillingAddress = fieldsArr->addBillingAddressIfUseBillingAddress(billingAddress)
  React.useEffect(() => {
    let areRequiredFieldsValid = fieldsArr->Array.reduce(true, (acc, paymentMethodFields) => {
      acc &&
      switch paymentMethodFields {
      | Email => email.isValid->Option.getOr(false)
      | FullName =>
        checkIfNameIsValid(requiredFields, paymentMethodFields, fullName) &&
        fullName.isValid->Option.getOr(false)
      | Country => country !== "" || countryNames->Array.length === 0
      | AddressCountry(countryArr) => country !== "" || countryArr->Array.length === 0
      | BillingName => checkIfNameIsValid(requiredFields, paymentMethodFields, billingName)
      | AddressLine1 => line1.value !== ""
      | AddressLine2 => billingAddress.isUseBillingAddress || line2.value !== ""
      | Bank => selectedBank !== "" || bankNames->Array.length === 0
      | PhoneNumber => phone.value !== ""
      | StateAndCity => state.value !== "" && city.value !== ""
      | CountryAndPincode(countryArr) =>
        (country !== "" || countryArr->Array.length === 0) && postalCode.value !== ""

      | AddressCity => city.value !== ""
      | AddressPincode => postalCode.value !== ""
      | AddressState => state.value !== ""
      | BlikCode => blikCode.value !== ""
      | CryptoCurrencyNetworks => cryptoCurrencyNetworks !== ""
      | Currency(currencyArr) => currency !== "" || currencyArr->Array.length === 0
      | CardNumber => isCardValid->Option.getOr(false)
      | CardExpiryMonth
      | CardExpiryYear
      | CardExpiryMonthAndYear =>
        isExpiryValid->Option.getOr(false)
      | CardCvc => isCVCValid->Option.getOr(false)
      | CardExpiryAndCvc => isExpiryValid->Option.getOr(false) && isCVCValid->Option.getOr(false)
      | DateOfBirth =>
        switch dateOfBirth->Nullable.toOption {
        | Some(val) => val->Utils.checkIs18OrAbove
        | None => false
        }
      | VpaId => vpaId.isValid->Option.getOr(false)
      | PixCNPJ => pixCNPJ.isValid->Option.getOr(false)
      | PixCPF => pixCPF.isValid->Option.getOr(false)
      | PixKey => pixKey.isValid->Option.getOr(false)
      | BankAccountNumber
      | IBAN =>
        bankAccountNumber.value !== ""
      | GiftCardNumber => giftCardNumber.value !== ""
      | GiftCardCvc => giftCardCvc.value !== ""
      | SourceBankAccountId => sourceBankAccountId.value !== ""
      | _ => true
      }
    })
    let finalAreRequiredFieldsValid = isSavedCardFlow || areRequiredFieldsValid
    setAreRequiredFieldsValidLocal(_ => finalAreRequiredFieldsValid)
    setAreRequiredFieldsValid(_ => finalAreRequiredFieldsValid)

    let areRequiredFieldsEmpty = fieldsArrWithBillingAddress->Array.reduce(false, (
      acc,
      paymentMethodFields: PaymentMethodsRecord.paymentMethodsFields,
    ) => {
      open CardUtils
      acc ||
      switch paymentMethodFields {
      | Email => email.value === ""
      | FullName => fullName.value === ""
      | Country => country === "" && countryNames->Array.length > 0
      | AddressCountry(countryArr) => country === "" && countryArr->Array.length > 0
      | BillingName => billingName.value === ""
      | AddressLine1 => line1.value === ""
      | AddressLine2 => !billingAddress.isUseBillingAddress && line2.value === ""
      | Bank => selectedBank === "" && bankNames->Array.length > 0
      | StateAndCity => city.value === "" || state.value === ""
      | CountryAndPincode(countryArr) =>
        (country === "" && countryArr->Array.length > 0) || postalCode.value === ""
      | PhoneNumber => phone.value === ""
      | AddressCity => city.value === ""
      | AddressPincode => postalCode.value === ""
      | AddressState => state.value === ""
      | BlikCode => blikCode.value === ""
      | PixCNPJ => pixCNPJ.value === ""
      | PixCPF => pixCPF.value === ""
      | PixKey => pixKey.value === ""
      | CryptoCurrencyNetworks => cryptoCurrencyNetworks === ""
      | Currency(currencyArr) => currency === "" && currencyArr->Array.length > 0
      | CardNumber => cardNumber === ""
      | CardExpiryMonth =>
        let (month, _) = getExpiryDates(cardExpiry)
        month === ""
      | CardExpiryYear =>
        let (_, year) = getExpiryDates(cardExpiry)
        year === ""
      | CardExpiryMonthAndYear =>
        let (month, year) = getExpiryDates(cardExpiry)
        month === "" || year === ""
      | CardCvc => cvcNumber === ""
      | CardExpiryAndCvc =>
        let (month, year) = getExpiryDates(cardExpiry)
        month === "" || year === "" || cvcNumber === ""
      | DateOfBirth => dateOfBirth->Js.Nullable.isNullable
      | BankAccountNumber
      | IBAN =>
        bankAccountNumber.value === ""
      | GiftCardNumber => giftCardNumber.value === ""
      | GiftCardCvc => giftCardCvc.value === ""
      | SourceBankAccountId => sourceBankAccountId.value === ""
      | _ => false
      }
    })
    setAreRequiredFieldsEmpty(_ => areRequiredFieldsEmpty)
    None
  }, (
    fieldsArr,
    currency,
    fullName.value,
    country,
    billingName.value,
    line1.value,
    dateOfBirth,
    email,
    vpaId,
    line2.value,
    selectedBank,
    phone.value,
    city.value,
    postalCode,
    state.value,
    blikCode.value,
    pixCNPJ.value,
    pixKey.value,
    pixCPF.value,
    isCardValid,
    isExpiryValid,
    isCVCValid,
    cardNumber,
    cardExpiry,
    cvcNumber,
    bankAccountNumber,
    sourceBankAccountId.value,
    cryptoCurrencyNetworks,
    giftCardCvc.value,
    giftCardNumber.value,
  ))

  React.useEffect(() => {
    switch (isCardValid, isExpiryValid, isCVCValid) {
    | (Some(cardValid), Some(expiryValid), Some(cvcValid)) =>
      CardUtils.emitIsFormReadyForSubmission(
        cardValid && expiryValid && cvcValid && areRequiredFieldsValidLocal,
      )
    | _ => ()
    }
    None
  }, (isCardValid, isExpiryValid, isCVCValid, areRequiredFieldsValidLocal))
}

let useSetInitialRequiredFields = (
  ~requiredFields: array<PaymentMethodsRecord.required_fields>,
  ~paymentMethodType,
) => {
  let (email, setEmail) = Recoil.useRecoilState(userEmailAddress)
  let (fullName, setFullName) = Recoil.useRecoilState(userFullName)
  let (billingName, setBillingName) = Recoil.useRecoilState(userBillingName)
  let (line1, setLine1) = Recoil.useRecoilState(userAddressline1)
  let (line2, setLine2) = Recoil.useRecoilState(userAddressline2)
  let (phone, setPhone) = Recoil.useRecoilState(userPhoneNumber)
  let (state, setState) = Recoil.useRecoilState(userAddressState)
  let (city, setCity) = Recoil.useRecoilState(userAddressCity)
  let (postalCode, setPostalCode) = Recoil.useRecoilState(userAddressPincode)
  let (blikCode, setBlikCode) = Recoil.useRecoilState(userBlikCode)
  let (pixCNPJ, setPixCNPJ) = Recoil.useRecoilState(userPixCNPJ)
  let (pixCPF, setPixCPF) = Recoil.useRecoilState(userPixCPF)
  let (pixKey, setPixKey) = Recoil.useRecoilState(userPixKey)

  let (country, setCountry) = Recoil.useRecoilState(userCountry)
  let (selectedBank, setSelectedBank) = Recoil.useRecoilState(userBank)
  let (currency, setCurrency) = Recoil.useRecoilState(userCurrency)
  let (cryptoCurrencyNetworks, setCryptoCurrencyNetworks) = Recoil.useRecoilState(
    cryptoCurrencyNetworks,
  )
  let (dateOfBirth, setDateOfBirth) = Recoil.useRecoilState(dateOfBirth)
  let (bankAccountNumber, setBankAccountNumber) = Recoil.useRecoilState(userBankAccountNumber)
  let (sourceBankAccountId, setSourceBankAccountId) = Recoil.useRecoilState(sourceBankAccountId)
  let (giftCardNumber, setGiftCardNumber) = Recoil.useRecoilState(userGiftCardNumber)
  let (giftCardCvc, setGiftCardCvc) = Recoil.useRecoilState(userGiftCardCvc)

  React.useEffect(() => {
    let getNameValue = (item: PaymentMethodsRecord.required_fields) => {
      requiredFields
      ->Array.filter(requiredFields => requiredFields.field_type === item.field_type)
      ->Array.reduce("", (acc, item) => {
        let requiredFieldsArr = item.required_field->String.split(".")
        switch requiredFieldsArr->Array.get(requiredFieldsArr->Array.length - 1)->Option.getOr("") {
        | "first_name" => item.value->String.concat(acc)
        | "last_name" => acc->String.concatMany([" ", item.value])
        | _ => acc
        }
      })
      ->String.trim
    }

    let setFields = (
      setMethod: (RecoilAtomTypes.field => RecoilAtomTypes.field) => unit,
      field: RecoilAtomTypes.field,
      item: PaymentMethodsRecord.required_fields,
      isNameField,
      ~isCountryCodeAvailable=?,
    ) => {
      if isNameField && field.value === "" {
        setMethod(prev => {
          ...prev,
          value: getNameValue(item),
        })
        if isCountryCodeAvailable->Option.isSome {
          setMethod(prev => {
            ...prev,
            countryCode: getNameValue(item),
          })
        }
      } else if field.value === "" {
        if isCountryCodeAvailable->Option.isSome {
          setMethod(prev => {
            ...prev,
            countryCode: item.value,
          })
        } else {
          setMethod(prev => {
            ...prev,
            value: item.value,
          })
        }
      }
    }

    requiredFields->Array.forEach(requiredField => {
      let value = requiredField.value
      switch requiredField.field_type {
      | Email => {
          let emailValue = email.value
          setFields(setEmail, email, requiredField, false)
          if emailValue === "" {
            let newEmail: RecoilAtomTypes.field = {
              value,
              isValid: None,
              errorString: "",
            }
            Utils.checkEmailValid(newEmail, setEmail)
          }
        }
      | FullName => setFields(setFullName, fullName, requiredField, true)
      | AddressLine1 => setFields(setLine1, line1, requiredField, false)
      | AddressLine2 => setFields(setLine2, line2, requiredField, false)
      | StateAndCity => {
          setFields(setState, state, requiredField, false)
          setFields(setCity, city, requiredField, false)
        }
      | CountryAndPincode(_) => {
          setFields(setPostalCode, postalCode, requiredField, false)
          if value !== "" && country === "" {
            let countryCode =
              Country.getCountry(paymentMethodType, countryList)
              ->Array.filter(item => item.isoAlpha2 === value)
              ->Array.get(0)
              ->Option.getOr(Country.defaultTimeZone)
            setCountry(_ => countryCode.countryName)
          }
        }
      | AddressState => setFields(setState, state, requiredField, false)
      | GiftCardNumber => setFields(setGiftCardNumber, giftCardNumber, requiredField, false)
      | GiftCardCvc => setFields(setGiftCardCvc, giftCardCvc, requiredField, false)
      | AddressCity => setFields(setCity, city, requiredField, false)
      | PhoneCountryCode =>
        setFields(setPhone, phone, requiredField, false, ~isCountryCodeAvailable=true)
      | AddressPincode => setFields(setPostalCode, postalCode, requiredField, false)
      | PhoneNumber => setFields(setPhone, phone, requiredField, false)
      | PhoneNumberAndCountryCode =>
        setFields(setPhone, phone, requiredField, false, ~isCountryCodeAvailable=true)
      | BlikCode => setFields(setBlikCode, blikCode, requiredField, false)
      | PixKey => setFields(setPixKey, pixKey, requiredField, false)
      | PixCNPJ => setFields(setPixCNPJ, pixCNPJ, requiredField, false)
      | PixCPF => setFields(setPixCPF, pixCPF, requiredField, false)
      | BillingName => setFields(setBillingName, billingName, requiredField, true)
      | Country
      | AddressCountry(_) =>
        if value !== "" {
          let defaultCountry =
            Country.getCountry(paymentMethodType, countryList)
            ->Array.filter(item => item.isoAlpha2 === value)
            ->Array.get(0)
            ->Option.getOr(Country.defaultTimeZone)
          setCountry(_ => defaultCountry.countryName)
        }
      | Currency(_) =>
        if value !== "" && currency === "" {
          setCurrency(_ => value)
        }
      | Bank =>
        if value !== "" && selectedBank === "" {
          setSelectedBank(_ => value)
        }
      | CryptoCurrencyNetworks =>
        if value !== "" && cryptoCurrencyNetworks === "" {
          setCryptoCurrencyNetworks(_ => value)
        }
      | DateOfBirth =>
        switch dateOfBirth->Nullable.toOption {
        | Some(x) =>
          if value !== "" && x->Date.toDateString === "" {
            setDateOfBirth(_ => Nullable.make(x))
          }
        | None => ()
        }
      | IBAN
      | BankAccountNumber =>
        setFields(setBankAccountNumber, bankAccountNumber, requiredField, false)
      | SourceBankAccountId =>
        setFields(setSourceBankAccountId, sourceBankAccountId, requiredField, false)
      | LanguagePreference(_)
      | SpecialField(_)
      | InfoElement
      | CardNumber
      | CardExpiryMonth
      | CardExpiryYear
      | CardExpiryMonthAndYear
      | CardCvc
      | CardExpiryAndCvc
      | ShippingName // Shipping Details are currently supported by only one click widgets
      | ShippingAddressLine1
      | ShippingAddressLine2
      | ShippingAddressCity
      | ShippingAddressPincode
      | ShippingAddressState
      | ShippingAddressCountry(_)
      | BankList(_)
      | VpaId
      | None => ()
      }
    })
    None
  }, [requiredFields])
}

let useRequiredFieldsBody = (
  ~requiredFields: array<PaymentMethodsRecord.required_fields>,
  ~paymentMethodType,
  ~cardNumber,
  ~cardExpiry,
  ~cvcNumber,
  ~isSavedCardFlow,
  ~isAllStoredCardsHaveName,
  ~setRequiredFieldsBody,
) => {
  let configValue = Recoil.useRecoilValueFromAtom(configAtom)
  let email = Recoil.useRecoilValueFromAtom(userEmailAddress)
  let vpaId = Recoil.useRecoilValueFromAtom(userVpaId)
  let pixCNPJ = Recoil.useRecoilValueFromAtom(userPixCNPJ)
  let pixCPF = Recoil.useRecoilValueFromAtom(userPixCPF)
  let pixKey = Recoil.useRecoilValueFromAtom(userPixKey)
  let fullName = Recoil.useRecoilValueFromAtom(userFullName)
  let billingName = Recoil.useRecoilValueFromAtom(userBillingName)
  let line1 = Recoil.useRecoilValueFromAtom(userAddressline1)
  let line2 = Recoil.useRecoilValueFromAtom(userAddressline2)
  let phone = Recoil.useRecoilValueFromAtom(userPhoneNumber)
  let state = Recoil.useRecoilValueFromAtom(userAddressState)
  let city = Recoil.useRecoilValueFromAtom(userAddressCity)
  let postalCode = Recoil.useRecoilValueFromAtom(userAddressPincode)
  let blikCode = Recoil.useRecoilValueFromAtom(userBlikCode)
  let country = Recoil.useRecoilValueFromAtom(userCountry)
  let selectedBank = Recoil.useRecoilValueFromAtom(userBank)
  let currency = Recoil.useRecoilValueFromAtom(userCurrency)
  let {billingAddress} = Recoil.useRecoilValueFromAtom(optionAtom)
  let cryptoCurrencyNetworks = Recoil.useRecoilValueFromAtom(cryptoCurrencyNetworks)
  let dateOfBirth = Recoil.useRecoilValueFromAtom(dateOfBirth)
  let bankAccountNumber = Recoil.useRecoilValueFromAtom(userBankAccountNumber)
  let sourceBankAccountId = Recoil.useRecoilValueFromAtom(sourceBankAccountId)
  let countryCode = Utils.getCountryCode(country).isoAlpha2
  let stateCode = Utils.getStateCodeFromStateName(state.value, countryCode)
  let giftCardNumber = Recoil.useRecoilValueFromAtom(userGiftCardNumber)
  let giftCardCvc = Recoil.useRecoilValueFromAtom(userGiftCardCvc)

  let getFieldValueFromFieldType = (fieldType: PaymentMethodsRecord.paymentMethodsFields) => {
    switch fieldType {
    | Email => email.value
    | AddressLine1 => line1.value
    | AddressLine2 => line2.value
    | AddressCity => city.value
    | AddressPincode => postalCode.value
    | AddressState => stateCode
    | BlikCode => blikCode.value->Utils.removeHyphen
    | PhoneNumber => phone.value
    | PhoneCountryCode => phone.countryCode->Option.getOr("")
    | Currency(_) => currency
    | Country => country
    | LanguagePreference(languageOptions) =>
      languageOptions->Array.includes(
        configValue.config.locale->String.toUpperCase->String.split("-")->Array.join("_"),
      )
        ? configValue.config.locale
        : "en"
    | Bank =>
      (
        Bank.getBanks(paymentMethodType)
        ->Array.find(item => item.displayName == selectedBank)
        ->Option.getOr(Bank.defaultBank)
      ).value
    | AddressCountry(_) => {
        let countryCode =
          Country.getCountry(paymentMethodType, countryList)
          ->Array.filter(item => item.countryName === country)
          ->Array.get(0)
          ->Option.getOr(Country.defaultTimeZone)
        countryCode.isoAlpha2
      }
    | BillingName => billingName.value
    | CardNumber => cardNumber->CardValidations.clearSpaces
    | GiftCardNumber => giftCardNumber.value
    | GiftCardCvc => giftCardCvc.value
    | CardExpiryMonth =>
      let (month, _) = CardUtils.getExpiryDates(cardExpiry)
      month
    | CardExpiryYear =>
      let (_, year) = CardUtils.getExpiryDates(cardExpiry)
      year
    | CryptoCurrencyNetworks => cryptoCurrencyNetworks
    | DateOfBirth =>
      switch dateOfBirth->Nullable.toOption {
      | Some(x) => x->Date.toISOString->String.slice(~start=0, ~end=10)
      | None => ""
      }
    | CardCvc => cvcNumber
    | VpaId => vpaId.value
    | PixCNPJ => pixCNPJ.value
    | PixCPF => pixCPF.value
    | PixKey => pixKey.value
    | IBAN
    | BankAccountNumber =>
      bankAccountNumber.value
    | SourceBankAccountId => sourceBankAccountId.value
    | StateAndCity
    | PhoneNumberAndCountryCode
    | CountryAndPincode(_)
    | SpecialField(_)
    | InfoElement
    | CardExpiryMonthAndYear
    | CardExpiryAndCvc
    | FullName
    | ShippingName // Shipping Details are currently supported by only one click widgets
    | ShippingAddressLine1
    | ShippingAddressLine2
    | ShippingAddressCity
    | ShippingAddressPincode
    | ShippingAddressState
    | ShippingAddressCountry(_)
    | BankList(_)
    | None => ""
    }
  }

  let addBillingDetailsIfUseBillingAddress = requiredFieldsBody => {
    if billingAddress.isUseBillingAddress {
      billingAddressFields->Array.reduce(requiredFieldsBody, (acc, item) => {
        let value = item->getFieldValueFromFieldType
        if item === BillingName {
          let arr = value->String.split(" ")
          acc->Dict.set(
            "payment_method_data.billing.address.first_name",
            arr->Array.get(0)->Option.getOr("")->JSON.Encode.string,
          )
          acc->Dict.set(
            "payment_method_data.billing.address.last_name",
            arr->Array.get(1)->Option.getOr("")->JSON.Encode.string,
          )
        } else {
          let path = item->getBillingAddressPathFromFieldType
          acc->Dict.set(path, value->JSON.Encode.string)
        }
        acc
      })
    } else {
      requiredFieldsBody
    }
  }

  React.useEffect(() => {
    let requiredFieldsBody =
      requiredFields
      ->Array.filter(item => item.field_type !== None)
      ->Array.reduce(Dict.make(), (acc, item) => {
        let value = switch item.field_type {
        | BillingName => getName(item, billingName)
        | FullName => getName(item, fullName)
        | _ => item.field_type->getFieldValueFromFieldType
        }
        if value != "" {
          if (
            isSavedCardFlow &&
            (item.field_type === BillingName || item.field_type === FullName) &&
            item.display_name === "card_holder_name" &&
            item.required_field === "payment_method_data.card.card_holder_name"
          ) {
            if !isAllStoredCardsHaveName {
              acc->Dict.set(
                "payment_method_data.card_token.card_holder_name",
                value->JSON.Encode.string,
              )
            }
          } else {
            acc->Dict.set(item.required_field, value->JSON.Encode.string)
          }
        }
        acc
      })
      ->addBillingDetailsIfUseBillingAddress
    setRequiredFieldsBody(_ => requiredFieldsBody)
    None
  }, (
    fullName.value,
    email.value,
    vpaId.value,
    line1.value,
    line2.value,
    pixCNPJ.value,
    pixCPF.value,
    pixKey.value,
    city.value,
    postalCode.value,
    state.value,
    blikCode.value,
    phone.value,
    phone.countryCode,
    currency,
    billingName.value,
    country,
    cardNumber,
    cardExpiry,
    cvcNumber,
    selectedBank,
    cryptoCurrencyNetworks,
    dateOfBirth,
    bankAccountNumber,
    sourceBankAccountId,
    giftCardCvc.value,
    giftCardNumber.value,
  ))
}

let isFieldTypeToRenderOutsideBilling = (fieldType: PaymentMethodsRecord.paymentMethodsFields) => {
  switch fieldType {
  | FullName
  | CardNumber
  | GiftCardNumber
  | CardExpiryMonth
  | CardExpiryYear
  | CardExpiryMonthAndYear
  | CardCvc
  | GiftCardCvc
  | CardExpiryAndCvc
  | CryptoCurrencyNetworks
  | PixKey
  | PixCPF
  | PixCNPJ
  | DateOfBirth
  | Currency(_)
  | VpaId
  | IBAN
  | SourceBankAccountId
  | BankAccountNumber
  | InfoElement => true
  | _ => false
  }
}

let combineStateAndCity = arr => {
  open PaymentMethodsRecord
  let hasStateAndCity = arr->Array.includes(AddressState) && arr->Array.includes(AddressCity)
  if hasStateAndCity {
    arr->Array.push(StateAndCity)->ignore
    arr->Array.filter(item =>
      switch item {
      | AddressCity
      | AddressState => false
      | _ => true
      }
    )
  } else {
    arr
  }
}

let combineCountryAndPostal = arr => {
  open PaymentMethodsRecord
  let hasCountryAndPostal =
    arr
    ->Array.filter(item =>
      switch item {
      | AddressCountry(_) => true
      | AddressPincode => true
      | _ => false
      }
    )
    ->Array.length == 2

  let options = arr->Array.reduce([], (acc, item) => {
    acc->Array.concat(
      switch item {
      | AddressCountry(val) => val
      | _ => []
      },
    )
  })

  if hasCountryAndPostal {
    arr->Array.push(CountryAndPincode(options))->ignore
    arr->Array.filter(item =>
      switch item {
      | AddressPincode
      | AddressCountry(_) => false
      | _ => true
      }
    )
  } else {
    arr
  }
}

let combineCardExpiryMonthAndYear = arr => {
  open PaymentMethodsRecord
  let hasCardExpiryMonthAndYear =
    arr->Array.includes(CardExpiryMonth) && arr->Array.includes(CardExpiryYear)
  if hasCardExpiryMonthAndYear {
    arr->Array.push(CardExpiryMonthAndYear)->ignore
    arr->Array.filter(item =>
      switch item {
      | CardExpiryMonth
      | CardExpiryYear => false
      | _ => true
      }
    )
  } else {
    arr
  }
}

let combineCardExpiryAndCvc = arr => {
  open PaymentMethodsRecord
  let hasCardExpiryAndCvc =
    arr->Array.includes(CardExpiryMonthAndYear) && arr->Array.includes(CardCvc)
  if hasCardExpiryAndCvc {
    arr->Array.push(CardExpiryAndCvc)->ignore
    arr->Array.filter(item =>
      switch item {
      | CardExpiryMonthAndYear
      | CardCvc => false
      | _ => true
      }
    )
  } else {
    arr
  }
}

let combinePhoneNumberAndCountryCode = arr => {
  open PaymentMethodsRecord
  let hasPhoneNumberOrCountryCodeField =
    arr->Array.includes(PhoneCountryCode) || arr->Array.includes(PhoneNumber)
  if hasPhoneNumberOrCountryCodeField {
    arr->Array.push(PhoneNumberAndCountryCode)->ignore
    arr->Array.filter(item =>
      switch item {
      | PhoneCountryCode
      | PhoneNumber => false
      | _ => true
      }
    )
  } else {
    arr
  }
}

let updateDynamicFields = (
  arr: array<PaymentMethodsRecord.paymentMethodsFields>,
  billingAddress,
  isSaveDetailsWithClickToPay,
  clickToPayConfig,
) => {
  arr
  ->Utils.removeDuplicate
  ->Array.filter(item => item !== None)
  ->addBillingAddressIfUseBillingAddress(billingAddress)
  ->addClickToPayFieldsIfSaveDetailsWithClickToPay(isSaveDetailsWithClickToPay, clickToPayConfig)
  ->combineStateAndCity
  ->combineCountryAndPostal
  ->combineCardExpiryMonthAndYear
  ->combineCardExpiryAndCvc
  ->combinePhoneNumberAndCountryCode
}

let useSubmitCallback = () => {
  let (line1, setLine1) = Recoil.useRecoilState(userAddressline1)
  let (line2, setLine2) = Recoil.useRecoilState(userAddressline2)
  let (state, setState) = Recoil.useRecoilState(userAddressState)
  let (postalCode, setPostalCode) = Recoil.useRecoilState(userAddressPincode)
  let (city, setCity) = Recoil.useRecoilState(userAddressCity)
  let {billingAddress} = Recoil.useRecoilValueFromAtom(optionAtom)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  React.useCallback((ev: Window.event) => {
    let json = ev.data->Utils.safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit && !isGiftCardOnlyPayment {
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

let removeRequiredFieldsDuplicates = (
  requiredFields: array<PaymentMethodsRecord.required_fields>,
) => {
  let (_, requiredFields) = requiredFields->Array.reduce(([], []), (
    (requiredFieldKeys, uniqueRequiredFields),
    item,
  ) => {
    let requiredField = item.required_field

    if requiredFieldKeys->Array.includes(requiredField)->not {
      requiredFieldKeys->Array.push(requiredField)
      uniqueRequiredFields->Array.push(item)
    }

    (requiredFieldKeys, uniqueRequiredFields)
  })

  requiredFields
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
