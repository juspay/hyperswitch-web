open SuperpositionTypes

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
  ~areCardFieldsRendered=false,
) => {
  open DynamicFieldsUtils
  // open PaymentTypeContext
  open Utils
  open RecoilAtoms

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  // let paymentManagementListValue = Recoil.useRecoilValueFromAtom(
  //   PaymentUtils.paymentManagementListValue,
  // )
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  // let contextPaymentType = usePaymentType()
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

  // let paymentMethodTypesV2 = PaymentUtilsV2.usePaymentMethodTypeFromListV2(
  //   ~paymentsListValueV2=paymentManagementListValue,
  //   ~paymentMethod,
  //   ~paymentMethodType,
  // )

  // let creditPaymentMethodTypes = PaymentUtils.usePaymentMethodTypeFromList(
  //   ~paymentMethodListValue,
  //   ~paymentMethod,
  //   ~paymentMethodType="credit",
  // )

  // let creditPaymentMethodTypesV2 = PaymentUtilsV2.usePaymentMethodTypeFromListV2(
  //   ~paymentsListValueV2=paymentManagementListValue,
  //   ~paymentMethod,
  //   ~paymentMethodType="credit",
  // )

  // let requiredFieldsWithBillingDetails = React.useMemo(() => {
  //   if paymentMethod === "card" {
  //     switch GlobalVars.sdkVersion {
  //     | V2 =>
  //       let creditRequiredFields =
  //         paymentManagementListValue.paymentMethodsEnabled
  //         ->Array.filter(item => {
  //           item.paymentMethodSubtype === "credit" && item.paymentMethodType === "card"
  //         })
  //         ->Array.get(0)
  //         ->Option.getOr(UnifiedHelpersV2.defaultPaymentMethods)

  //       let finalCreditRequiredFields = creditRequiredFields.requiredFields
  //       [
  //         ...paymentMethodTypes.required_fields,
  //         ...finalCreditRequiredFields,
  //       ]->removeRequiredFieldsDuplicates

  //     | V1 =>
  //       let creditRequiredFields = creditPaymentMethodTypes.required_fields

  //       [
  //         ...paymentMethodTypes.required_fields,
  //         ...creditRequiredFields,
  //       ]->removeRequiredFieldsDuplicates
  //     }
  //   } else if dynamicFieldsEnabledPaymentMethods->Array.includes(paymentMethodType) {
  //     switch GlobalVars.sdkVersion {
  //     | V1 => paymentMethodTypes.required_fields
  //     | V2 => paymentMethodTypesV2.requiredFields
  //     }
  //   } else {
  //     []
  //   }
  // }, (
  //   paymentMethod,
  //   paymentMethodTypes.required_fields,
  //   paymentMethodTypesV2.requiredFields,
  //   paymentMethodType,
  //   creditPaymentMethodTypes.required_fields,
  //   creditPaymentMethodTypesV2.requiredFields,
  // ))

  // let requiredFields = React.useMemo(() => {
  //   requiredFieldsWithBillingDetails
  //   ->removeBillingDetailsIfUseBillingAddress(billingAddress)
  //   ->removeClickToPayFieldsIfSaveDetailsWithClickToPay(isSaveDetailsWithClickToPay)
  // }, (requiredFieldsWithBillingDetails, isSaveDetailsWithClickToPay))

  // let isAllStoredCardsHaveName = React.useMemo(() => {
  //   PaymentType.getIsStoredPaymentMethodHasName(savedMethod)
  // }, [savedMethod])

  let (missingRequiredFields, initialValues, isLoading) = useSuperpositionFields(
    ~paymentMethod,
    ~paymentMethodType,
    ~paymentMethodTypes,
    ~paymentMethodListValue,
  )

  let processedFieldConfigs = React.useMemo(() => {
    missingRequiredFields
    ->removeBillingDetailsFromFieldConfigs(billingAddress)
    ->removeClickToPayFieldsFromFieldConfigs(isSaveDetailsWithClickToPay)
    ->removeCardFieldsFromFieldConfigs(areCardFieldsRendered)
    ->removeCardNetworkFromFieldConfigs
    ->processFieldConfigs(billingAddress, isSaveDetailsWithClickToPay)
  }, (missingRequiredFields, billingAddress, isSaveDetailsWithClickToPay, areCardFieldsRendered))

  // let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)

  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced

  let (currency, setCurrency) = Recoil.useRecoilState(userCurrency)
  let line1Ref = React.useRef(Nullable.null)
  let line2Ref = React.useRef(Nullable.null)
  let cityRef = React.useRef(Nullable.null)
  let stateRef = React.useRef(Nullable.null)
  let bankAccountNumberRef = React.useRef(Nullable.null)
  let sourceBankAccountIdRef = React.useRef(Nullable.null)
  let postalRef = React.useRef(Nullable.null)
  let (selectedBank, setSelectedBank) = Recoil.useRecoilState(userBank)
  let (country, setCountry) = Recoil.useRecoilState(userCountry)
  let stateNames = getStateNames({
    value: country,
    isValid: None,
    errorString: "",
  })

  let bankNames = Bank.getBanks(paymentMethodType)->getBankNames(paymentMethodTypes.bank_names)

  let countryNames = getCountryNames(Country.getCountry(paymentMethodType, countryList))

  let initialCountryIso = {
    let effectiveCountry = country !== "" ? country : countryNames->Array.get(0)->Option.getOr("")
    Utils.getCountryCode(effectiveCountry).isoAlpha2
  }

  let countryIso = Utils.getCountryCode(country).isoAlpha2

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

  let formSubmitRef = React.useRef(None)

  let submitCallback = useSubmitCallback(~onConfirm=() => {
    switch formSubmitRef.current {
    | Some(submitFn) => submitFn()
    | None => ()
    }
  })
  useSubmitPaymentData(submitCallback)

  let bottomElement = <InfoElement />

  let fullNameConfig = React.useMemo(() => {
    missingRequiredFields
    ->Array.find(fc =>
      switch fc.fieldType {
      | FullNameInput(_) => true
      | _ => false
      }
    )
    ->Option.map(fc =>
      switch fc.fieldType {
      | FullNameInput(config) => config
      | _ => {firstName: None, lastName: None}
      }
    )
    ->Option.getOr({firstName: None, lastName: None})
  }, [missingRequiredFields])

  let firstNamePath = React.useMemo(() => {
    fullNameConfig.firstName->Option.map(fc => fc.outputPath)->Option.getOr("")
  }, [fullNameConfig])

  let lastNamePath = React.useMemo(() => {
    fullNameConfig.lastName->Option.map(fc => fc.outputPath)->Option.getOr("")
  }, [fullNameConfig])

  // State + City: both present → render as a side-by-side pair.
  let cityOutputPath = React.useMemo(() => {
    processedFieldConfigs->DynamicFieldsUtils.getOutputPathForFieldType(AddressCityInput)
  }, [processedFieldConfigs])

  let stateOutputPath = React.useMemo(() => {
    processedFieldConfigs->DynamicFieldsUtils.getOutputPathForFieldType(AddressStateInput)
  }, [processedFieldConfigs])

  let hasBothStateAndCity = React.useMemo(() => {
    processedFieldConfigs->DynamicFieldsUtils.hasBothFieldTypes(AddressCityInput, AddressStateInput)
  }, [processedFieldConfigs])

  // Country + Postal: both present → render as a side-by-side pair.
  let countryOutputPath = React.useMemo(() => {
    processedFieldConfigs->DynamicFieldsUtils.getOutputPathForFieldType(AddressCountryInput)
  }, [processedFieldConfigs])

  let postalOutputPath = React.useMemo(() => {
    processedFieldConfigs->DynamicFieldsUtils.getOutputPathForFieldType(AddressPostalCodeInput)
  }, [processedFieldConfigs])

  let hasBothCountryAndPostal = React.useMemo(() => {
    processedFieldConfigs->DynamicFieldsUtils.hasBothFieldTypes(
      AddressCountryInput,
      AddressPostalCodeInput,
    )
  }, [processedFieldConfigs])

  // Phone + CountryCode: both present → render as a combined phone input.
  let phoneNumberOutputPath = React.useMemo(() => {
    processedFieldConfigs->DynamicFieldsUtils.getOutputPathForFieldType(PhoneInput)
  }, [processedFieldConfigs])

  let countryCodeOutputPath = React.useMemo(() => {
    processedFieldConfigs->DynamicFieldsUtils.getOutputPathForFieldType(CountryCodeSelect)
  }, [processedFieldConfigs])

  let hasBothPhoneAndCountryCode = React.useMemo(() => {
    processedFieldConfigs->DynamicFieldsUtils.hasBothFieldTypes(PhoneInput, CountryCodeSelect)
  }, [processedFieldConfigs])

  // Month + Year expiry: both present → render as a single expiry input (outside billing).
  let hasBothMonthAndYear = React.useMemo(() => {
    processedFieldConfigs->DynamicFieldsUtils.hasBothFieldTypes(MonthSelect, YearSelect)
  }, [processedFieldConfigs])

  // CvcPasswordInput alongside month+year:
  // render expiry + CVC side-by-side.
  let hasExpiryAndCvc = React.useMemo(() => {
    hasBothMonthAndYear && processedFieldConfigs->DynamicFieldsUtils.hasFieldType(CvcPasswordInput)
  }, [processedFieldConfigs])

  // Split fields into outside and inside billing sections
  let fieldsOutsideBilling = React.useMemo(() => {
    processedFieldConfigs->Array.filter(fc => fc->isFieldTypeToRenderOutsideBillingConfig)
  }, [processedFieldConfigs])

  let fieldsInsideBilling = React.useMemo(() => {
    processedFieldConfigs->Array.filter(fc => !(fc->isFieldTypeToRenderOutsideBillingConfig))
  }, [processedFieldConfigs])

  let isInfoElementPresent =
    fieldsOutsideBilling
    ->Array.find(fc => fc.fieldType == InfoElementType)
    ->Option.isSome
  let isRenderInfoElement = isInfoElementPresent && !isDisableInfoElement

  let isRenderDynamicFieldsInsideBilling = fieldsInsideBilling->Array.length > 0

  let spacedStylesForBiilingDetails = isSpacedInnerLayout ? "p-2" : "my-2"

  let formValidator = React.useMemo(() => {
    _ => Dict.make()
  }, [processedFieldConfigs])

  let (_, setAreRequiredFieldsValid) = Recoil.useRecoilState(areRequiredFieldsValid)

  React.useEffect(() => {
    // this sideEffect is for resetting the validation context when payment method changes and there are no required fields to render.
    if processedFieldConfigs->Array.length === 0 && !isLoading {
      setAreRequiredFieldsValid(_ => true)
    }
    None
  }, (processedFieldConfigs, isLoading))

  <RenderIf condition={!isSavedCardFlow && processedFieldConfigs->Array.length > 0}>
    <ReactFinalForm.Form
      onSubmit={_ => ()}
      initialValues={Some(initialValues)}
      validate={Some(formValidator)}
      render={formProps => {
        formSubmitRef.current = Some(formProps.form.submit)
        let submitFailed = formProps.submitFailed
        ReactFinalForm.useFormStateHandler(
          ~onFormChange=values => {
            // Flatten the nested form values so keys align correctly during merge using `mergeAndFlattenToTuples`.
            let flatValues = values->JSON.Encode.object->Utils.flattenObject(false)
            setRequiredFieldsBody(_ => flatValues)
          },
          ~onValidationChange=isValid => {
            setAreRequiredFieldsValid(_ => isValid)
          },
          ~formProps,
        )
        <>
          {fieldsOutsideBilling
          ->Array.mapWithIndex((item, index) => {
            <DynamicFieldsToRenderWrapper key={index->Int.toString} index={index} isInside={false}>
              {switch item.fieldType {
              | CardNumberTextInput =>
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
              | GiftCardNumberInput => <GiftCardNumberInput />
              | GiftCardPinInput => <GiftCardPinInput />
              | MonthSelect =>
                if hasExpiryAndCvc {
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
                } else {
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
                }
              | YearSelect => React.null
              | CvcPasswordInput =>
                if hasExpiryAndCvc {
                  React.null
                } else {
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
                }
              | CurrencySelect =>
                let updatedCurrencyArray =
                  item.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                <ReactFinalFormField
                  name={item.outputPath}
                  render={(field: ReactFinalForm.Field.fieldProps) => {
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
              | DocumentTypeSelect => {
                  let updatedDocumentTypeArray =
                    item.options->DropdownField.updateArrayOfStringToOptionsTypeArrayWithUpperCaseLabel
                  <DocumentNumberInput name={item.outputPath} options={updatedDocumentTypeArray} />
                }
              | FullNameInput(_) =>
                let defaultName =
                  paymentMethod === "card"
                    ? localeString.cardHolderName
                    : localeString.fullNameLabel
                <>
                  <RenderIf condition={!isSpacedInnerLayout}>
                    <div
                      style={
                        marginBottom: "5px",
                        fontSize: themeObj.fontSizeLg,
                        opacity: "0.6",
                      }>
                      {defaultName->React.string}
                    </div>
                  </RenderIf>
                  <FullNamePaymentInput
                    customFieldName={Some(defaultName)} firstNamePath lastNamePath
                  />
                </>
              | CryptoNetworkSelect => <CryptoCurrencyNetworks name={item.outputPath} />
              | DatePicker => <DateOfBirth name={item.outputPath} />
              | VpaTextInput => <VpaIdPaymentInput name={item.outputPath} />
              | PixKeyInput => <PixPaymentInput name={item.outputPath} fieldType="pixKey" />
              | PixCpfInput => <PixPaymentInput name={item.outputPath} fieldType="pixCPF" />
              | PixCnpjInput => <PixPaymentInput name={item.outputPath} fieldType="pixCNPJ" />
              | BankAccountNumberInput =>
                <ReactFinalFormField
                  name={item.outputPath}
                  validationRule={Validation.fieldTypeToValidationRule(BankAccountNumberInput)}
                  render={(field: ReactFinalForm.Field.fieldProps) => {
                    let val = field.input.value->Option.getOr("")
                    <PaymentField
                      fieldName="Account Number"
                      value={
                        RecoilAtomTypes.value: val,
                        isValid: Some(field.meta.valid),
                        errorString: submitFailed || field.meta.touched
                          ? field.meta.error->Option.getOr("")
                          : "",
                      }
                      onChange={ev => {
                        let rawValue = ReactEvent.Form.target(ev)["value"]
                        let cleanValue = rawValue->Validation.clearSpaces
                        field.input.onChange(cleanValue)
                      }}
                      onBlur={_ev => field.input.onBlur()}
                      type_="tel"
                      name="bankAccountNumber"
                      maxLength=17
                      inputRef=bankAccountNumberRef
                      placeholder="000123456789"
                    />
                  }}
                />
              | IbanInput =>
                <ReactFinalFormField
                  name={item.outputPath}
                  validationRule={Validation.fieldTypeToValidationRule(IbanInput)}
                  render={(field: ReactFinalForm.Field.fieldProps) => {
                    let val = field.input.value->Option.getOr("")
                    <PaymentField
                      fieldName="IBAN"
                      value={
                        RecoilAtomTypes.value: val,
                        isValid: Some(field.meta.valid),
                        errorString: submitFailed || field.meta.touched
                          ? field.meta.error->Option.getOr("")
                          : "",
                      }
                      onChange={ev => field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                      onBlur={_ev => field.input.onBlur()}
                      type_="text"
                      name="iban"
                      maxLength=42
                      inputRef={React.useRef(Nullable.null)}
                      placeholder="DE00 0000 0000 0000 0000 00"
                    />
                  }}
                />
              | SourceBankAccountIdInput =>
                <ReactFinalFormField
                  name={item.outputPath}
                  render={(field: ReactFinalForm.Field.fieldProps) => {
                    let val = field.input.value->Option.getOr("")
                    <PaymentField
                      fieldName="Source Bank Account ID"
                      value={
                        RecoilAtomTypes.value: val,
                        isValid: Some(field.meta.valid),
                        errorString: submitFailed || field.meta.touched
                          ? field.meta.error->Option.getOr("")
                          : "",
                      }
                      onChange={ev => field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                      onBlur={_ev => field.input.onBlur()}
                      type_="text"
                      name="sourceBankAccountId"
                      maxLength=42
                      inputRef=sourceBankAccountIdRef
                      placeholder="DE00 0000 0000 0000 0000 00"
                    />
                  }}
                />
              | DocumentNumberInput
              | EmailInput(_)
              | InfoElementType
              | CountrySelect
              | BankSelect
              | BankListSelect
              | PhoneInput
              | AddressLine1Input
              | AddressLine2Input
              | AddressCityInput
              | AddressPostalCodeInput
              | AddressStateInput
              | BlikCodeInput
              | AddressCountryInput
              | // | ShippingNameInput // Shipping Details are currently supported by only one click widgets
              // | ShippingAddressLine1Input
              // | ShippingAddressLine2Input
              // | ShippingAddressCityInput
              // | ShippingAddressPostalCodeInput
              // | ShippingAddressStateInput
              // | ShippingAddressCountryInput
              CountryCodeSelect
              | TextInput
              | PasswordInput
              | StateSelect
              | DropdownSelect => React.null
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
                {fieldsInsideBilling
                ->Array.mapWithIndex((item, index) => {
                  <DynamicFieldsToRenderWrapper key={index->Int.toString} index={index}>
                    {switch item.fieldType {
                    | EmailInput(emailFields) =>
                      <EmailPaymentInput emailFields />
                    | PhoneInput =>
                      if hasBothPhoneAndCountryCode {
                        <PhoneNumberPaymentInput
                          numberName={phoneNumberOutputPath} codeName={countryCodeOutputPath}
                        />
                      } else {
                        <ReactFinalFormField
                          name={item.outputPath}
                          validationRule={Validation.fieldTypeToValidationRule(PhoneInput)}
                          render={(field: ReactFinalForm.Field.fieldProps) => {
                            let val = field.input.value->Option.getOr("")
                            <PaymentField
                              fieldName=localeString.formFieldPhoneNumberLabel
                              value={
                                value: val,
                                isValid: Some(field.meta.valid),
                                errorString: submitFailed || field.meta.touched
                                  ? field.meta.error->Option.getOr("")
                                  : "",
                              }
                              onChange={ev =>
                                field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                              onBlur={_ev => field.input.onBlur()}
                              type_="tel"
                              name="phone"
                              inputRef={React.useRef(Nullable.null)}
                              placeholder="000 000 000"
                            />
                          }}
                        />
                      }
                    | CountryCodeSelect => React.null
                    | AddressCityInput =>
                      if hasBothStateAndCity {
                        <div
                          className={`flex ${isSpacedInnerLayout ? "gap-4" : ""} overflow-hidden`}>
                          <ReactFinalFormField
                            name={cityOutputPath}
                            validationRule={Validation.fieldTypeToValidationRule(AddressCityInput)}
                            render={(field: ReactFinalForm.Field.fieldProps) => {
                              let val = field.input.value->Option.getOr("")
                              <PaymentField
                                fieldName=localeString.cityLabel
                                value={
                                  value: val,
                                  isValid: Some(field.meta.valid),
                                  errorString: submitFailed || field.meta.touched
                                    ? field.meta.error->Option.getOr("")
                                    : "",
                                }
                                onChange={ev =>
                                  field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                                onBlur={_ev => field.input.onBlur()}
                                type_="text"
                                name="city"
                                inputRef=cityRef
                                placeholder=localeString.cityLabel
                                className={isSpacedInnerLayout ? "" : "!border-r-0"}
                              />
                            }}
                          />
                          <ReactFinalFormField
                            name={stateOutputPath}
                            validationRule={Validation.fieldTypeToValidationRule(AddressStateInput)}
                            render={(field: ReactFinalForm.Field.fieldProps) => {
                              let val = field.input.value->Option.getOr("")
                              if stateNames->Array.length > 0 {
                                <PaymentDropDownField
                                  fieldName=localeString.stateLabel
                                  value={
                                    value: val,
                                    isValid: Some(field.meta.valid),
                                    errorString: submitFailed || field.meta.touched
                                      ? field.meta.error->Option.getOr("")
                                      : "",
                                  }
                                  setValue={setter => {
                                    let newVal = setter({
                                      value: val,
                                      isValid: Some(field.meta.valid),
                                      errorString: "",
                                    })
                                    let countryIso = Utils.getCountryCode(country).isoAlpha2
                                    let stateCode = Utils.getStateCodeFromStateName(
                                      newVal.value,
                                      countryIso,
                                    )
                                    field.input.onChange(stateCode)
                                  }}
                                  options={stateNames}
                                />
                              } else {
                                <PaymentField
                                  fieldName=localeString.stateLabel
                                  value={
                                    value: val,
                                    isValid: Some(field.meta.valid),
                                    errorString: submitFailed || field.meta.touched
                                      ? field.meta.error->Option.getOr("")
                                      : "",
                                  }
                                  onChange={ev =>
                                    field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                                  onBlur={_ev => field.input.onBlur()}
                                  type_="text"
                                  name="state"
                                  placeholder=localeString.stateLabel
                                  inputRef=stateRef
                                />
                              }
                            }}
                          />
                        </div>
                      } else {
                        <ReactFinalFormField
                          name={item.outputPath}
                          validationRule={Validation.fieldTypeToValidationRule(AddressCityInput)}
                          render={(field: ReactFinalForm.Field.fieldProps) => {
                            let val = field.input.value->Option.getOr("")
                            <PaymentField
                              fieldName=localeString.cityLabel
                              value={
                                value: val,
                                isValid: Some(field.meta.valid),
                                errorString: submitFailed || field.meta.touched
                                  ? field.meta.error->Option.getOr("")
                                  : "",
                              }
                              onChange={ev =>
                                field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                              onBlur={_ev => field.input.onBlur()}
                              type_="text"
                              name="city"
                              inputRef=cityRef
                              placeholder=localeString.cityLabel
                            />
                          }}
                        />
                      }
                    | AddressStateInput =>
                      if hasBothStateAndCity {
                        React.null
                      } else {
                        <ReactFinalFormField
                          name={item.outputPath}
                          validationRule={Validation.fieldTypeToValidationRule(AddressStateInput)}
                          render={(field: ReactFinalForm.Field.fieldProps) => {
                            let val = field.input.value->Option.getOr("")
                            if stateNames->Array.length > 0 {
                              <PaymentDropDownField
                                fieldName=localeString.stateLabel
                                value={
                                  value: val,
                                  isValid: Some(field.meta.valid),
                                  errorString: submitFailed || field.meta.touched
                                    ? field.meta.error->Option.getOr("")
                                    : "",
                                }
                                setValue={setter => {
                                  let newVal = setter({
                                    value: val,
                                    isValid: Some(field.meta.valid),
                                    errorString: "",
                                  })
                                  let countryIso = Utils.getCountryCode(country).isoAlpha2
                                  let stateCode = Utils.getStateCodeFromStateName(
                                    newVal.value,
                                    countryIso,
                                  )
                                  field.input.onChange(stateCode)
                                }}
                                options={stateNames}
                              />
                            } else {
                              <PaymentField
                                fieldName=localeString.stateLabel
                                value={
                                  value: val,
                                  isValid: Some(field.meta.valid),
                                  errorString: submitFailed || field.meta.touched
                                    ? field.meta.error->Option.getOr("")
                                    : "",
                                }
                                onChange={ev =>
                                  field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                                onBlur={_ev => field.input.onBlur()}
                                type_="text"
                                name="state"
                                placeholder=localeString.stateLabel
                                inputRef=stateRef
                              />
                            }
                          }}
                        />
                      }
                    | AddressCountryInput =>
                      if hasBothCountryAndPostal {
                        let updatedCountryArray =
                          countryNames->DropdownField.updateArrayOfStringToOptionsTypeArray
                        <div className={`flex ${isSpacedInnerLayout ? "gap-4" : ""}`}>
                          <ReactFinalFormField
                            name={countryOutputPath}
                            initialValue=initialCountryIso
                            render={(field: ReactFinalForm.Field.fieldProps) => {
                              <DropdownField
                                appearance=config.appearance
                                fieldName=localeString.countryLabel
                                value=country
                                setValue={setter => {
                                  let newVal = setter(field.input.value->Option.getOr(country))
                                  setCountry(_ => newVal)
                                  let countryIso = Utils.getCountryCode(newVal).isoAlpha2
                                  field.input.onChange(countryIso)
                                }}
                                disabled=false
                                options=updatedCountryArray
                                className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
                              />
                            }}
                          />
                          <ReactFinalFormField
                            name={postalOutputPath}
                            validationRule={Validation.fieldTypeToValidationRule(
                              AddressPostalCodeInput,
                              ~country=countryIso,
                            )}
                            render={(field: ReactFinalForm.Field.fieldProps) => {
                              let val = field.input.value->Option.getOr("")
                              <PaymentField
                                fieldName=localeString.postalCodeLabel
                                value={
                                  value: val,
                                  isValid: Some(field.meta.valid),
                                  errorString: submitFailed || field.meta.touched
                                    ? field.meta.error->Option.getOr("")
                                    : "",
                                }
                                onChange={ev =>
                                  field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                                onBlur={_ev => field.input.onBlur()}
                                name="postal"
                                inputRef=postalRef
                                placeholder=localeString.postalCodeLabel
                                className={isSpacedInnerLayout ? "" : "!border-t-0"}
                              />
                            }}
                          />
                        </div>
                      } else {
                        let updatedCountryArr =
                          countryNames->DropdownField.updateArrayOfStringToOptionsTypeArray
                        <ReactFinalFormField
                          name={item.outputPath}
                          initialValue=initialCountryIso
                          render={(field: ReactFinalForm.Field.fieldProps) => {
                            <DropdownField
                              appearance=config.appearance
                              fieldName=localeString.countryLabel
                              value=country
                              setValue={setter => {
                                let newVal = setter(field.input.value->Option.getOr(country))
                                setCountry(_ => newVal)
                                let countryIso = Utils.getCountryCode(newVal).isoAlpha2
                                field.input.onChange(countryIso)
                              }}
                              disabled=false
                              options=updatedCountryArr
                            />
                          }}
                        />
                      }
                    | AddressPostalCodeInput =>
                      if hasBothCountryAndPostal {
                        React.null
                      } else {
                        <ReactFinalFormField
                          name={item.outputPath}
                          validationRule={Validation.fieldTypeToValidationRule(
                            AddressPostalCodeInput,
                            ~country=countryIso,
                          )}
                          render={(field: ReactFinalForm.Field.fieldProps) => {
                            let val = field.input.value->Option.getOr("")
                            <PaymentField
                              fieldName=localeString.postalCodeLabel
                              value={
                                value: val,
                                isValid: Some(field.meta.valid),
                                errorString: submitFailed || field.meta.touched
                                  ? field.meta.error->Option.getOr("")
                                  : "",
                              }
                              onChange={ev =>
                                field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                              onBlur={_ev => field.input.onBlur()}
                              name="postal"
                              inputRef=postalRef
                              placeholder=localeString.postalCodeLabel
                            />
                          }}
                        />
                      }
                    | AddressLine1Input =>
                      <ReactFinalFormField
                        name={item.outputPath}
                        validationRule={Validation.fieldTypeToValidationRule(AddressLine1Input)}
                        render={(field: ReactFinalForm.Field.fieldProps) => {
                          let val = field.input.value->Option.getOr("")
                          <PaymentField
                            fieldName=localeString.line1Label
                            value={
                              value: val,
                              isValid: Some(field.meta.valid),
                              errorString: submitFailed || field.meta.touched
                                ? field.meta.error->Option.getOr("")
                                : "",
                            }
                            onChange={ev =>
                              field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                            onBlur={_ev => field.input.onBlur()}
                            type_="text"
                            name="line1"
                            inputRef=line1Ref
                            placeholder=localeString.line1Placeholder
                            className={isSpacedInnerLayout ? "" : "!border-b-0"}
                          />
                        }}
                      />
                    | AddressLine2Input =>
                      <ReactFinalFormField
                        name={item.outputPath}
                        render={(field: ReactFinalForm.Field.fieldProps) => {
                          let val = field.input.value->Option.getOr("")
                          <PaymentField
                            fieldName=localeString.line2Label
                            value={
                              value: val,
                              isValid: Some(field.meta.valid),
                              errorString: submitFailed || field.meta.touched
                                ? field.meta.error->Option.getOr("")
                                : "",
                            }
                            onChange={ev =>
                              field.input.onChange(ReactEvent.Form.target(ev)["value"])}
                            onBlur={_ev => field.input.onBlur()}
                            type_="text"
                            name="line2"
                            inputRef=line2Ref
                            placeholder=localeString.line2Placeholder
                          />
                        }}
                      />
                    | BlikCodeInput => <BlikCodePaymentInput />
                    | CountrySelect =>
                      let updatedCountryNames =
                        countryNames->DropdownField.updateArrayOfStringToOptionsTypeArray
                      <ReactFinalFormField
                        name={item.outputPath}
                        initialValue=initialCountryIso
                        render={(field: ReactFinalForm.Field.fieldProps) => {
                          <DropdownField
                            appearance=config.appearance
                            fieldName=localeString.countryLabel
                            value=country
                            setValue={setter => {
                              let newVal = setter(field.input.value->Option.getOr(country))
                              setCountry(_ => newVal)
                              let countryIso = Utils.getCountryCode(newVal).isoAlpha2
                              field.input.onChange(countryIso)
                            }}
                            disabled=false
                            options=updatedCountryNames
                          />
                        }}
                      />
                    | BankListSelect =>
                      let updatedBankNames =
                        Bank.getBanks(paymentMethodType)
                        ->getBankNames(item.options)
                        ->DropdownField.updateArrayOfStringToOptionsTypeArray
                      <ReactFinalFormField
                        name={item.outputPath}
                        render={(field: ReactFinalForm.Field.fieldProps) => {
                          let val = field.input.value->Option.getOr(selectedBank)
                          <DropdownField
                            appearance=config.appearance
                            fieldName=localeString.bankLabel
                            value=val
                            setValue={setter => {
                              let newVal = setter(val)
                              setSelectedBank(_ => newVal)
                              field.input.onChange(newVal)
                            }}
                            disabled=false
                            options=updatedBankNames
                          />
                        }}
                      />
                    | BankSelect =>
                      let updatedBankNames =
                        bankNames->DropdownField.updateArrayOfStringToOptionsTypeArray
                      <ReactFinalFormField
                        name={item.outputPath}
                        render={(field: ReactFinalForm.Field.fieldProps) => {
                          let val = field.input.value->Option.getOr(selectedBank)
                          <DropdownField
                            appearance=config.appearance
                            fieldName=localeString.bankLabel
                            value=val
                            setValue={setter => {
                              let newVal = setter(val)
                              setSelectedBank(_ => newVal)
                              field.input.onChange(newVal)
                            }}
                            disabled=false
                            options=updatedBankNames
                          />
                        }}
                      />
                    | InfoElementType
                    | PixKeyInput
                    | PixCpfInput
                    | PixCnpjInput
                    | DocumentTypeSelect
                    | DocumentNumberInput
                    | CardNumberTextInput
                    | MonthSelect
                    | YearSelect
                    | CvcPasswordInput
                    | CurrencySelect
                    | FullNameInput(_)
                    | GiftCardNumberInput
                    | GiftCardPinInput
                    | // | ShippingNameInput // Shipping Details are currently supported by only one click widgets
                    // | ShippingAddressLine1Input
                    // | ShippingAddressLine2Input
                    // | ShippingAddressCityInput
                    // | ShippingAddressPostalCodeInput
                    // | ShippingAddressStateInput
                    // | ShippingAddressCountryInput
                    CryptoNetworkSelect
                    | DatePicker
                    | VpaTextInput
                    | BankAccountNumberInput
                    | IbanInput
                    | SourceBankAccountIdInput
                    | TextInput
                    | PasswordInput
                    | StateSelect
                    | DropdownSelect => React.null
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
              {if processedFieldConfigs->Array.length > 1 {
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
