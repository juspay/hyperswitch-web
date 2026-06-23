open SuperpositionTypes

@react.component
let make = (~fieldConfig: fieldConfig, ~hideLabel=false) => {
  let fieldRef = React.useRef(Nullable.null)
  let path = fieldConfig.confirmRequestWritePath
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label, placeholder} = DynamicFieldsUtils.resolveFieldTexts(
    ~field=fieldConfig,
    ~localeObject=localeString,
  )
  let maxLength = fieldConfig.maxInputLength
  let autocomplete = fieldConfig.htmlAutocompleteAttribute->Option.getOr("tel-national")

  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)

  let field = ReactFinalForm.useField(path, ~config={validate: validate})

  let value = field.input.value->Option.getOr("")
  let invalid = field.meta.invalid
  let showError = field.meta.touched && !field.meta.active
  let isValid = showError ? Some(!invalid) : None
  let errorString = if showError && invalid {
    field.meta.error->Option.getOr("")
  } else {
    ""
  }

  <PaymentInputField
    fieldName={hideLabel ? "" : label}
    value
    onChange={ev => {
      let val = ReactEvent.Form.target(ev)["value"]->String.replaceRegExp(%re("/\D|\s/g"), "")
      field.input.onChange(val)
    }}
    onBlur={_ev => field.input.onBlur()}
    onFocus={_ev => field.input.onFocus()}
    isValid
    errorString
    placeholder
    inputRef={fieldRef}
    autocomplete
    ?maxLength
  />
}
