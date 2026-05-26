open SuperpositionTypes

@react.component
let make = (~fieldConfig: fieldConfig, ~options: array<DropdownField.optionType>) => {
  let {config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label} = DynamicFieldsUtils.resolveFieldTexts(~field=fieldConfig, ~localeObject=localeString)
  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)
  let defaultCountry = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let firstOption = options->Array.get(0)->Option.map(opt => opt.value)->Option.getOr("")
  let initialCountry = defaultCountry !== "" ? defaultCountry : firstOption
  let initialIso = Utils.getCountryCode(initialCountry).isoAlpha2

  let field = ReactFinalForm.useField(
    fieldConfig.confirmRequestWritePath,
    ~config={validate, initialValue: Some(initialIso)},
  )

  let (country, setCountry) = Recoil.useRecoilState(RecoilAtoms.userCountry)

  <DropdownField
    appearance={config.appearance}
    fieldName={label}
    value={country}
    setValue={setter => {
      let newVal = setter(field.input.value->Option.getOr(country))
      setCountry(_ => newVal)
      let countryIso = Utils.getCountryCode(newVal).isoAlpha2
      field.input.onChange(countryIso)
    }}
    disabled=false
    options
  />
}
