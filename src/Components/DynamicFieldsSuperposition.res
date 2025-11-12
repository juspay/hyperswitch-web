open SuperpositionTypes

type dynamicFieldsFormRef = {getFormState: unit => ReactFinalForm.getState}

module ElementsRenderer = {
  @react.component
  let make = (~elements: SuperpositionTypes.elementType) => {
    switch elements {
    | CARD(fields) if fields->Array.length > 0 => <CardFieldsRenderer fields />
    | CRYPTO(fields) if fields->Array.length > 0 => <CryptoElement fields />
    | FULLNAME(fields) if fields->Array.length > 0 => <FullNameElement fields />
    | PHONE(fields) if fields->Array.length > 0 => <PhoneElement fields />
    | EMAIL(fields) if fields->Array.length > 0 => <EmailElement fields />
    | GENERIC(fields) if fields->Array.length > 0 =>
      fields
      ->Array.map(field => {
        <DynamicInputFields key={field.outputPath} field />
      })
      ->React.array
    | _ => React.null
    }
  }
}

module CustomFieldsRenderer = {
  @react.component
  let make = (~customFields) => {
    <RenderIf condition={customFields->Array.length > 0}>
      {customFields
      ->Array.map(group => {
        <ElementsRenderer elements=group />
      })
      ->React.array}
    </RenderIf>
  }
}

@react.component
let make = React.forwardRef((
  ~paymentMethod,
  ~paymentMethodType,
  ~submitCallback,
  ~showOnlyCustomFields=false,
  ~customFields=[],
  ~disableSubmitListener=false,
  ref,
) => {
  let (groupedFields, initialValues) = UseGroupedFields.useGroupedFieldsFromSuperposition(
    ~paymentMethod,
    ~paymentMethodType,
  )
  Console.log2("Grouped Fields:", groupedFields)
  let (
    cardFields,
    emailFields,
    billingNameFields,
    billingPhoneFields,
    billingOtherFields,
    cryptoFields,
    otherFields,
  ) = groupedFields

  let formSubmitCallback = (ev: Window.event, props: ReactFinalForm.formProps) => {
    let {form} = props
    Console.log(props)
    let json = ev.data->Utils.safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      let _ = form.submit()
      let formState = props.form.getState()
      let formValues = formState.values
      let formValuesWithInitialValues = CommonUtils.mergeDict(formValues, initialValues)
      if formState.valid {
        submitCallback(ev, formValuesWithInitialValues, formValues)
      } else {
        Console.log("Form is invalid, cannot submit")
        Utils.postFailedSubmitResponse(
          ~errortype="validation_error",
          ~message="one or more fields are invalid",
        )
      }
    }
  }

  let handleFormSubmit = (_values, form: ReactFinalForm.formMethods) => {
    Console.log2("Form submitted with values:", form.getState())
  }

  <>
    <ReactFinalForm.Form
      key="dynamic-fields-form"
      onSubmit={handleFormSubmit}
      render={props => {
        if !disableSubmitListener {
          Utils.useSubmitPaymentData(ev => formSubmitCallback(ev, props))
        }
        React.useImperativeHandle0(ref, () => {
          getFormState: () => props.form.getState(),
        })
        <>
          <RenderIf condition={!showOnlyCustomFields}>
            <ElementsRenderer elements=CARD(cardFields) />
            <ElementsRenderer elements=CRYPTO(cryptoFields) />
            <ElementsRenderer elements=FULLNAME(billingNameFields) />
            <ElementsRenderer elements=PHONE(billingPhoneFields) />
            <ElementsRenderer elements=EMAIL(emailFields) />
            <ElementsRenderer elements=GENERIC(billingOtherFields) />
            <ElementsRenderer elements=GENERIC(otherFields) />
          </RenderIf>
          <CustomFieldsRenderer customFields />
          <InfoElementRenderer paymentMethodType groupedFields />
          <Utils.FormValuesSpy />
        </>
      }}
    />
  </>
})
