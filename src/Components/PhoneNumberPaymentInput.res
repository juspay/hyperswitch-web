@react.component
let make = () => {
  open RecoilAtoms
  open PaymentType
  open Utils

  let phoneRef = React.useRef(Nullable.null)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let showDetails = getShowDetails(~billingDetails=fields.billingDetails, ~logger=loggerState)
  let (phone, setPhone) = Recoil.useLoggedRecoilState(userPhoneNumber, "phone", loggerState)
  let clientCountry = getClientCountry(CardUtils.dateTimeFormat().resolvedOptions().timeZone)
  let currentCountryCode = Utils.getCountryCode(clientCountry.countryName)
  let (displayValue, setDisplayValue) = React.useState(_ => "")

  let countryAndCodeCodeList =
    phoneNumberJson
    ->JSON.Decode.object
    ->Option.getOr(Dict.make())
    ->getArray("countries")

  let phoneNumberCodeOptions: array<
    DropdownField.optionType,
  > = countryAndCodeCodeList->Array.reduce([], (acc, countryObj) => {
    let countryObjDict = countryObj->getDictFromJson
    let countryFlag = countryObjDict->getString("country_flag", "")
    let phoneNumberCode = countryObjDict->getString("phone_number_code", "")
    let countryName = countryObjDict->getString("country_name", "")

    let phoneNumberOptionsValue: DropdownField.optionType = {
      label: `${countryFlag} ${countryName} ${phoneNumberCode}`,
      displayValue: `${countryFlag} ${phoneNumberCode}`,
      value: `${countryFlag}#${phoneNumberCode}`,
    }
    acc->Array.push(phoneNumberOptionsValue)
    acc
  })

  let defaultCountryCodeFilteredValue =
    countryAndCodeCodeList
    ->Array.filter(countryObj => {
      countryObj->getDictFromJson->getString("country_code", "") === currentCountryCode.isoAlpha2
    })
    ->Array.get(0)
    ->Option.getOr(
      {
        "phone_number_code": "",
      }->Identity.anyTypeToJson,
    )
    ->getDictFromJson
    ->getString("phone_number_code", "")

  let (valueDropDown, setValueDropDown) = React.useState(_ => defaultCountryCodeFilteredValue)
  let getCountryCodeSplitValue = val => val->String.split("#")->Array.get(1)->Option.getOr("")

  let changePhone = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]->String.replaceRegExp(%re("/\D|\s/g"), "")
    setPhone(prev => {
      ...prev,
      countryCode: valueDropDown->getCountryCodeSplitValue,
      value: val,
    })
  }

  React.useEffect(() => {
    setPhone(prev => {
      ...prev,
      countryCode: valueDropDown->getCountryCodeSplitValue,
    })
    None
  }, [valueDropDown])

  React.useEffect(() => {
    let findDisplayValue =
      phoneNumberCodeOptions
      ->Array.find(ele => ele.value === valueDropDown)
      ->Option.getOr(DropdownField.defaultValue)
    setDisplayValue(_ =>
      findDisplayValue.displayValue->Option.getOr(
        findDisplayValue.label->Option.getOr(findDisplayValue.value),
      )
    )
    None
  }, [phoneNumberCodeOptions])

  <RenderIf condition={showDetails.phone == Auto}>
    <PaymentField
      fieldName="Phone Number"
      value=phone
      onChange=changePhone
      paymentType=Payment
      type_="tel"
      name="phone"
      inputRef=phoneRef
      placeholder="+351 200 000 000"
      maxLength=14
      dropDownOptions=phoneNumberCodeOptions
      valueDropDown
      setValueDropDown
      displayValue
      setDisplayValue
    />
  </RenderIf>
}
