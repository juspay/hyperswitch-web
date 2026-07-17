open SuperpositionTypes

@react.component
let make = (~fieldConfig: fieldConfig) => {
  let {config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label} = DynamicFieldsUtils.resolveFieldTexts(~field=fieldConfig, ~localeObject=localeString)
  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)

  let countryName = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let countryIso = Utils.getCountryCode(countryName).isoAlpha2

  let stateDisplayNames = Utils.getStateNames({
    value: countryName,
    isValid: None,
    errorString: "",
  })
  let stateOptions = stateDisplayNames->DropdownField.updateArrayOfStringToOptionsTypeArray
  let hasStates = stateOptions->Array.length > 0

  let stateField = ReactFinalForm.useField(
    fieldConfig.confirmRequestWritePath,
    ~config={validate: validate},
  )
  let storedCode = stateField.input.value->Option.getOr("")
  let storedDisplayName = Utils.getStateNameFromCode(storedCode, countryIso)
  let isStoredCodeValidForCountry = stateDisplayNames->Array.includes(storedDisplayName)
  let firstStateName = stateDisplayNames->Array.get(0)->Option.getOr("")
  let effectiveDisplayName = isStoredCodeValidForCountry ? storedDisplayName : firstStateName
  let effectiveCode = Utils.getStateCodeFromStateName(effectiveDisplayName, countryIso)

  React.useEffect(() => {
    if hasStates && storedCode !== effectiveCode {
      stateField.input.onChange(effectiveCode)
    }
    None
  }, (hasStates, storedCode, effectiveCode))

  <RenderIf condition={hasStates}>
    <DropdownField
      appearance={config.appearance}
      fieldName={label}
      value={effectiveDisplayName}
      setValue={fn => {
        let selectedDisplayName = fn(effectiveDisplayName)
        let stateCode = Utils.getStateCodeFromStateName(selectedDisplayName, countryIso)
        stateField.input.onChange(stateCode)
      }}
      disabled=false
      options={stateOptions}
    />
  </RenderIf>
}
