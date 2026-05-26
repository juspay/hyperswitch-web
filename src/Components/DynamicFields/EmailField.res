open SuperpositionTypes

@react.component
let make = (~fieldConfig: fieldConfig, ~paths: array<string>) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label, placeholder} = DynamicFieldsUtils.resolveFieldTexts(
    ~field=fieldConfig,
    ~localeObject=localeString,
  )
  let autocomplete = fieldConfig.htmlAutocompleteAttribute->Option.getOr("email")
  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)

  switch paths->Array.get(0) {
  | None => React.null
  | Some(primaryPath) =>
    let form = ReactFinalForm.useForm()
    let primaryField = ReactFinalForm.useField(primaryPath, ~config={validate: validate})
    let fieldRef = React.useRef(Nullable.null)

    let value = primaryField.input.value->Option.getOr("")
    let touched = primaryField.meta.touched
    let invalid = primaryField.meta.invalid
    let isValid = if touched {
      Some(!invalid)
    } else {
      None
    }
    let errorString = if touched && invalid {
      primaryField.meta.error->Option.getOr("")
    } else {
      ""
    }

    <PaymentInputField
      fieldName={label}
      value
      onChange={ev => {
        let val = ReactEvent.Form.target(ev)["value"]
        paths->Array.forEach(path => form.change(path, val))
      }}
      onBlur={_ev => primaryField.input.onBlur()}
      isValid
      errorString
      placeholder
      inputRef={fieldRef}
      autocomplete
    />
  }
}
