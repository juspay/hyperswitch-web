open SuperpositionTypes

let getPhoneCode = val => val->String.split("#")->Array.get(1)->Option.getOr("")

@react.component
let make = (~fieldConfig: fieldConfig, ~hideLabel=false) => {
  open Utils
  let {config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label} = DynamicFieldsUtils.resolveFieldTexts(~field=fieldConfig, ~localeObject=localeString)
  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)

  let countryAndCodeList = React.useMemo0(() =>
    phoneNumberJson
    ->getDictFromJson
    ->getArray("countries")
  )

  let phoneNumberCodeOptions: array<DropdownField.optionType> = React.useMemo0(() =>
    countryAndCodeList->Array.reduce([], (acc, countryObj) => {
      let countryDict = countryObj->getDictFromJson
      let flag = countryDict->getString("country_flag", "")
      let code = countryDict->getString("phone_number_code", "")
      let name = countryDict->getString("country_name", "")
      let opt: DropdownField.optionType = {
        label: `${flag} ${name} ${code}`,
        displayValue: `${flag} ${code}`,
        value: `${flag}#${code}`,
      }
      acc->Array.push(opt)
      acc
    })
  )

  let defaultCountry = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let firstOptionValue =
    phoneNumberCodeOptions->Array.get(0)->Option.map(o => o.value)->Option.getOr("")
  let seedCountry = defaultCountry !== "" ? defaultCountry : firstOptionValue
  let seedIso = getCountryCode(seedCountry).isoAlpha2

  let defaultDropdownValue =
    countryAndCodeList
    ->Array.find(c => c->getDictFromJson->getString("country_code", "") === seedIso)
    ->Option.map(c => {
      let countryDict = c->getDictFromJson
      let flag = countryDict->getString("country_flag", "")
      let code = countryDict->getString("phone_number_code", "")
      `${flag}#${code}`
    })
    ->Option.getOr(firstOptionValue)

  let defaultCode = defaultDropdownValue->getPhoneCode
  let field = ReactFinalForm.useField(
    fieldConfig.confirmRequestWritePath,
    ~config={validate, initialValue: Some(defaultCode)},
  )

  let (valueDropDown, setValueDropDown) = React.useState(_ => defaultDropdownValue)
  let (displayValue, setDisplayValue) = React.useState(_ => "")

  React.useEffect(() => {
    let found =
      phoneNumberCodeOptions
      ->Array.find(ele => ele.value === valueDropDown)
      ->Option.getOr(DropdownField.defaultValue)
    setDisplayValue(_ => found.displayValue->Option.getOr(found.label->Option.getOr(found.value)))
    None
  }, (phoneNumberCodeOptions, valueDropDown))

  React.useEffect(() => {
    field.input.onChange(valueDropDown->getPhoneCode)
    None
  }, [valueDropDown])

  <DropdownField
    appearance={config.appearance}
    fieldName={hideLabel ? "" : label}
    value=valueDropDown
    setValue={setter => setValueDropDown(prev => setter(prev))}
    disabled=false
    options=phoneNumberCodeOptions
    width="w-full min-w-24"
    displayValue
    setDisplayValue
    isDisplayValueVisible=true
  />
}
