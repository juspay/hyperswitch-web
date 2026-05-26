open SuperpositionTypes

@react.component
let make = (~fieldConfig: fieldConfig) => {
  let fieldRef = React.useRef(Nullable.null)
  let path = fieldConfig.confirmRequestWritePath
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label, placeholder} = DynamicFieldsUtils.resolveFieldTexts(
    ~field=fieldConfig,
    ~localeObject=localeString,
  )
  let maxLength = fieldConfig.maxInputLength

  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)

  let field = ReactFinalForm.useField(path, ~config={validate: validate})

  let value = field.input.value->Option.getOr("")
  let touched = field.meta.touched
  let invalid = field.meta.invalid
  let isValid = if touched {
    Some(!invalid)
  } else {
    None
  }
  let errorString = if touched && invalid {
    field.meta.error->Option.getOr("")
  } else {
    ""
  }

  <PaymentInputField
    fieldName={label}
    value
    onChange={ev => {
      let val = ReactEvent.Form.target(ev)["value"]->String.replaceRegExp(%re("/\D|\s/g"), "")
      field.input.onChange(val)
    }}
    onBlur={_ev => field.input.onBlur()}
    isValid
    errorString
    placeholder
    inputRef={fieldRef}
    autocomplete="tel-national"
    ?maxLength
  />
}
