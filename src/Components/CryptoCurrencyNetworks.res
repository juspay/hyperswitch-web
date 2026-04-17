@react.component
let make = (~name: string, ~currencyFieldName: string) => {
  open DropdownField
  let {config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let currencyField = ReactFinalForm.useField(currencyFieldName)
  let currencyVal = currencyField.input.value->Option.getOr("")

  let dropdownOptions =
    Utils.currencyNetworksDict
    ->Dict.get(currencyVal)
    ->Option.getOr([])
    ->Array.map(item => {
      label: Utils.toSpacedUpperCase(~str=item, ~delimiter="_"),
      value: item,
    })

  let initialValue = (
    dropdownOptions
    ->Array.get(0)
    ->Option.getOr({
      label: "",
      value: "",
    })
  ).value

  let field = ReactFinalForm.useField(
    name,
    ~config={initialValue: initialValue->JSON.Encode.string}
  )

  let cryptoCurrencyNetworks = field.input.value->Option.getOr(initialValue)

  React.useEffect(() => {
    field.input.onChange(initialValue)
    None
  }, [initialValue])

  <DropdownField
    appearance=config.appearance
    fieldName=localeString.currencyNetwork
    value=cryptoCurrencyNetworks
    setValue={setter => {
      let newVal = setter(cryptoCurrencyNetworks)
      field.input.onChange(newVal)
    }}
    disabled=false
    options=dropdownOptions
  />
}
