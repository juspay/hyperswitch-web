@react.component
let make = () => {
  open DropdownField
  let currencyVal = Jotai.useAtomValue(JotaiAtoms.userCurrency)
  let {config, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let (cryptoCurrencyNetworks, setCryptoCurrencyNetworks) = Jotai.useAtom(
    JotaiAtoms.cryptoCurrencyNetworks,
  )

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

  React.useEffect(() => {
    setCryptoCurrencyNetworks(_ => initialValue)
    None
  }, [initialValue])

  <DropdownField
    appearance=config.appearance
    fieldName=localeString.currencyNetwork
    value=cryptoCurrencyNetworks
    setValue=setCryptoCurrencyNetworks
    disabled=false
    options=dropdownOptions
  />
}
