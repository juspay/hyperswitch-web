open RecoilAtoms
@react.component
let make = (
  ~paymentType,
  ~paymentMethod,
  ~paymentMethodType,
  ~setRequiredFieldsBody,
  ~isSavedCardFlow=false,
  ~savedMethod=PaymentType.defaultCustomerMethods,
  ~cardProps=None,
  ~expiryProps=None,
  ~cvcProps=None,
  ~isBancontact=false,
) => {
  open Utils
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  React.useEffect(() => {
    setRequiredFieldsBody(_ => Dict.make())
    None
  }, [paymentMethodType])

  let {billingAddress} = Recoil.useRecoilValueFromAtom(optionAtom)

  //<...>//
  let paymentMethodTypes = PaymentUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod,
    ~paymentMethodType,
  )

  let creditPaymentMethodTypes = PaymentUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod,
    ~paymentMethodType="credit",
  )

  let requiredFieldsWithBillingDetails = React.useMemo(() => {
    if paymentMethod === "card" {
      let creditRequiredFields = creditPaymentMethodTypes.required_fields

      paymentMethodTypes.required_fields
      ->Array.concat(creditRequiredFields)
      ->DynamicFieldsUtils.removeRequiredFieldsDuplicates
    } else if (
      PaymentMethodsRecord.dynamicFieldsEnabledPaymentMethods->Array.includes(paymentMethodType)
    ) {
      paymentMethodTypes.required_fields
    } else {
      []
    }
  }, (paymentMethod, paymentMethodTypes.required_fields, paymentMethodType))

  let requiredFields = React.useMemo(() => {
    requiredFieldsWithBillingDetails->DynamicFieldsUtils.removeBillingDetailsIfUseBillingAddress(
      billingAddress,
    )
  }, [requiredFieldsWithBillingDetails])

  let isAllStoredCardsHaveName = React.useMemo(() => {
    PaymentType.getIsStoredPaymentMethodHasName(savedMethod)
  }, [savedMethod])

  //<...>//
  let fieldsArr = React.useMemo(() => {
    PaymentMethodsRecord.getPaymentMethodFields(
      paymentMethodType,
      requiredFields,
      ~isSavedCardFlow,
      ~isAllStoredCardsHaveName,
      (),
    )
    ->DynamicFieldsUtils.updateDynamicFields(
      billingAddress,
      ~paymentMethodListValue,
      ~paymentMethod,
      ~isSavedCardFlow,
      (),
    )
    ->Belt.SortArray.stableSortBy(PaymentMethodsRecord.sortPaymentMethodFields)
    //<...>//
  }, (requiredFields, isAllStoredCardsHaveName, isSavedCardFlow))

  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced

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
  let line1Ref = React.useRef(Nullable.null)
  let line2Ref = React.useRef(Nullable.null)
  let cityRef = React.useRef(Nullable.null)
  let postalRef = React.useRef(Nullable.null)
  let (selectedBank, setSelectedBank) = Recoil.useRecoilState(userBank)
  let (country, setCountry) = Recoil.useRecoilState(userCountry)

  let defaultCardProps = (
    None,
    _ => (),
    "",
    _ => (),
    _ => (),
    React.useRef(Nullable.null),
    React.null,
    "",
    _ => (),
    0,
  )

  let defaultExpiryProps = (
    None,
    _ => (),
    "",
    _ => (),
    _ => (),
    React.useRef(Nullable.null),
    _ => (),
    "",
    _ => (),
  )

  let defaultCvcProps = (
    None,
    _ => (),
    "",
    _ => (),
    _ => (),
    _ => (),
    React.useRef(Nullable.null),
    _ => (),
    "",
    _ => (),
  )

  let (stateJson, setStatesJson) = React.useState(_ => None)

  let bankNames = Bank.getBanks(paymentMethodType)->getBankNames(paymentMethodTypes.bank_names)
  let countryNames = getCountryNames(Country.getCountry(paymentMethodType))

  let setCurrency = val => {
    setCurrency(val)
  }
  let setSelectedBank = val => {
    setSelectedBank(val)
  }
  let setCountry = val => {
    setCountry(val)
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
    setCardError,
    maxCardLength,
  ) = switch cardProps {
  | Some(cardProps) => cardProps
  | None => defaultCardProps
  }

  let (
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    _,
    expiryError,
    setExpiryError,
  ) = switch expiryProps {
  | Some(expiryProps) => expiryProps
  | None => defaultExpiryProps
  }

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
    setCvcError,
  ) = switch cvcProps {
  | Some(cvcProps) => cvcProps
  | None => defaultCvcProps
  }

  let isCvcValidValue = CardUtils.getBoolOptionVal(isCVCValid)
  let (cardEmpty, cardComplete, cardInvalid) = CardUtils.useCardDetails(
    ~cvcNumber,
    ~isCVCValid,
    ~isCvcValidValue,
  )

  React.useEffect0(() => {
    let bank = bankNames->Array.get(0)->Option.getOr("")
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

  let _regex = CardUtils.postalRegex(postalCodes, ~country={getCountryCode(country).isoAlpha2}, ())

  let onPostalChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]

    if val !== "" {
      setPostalCode(_ => {
        isValid: Some(true),
        value: val,
        errorString: "",
      })
    } else {
      setPostalCode(_ => {
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
    ~paymentMethodListValue,
  )

  let submitCallback = DynamicFieldsUtils.useSubmitCallback(
    ~cardNumber,
    ~setCardError,
    ~cardExpiry,
    ~setExpiryError,
    ~cvcNumber,
    ~setCvcError,
  )
  useSubmitPaymentData(submitCallback)

  let bottomElement = <InfoElement />

  let getCustomFieldName = (item: PaymentMethodsRecord.paymentMethodsFields) => {
    if (
      requiredFields
      ->Array.filter(requiredFieldType =>
        requiredFieldType.field_type === item &&
          requiredFieldType.display_name === "card_holder_name"
      )
      ->Array.length > 0
    ) {
      Some(localeString.cardHolderName)
    } else {
      None
    }
  }

  let dynamicFieldsToRenderOutsideBilling = React.useMemo(() => {
    fieldsArr->Array.filter(DynamicFieldsUtils.isFieldTypeToRenderOutsideBilling)
  }, [fieldsArr])

  let dynamicFieldsToRenderInsideBilling = React.useMemo(() => {
    fieldsArr->Array.filter(field => !(field->DynamicFieldsUtils.isFieldTypeToRenderOutsideBilling))
  }, [fieldsArr])

  let isInfoElementPresent = dynamicFieldsToRenderInsideBilling->Array.includes(InfoElement)

  let isOnlyInfoElementPresent =
    dynamicFieldsToRenderInsideBilling->Array.length === 1 && isInfoElementPresent

  let isRenderDynamicFieldsInsideBilling =
    dynamicFieldsToRenderInsideBilling->Array.length > 0 &&
      (dynamicFieldsToRenderInsideBilling->Array.length > 1 || !isOnlyInfoElementPresent)

  let spacedStylesForBiilingDetails = isSpacedInnerLayout ? "p-2" : "my-2"
  let spacedStylesForCity = isSpacedInnerLayout ? "p-2" : ""

  <RenderIf condition={fieldsArr->Array.length > 0}>
    {<>
      {dynamicFieldsToRenderOutsideBilling
      ->Array.mapWithIndex((item, index) => {
        <div
          key={`outside-billing-${index->Int.toString}`}
          className="flex flex-col w-full place-content-between"
          style={ReactDOMStyle.make(
            ~marginTop=index !== 0 ? themeObj.spacingGridColumn : "",
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
            <>
              <RenderIf condition={!isSpacedInnerLayout}>
                <div
                  style={ReactDOMStyle.make(
                    ~marginBottom="5px",
                    ~fontSize=themeObj.fontSizeLg,
                    ~opacity="0.6",
                    (),
                  )}>
                  {item->getCustomFieldName->Option.getOr("")->React.string}
                </div>
              </RenderIf>
              <FullNamePaymentInput
                paymentType
                customFieldName={item->getCustomFieldName}
                optionalRequiredFields={Some(requiredFields)}
              />
            </>
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
          className={`${spacedStylesForBiilingDetails} w-full text-left`}
          style={ReactDOMStyle.make(
            ~border={isSpacedInnerLayout ? `1px solid ${themeObj.borderColor}` : ""},
            ~borderRadius={isSpacedInnerLayout ? themeObj.borderRadius : ""},
            ~margin={isSpacedInnerLayout ? `10px 0` : ""},
            (),
          )}>
          <div
            style={ReactDOMStyle.make(
              ~marginBottom="5px",
              ~fontSize=themeObj.fontSizeLg,
              ~opacity="0.6",
              (),
            )}>
            {React.string(localeString.billingDetailsText)}
          </div>
          <div
            className={`${spacedStylesForCity} flex flex-col ${isSpacedInnerLayout
                ? "gap-2"
                : ""}`}>
            {dynamicFieldsToRenderInsideBilling
            ->Array.mapWithIndex((item, index) => {
              <div
                key={`inside-billing-${index->Int.toString}`}
                className="flex flex-col w-full place-content-between">
                {switch item {
                | BillingName => <BillingNamePaymentInput paymentType requiredFields />
                | Email => <EmailPaymentInput paymentType />
                | PhoneNumber => <PhoneNumberPaymentInput />
                | StateAndCity =>
                  <div className={`flex ${isSpacedInnerLayout ? "gap-1" : ""}`}>
                    <PaymentField
                      fieldName=localeString.cityLabel
                      setValue={setCity}
                      value=city
                      onChange={ev => {
                        let value = ReactEvent.Form.target(ev)["value"]
                        setCity(prev => {
                          isValid: value !== "" ? Some(true) : Some(false),
                          value,
                          errorString: value !== "" ? "" : prev.errorString,
                        })
                      }}
                      onBlur={ev => {
                        let value = ReactEvent.Focus.target(ev)["value"]
                        setCity(prev => {
                          ...prev,
                          isValid: Some(value !== ""),
                        })
                      }}
                      paymentType
                      type_="text"
                      name="city"
                      inputRef=cityRef
                      placeholder=localeString.cityLabel
                      className={isSpacedInnerLayout ? "" : "!border-r-0"}
                    />
                    {switch stateJson {
                    | Some(options) =>
                      <PaymentDropDownField
                        fieldName=localeString.stateLabel
                        value=state
                        setValue=setState
                        options={options->getStateNames({
                          value: country,
                          isValid: None,
                          errorString: "",
                        })}
                      />
                    | None => React.null
                    }}
                  </div>
                | CountryAndPincode(countryArr) =>
                  <div className={`flex ${isSpacedInnerLayout ? "gap-1" : ""}`}>
                    <DropdownField
                      appearance=config.appearance
                      fieldName=localeString.countryLabel
                      value=country
                      setValue={setCountry}
                      disabled=false
                      options=countryArr
                      className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
                    />
                    <PaymentField
                      fieldName=localeString.postalCodeLabel
                      setValue={setPostalCode}
                      value=postalCode
                      onBlur={ev => {
                        let value = ReactEvent.Focus.target(ev)["value"]
                        setPostalCode(prev => {
                          ...prev,
                          isValid: Some(value !== ""),
                        })
                      }}
                      onChange=onPostalChange
                      paymentType
                      name="postal"
                      inputRef=postalRef
                      placeholder=localeString.postalCodeLabel
                      className={isSpacedInnerLayout ? "" : "!border-t-0"}
                    />
                  </div>
                | AddressLine1 =>
                  <PaymentField
                    fieldName=localeString.line1Label
                    setValue={setLine1}
                    value=line1
                    onChange={ev => {
                      let value = ReactEvent.Form.target(ev)["value"]
                      setLine1(prev => {
                        isValid: value !== "" ? Some(true) : Some(false),
                        value,
                        errorString: value !== "" ? "" : prev.errorString,
                      })
                    }}
                    onBlur={ev => {
                      let value = ReactEvent.Focus.target(ev)["value"]
                      setLine1(prev => {
                        ...prev,
                        isValid: Some(value !== ""),
                      })
                    }}
                    paymentType
                    type_="text"
                    name="line1"
                    inputRef=line1Ref
                    placeholder=localeString.line1Placeholder
                    className={isSpacedInnerLayout ? "" : "!border-b-0"}
                  />
                | AddressLine2 =>
                  <PaymentField
                    fieldName=localeString.line2Label
                    setValue={setLine2}
                    value=line2
                    onChange={ev => {
                      let value = ReactEvent.Form.target(ev)["value"]
                      setLine2(prev => {
                        isValid: value !== "" ? Some(true) : Some(false),
                        value,
                        errorString: value !== "" ? "" : prev.errorString,
                      })
                    }}
                    onBlur={ev => {
                      let value = ReactEvent.Focus.target(ev)["value"]
                      setLine2(prev => {
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
                      setCity(prev => {
                        isValid: value !== "" ? Some(true) : Some(false),
                        value,
                        errorString: value !== "" ? "" : prev.errorString,
                      })
                    }}
                    onBlur={ev => {
                      let value = ReactEvent.Focus.target(ev)["value"]
                      setCity(prev => {
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
                      options={options->getStateNames({
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
                      setPostalCode(prev => {
                        ...prev,
                        isValid: Some(value !== ""),
                      })
                    }}
                    onChange=onPostalChange
                    paymentType
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
                    <Surcharge paymentMethod paymentMethodType />
                    {if fieldsArr->Array.length > 1 {
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
          <Surcharge paymentMethod paymentMethodType />
          {if fieldsArr->Array.length > 1 {
            bottomElement
          } else {
            <Block bottomElement />
          }}
        </>}
      </RenderIf>
      <RenderIf condition={!isInfoElementPresent}>
        <Surcharge paymentMethod paymentMethodType />
      </RenderIf>
    </>}
  </RenderIf>
}
