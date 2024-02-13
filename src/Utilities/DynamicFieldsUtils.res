let getName = (item: PaymentMethodsRecord.required_fields, field: RecoilAtomTypes.field) => {
  let fieldNameArr = field.value->Js.String2.split(" ")
  let requiredFieldsArr = item.required_field->Js.String2.split(".")
  switch requiredFieldsArr
  ->Belt.Array.get(requiredFieldsArr->Belt.Array.length - 1)
  ->Belt.Option.getWithDefault("") {
  | "first_name" => fieldNameArr->Belt.Array.get(0)->Belt.Option.getWithDefault(field.value)
  | "last_name" => fieldNameArr->Belt.Array.sliceToEnd(1)->Js.Array2.reduce((acc, item) => {
      acc ++ item
    }, "")
  | _ => field.value
  }
}

let countryNames = Utils.getCountryNames(Country.country)

let billingAddressFields: array<PaymentMethodsRecord.paymentMethodsFields> = [
  AddressLine1,
  AddressLine2,
  AddressCity,
  AddressState,
  AddressCountry(countryNames),
  AddressPincode,
]

let isBillingAddressFieldType = (fieldType: PaymentMethodsRecord.paymentMethodsFields) => {
  switch fieldType {
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
  | AddressLine1 => "billing.address.line1"
  | AddressLine2 => "billing.address.line2"
  | AddressCity => "billing.address.city"
  | AddressState => "billing.address.state"
  | AddressCountry(_) => "billing.address.country"
  | AddressPincode => "billing.address.zip"
  | _ => ""
  }
}

let removeBillingDetailsIfUseBillingAddress = (
  requiredFields: Js.Array2.t<PaymentMethodsRecord.required_fields>,
  billingAddress: PaymentType.billingAddress,
) => {
  if billingAddress.isUseBillingAddress {
    requiredFields->Js.Array2.filter(requiredField => {
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
    fieldsArr->Js.Array2.concat(billingAddressFields)
  } else {
    fieldsArr
  }
}

let checkIfNameIsValid = (
  requiredFieldsType: array<PaymentMethodsRecord.required_fields>,
  paymentMethodFields,
  field: RecoilAtomTypes.field,
) => {
  requiredFieldsType
  ->Js.Array2.filter(required_field => required_field.field_type === paymentMethodFields)
  ->Js.Array2.reduce((acc, item) => {
    let fieldNameArr = field.value->Js.String2.split(" ")
    let requiredFieldsArr = item.required_field->Js.String2.split(".")
    let fieldValue = switch requiredFieldsArr
    ->Belt.Array.get(requiredFieldsArr->Belt.Array.length - 1)
    ->Belt.Option.getWithDefault("") {
    | "first_name" => fieldNameArr->Belt.Array.get(0)->Belt.Option.getWithDefault("")
    | "last_name" => fieldNameArr->Belt.Array.get(1)->Belt.Option.getWithDefault("")
    | _ => field.value
    }
    acc && fieldValue !== ""
  }, true)
}

let useRequiredFieldsEmptyAndValid = (
  ~requiredFields,
  ~fieldsArr: Js.Array2.t<PaymentMethodsRecord.paymentMethodsFields>,
  ~countryNames,
  ~bankNames,
  ~isCardValid,
  ~isExpiryValid,
  ~isCVCValid,
  ~cardNumber,
  ~cardExpiry,
  ~cvcNumber,
) => {
  let email = Recoil.useRecoilValueFromAtom(RecoilAtoms.userEmailAddress)
  let fullName = Recoil.useRecoilValueFromAtom(RecoilAtoms.userFullName)
  let billingName = Recoil.useRecoilValueFromAtom(RecoilAtoms.userBillingName)
  let line1 = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressline1)
  let line2 = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressline2)
  let phone = Recoil.useRecoilValueFromAtom(RecoilAtoms.userPhoneNumber)
  let state = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressState)
  let city = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressCity)
  let postalCode = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressPincode)
  let blikCode = Recoil.useRecoilValueFromAtom(RecoilAtoms.userBlikCode)
  let country = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let selectedBank = Recoil.useRecoilValueFromAtom(RecoilAtoms.userBank)
  let currency = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCurrency)
  let setAreRequiredFieldsValid = Recoil.useSetRecoilState(RecoilAtoms.areRequiredFieldsValid)
  let setAreRequiredFieldsEmpty = Recoil.useSetRecoilState(RecoilAtoms.areRequiredFieldsEmpty)
  let {billingAddress} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)

  let fieldsArrWithBillingAddress = fieldsArr->addBillingAddressIfUseBillingAddress(billingAddress)

  React.useEffect7(() => {
    let areRequiredFieldsValid = fieldsArr->Js.Array2.reduce((acc, paymentMethodFields) => {
      acc &&
      switch paymentMethodFields {
      | Email => email.isValid->Belt.Option.getWithDefault(false)
      | FullName => checkIfNameIsValid(requiredFields, paymentMethodFields, fullName)
      | Country => country !== "" || countryNames->Belt.Array.length === 0
      | AddressCountry(countryArr) => country !== "" || countryArr->Belt.Array.length === 0
      | BillingName => checkIfNameIsValid(requiredFields, paymentMethodFields, billingName)
      | AddressLine1 => line1.value !== ""
      | AddressLine2 => line2.value !== ""
      | Bank => selectedBank !== "" || bankNames->Belt.Array.length === 0
      | PhoneNumber => phone.value !== ""
      | StateAndCity => state.value !== "" && city.value !== ""
      | CountryAndPincode(countryArr) =>
        (country !== "" || countryArr->Belt.Array.length === 0) &&
          postalCode.isValid->Belt.Option.getWithDefault(false)

      | AddressCity => city.value !== ""
      | AddressPincode => postalCode.isValid->Belt.Option.getWithDefault(false)
      | AddressState => state.value !== ""
      | BlikCode => blikCode.value !== ""
      | Currency(currencyArr) => currency !== "" || currencyArr->Belt.Array.length === 0
      | CardNumber => isCardValid->Belt.Option.getWithDefault(false)
      | CardExpiryMonth
      | CardExpiryYear
      | CardExpiryMonthAndYear =>
        isExpiryValid->Belt.Option.getWithDefault(false)
      | CardCvc => isCVCValid->Belt.Option.getWithDefault(false)
      | CardExpiryAndCvc =>
        isExpiryValid->Belt.Option.getWithDefault(false) &&
          isCVCValid->Belt.Option.getWithDefault(false)
      | _ => true
      }
    }, true)
    setAreRequiredFieldsValid(._ => areRequiredFieldsValid)

    let areRequiredFieldsEmpty =
      fieldsArrWithBillingAddress->Js.Array2.reduce((acc, paymentMethodFields) => {
        acc ||
        switch paymentMethodFields {
        | Email => email.value === ""
        | FullName => fullName.value === ""
        | Country => country === "" && countryNames->Belt.Array.length > 0
        | AddressCountry(countryArr) => country === "" && countryArr->Belt.Array.length > 0
        | BillingName => billingName.value === ""
        | AddressLine1 => line1.value === ""
        | AddressLine2 => line2.value === ""
        | Bank => selectedBank === "" && bankNames->Belt.Array.length > 0
        | StateAndCity => city.value === "" || state.value === ""
        | CountryAndPincode(countryArr) =>
          (country === "" && countryArr->Belt.Array.length > 0) || postalCode.value === ""
        | PhoneNumber => phone.value === ""
        | AddressCity => city.value === ""
        | AddressPincode => postalCode.value === ""
        | AddressState => state.value === ""
        | BlikCode => blikCode.value === ""
        | Currency(currencyArr) => currency === "" && currencyArr->Belt.Array.length > 0
        | CardNumber => cardNumber === ""
        | CardExpiryMonth =>
          let (month, _) = CardUtils.getExpiryDates(cardExpiry)
          month === ""
        | CardExpiryYear =>
          let (_, year) = CardUtils.getExpiryDates(cardExpiry)
          year === ""
        | CardExpiryMonthAndYear =>
          let (month, year) = CardUtils.getExpiryDates(cardExpiry)
          month === "" || year === ""
        | CardCvc => cvcNumber === ""
        | CardExpiryAndCvc =>
          let (month, year) = CardUtils.getExpiryDates(cardExpiry)
          month === "" || year === "" || cvcNumber === ""
        | _ => false
        }
      }, false)
    setAreRequiredFieldsEmpty(._ => areRequiredFieldsEmpty)
    None
  }, (
    fieldsArr,
    currency,
    fullName.value,
    country,
    billingName.value,
    line1.value,
    (
      email,
      line2.value,
      selectedBank,
      phone.value,
      city.value,
      postalCode,
      state.value,
      blikCode.value,
      isCardValid,
      isExpiryValid,
      isCVCValid,
      cardNumber,
      cardExpiry,
      cvcNumber,
    ),
  ))
}

let useSetInitialRequiredFields = (
  ~requiredFields: Js.Array2.t<PaymentMethodsRecord.required_fields>,
  ~paymentMethodType,
) => {
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let (email, setEmail) = Recoil.useLoggedRecoilState(RecoilAtoms.userEmailAddress, "email", logger)
  let (fullName, setFullName) = Recoil.useLoggedRecoilState(
    RecoilAtoms.userFullName,
    "fullName",
    logger,
  )
  let (billingName, setBillingName) = Recoil.useLoggedRecoilState(
    RecoilAtoms.userBillingName,
    "billingName",
    logger,
  )
  let (line1, setLine1) = Recoil.useLoggedRecoilState(RecoilAtoms.userAddressline1, "line1", logger)
  let (line2, setLine2) = Recoil.useLoggedRecoilState(RecoilAtoms.userAddressline2, "line2", logger)
  let (phone, setPhone) = Recoil.useLoggedRecoilState(RecoilAtoms.userPhoneNumber, "phone", logger)
  let (state, setState) = Recoil.useLoggedRecoilState(RecoilAtoms.userAddressState, "state", logger)
  let (city, setCity) = Recoil.useLoggedRecoilState(RecoilAtoms.userAddressCity, "city", logger)
  let (postalCode, setPostalCode) = Recoil.useLoggedRecoilState(
    RecoilAtoms.userAddressPincode,
    "postal_code",
    logger,
  )
  let (blikCode, setBlikCode) = Recoil.useLoggedRecoilState(
    RecoilAtoms.userBlikCode,
    "blikCode",
    logger,
  )
  let (country, setCountry) = Recoil.useLoggedRecoilState(
    RecoilAtoms.userCountry,
    "country",
    logger,
  )
  let (selectedBank, setSelectedBank) = Recoil.useLoggedRecoilState(
    RecoilAtoms.userBank,
    "selectedBank",
    logger,
  )
  let (currency, setCurrency) = Recoil.useLoggedRecoilState(
    RecoilAtoms.userCurrency,
    "currency",
    logger,
  )

  React.useEffect1(() => {
    let getNameValue = (item: PaymentMethodsRecord.required_fields) => {
      requiredFields
      ->Js.Array2.filter(requiredFields => requiredFields.field_type === item.field_type)
      ->Js.Array2.reduce((acc, item) => {
        let requiredFieldsArr = item.required_field->Js.String2.split(".")
        switch requiredFieldsArr
        ->Belt.Array.get(requiredFieldsArr->Belt.Array.length - 1)
        ->Belt.Option.getWithDefault("") {
        | "first_name" => item.value->Js.String2.concat(acc)
        | "last_name" => acc->Js.String2.concatMany([" ", item.value])
        | _ => acc
        }
      }, "")
      ->Js.String2.trim
    }

    let setFields = (
      setMethod: (. RecoilAtomTypes.field => RecoilAtomTypes.field) => unit,
      field: RecoilAtomTypes.field,
      item: PaymentMethodsRecord.required_fields,
      isNameField,
    ) => {
      if isNameField && field.value === "" {
        setMethod(.prev => {
          ...prev,
          value: getNameValue(item),
        })
      } else if field.value === "" {
        setMethod(.prev => {
          ...prev,
          value: item.value,
        })
      }
    }

    requiredFields->Js.Array2.forEach(requiredField => {
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
              Country.getCountry(paymentMethodType)
              ->Js.Array2.filter(item => item.isoAlpha2 === value)
              ->Belt.Array.get(0)
              ->Belt.Option.getWithDefault(Country.defaultTimeZone)
            setCountry(. _ => countryCode.countryName)
          }
        }
      | AddressState => setFields(setState, state, requiredField, false)
      | AddressCity => setFields(setCity, city, requiredField, false)
      | AddressPincode => setFields(setPostalCode, postalCode, requiredField, false)
      | PhoneNumber => setFields(setPhone, phone, requiredField, false)
      | BlikCode => setFields(setBlikCode, blikCode, requiredField, false)
      | BillingName => setFields(setBillingName, billingName, requiredField, true)
      | Country
      | AddressCountry(_) =>
        if value !== "" {
          let defaultCountry =
            Country.getCountry(paymentMethodType)
            ->Js.Array2.filter(item => item.isoAlpha2 === value)
            ->Belt.Array.get(0)
            ->Belt.Option.getWithDefault(Country.defaultTimeZone)
          setCountry(. _ => defaultCountry.countryName)
        }
      | Currency(_) =>
        if value !== "" && currency === "" {
          setCurrency(. _ => value)
        }
      | Bank =>
        if value !== "" && selectedBank === "" {
          setSelectedBank(. _ => value)
        }
      | StateAndCity
      | CountryAndPincode(_)
      | SpecialField(_)
      | InfoElement
      | CardNumber
      | CardExpiryMonth
      | CardExpiryYear
      | CardExpiryMonthAndYear
      | CardCvc
      | CardExpiryAndCvc
      | None => ()
      }
    })
    None
  }, [requiredFields])
}

let useRequiredFieldsBody = (
  ~requiredFields: Js.Array2.t<PaymentMethodsRecord.required_fields>,
  ~paymentMethodType,
  ~cardNumber,
  ~cardExpiry,
  ~cvcNumber,
  ~isSavedCardFlow,
  ~isAllStoredCardsHaveName,
  ~setRequiredFieldsBody,
) => {
  let email = Recoil.useRecoilValueFromAtom(RecoilAtoms.userEmailAddress)
  let fullName = Recoil.useRecoilValueFromAtom(RecoilAtoms.userFullName)
  let billingName = Recoil.useRecoilValueFromAtom(RecoilAtoms.userBillingName)
  let line1 = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressline1)
  let line2 = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressline2)
  let phone = Recoil.useRecoilValueFromAtom(RecoilAtoms.userPhoneNumber)
  let state = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressState)
  let city = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressCity)
  let postalCode = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressPincode)
  let blikCode = Recoil.useRecoilValueFromAtom(RecoilAtoms.userBlikCode)
  let country = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let selectedBank = Recoil.useRecoilValueFromAtom(RecoilAtoms.userBank)
  let currency = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCurrency)
  let {billingAddress} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)

  let getFieldValueFromFieldType = (fieldType: PaymentMethodsRecord.paymentMethodsFields) => {
    switch fieldType {
    | Email => email.value
    | AddressLine1 => line1.value
    | AddressLine2 => line2.value
    | AddressCity => city.value
    | AddressPincode => postalCode.value
    | AddressState => state.value
    | BlikCode => blikCode.value
    | PhoneNumber => phone.value
    | Currency(_) => currency
    | Country => country
    | Bank => selectedBank
    | AddressCountry(_) => {
        let countryCode =
          Country.getCountry(paymentMethodType)
          ->Js.Array2.filter(item => item.countryName === country)
          ->Belt.Array.get(0)
          ->Belt.Option.getWithDefault(Country.defaultTimeZone)
        countryCode.isoAlpha2
      }
    | CardNumber => cardNumber->CardUtils.clearSpaces
    | CardExpiryMonth =>
      let (month, _) = CardUtils.getExpiryDates(cardExpiry)
      month
    | CardExpiryYear =>
      let (_, year) = CardUtils.getExpiryDates(cardExpiry)
      year
    | CardCvc => cvcNumber
    | StateAndCity
    | CountryAndPincode(_)
    | SpecialField(_)
    | InfoElement
    | CardExpiryMonthAndYear
    | CardExpiryAndCvc
    | FullName
    | BillingName
    | None => ""
    }
  }

  let addBillingDetailsIfUseBillingAddress = requiredFieldsBody => {
    if billingAddress.isUseBillingAddress {
      billingAddressFields->Js.Array2.reduce((acc, item) => {
        let value = item->getFieldValueFromFieldType
        let path = item->getBillingAddressPathFromFieldType
        acc->Js.Dict.set(path, value->Js.Json.string)
        acc
      }, requiredFieldsBody)
    } else {
      requiredFieldsBody
    }
  }

  React.useEffect1(() => {
    let requiredFieldsBody =
      requiredFields
      ->Js.Array2.filter(item => item.field_type !== None)
      ->Js.Array2.reduce((acc, item) => {
        let value = switch item.field_type {
        | BillingName => getName(item, billingName)
        | FullName => getName(item, fullName)
        | _ => item.field_type->getFieldValueFromFieldType
        }
        if (
          isSavedCardFlow &&
          (item.field_type === BillingName || item.field_type === FullName) &&
          item.display_name === "card_holder_name" &&
          item.required_field === "payment_method_data.card.card_holder_name"
        ) {
          if !isAllStoredCardsHaveName {
            acc->Js.Dict.set(
              "payment_method_data.card_token.card_holder_name",
              value->Js.Json.string,
            )
          }
        } else {
          acc->Js.Dict.set(item.required_field, value->Js.Json.string)
        }
        acc
      }, Js.Dict.empty())
      ->addBillingDetailsIfUseBillingAddress

    setRequiredFieldsBody(_ => requiredFieldsBody)
    None
  }, [
    fullName.value,
    email.value,
    line1.value,
    line2.value,
    city.value,
    postalCode.value,
    state.value,
    blikCode.value,
    phone.value,
    currency,
    billingName.value,
    country,
    cardNumber,
    cardExpiry,
    cvcNumber,
  ])
}

let isFieldTypeToRenderOutsideBilling = (fieldType: PaymentMethodsRecord.paymentMethodsFields) => {
  switch fieldType {
  | CardNumber
  | CardExpiryMonth
  | CardExpiryYear
  | CardExpiryMonthAndYear
  | CardCvc
  | CardExpiryAndCvc
  | Currency(_) => true
  | _ => false
  }
}

let combineStateAndCity = arr => {
  open PaymentMethodsRecord
  let hasStateAndCity =
    arr->Js.Array2.includes(AddressState) && arr->Js.Array2.includes(AddressCity)
  if hasStateAndCity {
    arr->Js.Array2.push(StateAndCity)->ignore
    arr->Js.Array2.filter(item =>
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
    ->Js.Array2.filter(item =>
      switch item {
      | AddressCountry(_) => true
      | AddressPincode => true
      | _ => false
      }
    )
    ->Js.Array2.length == 2

  let options = arr->Js.Array2.reduce((acc, item) => {
    acc->Js.Array2.concat(
      switch item {
      | AddressCountry(val) => val
      | _ => []
      },
    )
  }, [])

  if hasCountryAndPostal {
    arr->Js.Array2.push(CountryAndPincode(options))->ignore
    arr->Js.Array2.filter(item =>
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
    arr->Js.Array2.includes(CardExpiryMonth) && arr->Js.Array2.includes(CardExpiryYear)
  if hasCardExpiryMonthAndYear {
    arr->Js.Array2.push(CardExpiryMonthAndYear)->ignore
    arr->Js.Array2.filter(item =>
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
    arr->Js.Array2.includes(CardExpiryMonthAndYear) && arr->Js.Array2.includes(CardCvc)
  if hasCardExpiryAndCvc {
    arr->Js.Array2.push(CardExpiryAndCvc)->ignore
    arr->Js.Array2.filter(item =>
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

let updateDynamicFields = (
  arr: Js.Array2.t<PaymentMethodsRecord.paymentMethodsFields>,
  billingAddress,
  (),
) => {
  arr
  ->Utils.removeDuplicate
  ->Js.Array2.filter(item => item !== None)
  ->addBillingAddressIfUseBillingAddress(billingAddress)
  ->combineStateAndCity
  ->combineCountryAndPostal
  ->combineCardExpiryMonthAndYear
  ->combineCardExpiryAndCvc
}
