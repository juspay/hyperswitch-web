open SuperpositionTypes

module EmailInput = {
  @react.component
  let make = (~primaryFieldConfig, ~fields) => {
    let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let fieldRef = React.useRef(Nullable.null)
    let form = ReactFinalForm.useForm()

    let {label, placeholder} = DynamicFieldsUtils.resolveFieldTexts(
      ~field=primaryFieldConfig,
      ~localeObject=localeString,
    )
    let autocomplete = primaryFieldConfig.htmlAutocompleteAttribute->Option.getOr("email")
    let validate = DynamicFieldsUtils.resolveValidator(
      ~field=primaryFieldConfig,
      ~localeObject=localeString,
    )

    let primaryField = ReactFinalForm.useField(
      primaryFieldConfig.confirmRequestWritePath,
      ~config={validate: validate},
    )

    let value = primaryField.input.value->Option.getOr("")
    let invalid = primaryField.meta.invalid
    let showError = primaryField.meta.touched && !primaryField.meta.active
    let isValid = showError ? Some(!invalid) : None
    let errorString = showError && invalid ? primaryField.meta.error->Option.getOr("") : ""

    <PaymentInputField
      fieldName={label}
      value
      onChange={ev => {
        let val = ReactEvent.Form.target(ev)["value"]
        fields->Array.forEach(field => form.change(field.confirmRequestWritePath, val))
      }}
      onBlur={_ev => primaryField.input.onBlur()}
      onFocus={_ev => primaryField.input.onFocus()}
      isValid
      errorString
      placeholder
      inputRef={fieldRef}
      autocomplete
      ariaRequired={primaryFieldConfig.isRequired}
    />
  }
}

@react.component
let make = (~fields: array<fieldConfig>) => {
  switch fields->Array.get(0) {
  | None => React.null
  | Some(primaryFieldConfig) => <EmailInput primaryFieldConfig fields />
  }
}
