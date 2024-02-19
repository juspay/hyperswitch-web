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
  ~cardProps=None,
  ~expiryProps=None,
  ~cvcProps=None,
  ~isBancontact=false,
) => {
  React.useEffect1(() => {
    setRequiredFieldsBody(_ => Js.Dict.empty())
    None
  }, [paymentMethodType])

  let {billingAddress} = Recoil.useRecoilValueFromAtom(optionAtom)

  //<...>//
  let paymentMethodTypes = React.useMemo3(() => {
    PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~list,
      ~paymentMethod,
      ~paymentMethodType=PaymentUtils.getPaymentMethodName(
        ~paymentMethodType=paymentMethod,
        ~paymentMethodName=paymentMethodType,
      ),
    )->Belt.Option.getWithDefault(PaymentMethodsRecord.defaultPaymentMethodType)
  }, (list, paymentMethod, paymentMethodType))

  let requiredFieldsWithBillingDetails = React.useMemo3(() => {
    if paymentMethod === "card" {
      paymentMethodTypes.required_fields
    } else if (
      PaymentMethodsRecord.dynamicFieldsEnabledPaymentMethods->Js.Array2.includes(paymentMethodType)
    ) {
      paymentMethodTypes.required_fields
    } else {
      []
    }
  }, (paymentMethod, paymentMethodTypes.required_fields, paymentMethodType))

  let requiredFields = React.useMemo1(() => {
    requiredFieldsWithBillingDetails->DynamicFieldsUtils.removeBillingDetailsIfUseBillingAddress(
      billingAddress,
    )
  }, [requiredFieldsWithBillingDetails])

  let isAllStoredCardsHaveName = React.useMemo1(() => {
    PaymentType.getIsAllStoredCardsHaveName(savedCards)
  }, [savedCards])

  //<...>//
  let fieldsArr = React.useMemo3(() => {
    PaymentMethodsRecord.getPaymentMethodFields(
      paymentMethodType,
      requiredFields,
      ~isSavedCardFlow,
      ~isAllStoredCardsHaveName,
      (),
    )
    ->DynamicFieldsUtils.updateDynamicFields(billingAddress, ())
    ->Belt.SortArray.stableSortBy(PaymentMethodsRecord.sortPaymentMethodFields)
    //<...>//
  }, (requiredFields, isAllStoredCardsHaveName, isSavedCardFlow))

  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  let logger = Recoil.useRecoilValueFromAtom(loggerAtom)

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
  let (currency, setCurrency) = Recoil.useLoggedRecoilState(userCurrency, "currency", logger)
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

  let (
    isCardValid,
    setIsCardValid,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    icon,
    cardError,
    _,
    maxCardLength,
  ) =
    cardProps->CardUtils.getCardDetailsFromCardProps

  let (
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    _,
    expiryError,
    _,
  ) =
    expiryProps->CardUtils.getExpiryDetailsFromExpiryProps

  let (
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    _,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    _,
    cvcError,
    _,
  ) =
    cvcProps->CardUtils.getCvcDetailsFromCvcProps

  let isCvcValidValue = CardUtils.getBoolOptionVal(isCVCValid)
  let (cardEmpty, cardComplete, cardInvalid) = CardUtils.useCardDetails(
    ~cvcNumber,
    ~isCVCValid,
    ~isCvcValidValue,
  )

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

    if val !== "" {
      setPostalCode(._ => {
        isValid: Some(true),
        value: val,
        errorString: "",
      })
    } else {
      setPostalCode(._ => {
        isValid: Some(false),
        value: val,
        errorString: "",
      })
    }
  }

  DynamicFieldsUtils.useRequiredFieldsEmptyAndValid(
    ~requiredFields,
    ~fieldsArr,
    ~countryNames,
    ~bankNames,
    ~isCardValid,
    ~isExpiryValid,
    ~isCVCValid,
    ~cardNumber,
    ~cardExpiry,
    ~cvcNumber,
  )

  DynamicFieldsUtils.useSetInitialRequiredFields(
    ~requiredFields={
      billingAddress.usePrefilledValues === Auto ? requiredFieldsWithBillingDetails : requiredFields
    },
    ~paymentMethodType,
  )

  DynamicFieldsUtils.useRequiredFieldsBody(
    ~requiredFields,
    ~paymentMethodType,
    ~cardNumber,
    ~cardExpiry,
    ~cvcNumber,
    ~isSavedCardFlow,
    ~isAllStoredCardsHaveName,
    ~setRequiredFieldsBody,
  )

  let submitCallback = DynamicFieldsUtils.useSubmitCallback()
  Utils.submitPaymentData(submitCallback)

  let bottomElement = <InfoElement />

  let getCustomFieldName = (item: PaymentMethodsRecord.paymentMethodsFields) => {
    if (
      requiredFields
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

  let dynamicFieldsToRenderOutsideBilling = React.useMemo1(() => {
    fieldsArr->Js.Array2.filter(field =>
      field->DynamicFieldsUtils.isFieldTypeToRenderOutsideBilling
    )
  }, [fieldsArr])

  let dynamicFieldsToRenderInsideBilling = React.useMemo1(() => {
    fieldsArr->Js.Array2.filter(field =>
      !(field->DynamicFieldsUtils.isFieldTypeToRenderOutsideBilling)
    )
  }, [fieldsArr])

  let isInfoElementPresent = React.useMemo1(() => {
    dynamicFieldsToRenderInsideBilling->Js.Array2.includes(InfoElement)
  }, [dynamicFieldsToRenderInsideBilling])

  let isOnlyInfoElementPresent = React.useMemo2(() => {
    dynamicFieldsToRenderInsideBilling->Js.Array2.length === 1 && isInfoElementPresent
  }, (dynamicFieldsToRenderInsideBilling, isInfoElementPresent))

  let isRenderDynamicFieldsInsideBilling = React.useMemo2(() => {
    dynamicFieldsToRenderInsideBilling->Js.Array2.length > 0 &&
      (dynamicFieldsToRenderInsideBilling->Js.Array2.length > 1 || !isOnlyInfoElementPresent)
  }, (dynamicFieldsToRenderInsideBilling, isOnlyInfoElementPresent))

  {
    fieldsArr->Js.Array2.length > 0
      ? <>
          {dynamicFieldsToRenderOutsideBilling
          ->Js.Array2.mapi((item, index) => {
            <div
              key={`outside-billing-${index->Js.Int.toString}`}
              className="flex flex-col w-full place-content-between"
              style={ReactDOMStyle.make(
                ~marginTop=index !== 0 || paymentMethod === "card"
                  ? themeObj.spacingGridColumn
                  : "",
                ~gridColumnGap=themeObj.spacingGridRow,
                (),
              )}>
              {switch item {
              | CardNumber =>
                <PaymentInputField
                  fieldName=localeString.cardNumberLabel
                  isValid=isCardValid
                  setIsValid=setIsCardValid
                  value=cardNumber
                  onChange=changeCardNumber
                  onBlur=handleCardBlur
                  rightIcon={icon}
                  errorString=cardError
                  paymentType
                  type_="tel"
                  appearance=config.appearance
                  maxLength=maxCardLength
                  inputRef=cardRef
                  placeholder="1234 1234 1234 1234"
                />
              | CardExpiryMonth
              | CardExpiryYear
              | CardExpiryMonthAndYear =>
                <PaymentInputField
                  fieldName=localeString.validThruText
                  isValid=isExpiryValid
                  setIsValid=setIsExpiryValid
                  value=cardExpiry
                  onChange=changeCardExpiry
                  onBlur=handleExpiryBlur
                  errorString=expiryError
                  paymentType
                  type_="tel"
                  appearance=config.appearance
                  maxLength=7
                  inputRef=expiryRef
                  placeholder="MM / YY"
                />
              | CardCvc =>
                <PaymentInputField
                  fieldName=localeString.cvcTextLabel
                  isValid=isCVCValid
                  setIsValid=setIsCVCValid
                  value=cvcNumber
                  onChange=changeCVCNumber
                  onBlur=handleCVCBlur
                  errorString=cvcError
                  paymentType
                  rightIcon={CardUtils.setRightIconForCvc(
                    ~cardEmpty,
                    ~cardInvalid,
                    ~color=themeObj.colorIconCardCvcError,
                    ~cardComplete,
                  )}
                  appearance=config.appearance
                  type_="tel"
                  className="tracking-widest w-full"
                  maxLength=4
                  inputRef=cvcRef
                  placeholder="123"
                />
              | CardExpiryAndCvc =>
                <div className="flex gap-10">
                  <PaymentInputField
                    fieldName=localeString.validThruText
                    isValid=isExpiryValid
                    setIsValid=setIsExpiryValid
                    value=cardExpiry
                    onChange=changeCardExpiry
                    onBlur=handleExpiryBlur
                    errorString=expiryError
                    paymentType
                    type_="tel"
                    appearance=config.appearance
                    maxLength=7
                    inputRef=expiryRef
                    placeholder="MM / YY"
                  />
                  <PaymentInputField
                    fieldName=localeString.cvcTextLabel
                    isValid=isCVCValid
                    setIsValid=setIsCVCValid
                    value=cvcNumber
                    onChange=changeCVCNumber
                    onBlur=handleCVCBlur
                    errorString=cvcError
                    paymentType
                    rightIcon={CardUtils.setRightIconForCvc(
                      ~cardEmpty,
                      ~cardInvalid,
                      ~color=themeObj.colorIconCardCvcError,
                      ~cardComplete,
                    )}
                    appearance=config.appearance
                    type_="tel"
                    className="tracking-widest w-full"
                    maxLength=4
                    inputRef=cvcRef
                    placeholder="123"
                  />
                </div>
              | Currency(currencyArr) =>
                <DropdownField
                  appearance=config.appearance
                  fieldName=localeString.currencyLabel
                  value=currency
                  setValue=setCurrency
                  disabled=false
                  options=currencyArr
                />
              | FullName =>
                <FullNamePaymentInput
                  paymentType
                  customFieldName={item->getCustomFieldName}
                  optionalRequiredFields={Some(requiredFields)}
                />
              | Email
              | InfoElement
              | Country
              | Bank
              | None
              | BillingName
              | PhoneNumber
              | AddressLine1
              | AddressLine2
              | AddressCity
              | StateAndCity
              | AddressPincode
              | AddressState
              | BlikCode
              | SpecialField(_)
              | CountryAndPincode(_)
              | AddressCountry(_) => React.null
              }}
            </div>
          })
          ->React.array}
          <RenderIf condition={isRenderDynamicFieldsInsideBilling}>
            <div
              className="p-2"
              style={ReactDOMStyle.make(
                ~border=`1px solid ${themeObj.borderColor}`,
                ~borderRadius=themeObj.borderRadius,
                ~margin=`10px 0`,
                (),
              )}>
              {React.string(localeString.billingDetailsText)}
              <div className="p-2 flex flex-col gap-2">
                {dynamicFieldsToRenderInsideBilling
                ->Js.Array2.mapi((item, index) => {
                  <div
                    key={`inside-billing-${index->Js.Int.toString}`}
                    className="flex flex-col w-full place-content-between">
                    {switch item {
                    | BillingName =>
                      <BillingNamePaymentInput
                        paymentType optionalRequiredFields={Some(requiredFields)}
                      />
                    | Email => <EmailPaymentInput paymentType />
                    | PhoneNumber => <PhoneNumberPaymentInput />
                    | StateAndCity =>
                      <div className="flex gap-1">
                        <PaymentField
                          fieldName=localeString.cityLabel
                          setValue={setCity}
                          value=city
                          onChange={ev => {
                            let value = ReactEvent.Form.target(ev)["value"]
                            setCity(.prev => {
                              isValid: value !== "" ? Some(true) : Some(false),
                              value,
                              errorString: value !== "" ? "" : prev.errorString,
                            })
                          }}
                          onBlur={ev => {
                            let value = ReactEvent.Focus.target(ev)["value"]
                            setCity(.prev => {
                              ...prev,
                              isValid: Some(value !== ""),
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
                      <div className="flex gap-1">
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
                          onBlur={ev => {
                            let value = ReactEvent.Focus.target(ev)["value"]
                            setPostalCode(.prev => {
                              ...prev,
                              isValid: Some(value !== ""),
                            })
                          }}
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
                          let value = ReactEvent.Form.target(ev)["value"]
                          setLine1(.prev => {
                            isValid: value !== "" ? Some(true) : Some(false),
                            value,
                            errorString: value !== "" ? "" : prev.errorString,
                          })
                        }}
                        onBlur={ev => {
                          let value = ReactEvent.Focus.target(ev)["value"]
                          setLine1(.prev => {
                            ...prev,
                            isValid: Some(value !== ""),
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
                          let value = ReactEvent.Form.target(ev)["value"]
                          setLine2(.prev => {
                            isValid: value !== "" ? Some(true) : Some(false),
                            value,
                            errorString: value !== "" ? "" : prev.errorString,
                          })
                        }}
                        onBlur={ev => {
                          let value = ReactEvent.Focus.target(ev)["value"]
                          setLine2(.prev => {
                            ...prev,
                            isValid: Some(value !== ""),
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
                          let value = ReactEvent.Form.target(ev)["value"]
                          setCity(.prev => {
                            isValid: value !== "" ? Some(true) : Some(false),
                            value,
                            errorString: value !== "" ? "" : prev.errorString,
                          })
                        }}
                        onBlur={ev => {
                          let value = ReactEvent.Focus.target(ev)["value"]
                          setCity(.prev => {
                            ...prev,
                            isValid: Some(value !== ""),
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
                        onBlur={ev => {
                          let value = ReactEvent.Focus.target(ev)["value"]
                          setPostalCode(.prev => {
                            ...prev,
                            isValid: Some(value !== ""),
                          })
                        }}
                        onChange=onPostalChange
                        paymentType
                        type_="tel"
                        name="postal"
                        inputRef=postalRef
                        placeholder=localeString.postalCodeLabel
                      />
                    | BlikCode => <BlikCodePaymentInput />
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
                    | CardNumber
                    | CardExpiryMonth
                    | CardExpiryYear
                    | CardExpiryMonthAndYear
                    | CardCvc
                    | CardExpiryAndCvc
                    | Currency(_)
                    | FullName
                    | None => React.null
                    }}
                  </div>
                })
                ->React.array}
              </div>
            </div>
          </RenderIf>
          <RenderIf condition={isOnlyInfoElementPresent}>
            {<>
              <Surcharge list paymentMethod paymentMethodType />
              {if fieldsArr->Js.Array2.length > 1 {
                bottomElement
              } else {
                <Block bottomElement />
              }}
            </>}
          </RenderIf>
          <RenderIf condition={!isInfoElementPresent}>
            <Surcharge list paymentMethod paymentMethodType />
          </RenderIf>
        </>
      : React.null
  }
}
