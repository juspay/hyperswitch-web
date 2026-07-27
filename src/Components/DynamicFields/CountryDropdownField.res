open SuperpositionTypes

@react.component
let make = (~fieldConfig: fieldConfig, ~options: array<DropdownField.optionType>) => {
  let {config, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let {label} = DynamicFieldsUtils.resolveFieldTexts(~field=fieldConfig, ~localeObject=localeString)
  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)
  let (countryName, setCountryName) = Jotai.useAtom(JotaiAtoms.userCountry)

  let firstCountryName = options->Array.get(0)->Option.map(opt => opt.value)->Option.getOr("")
  let defaultCountryName = countryName !== "" ? countryName : firstCountryName
  let defaultIso = Utils.getCountryCode(defaultCountryName).isoAlpha2
  let defaultIsoRef = React.useRef(defaultIso)

  let field = ReactFinalForm.useField(
    fieldConfig.confirmRequestWritePath,
    ~config={validate, defaultValue: Some(defaultIsoRef.current)},
  )

  let storedIso = field.input.value->Option.getOr("")
  let effectiveCountryName =
    storedIso !== "" ? Utils.getCountryNameFromCode(storedIso) : defaultCountryName

  React.useEffect(() => {
    if effectiveCountryName !== "" && countryName !== effectiveCountryName {
      setCountryName(_ => effectiveCountryName)
    }
    None
  }, [effectiveCountryName, countryName])

  <DropdownField
    appearance={config.appearance}
    fieldName={label}
    value={effectiveCountryName}
    setValue={setter => {
      let selectedCountryName = setter(effectiveCountryName)
      setCountryName(_ => selectedCountryName)
      let selectedIso = Utils.getCountryCode(selectedCountryName).isoAlpha2
      field.input.onChange(selectedIso)
    }}
    disabled=false
    options
  />
}
