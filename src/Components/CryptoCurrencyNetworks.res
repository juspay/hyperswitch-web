@react.component
let make = () => {
  open DropdownField
  let currencyVal = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCurrency)
  let {config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let (cryptoCurrencyNetworks, setCryptoCurrencyNetworks) = Recoil.useRecoilState(
    RecoilAtoms.cryptoCurrencyNetworks,
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
    setValue={newValue => {
      LoggerUtils.logInputChangeInfo("cryptoCurrencyNetwork", loggerState)
      setCryptoCurrencyNetworks(newValue)
    }}
    disabled=false
    options=dropdownOptions
  />
}
