@react.component
let make = (~name: string, ~options: array<string>) => {
  let {config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let dropdownOptions = options->DropdownField.updateArrayOfStringToOptionsTypeArray
  let initialValue = options->Array.get(0)->Option.getOr("")

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let field = ReactFinalForm.useField(
    name,
    ~config={
      initialValue: Some(initialValue),
      validate: createValidator(Validation.Required)
    },
  )

  let selectedCurrency = field.input.value->Option.getOr(initialValue)

  React.useEffect(() => {
    if selectedCurrency === "" || !(options->Array.includes(selectedCurrency)) {
      field.input.onChange(initialValue)
    }
    None
  }, (initialValue, selectedCurrency, options))

  <DropdownField
    appearance=config.appearance
    fieldName=localeString.currencyLabel
    value=selectedCurrency
    setValue={setter => {
      let newVal = setter(selectedCurrency)
      field.input.onChange(newVal)
    }}
    disabled=false
    options=dropdownOptions
  />
}
