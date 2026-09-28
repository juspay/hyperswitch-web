open SuperpositionTypes

let getPhoneCode = val => val->String.split("#")->Array.get(1)->Option.getOr("")

@react.component
let make = (~fieldConfig: fieldConfig, ~isLabelHidden=false) => {
  open Utils
  let {config, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let {label} = DynamicFieldsUtils.resolveFieldTexts(~field=fieldConfig, ~localeObject=localeString)
  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)

  let countryAndCodeList = React.useMemo0(() =>
    PhoneNumberUtils.phoneNumberJson
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

  let firstOptionValue =
    phoneNumberCodeOptions->Array.get(0)->Option.map(o => o.value)->Option.getOr("")
  let shopperCountryCode = defaultCountryCode()
  /*
   None means "no better answer than what is already selected" and must never collapse to
   entry 0 (Afghanistan +93). Two ways to get None: the country table has not landed, or the
   resolved country has no phone row - pre-existing, since Utils.getClientCountry takes the
   FIRST row whose timeZones contain the zone and 23 of 250 rows lack a phone row (Europe/Oslo
   resolves to BV rather than NO), but adopting on it would replace a shown code with +93.
   */
  let resolvedDropdownValue =
    countryAndCodeList
    ->Array.find(c => c->getDictFromJson->getString("country_code", "") === shopperCountryCode)
    ->Option.map(c => {
      let countryDict = c->getDictFromJson
      let flag = countryDict->getString("country_flag", "")
      let code = countryDict->getString("phone_number_code", "")
      `${flag}#${code}`
    })

  /*
   The value react-final-form registers the field with - it MUST be referentially stable.
   useField's registration effect is keyed on [name, data, defaultValue, initialValue]
   (react-final-form.cjs.js:661), so a changed initialValue re-runs registration and silently
   overwrites a code the shopper had already picked in the confirm body. resolvedDropdownValue
   changes when the country table lands, which is exactly that trap: freeze it here, and let
   later correction go through the onChange effect below.
   */
  let initialDropdownValue = React.useRef(resolvedDropdownValue->Option.getOr(firstOptionValue))
  let defaultCode = initialDropdownValue.current->getPhoneCode
  let field = ReactFinalForm.useField(
    fieldConfig.confirmRequestWritePath,
    ~config={validate, initialValue: Some(defaultCode)},
  )

  let (valueDropDown, setValueDropDown) = React.useState(_ => initialDropdownValue.current)
  let (displayValue, setDisplayValue) = React.useState(_ => "")

  /*
   This component can render once before defaultCountryCode() can resolve (countryDataRef is
   filled asynchronously), and the state above freezes entry 0 - Afghanistan +93, written
   straight into billing.phone.country_code. Adopt the real default the moment it resolves,
   only on a genuine match, and never over a code the shopper has picked.
   */
  let hasShopperPickedCode = React.useRef(false)

  React.useEffect(() => {
    switch resolvedDropdownValue {
    | Some(resolved) if !hasShopperPickedCode.current =>
      setValueDropDown(prev => prev === resolved ? prev : resolved)
    | _ => ()
    }
    None
  }, [resolvedDropdownValue])

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
    fieldName={label}
    isLabelHidden
    value=valueDropDown
    setValue={setter => {
      hasShopperPickedCode.current = true
      setValueDropDown(prev => setter(prev))
    }}
    disabled=false
    options=phoneNumberCodeOptions
    width="w-full min-w-24"
    displayValue
    setDisplayValue
    isDisplayValueVisible=true
  />
}
