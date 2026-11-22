open SuperpositionTypes

@react.component
let make = (~networkField: fieldConfig, ~currencyField: fieldConfig) => {
  let networkPath = networkField.confirmRequestWritePath
  let currencyFieldPath = currencyField.confirmRequestWritePath
  let {config, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let {label} = DynamicFieldsUtils.resolveFieldTexts(
    ~field=networkField,
    ~localeObject=localeString,
  )
  let validate = DynamicFieldsUtils.resolveValidator(
    ~field=networkField,
    ~localeObject=localeString,
  )

  let currencyFieldProps = ReactFinalForm.useField(currencyFieldPath)
  let currencyVal = currencyFieldProps.input.value->Option.getOr("")

  let dropdownOptions =
    Utils.currencyNetworksDict
    ->Dict.get(currencyVal)
    ->Option.getOr([])
    ->Array.map((item): DropdownField.optionType => {
      {
        label: Utils.toSpacedUpperCase(~str=item, ~delimiter="_"),
        value: item,
      }
    })

  let initialNetwork = dropdownOptions->Array.get(0)->Option.map(opt => opt.value)->Option.getOr("")

  let field = ReactFinalForm.useField(
    networkPath,
    ~config={validate, initialValue: Some(initialNetwork)},
  )

  React.useEffect(() => {
    if initialNetwork !== "" {
      field.input.onChange(initialNetwork)
    }
    None
  }, [initialNetwork])

  let value = field.input.value->Option.getOr(initialNetwork)

  <DropdownField
    appearance=config.appearance
    fieldName={label}
    value
    setValue={setter => field.input.onChange(setter(value))}
    disabled=false
    options=dropdownOptions
  />
}
