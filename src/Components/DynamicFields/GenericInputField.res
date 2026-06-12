open SuperpositionTypes

@react.component
let make = (~fieldConfig: fieldConfig) => {
  let fieldRef = React.useRef(Nullable.null)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label, placeholder} = DynamicFieldsUtils.resolveFieldTexts(
    ~field=fieldConfig,
    ~localeObject=localeString,
  )
  let autocomplete = fieldConfig.htmlAutocompleteAttribute
  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)

  <ReactFinalForm.Field name={fieldConfig.confirmRequestWritePath} validate={Some(validate)}>
    {(fieldProps: ReactFinalForm.Field.fieldProps) => {
      let {input, meta} = fieldProps
      let value = input.value->Option.getOr("")
      let showError = meta.touched || meta.submitFailed
      let isValid = showError ? Some(meta.valid) : None
      let errorString = showError && meta.invalid ? meta.error->Option.getOr("") : ""
      <PaymentInputField
        fieldName={label}
        value
        onChange={ev => input.onChange(ReactEvent.Form.target(ev)["value"])}
        onBlur={_ev => input.onBlur()}
        isValid
        errorString
        placeholder
        inputRef={fieldRef}
        ?autocomplete
        maxLength=?{fieldConfig.maxInputLength}
      />
    }}
  </ReactFinalForm.Field>
}
