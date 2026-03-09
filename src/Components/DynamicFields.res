module RffField = {
  @react.component
  let make = (~name: string, ~render) => {
    let field: ReactFinalForm.fieldProps<ReactEvent.Focus.t> = ReactFinalForm.useField(name)
    render(field)
  }
}

module DynamicFieldsToRenderWrapper = {
  @react.component
  let make = (~children, ~index, ~isInside=true) => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

    <RenderIf condition={children != React.null}>
      <div
        key={`${isInside ? "inside" : "outside"}-billing-${index->Int.toString}`}
        className="flex flex-col w-full place-content-between"
        style={
          gridColumnGap: isInside ? "0px" : themeObj.spacingGridRow,
        }>
        {children}
      </div>
    </RenderIf>
  }
}

@react.component
let make = (
  ~paymentMethod,
  ~paymentMethodType,
  ~setRequiredFieldsBody,
  ~isSavedCardFlow=false,
  ~savedMethod=PaymentType.defaultCustomerMethods,
  ~cardProps=None,
  ~expiryProps=None,
  ~cvcProps=None,
  ~isBancontact=false,
  ~isSaveDetailsWithClickToPay=false,
  ~isDisableInfoElement=false,
  ~isSplitPaymentsEnabled=false,
) => {
  open DynamicFieldsUtils
  open PaymentTypeContext
  open Utils
  open RecoilAtoms

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let paymentManagementListValue = Recoil.useRecoilValueFromAtom(
    PaymentUtils.paymentManagementListValue,
  )
  let paymentMethodListValueV2 = Recoil.useRecoilValueFromAtom(
    RecoilAtomsV2.paymentMethodListValueV2,
  )
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let contextPaymentType = usePaymentType()
  let listValue = switch contextPaymentType {
  | PaymentMethodsManagement => paymentManagementListValue
  | _ => paymentMethodListValueV2
  }
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

  let paymentMethodTypesV2 = PaymentUtilsV2.usePaymentMethodTypeFromListV2(
    ~paymentsListValueV2=listValue,
    ~paymentMethod,
    ~paymentMethodType,
  )

  let creditPaymentMethodTypes = PaymentUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod,
    ~paymentMethodType="credit",
  )

  let creditPaymentMethodTypesV2 = PaymentUtilsV2.usePaymentMethodTypeFromListV2(
    ~paymentsListValueV2=listValue,
    ~paymentMethod,
    ~paymentMethodType="credit",
  )

  // Get missing fields and initial values from superposition
  // missingFields = fields that still need user input (after accounting for PML pre-filled values)
  // initialValues = pre-filled values from PML to set in Recoil atoms
  let (superpositionMissingFields, initialValues, _) = useSuperpositionFields(
    ~paymentMethod,
    ~paymentMethodType,
    ~paymentMethodTypes,
    ~paymentMethodListValue,
  )

  // Pre-populate Recoil atoms with initial values from superposition
  // useSetInitialValuesFromSuperposition(~initialValues, ~paymentMethodType)

  // Use superposition missing fields directly as the required fields
  // These are fields that still need user input
  let requiredFieldsWithBillingDetails = React.useMemo(() => {
    superpositionMissingFields
  }, [superpositionMissingFields])

  let requiredFields = React.useMemo(() => {
    requiredFieldsWithBillingDetails
    ->removeBillingDetailsIfUseBillingAddress(billingAddress)
    ->removeClickToPayFieldsIfSaveDetailsWithClickToPay(isSaveDetailsWithClickToPay)
  }, (requiredFieldsWithBillingDetails, isSaveDetailsWithClickToPay))

  let getRequiredFieldPath = (fieldType: PaymentMethodsRecord.paymentMethodsFields) => {
    requiredFields
    ->Array.find(r => r.field_type === fieldType)
    ->Option.map(r => r.required_field)
    ->Option.getOr("")
  }

  let isAllStoredCardsHaveName = React.useMemo(() => {
    PaymentType.getIsStoredPaymentMethodHasName(savedMethod)
  }, [savedMethod])

  //<...>//

  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)

  let fieldsArr = React.useMemo(() => {
    PaymentMethodsRecord.getPaymentMethodFields(
      paymentMethodType,
      requiredFields,
      ~isSavedCardFlow,
      ~isAllStoredCardsHaveName,
      ~localeString,
    )
    ->updateDynamicFields(billingAddress, isSaveDetailsWithClickToPay, clickToPayConfig)
    ->Belt.SortArray.stableSortBy(PaymentMethodsRecord.sortPaymentMethodFields)
    //<...>//
  }, (requiredFields, isAllStoredCardsHaveName, isSavedCardFlow, isSaveDetailsWithClickToPay))

  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced

  let (line1, setLine1) = Recoil.useRecoilState(userAddressline1)
  let (line2, setLine2) = Recoil.useRecoilState(userAddressline2)
  let (city, setCity) = Recoil.useRecoilState(userAddressCity)
  let (state, setState) = Recoil.useRecoilState(userAddressState)
  let (postalCode, setPostalCode) = Recoil.useRecoilState(userAddressPincode)

  let (currency, setCurrency) = Recoil.useRecoilState(userCurrency)
  let line1Ref = React.useRef(Nullable.null)
  let line2Ref = React.useRef(Nullable.null)
  let cityRef = React.useRef(Nullable.null)
  let bankAccountNumberRef = React.useRef(Nullable.null)
  let sourceBankAccountIdRef = React.useRef(Nullable.null)
  let postalRef = React.useRef(Nullable.null)
  let (selectedBank, setSelectedBank) = Recoil.useRecoilState(userBank)
  let (country, setCountry) = Recoil.useRecoilState(userCountry)

  let (bankAccountNumber, setBankAccountNumber) = Recoil.useRecoilState(userBankAccountNumber)
  let (sourceBankAccountId, setSourceBankAccountId) = Recoil.useRecoilState(sourceBankAccountId)
  let countryList = CountryStateDataRefs.countryDataRef.contents
  let stateNames = getStateNames({
    value: country,
    isValid: None,
    errorString: "",
  })

  let bankNames = switch GlobalVars.sdkVersion {
  | V2 =>
    Bank.getBanks(paymentMethodType)->getBankNames(paymentMethodTypesV2.bankNames->Option.getOr([]))
  | V1 => Bank.getBanks(paymentMethodType)->getBankNames(paymentMethodTypes.bank_names)
  }
  let countryNames = getCountryNames(Country.getCountry(paymentMethodType, countryList))

  let setCurrency = val => {
    setCurrency(val)
  }
  let setSelectedBank = val => {
    setSelectedBank(val)
  }
  let setCountry = val => {
    setCountry(val)
  }

  let defaultCardProps = CardUtils.useDefaultCardProps()
  let defaultExpiryProps = CardUtils.useDefaultExpiryProps()
  let defaultCvcProps = CardUtils.useDefaultCvcProps()

  let cardProps = switch cardProps {
  | Some(props) => props
  | None => defaultCardProps
  }

  let expiryProps = switch expiryProps {
  | Some(props) => props
  | None => defaultExpiryProps
  }

  let cvcProps = switch cvcProps {
  | Some(props) => props
  | None => defaultCvcProps
  }

  let {
    isCardValid,
    setIsCardValid,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    icon,
    cardError,
    maxCardLength,
  } = cardProps

  let {
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    expiryError,
  } = expiryProps

  let {
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    cvcError,
  } = cvcProps

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

  // useRequiredFieldsEmptyAndValid(
  //   ~requiredFields,
  //   ~fieldsArr,
  //   ~countryNames,
  //   ~bankNames,
  //   ~isCardValid,
  //   ~isExpiryValid,
  //   ~isCVCValid,
  //   ~cardNumber,
  //   ~cardExpiry,
  //   ~cvcNumber,
  //   ~isSavedCardFlow,
  //   ~isSplitPaymentsEnabled,
  // )

  // useSetInitialRequiredFields(
  //   ~requiredFields={
  //     billingAddress.usePrefilledValues === Auto ? requiredFieldsWithBillingDetails : requiredFields
  //   },
  //   ~paymentMethodType,
  // )

  // useRequiredFieldsBody(
  //   ~requiredFields,
  //   ~paymentMethodType,
  //   ~cardNumber,
  //   ~cardExpiry,
  //   ~cvcNumber,
  //   ~isSavedCardFlow,
  //   ~isAllStoredCardsHaveName,
  //   ~setRequiredFieldsBody,
  // )

  let submitCallback = useSubmitCallback()
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
    fieldsArr->Array.filter(isFieldTypeToRenderOutsideBilling)
  }, [fieldsArr])

  let dynamicFieldsToRenderInsideBilling = React.useMemo(() => {
    fieldsArr->Array.filter(field => !(field->isFieldTypeToRenderOutsideBilling))
  }, [fieldsArr])

  let isInfoElementPresent = dynamicFieldsToRenderOutsideBilling->Array.includes(InfoElement)
  let isRenderInfoElement = isInfoElementPresent && !isDisableInfoElement

  let isRenderDynamicFieldsInsideBilling = dynamicFieldsToRenderInsideBilling->Array.length > 0

  let spacedStylesForBiilingDetails = isSpacedInnerLayout ? "p-2" : "my-2"

  <RenderIf condition={!isSavedCardFlow && fieldsArr->Array.length > 0}>
    <ReactFinalForm.Form
      onSubmit={(_, _) => ()}
      initialValues={Some(initialValues)}
      render={formProps => {
        ReactFinalForm.useFormStateHandler(
          ~onFormChange=values => {
            let formattedValues = DynamicFieldsUtils.formatFormValues(values)
            setRequiredFieldsBody(_ => formattedValues)
          },
          ~onValidationChange=_ => (),
          ~formProps,
        )
        <>
          {dynamicFieldsToRenderOutsideBilling
          ->Array.mapWithIndex((item, index) => {
            <DynamicFieldsToRenderWrapper key={index->Int.toString} index={index} isInside={false}>
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
                  type_="tel"
                  maxLength=maxCardLength
                  inputRef=cardRef
                  placeholder="1234 1234 1234 1234"
                  autocomplete="cc-number"
                />
              | GiftCardNumber => <GiftCardNumberInput />
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
                  type_="tel"
                  maxLength=7
                  inputRef=expiryRef
                  placeholder=localeString.expiryPlaceholder
                  autocomplete="cc-exp"
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
                  rightIcon={CardUtils.setRightIconForCvc(
                    ~cardEmpty,
                    ~cardInvalid,
                    ~color=themeObj.colorIconCardCvcError,
                    ~cardComplete,
                  )}
                  type_="tel"
                  className="tracking-widest w-full"
                  maxLength=4
                  inputRef=cvcRef
                  placeholder="123"
                  autocomplete="cc-csc"
                />
              | GiftCardPin => <GiftCardPinInput />

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
                    type_="tel"
                    maxLength=7
                    inputRef=expiryRef
                    placeholder=localeString.expiryPlaceholder
                    autocomplete="cc-exp"
                  />
                  <PaymentInputField
                    fieldName=localeString.cvcTextLabel
                    isValid=isCVCValid
                    setIsValid=setIsCVCValid
                    value=cvcNumber
                    onChange=changeCVCNumber
                    onBlur=handleCVCBlur
                    errorString=cvcError
                    rightIcon={CardUtils.setRightIconForCvc(
                      ~cardEmpty,
                      ~cardInvalid,
                      ~color=themeObj.colorIconCardCvcError,
                      ~cardComplete,
                    )}
                    type_="tel"
                    className="tracking-widest w-full"
                    maxLength=4
                    inputRef=cvcRef
                    placeholder="123"
                    autocomplete="cc-csc"
                  />
                </div>
              | Currency(currencyArr) =>
                let updatedCurrencyArray =
                  currencyArr->DropdownField.updateArrayOfStringToOptionsTypeArray
                <RffField
                  name={getRequiredFieldPath(Currency(currencyArr))}
                  render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                    let val = field.input.value->Option.getOr(currency)
                    <DropdownField
                      appearance=config.appearance
                      fieldName=localeString.currencyLabel
                      value=val
                      setValue={setter => {
                        let newVal = setter(val)
                        setCurrency(_ => newVal)
                        field.input.onChange(newVal)
                      }}
                      disabled=false
                      options=updatedCurrencyArray
                    />
                  }}
                />
              | DocumentType(opt) => {
                  let updatedDocumentTypeArray =
                    opt->DropdownField.updateArrayOfStringToOptionsTypeArrayWithUpperCaseLabel
                  <DocumentNumberInput
                    name={getRequiredFieldPath(DocumentNumber)} options={updatedDocumentTypeArray}
                  />
                }
              | FullName =>
                let defaultName =
                  paymentMethod === "card"
                    ? localeString.cardHolderName
                    : localeString.fullNameLabel
                let customName = item->getCustomFieldName->Option.getOr(defaultName)
                <>
                  <RenderIf condition={!isSpacedInnerLayout}>
                    <div
                      style={
                        marginBottom: "5px",
                        fontSize: themeObj.fontSizeLg,
                        opacity: "0.6",
                      }>
                      {customName->React.string}
                    </div>
                  </RenderIf>
                  <FullNamePaymentInput
                    name={getRequiredFieldPath(FullName)}
                    customFieldName={Some(customName)}
                    optionalRequiredFields={Some(requiredFields)}
                  />
                </>
              | CryptoCurrencyNetworks =>
                <CryptoCurrencyNetworks name={getRequiredFieldPath(CryptoCurrencyNetworks)} />
              | DateOfBirth => <DateOfBirth name={getRequiredFieldPath(DateOfBirth)} />
              | VpaId => <VpaIdPaymentInput name={getRequiredFieldPath(VpaId)} />
              | PixKey => <PixPaymentInput name={getRequiredFieldPath(PixKey)} fieldType="pixKey" />
              | PixCPF => <PixPaymentInput name={getRequiredFieldPath(PixCPF)} fieldType="pixCPF" />
              | PixCNPJ =>
                <PixPaymentInput name={getRequiredFieldPath(PixCNPJ)} fieldType="pixCNPJ" />
              | BankAccountNumber | IBAN =>
                <RffField
                  name={getRequiredFieldPath(BankAccountNumber)}
                  render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                    let val = field.input.value->Option.getOr("")
                    <PaymentField
                      fieldName="IBAN"
                      setValue={_ => ()}
                      value={
                        RecoilAtomTypes.value: val,
                        isValid: Some(field.meta.valid),
                        errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
                      }
                      onChange={ev => field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                      onBlur={ev => field.input.onBlur(ev)}
                      type_="text"
                      name="bankAccountNumber"
                      maxLength=42
                      inputRef=bankAccountNumberRef
                      placeholder="DE00 0000 0000 0000 0000 00"
                    />
                  }}
                />
              | SourceBankAccountId =>
                <RffField
                  name={getRequiredFieldPath(SourceBankAccountId)}
                  render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                    let val = field.input.value->Option.getOr("")
                    <PaymentField
                      fieldName="Source Bank Account ID"
                      setValue={_ => ()}
                      value={
                        RecoilAtomTypes.value: val,
                        isValid: Some(field.meta.valid),
                        errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
                      }
                      onChange={ev => field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                      onBlur={ev => field.input.onBlur(ev)}
                      type_="text"
                      name="sourceBankAccountId"
                      maxLength=42
                      inputRef=sourceBankAccountIdRef
                      placeholder="DE00 0000 0000 0000 0000 00"
                    />
                  }}
                />
              | DocumentNumber
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
              | AddressCountry(_)
              | ShippingName // Shipping Details are currently supported by only one click widgets
              | ShippingAddressLine1
              | ShippingAddressLine2
              | ShippingAddressCity
              | ShippingAddressPincode
              | ShippingAddressState
              | PhoneCountryCode
              | PhoneNumberAndCountryCode
              | LanguagePreference(_)
              | ShippingAddressCountry(_)
              | BankList(_) => React.null
              }}
            </DynamicFieldsToRenderWrapper>
          })
          ->React.array}
          <RenderIf condition={isRenderDynamicFieldsInsideBilling}>
            <div
              className={`billing-section ${spacedStylesForBiilingDetails} w-full text-left`}
              style={
                border: {isSpacedInnerLayout ? `1px solid ${themeObj.borderColor}` : ""},
                borderRadius: {isSpacedInnerLayout ? themeObj.borderRadius : ""},
              }>
              <div
                className="billing-details-text"
                style={
                  marginBottom: "5px",
                  fontSize: themeObj.fontSizeLg,
                  opacity: "0.6",
                }>
                {React.string(localeString.billingDetailsText)}
              </div>
              <div
                className={`flex flex-col`}
                style={
                  gap: isSpacedInnerLayout ? themeObj.spacingGridRow : "",
                }>
                {dynamicFieldsToRenderInsideBilling
                ->Array.mapWithIndex((item, index) => {
                  <DynamicFieldsToRenderWrapper key={index->Int.toString} index={index}>
                    {switch item {
                    | BillingName =>
                      <RffField
                        name={getRequiredFieldPath(BillingName)}
                        render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                          let val = field.input.value->Option.getOr("")
                          <PaymentField
                            fieldName=localeString.billingNameLabel
                            setValue={_ => ()}
                            value={
                              value: val,
                              isValid: Some(field.meta.valid),
                              errorString: field.meta.touched
                                ? field.meta.error->Option.getOr("")
                                : "",
                            }
                            onChange={ev =>
                              field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                            onBlur={ev => field.input.onBlur(ev)}
                            type_="text"
                            name=TestUtils.cardHolderNameInputTestId
                            inputRef={React.useRef(Nullable.null)}
                            placeholder=localeString.billingNamePlaceholder
                            className={isSpacedInnerLayout ? "" : "!border-b-0"}
                          />
                        }}
                      />
                    | Email =>
                      <RffField
                        name={getRequiredFieldPath(Email)}
                        render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                          let val = field.input.value->Option.getOr("")
                          <PaymentField
                            fieldName=localeString.emailLabel
                            setValue={_ => ()}
                            value={
                              value: val,
                              isValid: Some(field.meta.valid),
                              errorString: field.meta.touched
                                ? field.meta.error->Option.getOr("")
                                : "",
                            }
                            onChange={ev =>
                              field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                            onBlur={ev => field.input.onBlur(ev)}
                            type_="email"
                            name=TestUtils.emailInputTestId
                            inputRef={React.useRef(Nullable.null)}
                            placeholder="Eg: johndoe@gmail.com"
                          />
                        }}
                      />
                    | PhoneNumberAndCountryCode =>
                      // TODO: rename properly
                      <PhoneNumberPaymentInput.RffPhoneNumberPaymentInput
                        numberName={getRequiredFieldPath(PhoneNumber)}
                        codeName={getRequiredFieldPath(PhoneCountryCode)}
                      />
                    | StateAndCity =>
                      <div className={`flex ${isSpacedInnerLayout ? "gap-4" : ""} overflow-hidden`}>
                        <RffField
                          name={getRequiredFieldPath(AddressCity)}
                          render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                            let val = field.input.value->Option.getOr("")
                            <PaymentField
                              fieldName=localeString.cityLabel
                              setValue={_ => ()}
                              value={
                                value: val,
                                isValid: Some(field.meta.valid),
                                errorString: field.meta.touched
                                  ? field.meta.error->Option.getOr("")
                                  : "",
                              }
                              onChange={ev =>
                                field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                              onBlur={ev => field.input.onBlur(ev)}
                              type_="text"
                              name="city"
                              inputRef=cityRef
                              placeholder=localeString.cityLabel
                              className={isSpacedInnerLayout ? "" : "!border-r-0"}
                            />
                          }}
                        />
                        <RenderIf condition={stateNames->Array.length > 0}>
                          <RffField
                            name={getRequiredFieldPath(AddressState)}
                            render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                              let val = field.input.value->Option.getOr("")
                              <PaymentDropDownField
                                fieldName=localeString.stateLabel
                                value={
                                  value: val,
                                  isValid: Some(field.meta.valid),
                                  errorString: field.meta.touched
                                    ? field.meta.error->Option.getOr("")
                                    : "",
                                }
                                setValue={setter => {
                                  let newVal = setter({
                                    value: val,
                                    isValid: Some(field.meta.valid),
                                    errorString: "",
                                  })
                                  field.input.onChange(newVal.value)
                                }}
                                options={stateNames}
                              />
                            }}
                          />
                        </RenderIf>
                      </div>
                    | CountryAndPincode(countryArr) =>
                      let updatedCountryArray =
                        countryArr->DropdownField.updateArrayOfStringToOptionsTypeArray
                      <div className={`flex ${isSpacedInnerLayout ? "gap-4" : ""}`}>
                        <RffField
                          name={getRequiredFieldPath(AddressCountry(countryArr))}
                          render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                            let val = field.input.value->Option.getOr(country)
                            <DropdownField
                              appearance=config.appearance
                              fieldName=localeString.countryLabel
                              value=val
                              setValue={setter => {
                                let newVal = setter(val)
                                setCountry(_ => newVal)
                                field.input.onChange(newVal)
                              }}
                              disabled=false
                              options=updatedCountryArray
                              className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
                            />
                          }}
                        />
                        <RffField
                          name={getRequiredFieldPath(AddressPincode)}
                          render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                            let val = field.input.value->Option.getOr("")
                            <PaymentField
                              fieldName=localeString.postalCodeLabel
                              setValue={_ => ()}
                              value={
                                value: val,
                                isValid: Some(field.meta.valid),
                                errorString: field.meta.touched
                                  ? field.meta.error->Option.getOr("")
                                  : "",
                              }
                              onChange={ev =>
                                field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                              onBlur={ev => field.input.onBlur(ev)}
                              name="postal"
                              inputRef=postalRef
                              placeholder=localeString.postalCodeLabel
                              className={isSpacedInnerLayout ? "" : "!border-t-0"}
                            />
                          }}
                        />
                      </div>
                    | AddressLine1 =>
                      <RffField
                        name={getRequiredFieldPath(AddressLine1)}
                        render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                          let val = field.input.value->Option.getOr("")
                          <PaymentField
                            fieldName=localeString.line1Label
                            setValue={_ => ()}
                            value={
                              value: val,
                              isValid: Some(field.meta.valid),
                              errorString: field.meta.touched
                                ? field.meta.error->Option.getOr("")
                                : "",
                            }
                            onChange={ev =>
                              field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                            onBlur={ev => field.input.onBlur(ev)}
                            type_="text"
                            name="line1"
                            inputRef=line1Ref
                            placeholder=localeString.line1Placeholder
                            className={isSpacedInnerLayout ? "" : "!border-b-0"}
                          />
                        }}
                      />
                    | AddressLine2 =>
                      <RffField
                        name={getRequiredFieldPath(AddressLine2)}
                        render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                          let val = field.input.value->Option.getOr("")
                          <PaymentField
                            fieldName=localeString.line2Label
                            setValue={_ => ()}
                            value={
                              value: val,
                              isValid: Some(field.meta.valid),
                              errorString: field.meta.touched
                                ? field.meta.error->Option.getOr("")
                                : "",
                            }
                            onChange={ev =>
                              field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                            onBlur={ev => field.input.onBlur(ev)}
                            type_="text"
                            name="line2"
                            inputRef=line2Ref
                            placeholder=localeString.line2Placeholder
                          />
                        }}
                      />
                    | AddressCity =>
                      <RffField
                        name={getRequiredFieldPath(AddressCity)}
                        render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                          let val = field.input.value->Option.getOr("")
                          <PaymentField
                            fieldName=localeString.cityLabel
                            setValue={_ => ()}
                            value={
                              value: val,
                              isValid: Some(field.meta.valid),
                              errorString: field.meta.touched
                                ? field.meta.error->Option.getOr("")
                                : "",
                            }
                            onChange={ev =>
                              field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                            onBlur={ev => field.input.onBlur(ev)}
                            type_="text"
                            name="city"
                            inputRef=cityRef
                            placeholder=localeString.cityLabel
                          />
                        }}
                      />
                    | AddressState =>
                      <RenderIf condition={stateNames->Array.length > 0}>
                        <RffField
                          name={getRequiredFieldPath(AddressState)}
                          render={(field: ReactFinalForm.fieldProps<ReactEvent.Focus.t>) => {
                            let val = field.input.value->Option.getOr("")
                            <PaymentDropDownField
                              fieldName=localeString.stateLabel
                              value={
                                value: val,
                                isValid: Some(field.meta.valid),
                                errorString: field.meta.touched
                                  ? field.meta.error->Option.getOr("")
                                  : "",
                              }
                              setValue={setter => {
                                let newVal = setter({
                                  value: val,
                                  isValid: Some(field.meta.valid),
                                  errorString: "",
                                })
                                field.input.onChange(newVal.value)
                              }}
                              options={stateNames}
                            />
                          }}
                        />
                      </RenderIf>
                    | AddressPincode =>
                      <PaymentField
                        fieldName=localeString.postalCodeLabel
                        setValue=setPostalCode
                        value=postalCode
                        onBlur={ev => {
                          let value = ReactEvent.Focus.target(ev)["value"]
                          setPostalCode(prev => {
                            ...prev,
                            isValid: Some(value !== ""),
                          })
                        }}
                        onChange=onPostalChange
                        name="postal"
                        inputRef=postalRef
                        placeholder=localeString.postalCodeLabel
                      />
                    | BlikCode => <BlikCodePaymentInput />
                    | Country =>
                      let updatedCountryNames =
                        countryNames->DropdownField.updateArrayOfStringToOptionsTypeArray
                      <DropdownField
                        appearance=config.appearance
                        fieldName=localeString.countryLabel
                        value=country
                        setValue=setCountry
                        disabled=false
                        options=updatedCountryNames
                      />
                    | AddressCountry(countryArr) =>
                      let updatedCountryArr =
                        countryArr->DropdownField.updateArrayOfStringToOptionsTypeArray
                      <DropdownField
                        appearance=config.appearance
                        fieldName=localeString.countryLabel
                        value=country
                        setValue=setCountry
                        disabled=false
                        options=updatedCountryArr
                      />
                    | BankList(bankArr) =>
                      let updatedBankNames =
                        Bank.getBanks(paymentMethodType)
                        ->getBankNames(bankArr)
                        ->DropdownField.updateArrayOfStringToOptionsTypeArray
                      <DropdownField
                        appearance=config.appearance
                        fieldName=localeString.bankLabel
                        value=selectedBank
                        setValue=setSelectedBank
                        disabled=false
                        options=updatedBankNames
                      />
                    | Bank =>
                      let updatedBankNames =
                        bankNames->DropdownField.updateArrayOfStringToOptionsTypeArray
                      <DropdownField
                        appearance=config.appearance
                        fieldName=localeString.bankLabel
                        value=selectedBank
                        setValue=setSelectedBank
                        disabled=false
                        options=updatedBankNames
                      />
                    | SpecialField(element) => element
                    | InfoElement
                    | PixKey
                    | PixCPF
                    | PixCNPJ
                    | DocumentType(_)
                    | DocumentNumber
                    | CardNumber
                    | CardExpiryMonth
                    | CardExpiryYear
                    | CardExpiryMonthAndYear
                    | CardCvc
                    | CardExpiryAndCvc
                    | Currency(_)
                    | FullName
                    | GiftCardNumber
                    | GiftCardPin
                    | ShippingName // Shipping Details are currently supported by only one click widgets
                    | ShippingAddressLine1
                    | ShippingAddressLine2
                    | ShippingAddressCity
                    | ShippingAddressPincode
                    | ShippingAddressState
                    | ShippingAddressCountry(_)
                    | CryptoCurrencyNetworks
                    | DateOfBirth
                    | PhoneNumber
                    | PhoneCountryCode
                    | VpaId
                    | LanguagePreference(_)
                    | BankAccountNumber
                    | IBAN
                    | SourceBankAccountId
                    | None => React.null
                    }}
                  </DynamicFieldsToRenderWrapper>
                })
                ->React.array}
              </div>
            </div>
          </RenderIf>
          <Surcharge paymentMethod paymentMethodType />
          <RenderIf condition={isRenderInfoElement}>
            {<>
              {if fieldsArr->Array.length > 1 {
                bottomElement
              } else {
                <Block bottomElement />
              }}
            </>}
          </RenderIf>
        </>
      }}
    />
  </RenderIf>
}
