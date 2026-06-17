open SuperpositionTypes

@react.component
let make = (~fieldConfig: fieldConfig, ~paymentMethodType: string) => {
  let {config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label} = DynamicFieldsUtils.resolveFieldTexts(~field=fieldConfig, ~localeObject=localeString)
  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)

  let options = Bank.getBanks(paymentMethodType)->Array.map(bank => {
    DropdownField.value: bank.value,
    label: bank.displayName,
  })

  let initialValue = options->Array.get(0)->Option.map(opt => opt.value)->Option.getOr("")

  let field = ReactFinalForm.useField(
    fieldConfig.confirmRequestWritePath,
    ~config={validate, initialValue: Some(initialValue)},
  )
  let value = field.input.value->Option.getOr(initialValue)

  <RenderIf condition={options->Array.length > 0}>
    <DropdownField
      appearance={config.appearance}
      fieldName={label}
      value
      setValue={fn => field.input.onChange(fn(value))}
      disabled=false
      options
    />
  </RenderIf>
}
