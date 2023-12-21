open RecoilAtoms
@react.component
let make = (
  ~paymentType,
  ~list,
  ~paymentMethod,
  ~paymentMethodType,
  ~setRequiredFieldsBody,
  ~isSavedCardFlow=false,
  ~savedCards=[]: array<PaymentType.customerMethods>,
) => {
  React.useEffect1(() => {
    setRequiredFieldsBody(_ => Js.Dict.empty())
    None
  }, [paymentMethodType])

  //<...>//
  let paymentMethodTypes =
    PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~list,
      ~paymentMethod,
      ~paymentMethodType,
    )->Belt.Option.getWithDefault(PaymentMethodsRecord.defaultPaymentMethodType)

  let requiredFields = if paymentMethod === "card" {
    let creditPaymentMethodsRecord =
      PaymentMethodsRecord.getPaymentMethodTypeFromList(
        ~list,
        ~paymentMethod,
        ~paymentMethodType="credit",
      )->Belt.Option.getWithDefault(PaymentMethodsRecord.defaultPaymentMethodType)
    paymentMethodTypes.required_fields
    ->Utils.getDictFromJson
    ->Js.Dict.entries
    ->Js.Array2.concat(
      creditPaymentMethodsRecord.required_fields->Utils.getDictFromJson->Js.Dict.entries,
    )
    ->Js.Dict.fromArray
    ->Js.Json.object_
  } else if (
    PaymentMethodsRecord.dynamicFieldsEnabledPaymentMethods->Js.Array2.includes(paymentMethodType)
  ) {
    paymentMethodTypes.required_fields
  } else {
    Js.Json.null
  }

  let isAllStoredCardsHaveName = React.useMemo1(() => {
    PaymentType.getIsAllStoredCardsHaveName(savedCards)
  }, [savedCards])

  //<...>//
  let fieldsArr =
    PaymentMethodsRecord.getPaymentMethodFields(
      paymentMethodType,
      requiredFields,
      ~isSavedCardFlow,
      ~isAllStoredCardsHaveName,
      (),
    )
    ->Utils.removeDuplicate
    ->Js.Array2.filter(item => item !== None)
    ->PaymentUtils.updateDynamicFields()
    ->Belt.SortArray.stableSortBy(PaymentMethodsRecord.sortPaymentMethodFields)
  //<...>//

  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  let logger = Recoil.useRecoilValueFromAtom(loggerAtom)

  let setAreRequiredFieldsValid = Recoil.useSetRecoilState(areRequiredFieldsValid)
  let setAreRequiredFieldsEmpty = Recoil.useSetRecoilState(areRequiredFieldsEmpty)

  let (email, setEmail) = Recoil.useLoggedRecoilState(userEmailAddress, "email", logger)
  let (line1, setLine1) = Recoil.useLoggedRecoilState(userAddressline1, "line1", logger)
  let (line2, setLine2) = Recoil.useLoggedRecoilState(userAddressline2, "line2", logger)
  let (city, setCity) = Recoil.useLoggedRecoilState(userAddressCity, "city", logger)
  let (state, setState) = Recoil.useLoggedRecoilState(userAddressState, "state", logger)
  let (postalCode, setPostalCode) = Recoil.useLoggedRecoilState(
    userAddressPincode,
    "postal_code",
    logger,
  )
  let (postalCodes, setPostalCodes) = React.useState(_ => [PostalCodeType.defaultPostalCode])
  let (fullName, setFullName) = Recoil.useLoggedRecoilState(userFullName, "fullName", logger)
  let (blikCode, setBlikCode) = Recoil.useLoggedRecoilState(userBlikCode, "blikCode", logger)
  let (phone, setPhone) = Recoil.useLoggedRecoilState(userPhoneNumber, "phone", logger)
  let (currency, setCurrency) = Recoil.useLoggedRecoilState(userCurrency, "currency", logger)
  let (billingName, setBillingName) = Recoil.useLoggedRecoilState(
    userBillingName,
    "billingName",
    logger,
  )
  let line1Ref = React.useRef(Js.Nullable.null)
  let line2Ref = React.useRef(Js.Nullable.null)
  let cityRef = React.useRef(Js.Nullable.null)
  let postalRef = React.useRef(Js.Nullable.null)
  let (selectedBank, setSelectedBank) = Recoil.useRecoilState(userBank)
  let (country, setCountry) = Recoil.useRecoilState(userCountry)

  let (stateJson, setStatesJson) = React.useState(_ => None)

  let bankNames =
    Bank.getBanks(paymentMethodType)->Utils.getBankNames(paymentMethodTypes.bank_names)
  let countryNames = Utils.getCountryNames(Country.getCountry(paymentMethodType))

  let setCurrency = val => {
    setCurrency(. val)
  }
  let setSelectedBank = val => {
    setSelectedBank(. val)
  }
  let setCountry = val => {
    setCountry(. val)
  }

  React.useEffect0(() => {
    let bank = bankNames->Belt.Array.get(0)->Belt.Option.getWithDefault("")
    setSelectedBank(_ => bank)
    None
  })

  React.useEffect0(() => {
    open Promise
    // Dynamically import/download Postal codes and states JSON
    PostalCodeType.importPostalCode("./../PostalCodes.bs.js")
    ->then(res => {
      setPostalCodes(_ => res.default)
      resolve()
    })
    ->catch(_ => {
      setPostalCodes(_ => [PostalCodeType.defaultPostalCode])
      resolve()
    })
    ->ignore
    AddressPaymentInput.importStates("./../States.json")
    ->then(res => {
      setStatesJson(_ => Some(res.states))
      resolve()
    })
    ->catch(_ => {
      setStatesJson(_ => None)
      resolve()
    })
    ->ignore

    None
  })

  let regex = CardUtils.postalRegex(
    postalCodes,
    ~country={Utils.getCountryCode(country).isoAlpha2},
    (),
  )

  let onPostalChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]

    setPostalCode(.prev => {
      ...prev,
      value: val,
      errorString: "",
    })
    if regex !== "" && Js.Re.test_(regex->Js.Re.fromString, val) {
      CardUtils.blurRef(postalRef)
    }
  }

  let onPostalBlur = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]
    if regex !== "" && Js.Re.test_(regex->Js.Re.fromString, val) && val !== "" {
      setPostalCode(.prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else if regex !== "" && !Js.Re.test_(regex->Js.Re.fromString, val) && val !== "" {
      setPostalCode(.prev => {
        ...prev,
        isValid: Some(false),
        errorString: "Invalid postal code",
      })
    }
  }

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
      | Bank => Some(selectedBank !== "" || bankNames->Belt.Array.length === 0)
      | PhoneNumber => Some(phone.value !== "")
      | StateAndCity => Some(state.value !== "" && city.value !== "")
      | CountryAndPincode(countryArr) =>
        Some((country !== "" || countryArr->Belt.Array.length === 0) && postalCode.value !== "")
      | AddressCity => Some(city.value !== "")
      | AddressPincode => Some(postalCode.value !== "")
      | AddressState => Some(state.value !== "")
      | BlikCode => Some(blikCode.value !== "")
      | Currency(currencyArr) => Some(currency !== "" || currencyArr->Belt.Array.length === 0)
      | AddressLine2
      | SpecialField(_)
      | InfoElement
      | None =>
        Some(true)
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
      | AddressLine2
      | SpecialField(_)
      | InfoElement
      | None => false
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
    ),
  ))

  let requiredFieldsType =
    requiredFields
    ->Utils.getDictFromJson
    ->Js.Dict.values
    ->Js.Array2.map(item =>
      item->Utils.getDictFromJson->PaymentMethodsRecord.getRequiredFieldsFromJson
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
            setCountry(_ => countryCode.countryName)
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
      | StateAndCity
      | CountryAndPincode(_)
      | SpecialField(_)
      | InfoElement
      | None => ()
      }
    })
    None
  })

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
        | StateAndCity
        | CountryAndPincode(_)
        | SpecialField(_)
        | InfoElement
        | _ => ""
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
        // if (
        //   isSavedCardFlow &&
        //   (item.field_type === BillingName || item.field_type === FullName) &&
        //   item.display_name === "card_holder_name" &&
        //   item.required_field === "payment_method_data.card.card_holder_name"
        // ) {
        //   if !isAllStoredCardsHaveName {
        //     acc->Js.Dict.set(
        //       "payment_method_data.card_token.card_holder_name",
        //       value->Js.Json.string,
        //     )
        //   }
        // } else {
        //   acc->Js.Dict.set(item.required_field, value->Js.Json.string)
        // }
        acc->Js.Dict.set(item.required_field, value->Js.Json.string)
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
  ])

  let bottomElement = <InfoElement />

  let getCustomFieldName = (item: PaymentMethodsRecord.paymentMethodsFields) => {
    if (
      requiredFieldsType
      ->Js.Array2.filter(requiredFieldType =>
        requiredFieldType.field_type === item &&
          requiredFieldType.display_name === "card_holder_name"
      )
      ->Belt.Array.length > 0
    ) {
      Some(localeString.cardHolderName)
    } else {
      None
    }
  }

  {
    fieldsArr->Js.Array2.length > 0
      ? <div
          className="dynamic__fields p-2"
          style={ReactDOMStyle.make(
            ~border=`1px solid ${themeObj.borderColor}`,
            ~borderRadius=themeObj.borderRadius,
            ~margin=`10px 0`,
            (),
          )}>
          {React.string("Billing Details")}
          <div className="p-2 flex flex-col gap-2">
            {fieldsArr
            ->Js.Array2.mapi((item, index) => {
              <div
                key={index->Js.Int.toString} className="flex flex-col w-full place-content-between">
                {switch item {
                | FullName =>
                  <FullNamePaymentInput paymentType customFieldName={item->getCustomFieldName} />
                | BillingName =>
                  <BillingNamePaymentInput paymentType customFieldName={item->getCustomFieldName} />
                | Email => <EmailPaymentInput paymentType />
                | PhoneNumber => <PhoneNumberPaymentInput />
                | StateAndCity =>
                  <div className="state__city flex gap-1">
                    <PaymentField
                      fieldName=localeString.cityLabel
                      setValue={setCity}
                      value=city
                      onChange={ev => {
                        setCity(.prev => {
                          ...prev,
                          value: ReactEvent.Form.target(ev)["value"],
                        })
                      }}
                      paymentType
                      type_="text"
                      name="city"
                      inputRef=cityRef
                      placeholder=localeString.cityLabel
                    />
                    {switch stateJson {
                    | Some(options) =>
                      <PaymentDropDownField
                        fieldName=localeString.stateLabel
                        value=state
                        setValue=setState
                        options={options->Utils.getStateNames({
                          value: country,
                          isValid: None,
                          errorString: "",
                        })}
                      />
                    | None => React.null
                    }}
                  </div>
                | CountryAndPincode(countryArr) =>
                  <div className="country__pincode flex gap-1">
                    <DropdownField
                      appearance=config.appearance
                      fieldName=localeString.countryLabel
                      value=country
                      setValue={setCountry}
                      disabled=false
                      options=countryArr
                    />
                    <PaymentField
                      fieldName=localeString.postalCodeLabel
                      setValue={setPostalCode}
                      value=postalCode
                      onBlur=onPostalBlur
                      onChange=onPostalChange
                      paymentType
                      type_="tel"
                      name="postal"
                      inputRef=postalRef
                      placeholder=localeString.postalCodeLabel
                    />
                  </div>
                | AddressLine1 =>
                  <PaymentField
                    fieldName=localeString.line1Label
                    setValue={setLine1}
                    value=line1
                    onChange={ev => {
                      setLine1(.prev => {
                        ...prev,
                        value: ReactEvent.Form.target(ev)["value"],
                      })
                    }}
                    paymentType
                    type_="text"
                    name="line1"
                    inputRef=line1Ref
                    placeholder=localeString.line1Placeholder
                  />
                | AddressLine2 =>
                  <PaymentField
                    fieldName=localeString.line2Label
                    setValue={setLine2}
                    value=line2
                    onChange={ev => {
                      setLine2(.prev => {
                        ...prev,
                        value: ReactEvent.Form.target(ev)["value"],
                      })
                    }}
                    paymentType
                    type_="text"
                    name="line2"
                    inputRef=line2Ref
                    placeholder=localeString.line2Placeholder
                  />
                | AddressCity =>
                  <PaymentField
                    fieldName=localeString.cityLabel
                    setValue={setCity}
                    value=city
                    onChange={ev => {
                      setCity(.prev => {
                        ...prev,
                        value: ReactEvent.Form.target(ev)["value"],
                      })
                    }}
                    paymentType
                    type_="text"
                    name="city"
                    inputRef=cityRef
                    placeholder=localeString.cityLabel
                  />
                | AddressState =>
                  switch stateJson {
                  | Some(options) =>
                    <PaymentDropDownField
                      fieldName=localeString.stateLabel
                      value=state
                      setValue=setState
                      options={options->Utils.getStateNames({
                        value: country,
                        isValid: None,
                        errorString: "",
                      })}
                    />
                  | None => React.null
                  }
                | AddressPincode =>
                  <PaymentField
                    fieldName=localeString.postalCodeLabel
                    setValue={setPostalCode}
                    value=postalCode
                    onBlur=onPostalBlur
                    onChange=onPostalChange
                    paymentType
                    type_="tel"
                    name="postal"
                    inputRef=postalRef
                    placeholder=localeString.postalCodeLabel
                  />
                | BlikCode => <BlikCodePaymentInput />
                | Currency(currencyArr) =>
                  <DropdownField
                    appearance=config.appearance
                    fieldName=localeString.currencyLabel
                    value=currency
                    setValue=setCurrency
                    disabled=false
                    options=currencyArr
                  />
                | Country =>
                  <DropdownField
                    appearance=config.appearance
                    fieldName=localeString.countryLabel
                    value=country
                    setValue=setCountry
                    disabled=false
                    options=countryNames
                  />
                | AddressCountry(countryArr) =>
                  <DropdownField
                    appearance=config.appearance
                    fieldName=localeString.countryLabel
                    value=country
                    setValue=setCountry
                    disabled=false
                    options=countryArr
                  />
                | Bank =>
                  <DropdownField
                    appearance=config.appearance
                    fieldName=localeString.bankLabel
                    value=selectedBank
                    setValue=setSelectedBank
                    disabled=false
                    options=bankNames
                  />
                | SpecialField(element) => element
                | InfoElement =>
                  <>
                    <Surcharge list paymentMethod paymentMethodType />
                    {if fieldsArr->Js.Array2.length > 1 {
                      bottomElement
                    } else {
                      <Block bottomElement />
                    }}
                  </>
                | None => React.null
                }}
              </div>
            })
            ->React.array}
          </div>
        </div>
      : React.null
  }
}
