let useRequiredFieldsEmptyAndValid = (
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

  React.useEffect7(() => {
    let areRequiredFieldsValid = fieldsArr->Js.Array2.reduce((acc, paymentMethodFields) => {
      acc &&
      switch paymentMethodFields {
      | Email => email.isValid
      | FullName => Some(fullName.value !== "")
      | Country => Some(country !== "" || countryNames->Belt.Array.length === 0)
      | AddressCountry(countryArr) => Some(country !== "" || countryArr->Belt.Array.length === 0)
      | BillingName => Some(billingName.value !== "")
      | AddressLine1 => Some(line1.value !== "")
      | AddressLine2 => Some(line2.value !== "")
      | Bank => Some(selectedBank !== "" || bankNames->Belt.Array.length === 0)
      | PhoneNumber => Some(phone.value !== "")
      | StateAndCity => Some(state.value !== "" && city.value !== "")
      | CountryAndPincode(countryArr) =>
        Some(
          (country !== "" || countryArr->Belt.Array.length === 0) &&
            postalCode.isValid->Belt.Option.getWithDefault(false),
        )
      | AddressCity => Some(city.value !== "")
      | AddressPincode => postalCode.isValid
      | AddressState => Some(state.value !== "")
      | BlikCode => Some(blikCode.value !== "")
      | Currency(currencyArr) => Some(currency !== "" || currencyArr->Belt.Array.length === 0)
      | CardNumber => isCardValid
      | CardExpiryMonth
      | CardExpiryYear
      | CardExpiryMonthAndYear => isExpiryValid
      | CardCvc => isCVCValid
      | CardExpiryAndCvc =>
        Some(
          isExpiryValid->Belt.Option.getWithDefault(false) &&
            isCVCValid->Belt.Option.getWithDefault(false),
        )
      | _ => Some(true)
      }->Belt.Option.getWithDefault(false)
    }, true)
    setAreRequiredFieldsValid(._ => areRequiredFieldsValid)

    let areRequiredFieldsEmpty = fieldsArr->Js.Array2.reduce((acc, paymentMethodFields) => {
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
      postalCode.value,
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
  ~requiredFieldsType: Js.Array2.t<PaymentMethodsRecord.required_fields>,
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

  React.useEffect0(() => {
    let getNameValue = (item: PaymentMethodsRecord.required_fields) => {
      requiredFieldsType
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

    requiredFieldsType->Js.Array2.forEach(requiredField => {
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
  })
}

let useRequiredFieldsBody = (
  ~requiredFieldsType: Js.Array2.t<PaymentMethodsRecord.required_fields>,
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

  React.useEffect1(() => {
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

    let requiredFieldsBody =
      requiredFieldsType
      ->Js.Array2.filter(item => item.field_type !== None)
      ->Js.Array2.reduce((acc, item) => {
        let value = switch item.field_type {
        | Email => email.value
        | FullName => getName(item, fullName)
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
        | BillingName => getName(item, billingName)
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
        | None => ""
        }
        switch item.field_type {
        | StateAndCity =>
          acc->Js.Dict.set("billing.address.city", city.value->Js.Json.string)
          acc->Js.Dict.set("billing.address.state", state.value->Js.Json.string)
        | CountryAndPincode(_) =>
          acc->Js.Dict.set("billing.address.country", city.value->Js.Json.string)
          acc->Js.Dict.set("billing.address.zip", postalCode.value->Js.Json.string)
        | _ => ()
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
