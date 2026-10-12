module DynamicFieldsToRenderWrapper = {
  @react.component
  let make = (~children, ~index, ~isInside=true) => {
    let {themeObj} = Jotai.useAtomValue(JotaiAtoms.configAtom)

    <RenderIf condition={children != React.null}>
      <div
        key={`${isInside ? "inside" : "outside"}-billing-${index->Int.toString}`}
        className="flex flex-col w-full place-content-between"
        style={
          gridColumnGap: isInside ? "0px" : themeObj.spacingGridRow,
        }
      >
        {children}
      </div>
    </RenderIf>
  }
}

module FormBody = {
  open SuperpositionTypes

  @react.component
  let make = (
    ~formProps: ReactFinalForm.Form.formProps,
    ~formRef: React.ref<option<ReactFinalForm.Form.formMethods>>,
    ~languagePreferenceFields: array<fieldConfig>,
    ~missingRequiredFieldsFiltered: array<fieldConfig>,
    ~persistableFields: array<fieldConfig>,
    ~dynamicFieldsOutsideBilling: array<fieldConfig>,
    ~dynamicFieldsInsideBilling: array<fieldConfig>,
    ~allEmailFields: array<fieldConfig>,
    ~allCardHolderNameFields: array<fieldConfig>,
    ~paymentMethodType,
    ~setRequiredFieldsBody,
    ~syncEmitAddressAtoms,
  ) => {
    open DynamicFieldsUtils
    open JotaiAtoms

    let {config, themeObj, localeString} = Jotai.useAtomValue(configAtom)
    let setAreRequiredFieldsValid = Jotai.useSetAtom(areRequiredFieldsValid)
    let setAreRequiredFieldsEmpty = Jotai.useSetAtom(areRequiredFieldsEmpty)
    let setUserDynamicFieldsValues = Jotai.useSetAtom(userDynamicFieldsValues)

    let isSpacedInnerLayout = config.appearance.innerLayout === Spaced
    let isRenderDynamicFieldsInsideBilling = dynamicFieldsInsideBilling->Array.length > 0
    let spacedStylesForBillingDetails = isSpacedInnerLayout ? "p-2" : "my-2"

    formRef.current = Some(formProps.form)

    ReactFinalForm.useFormStateHandler(
      ~onFormChange=values => {
        // RFF stores values as nested objects; flatten to dot-notation keys so they align with the confirm-payload merge.
        let flatValues = values->JSON.Encode.object->Utils.flattenObject(false)

        languagePreferenceFields->Array.forEach(field =>
          flatValues->Dict.set(
            field.confirmRequestWritePath,
            getComputedLanguagePreferenceValue(
              ~locale=config.locale,
              ~options=field.dropdownOptions->Option.getOr([]),
            )->JSON.Encode.string,
          )
        )

        setRequiredFieldsBody(_ => flatValues)

        // Persist field values so they survive the remount on payment-method-type switch.
        setUserDynamicFieldsValues(prev => {
          let next = prev->Dict.copy
          persistableFields->Array.forEach(field => {
            let path = field.confirmRequestWritePath
            next->Dict.set(path, Utils.getString(flatValues, path, ""))
          })
          next
        })

        syncEmitAddressAtoms(flatValues)

        let isEmpty = missingRequiredFieldsFiltered->Array.some(field => {
          switch flatValues->Dict.get(field.confirmRequestWritePath) {
          | None | Some(JSON.Null) => true
          | Some(JSON.String(str)) => str->String.trim === ""
          | Some(_) => false
          }
        })
        setAreRequiredFieldsEmpty(_ => isEmpty)
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
          key={`outside-row-${rowIdx->Int.toString}`} index={rowIdx} isInside={false}
        >
          <DynamicFieldInput.makeRow
            items={row}
            allFields={dynamicFieldsOutsideBilling}
            paymentMethodType
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
          }
        >
          <div
            className="billing-details-text"
            style={
              marginBottom: "5px",
              fontSize: themeObj.fontSizeLg,
              opacity: "0.6",
            }
          >
            {React.string(localeString.billingDetailsText)}
          </div>
          <div
            className="flex flex-col"
            style={
              gap: isSpacedInnerLayout ? themeObj.spacingGridRow : "",
            }
          >
            {dynamicFieldsInsideBilling
            ->DynamicFieldInput.groupFieldsByRow
            ->Array.mapWithIndex((row, rowIdx) => {
              <DynamicFieldsToRenderWrapper
                key={`inside-row-${rowIdx->Int.toString}`} index={rowIdx}
              >
                <DynamicFieldInput.makeRow
                  items={row}
                  allFields={dynamicFieldsInsideBilling}
                  paymentMethodType
                  globalEmailFields={allEmailFields}
                  globalCardHolderNameFields={allCardHolderNameFields}
                />
              </DynamicFieldsToRenderWrapper>
            })
            ->React.array}
          </div>
        </div>
      </RenderIf>
    </>
  }
}

@react.component
let make = (
  ~paymentMethod,
  ~paymentMethodType,
  ~setRequiredFieldsBody,
  ~isSavedCardFlow=false,
  ~savedMethod=PaymentType.defaultCustomerMethods,
  ~isBancontact=false,
  ~isSaveDetailsWithClickToPay=false,
  ~isDisableInfoElement=false,
  ~isSplitPaymentsEnabled=false,
) => {
  open DynamicFieldsUtils
  open Utils
  open JotaiAtoms
  open SuperpositionTypes

  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let {localeString} = Jotai.useAtomValue(configAtom)
  let {billingAddress, redirectionInfo, defaultValues} = Jotai.useAtomValue(optionAtom)
  let syncEmitAddressAtoms = DynamicFieldsUtils.useSyncEmitAddressAtoms()
  let cachedUserDynamicFieldsValues = Jotai.useAtomValue(userDynamicFieldsValues)

  let intentData = paymentMethodListValue.intent_data.intentDataObject

  let (
    requiredFields,
    missingRequiredFields,
    superpositionInitialValues,
    resolutionContext,
  ) = DynamicFieldsUtils.useSuperpositionRequiredFields(~paymentMethod, ~paymentMethodType)
  let initialValues = React.useMemo(
    () => superpositionInitialValues,
    (
      intentData,
      paymentMethodType,
      billingAddress.isUseBillingAddress,
      billingAddress.usePrefilledValues,
    ),
  )

  React.useEffect(() => {
    setRequiredFieldsBody(prev => prev->filterByActiveFields(requiredFields))
    None
  }, [requiredFields])

  let rendersVisibleInput = (field: fieldConfig) =>
    switch field.fieldRenderType {
    | CardNumber
    | Cvc
    | CardExpiryMonth
    | CardExpiryYear
    | CardNetwork
    | LanguagePreference => false
    | Dropdown => field.dropdownOptions->Option.getOr([])->Array.length > 0
    | _ => true
    }

  let persistableFields = React.useMemo(() => {
    missingRequiredFields->Array.filter(field => rendersVisibleInput(field))
  }, [missingRequiredFields])

  let missingRequiredFieldsFiltered = React.useMemo(() => {
    let firstEmailPath =
      missingRequiredFields
      ->Array.filter(fieldConfig => fieldConfig.fieldRenderType === Email)
      ->Array.get(0)
      ->Option.map(fieldConfig => fieldConfig.confirmRequestWritePath)

    let firstCardHolderNamePath =
      missingRequiredFields
      ->Array.filter(fieldConfig => fieldConfig.fieldRenderType === CardHolderName)
      ->Array.get(0)
      ->Option.map(fieldConfig => fieldConfig.confirmRequestWritePath)

    // remove fields that would render as React.null:
    //   - Duplicate Email / CardHolderName fields (only the first path is rendered)
    // (Card-data fields, hidden dropdowns, etc. are already excluded from persistableFields.)
    persistableFields->Array.filter(field =>
      switch field.fieldRenderType {
      | Email => firstEmailPath === Some(field.confirmRequestWritePath)
      | CardHolderName => firstCardHolderNamePath === Some(field.confirmRequestWritePath)
      | _ => true
      }
    )
  }, (missingRequiredFields, persistableFields))

  let initialValuesWithBillingDataOverride = React.useMemo(() => {
    DynamicFieldsUtils.applyBillingDetailsOverride(initialValues, defaultValues.billingDetails)
  }, (initialValues, defaultValues.billingDetails))

  let initialValuesWithUserInputOverride = React.useMemo(() => {
    let merged = initialValuesWithBillingDataOverride
    persistableFields->Array.forEach(field =>
      switch cachedUserDynamicFieldsValues->Dict.get(field.confirmRequestWritePath) {
      | Some(value) =>
        Utils.setNested(
          merged,
          field.confirmRequestWritePath->String.split("."),
          value->JSON.Encode.string,
        )
      | None => ()
      }
    )
    merged
  }, (initialValuesWithBillingDataOverride, cachedUserDynamicFieldsValues, persistableFields))

  let isInsideBillingField = (field: fieldConfig) =>
    field.fieldRenderType === Email ||
      (field.confirmRequestWritePath->String.startsWith(billingPrefix) &&
        !(paymentMethod == "card" && field.fieldRenderType === CardHolderName))

  let dynamicFieldsInsideBilling = React.useMemo(() => {
    missingRequiredFieldsFiltered->Array.filter(field => isInsideBillingField(field))
  }, [missingRequiredFieldsFiltered])

  let dynamicFieldsOutsideBilling = React.useMemo(() => {
    missingRequiredFieldsFiltered->Array.filter(field => !isInsideBillingField(field))
  }, [missingRequiredFieldsFiltered])

  let allEmailFields = React.useMemo(() => {
    missingRequiredFields->Array.filter(fieldConfig => fieldConfig.fieldRenderType === Email)
  }, [missingRequiredFields])

  let allCardHolderNameFields = React.useMemo(() => {
    missingRequiredFields->Array.filter(fieldConfig =>
      fieldConfig.fieldRenderType === CardHolderName
    )
  }, [missingRequiredFields])

  let languagePreferenceFields = React.useMemo(() => {
    requiredFields->Array.filter(fieldConfig => fieldConfig.fieldRenderType === LanguagePreference)
  }, [requiredFields])

  let formRef: React.ref<option<ReactFinalForm.Form.formMethods>> = React.useRef(None)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      formRef.current->Option.forEach(form => form.submit())
    }
  }, [formRef])

  useSubmitPaymentData(submitCallback)

  let saveDetailsCheckbox = CustomPaymentMethodsConfig.useSaveDetailsCheckbox(
    ~paymentMethod,
    ~paymentMethodType,
  )
  let isShowSaveDetailsCheckbox = !isSavedCardFlow && saveDetailsCheckbox.isShow

  let bottomElement = <InfoElement />
  let isInfoElementPresent = React.useMemo(() => {
    PaymentMethodsRecord.getPaymentMethodsFields(~localeString)
    ->Array.find(pm => pm.paymentMethodName === paymentMethodType)
    ->Option.map(pm => pm.fields->Array.includes(PaymentMethodsRecord.InfoElement))
    ->Option.getOr(false)
  }, [paymentMethodType])
  let isRenderInfoElement =
    !isSavedCardFlow &&
    isInfoElementPresent &&
    !isDisableInfoElement &&
    redirectionInfo === ShowRedirectionInfo

  let hasAnyField = missingRequiredFieldsFiltered->Array.length > 0
  let shouldRenderForm =
    hasAnyField || initialValuesWithBillingDataOverride->Dict.keysToArray->Array.length > 0
  let setAreRequiredFieldsValid = Jotai.useSetAtom(areRequiredFieldsValid)
  let setAreRequiredFieldsEmpty = Jotai.useSetAtom(areRequiredFieldsEmpty)

  React.useEffect(() => {
    if isSavedCardFlow || !hasAnyField {
      setAreRequiredFieldsValid(_ => true)
      setAreRequiredFieldsEmpty(_ => false)
    }
    None
  }, (isSavedCardFlow, hasAnyField))

  // When a form renders, FormBody's onFormChange fully replaces requiredFieldsBody, so switching
  // methods is handled automatically. When no form renders, FormBody is unmounted and nothing
  // overwrites the body, so we clear it here to avoid leaking the previous method's values.
  React.useEffect(() => {
    if !shouldRenderForm {
      setRequiredFieldsBody(_ => Dict.make())
    }
    None
  }, (paymentMethodType, shouldRenderForm))

  // Log which dynamic fields are being rendered for the current payment method.
  DynamicFieldsUtils.useLogDynamicFieldsRendered(
    ~fields=missingRequiredFieldsFiltered,
    ~paymentMethod,
    ~resolutionContext,
    ~isSavedCardFlow,
  )

  <>
    <RenderIf condition={!isSavedCardFlow && shouldRenderForm}>
      <ReactFinalForm.Form
        initialValues={Some(initialValuesWithUserInputOverride)}
        onSubmit={_values => ()}
        render={formProps =>
          <FormBody
            formProps
            formRef
            languagePreferenceFields
            missingRequiredFieldsFiltered
            persistableFields
            dynamicFieldsOutsideBilling
            dynamicFieldsInsideBilling
            allEmailFields
            allCardHolderNameFields
            paymentMethodType
            setRequiredFieldsBody
            syncEmitAddressAtoms
          />}
      />
    </RenderIf>
    <RenderIf condition={!isSavedCardFlow && (hasAnyField || isInfoElementPresent)}>
      <Surcharge paymentMethod paymentMethodType />
    </RenderIf>
    // Fields to collect: checkbox sits right below them, info element in a block after.
    <RenderIf condition={hasAnyField && isShowSaveDetailsCheckbox}>
      <SaveDetailsCheckbox
        isChecked={saveDetailsCheckbox.isChecked}
        setIsChecked={saveDetailsCheckbox.setIsChecked}
        paymentMethod
        paymentMethodType
        acceptance=?{saveDetailsCheckbox.acceptance}
      />
    </RenderIf>
    <RenderIf condition={isRenderInfoElement}>
      {!hasAnyField || isShowSaveDetailsCheckbox ? <Block bottomElement /> : bottomElement}
    </RenderIf>
    // No fields to collect: info element block first, checkbox below it.
    <RenderIf condition={!hasAnyField && isShowSaveDetailsCheckbox}>
      <SaveDetailsCheckbox
        isChecked={saveDetailsCheckbox.isChecked}
        setIsChecked={saveDetailsCheckbox.setIsChecked}
        paymentMethod
        paymentMethodType
        acceptance=?{saveDetailsCheckbox.acceptance}
      />
    </RenderIf>
  </>
}
