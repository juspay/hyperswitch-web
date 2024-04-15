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
    let phoneNumberOptionsValue: DropdownField.optionType = {
      label: `${countryObjDict->getString("country_flag", "")} ${countryObjDict->getString(
          "country_name",
          "",
        )} ${countryObjDict->getString("phone_number_code", "")}`,
      displayValue: `${countryObjDict->getString("country_flag", "")} ${countryObjDict->getString(
          "phone_number_code",
          "",
        )}`,
      value: countryObjDict->getString("phone_number_code", ""),
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

  let changePhone = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]->String.replaceRegExp(%re("/\+D+/g"), "")
    setPhone(prev => {
      ...prev,
      countryCode: valueDropDown,
      value: val,
    })
  }

  React.useEffect(() => {
    setPhone(prev => {
      ...prev,
      countryCode: valueDropDown,
    })
    None
  }, [valueDropDown])

  React.useEffect(() => {
    let findDisplayValue =
      phoneNumberCodeOptions
      ->Array.find(ele => ele.value === valueDropDown)
      ->Option.getOr({
        label: "",
        value: "",
        displayValue: "",
      })
    setDisplayValue(_ => findDisplayValue.displayValue->Option.getOr(findDisplayValue.label))
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
