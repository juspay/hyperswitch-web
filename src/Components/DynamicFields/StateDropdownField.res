open SuperpositionTypes

@react.component
let make = (~fieldConfig: fieldConfig) => {
  let {config, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let loggerState = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  let {label} = DynamicFieldsUtils.resolveFieldTexts(~field=fieldConfig, ~localeObject=localeString)
  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)

  let countryName = Jotai.useAtomValue(JotaiAtoms.userCountry)
  let countryIso = Utils.getCountryCode(countryName).isoAlpha2

  /*
   * `_dropdown_options` is the merchant's state allowlist; empty means no restriction.
   * When it matches no state of the selected country, fall back to the full list so the
   * field stays fillable.
   */
  let allowedStateCodes = fieldConfig.dropdownOptions->Option.getOr([])
  let allowedStateNames = Utils.getStateNamesForCountry(~countryIso, ~allowedStateCodes)
  let isAllowlistUnusable =
    allowedStateCodes->Array.length > 0 && allowedStateNames->Array.length === 0

  let stateDisplayNames = isAllowlistUnusable
    ? Utils.getStateNamesForCountry(~countryIso)
    : allowedStateNames
  let stateOptions = stateDisplayNames->DropdownField.updateArrayOfStringToOptionsTypeArray
  let hasStates = stateOptions->Array.length > 0

  React.useEffect(() => {
    if isAllowlistUnusable && hasStates {
      ErrorUtils.manageErrorWarning(
        SDK_CONNECTOR_WARNING,
        ~dynamicStr=`None of the configured state options [${allowedStateCodes->Array.join(
            ", ",
          )}] for '${fieldConfig.confirmRequestWritePath}' are valid states of country '${countryIso}'. Falling back to the complete state list.`,
        ~logger=loggerState,
      )
    }
    None
  }, (isAllowlistUnusable, hasStates, countryIso))

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
