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
  let paymentMethodTypes =
    PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~list,
      ~paymentMethod,
      ~paymentMethodType=PaymentUtils.getPaymentMethodName(
        ~paymentMethodType=paymentMethod,
        ~paymentMethodName=paymentMethodType,
      ),
    )->Belt.Option.getWithDefault(PaymentMethodsRecord.defaultPaymentMethodType)

  let requiredFieldsWithBillingDetails = if paymentMethod === "card" {
    paymentMethodTypes.required_fields
  } else if (
    PaymentMethodsRecord.dynamicFieldsEnabledPaymentMethods->Js.Array2.includes(paymentMethodType)
  ) {
    paymentMethodTypes.required_fields
  } else {
    []
  }

  let requiredFields =
    requiredFieldsWithBillingDetails->DynamicFieldsUtils.removeBillingDetailsIfUseBillingAddress

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
    ->DynamicFieldsUtils.updateDynamicFields()
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

  let dynamicFieldsToRenderOutsideBilling =
    fieldsArr->Js.Array2.filter(field =>
      field->DynamicFieldsUtils.isFieldTypeToRenderOutsideBilling
    )

  let dynamicFieldsToRenderInsideBilling =
    fieldsArr->Js.Array2.filter(field =>
      !(field->DynamicFieldsUtils.isFieldTypeToRenderOutsideBilling)
    )

  let isInfoElementPresent = dynamicFieldsToRenderInsideBilling->Js.Array2.includes(InfoElement)

  let isOnlyInfoElementPresent =
    dynamicFieldsToRenderInsideBilling->Js.Array2.length === 1 && isInfoElementPresent

  let isRenderDynamicFieldsInsideBilling =
    dynamicFieldsToRenderInsideBilling->Js.Array2.length > 0 &&
      (dynamicFieldsToRenderInsideBilling->Js.Array2.length > 1 || !isOnlyInfoElementPresent)

  React.useEffect1(() => {
    let fieldsArrStr = fieldsArr->Js.Array2.map(field => {
      field->PaymentMethodsRecord.paymentMethodFieldToStrMapper->Js.Json.string
    })
    let dynamicFieldsToRenderOutsideBillingStr =
      dynamicFieldsToRenderOutsideBilling->Js.Array2.map(field => {
        field->PaymentMethodsRecord.paymentMethodFieldToStrMapper->Js.Json.string
      })
    let dynamicFieldsToRenderInsideBillingStr =
      dynamicFieldsToRenderInsideBilling->Js.Array2.map(field => {
        field->PaymentMethodsRecord.paymentMethodFieldToStrMapper->Js.Json.string
      })
    let requiredFieldsStr = requiredFields->Js.Array2.map(field => {
      field.required_field->Js.Json.string
    })

    let loggerPayload =
      [
        ("requiredFields", requiredFieldsStr->Js.Json.array),
        ("fieldsArr", fieldsArrStr->Js.Json.array),
        (
          "dynamicFieldsToRenderOutsideBilling",
          dynamicFieldsToRenderOutsideBillingStr->Js.Json.array,
        ),
        (
          "dynamicFieldsToRenderInsideBilling",
          dynamicFieldsToRenderInsideBillingStr->Js.Json.array,
        ),
        ("isRenderDynamicFieldsInsideBilling", isRenderDynamicFieldsInsideBilling->Js.Json.boolean),
        ("isOnlyInfoElementPresent", isOnlyInfoElementPresent->Js.Json.boolean),
        ("isInfoElementPresent", isInfoElementPresent->Js.Json.boolean),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_
    logger.setLogInfo(~value=loggerPayload->Js.Json.stringify, ~eventName=DYNAMIC_FIELDS_RENDER, ())
    None
  }, fieldsArr)

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
              | Email
              | FullName
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
              {React.string("Billing Details")}
              <div className="p-2 flex flex-col gap-2">
                {dynamicFieldsToRenderInsideBilling
                ->Js.Array2.mapi((item, index) => {
                  <div
                    key={`inside-billing-${index->Js.Int.toString}`}
                    className="flex flex-col w-full place-content-between">
                    {switch item {
                    | FullName =>
                      <FullNamePaymentInput
                        paymentType
                        customFieldName={item->getCustomFieldName}
                        optionalRequiredFields={Some(requiredFields)}
                      />
                    | BillingName =>
                      <BillingNamePaymentInput
                        paymentType
                        customFieldName={item->getCustomFieldName}
                        optionalRequiredFields={Some(requiredFields)}
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
