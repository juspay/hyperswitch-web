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
  open Utils
  open RecoilAtoms
  open SuperpositionTypes

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {billingAddress, redirectionInfo, defaultValues} = Recoil.useRecoilValueFromAtom(optionAtom)
  let country = Recoil.useRecoilValueFromAtom(userCountry)
  let sdkConfigsValue = Recoil.useRecoilValueFromAtom(PaymentUtils.sdkConfigsValue)

  React.useEffect(() => {
    setRequiredFieldsBody(_ => Dict.make())
    None
  }, [paymentMethodType])

  let rawConfigs = sdkConfigsValue.raw_configs

  let getSuperpositionFinalFields = ConfigurationService.useConfigurationService(~rawConfigs)

  let intentData = paymentMethodListValue.intent_data.intentDataObject

  let eligibleConnectors = React.useMemo(() => {
    SdkConfigParser.getEligibleConnectorsFromPaymentMethods(
      sdkConfigsValue.payment_methods,
      paymentMethod,
      paymentMethodType,
    )->Array.map(item => item->JSON.Encode.string)
  }, (sdkConfigsValue.payment_methods, paymentMethod, paymentMethodType))

  let superpositionBaseContext = React.useMemo(() => {
    buildSuperpositionBaseContext(
      ~paymentMethod,
      ~paymentMethodType,
      ~country,
      ~paymentMethodListValue,
    )
  }, (paymentMethod, paymentMethodType, country, paymentMethodListValue))

  let (_requiredFields, missingRequiredFields, initialValues) = React.useMemo(() => {
    getSuperpositionFinalFields(eligibleConnectors, superpositionBaseContext, intentData)
  }, (getSuperpositionFinalFields, eligibleConnectors, superpositionBaseContext, intentData))

  let missingRequiredFieldsFiltered = React.useMemo(() => {
    let afterBillingFilter = removeBillingDetailsIfUseBillingAddress(
      missingRequiredFields,
      billingAddress,
    )

    let firstEmailPath =
      afterBillingFilter
      ->Array.filter(fieldConfig => fieldConfig.fieldRenderType === Email)
      ->Array.get(0)
      ->Option.map(fieldConfig => fieldConfig.confirmRequestWritePath)

    let firstCardHolderNamePath =
      afterBillingFilter
      ->Array.filter(fieldConfig => fieldConfig.fieldRenderType === CardHolderName)
      ->Array.get(0)
      ->Option.map(fieldConfig => fieldConfig.confirmRequestWritePath)

    // remove fields that would render as React.null:
    //   - Any card-data fields (card_exp_month, card_exp_year, card_network, etc.)
    //   - Duplicate Email / CardHolderName fields (only the first path is rendered)
    //   - Dropdown fields with no options (would render React.null anyway)
    afterBillingFilter->Array.filter(field => {
      switch field.fieldRenderType {
      | CardNumber | Cvc | CardExpiryMonth | CardExpiryYear | CardNetwork => false
      | Dropdown =>
        let options = field.dropdownOptions->Option.getOr([])
        options->Array.length > 0
      | Email => firstEmailPath === Some(field.confirmRequestWritePath)
      | CardHolderName => firstCardHolderNamePath === Some(field.confirmRequestWritePath)
      | _ => true
      }
    })
  }, (missingRequiredFields, billingAddress.isUseBillingAddress))

  let finalInitialValues = React.useMemo(() => {
    DynamicFieldsUtils.applyBillingDetailsOverride(initialValues, defaultValues.billingDetails)
  }, (initialValues, defaultValues.billingDetails))

  let billingPrefix = "payment_method_data.billing."

  let dynamicFieldsOutsideBilling = React.useMemo(() => {
    missingRequiredFieldsFiltered->Array.filter(field =>
      !(field.confirmRequestWritePath->String.startsWith(billingPrefix)) ||
      (paymentMethod == "card" && field.fieldRenderType === CardHolderName)
    )
  }, [missingRequiredFieldsFiltered])

  let dynamicFieldsInsideBilling = React.useMemo(() => {
    missingRequiredFieldsFiltered->Array.filter(field =>
      field.confirmRequestWritePath->String.startsWith(billingPrefix) &&
        !(paymentMethod == "card" && field.fieldRenderType === CardHolderName)
    )
  }, [missingRequiredFieldsFiltered])

  let allEmailFields = React.useMemo(() => {
    missingRequiredFields->Array.filter(fieldConfig => fieldConfig.fieldRenderType === Email)
  }, [missingRequiredFields])

  let allCardHolderNameFields = React.useMemo(() => {
    missingRequiredFields->Array.filter(fieldConfig =>
      fieldConfig.fieldRenderType === CardHolderName
    )
  }, [missingRequiredFields])

  let formRef: React.ref<option<ReactFinalForm.Form.formMethods>> = React.useRef(None)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      formRef.current->Option.forEach(form => form.submit())
    }
  }, [formRef])

  useSubmitPaymentData(submitCallback)

  let bottomElement = <InfoElement />
  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced
  let isRenderDynamicFieldsInsideBilling = dynamicFieldsInsideBilling->Array.length > 0
  let isInfoElementPresent = React.useMemo(() => {
    PaymentMethodsRecord.getPaymentMethodsFields(~localeString)
    ->Array.find(pm => pm.paymentMethodName === paymentMethodType)
    ->Option.map(pm => pm.fields->Array.includes(PaymentMethodsRecord.InfoElement))
    ->Option.getOr(false)
  }, [paymentMethodType])
  let isRenderInfoElement =
    isInfoElementPresent && !isDisableInfoElement && redirectionInfo === ShowRedirectionInfo

  let spacedStylesForBillingDetails = isSpacedInnerLayout ? "p-2" : "my-2"
  let hasAnyField = missingRequiredFieldsFiltered->Array.length > 0
  let setAreRequiredFieldsValid = Recoil.useSetRecoilState(areRequiredFieldsValid)

  <>
    <RenderIf condition={!isSavedCardFlow && hasAnyField}>
      <ReactFinalForm.Form
        initialValues={Some(finalInitialValues)}
        onSubmit={_values => ()}
        render={formProps => {
          formRef.current = Some(formProps.form)

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
            {dynamicFieldsOutsideBilling
            ->DynamicFieldInput.groupFieldsByRow
            ->Array.mapWithIndex((row, rowIdx) => {
              <DynamicFieldsToRenderWrapper
                key={`outside-row-${rowIdx->Int.toString}`} index={rowIdx} isInside={false}>
                <DynamicFieldInput.makeRow
                  items={row}
                  allFields={dynamicFieldsOutsideBilling}
                  globalEmailFields={allEmailFields}
                  globalCardHolderNameFields={allCardHolderNameFields}
                />
              </DynamicFieldsToRenderWrapper>
            })
            ->React.array}
            <RenderIf condition={isRenderDynamicFieldsInsideBilling}>
              <div
                className={`billing-section ${spacedStylesForBillingDetails} w-full text-left`}
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
                  className="flex flex-col"
                  style={
                    gap: isSpacedInnerLayout ? themeObj.spacingGridRow : "",
                  }>
                  {dynamicFieldsInsideBilling
                  ->DynamicFieldInput.groupFieldsByRow
                  ->Array.mapWithIndex((row, rowIdx) => {
                    <DynamicFieldsToRenderWrapper
                      key={`inside-row-${rowIdx->Int.toString}`} index={rowIdx}>
                      <DynamicFieldInput.makeRow
                        items={row}
                        allFields={dynamicFieldsInsideBilling}
                        globalEmailFields={allEmailFields}
                        globalCardHolderNameFields={allCardHolderNameFields}
                      />
                    </DynamicFieldsToRenderWrapper>
                  })
                  ->React.array}
                </div>
              </div>
            </RenderIf>
            <Surcharge paymentMethod paymentMethodType />
          </>
        }}
      />
    </RenderIf>
    <RenderIf condition={isRenderInfoElement}>
      {if missingRequiredFieldsFiltered->Array.length >= 1 {
        bottomElement
      } else {
        <Block bottomElement />
      }}
    </RenderIf>
  </>
}
