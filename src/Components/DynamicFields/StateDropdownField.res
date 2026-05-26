open SuperpositionTypes

@react.component
let make = (
  ~field: fieldConfig,
  ~countryFieldPath: string,
) => {
  let {config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label} = DynamicFieldsUtils.resolveFieldTexts(~field, ~localeObject=localeString)
  let validate =
    DynamicFieldsUtils.resolveValidator(~field, ~localeObject=localeString)
  let defaultCountryIso = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let countryFieldProps = ReactFinalForm.useField(countryFieldPath)
  let rffCountryIso = countryFieldProps.input.value->Option.getOr("")
  let countryIso = if rffCountryIso !== "" { rffCountryIso } else { defaultCountryIso }
  let countryDisplayName = Utils.getCountryNameFromCode(countryIso)

  let stateDisplayNames =
    Utils.getStateNames({value: countryDisplayName, isValid: None, errorString: ""})

  let stateOptions = stateDisplayNames->DropdownField.updateArrayOfStringToOptionsTypeArray
  let field = ReactFinalForm.useField(field.confirmRequestWritePath, ~config={validate: validate})
  let storedCode = field.input.value->Option.getOr("")

  if stateOptions->Array.length === 0 {
    React.null
  } else {
    let displayName = Utils.getStateNameFromCode(storedCode, countryIso)
    let effectiveDisplayName =
      displayName !== "" ? displayName : stateDisplayNames->Array.get(0)->Option.getOr("")

    <DropdownField
      appearance={config.appearance}
      fieldName={label}
      value={effectiveDisplayName}
      setValue={fn => {
        let selectedDisplayName = fn(effectiveDisplayName)
        let stateCode = Utils.getStateCodeFromStateName(selectedDisplayName, countryIso)
        field.input.onChange(stateCode)
      }}
      disabled=false
      options={stateOptions}
    />
  }
}
