open SuperpositionTypes

@react.component
let make = (~fieldConfig: fieldConfig, ~options: array<DropdownField.optionType>) => {
  let {config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label} = DynamicFieldsUtils.resolveFieldTexts(~field=fieldConfig, ~localeObject=localeString)
  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)
  let initialValue = options->Array.get(0)->Option.map(opt => opt.value)->Option.getOr("")

  let field = ReactFinalForm.useField(
    fieldConfig.confirmRequestWritePath,
    ~config={validate, initialValue: Some(initialValue)},
  )
  let value = field.input.value->Option.getOr(initialValue)

  <DropdownField
    appearance={config.appearance}
    fieldName={label}
    value
    setValue={fn => field.input.onChange(fn(value))}
    disabled=false
    options
    isRequired={fieldConfig.isRequired}
  />
}
