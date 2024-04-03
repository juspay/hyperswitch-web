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

  let countryAndCodeCodeList =
    phoneNumberJson
    ->JSON.Decode.object
    ->Option.getOr(Dict.make())
    ->getArray("countries")

  let phoneNumberCodeOptions = countryAndCodeCodeList->Array.reduce([], (acc, countryObj) => {
    acc->Array.push(countryObj->getDictFromJson->getString("phone_number_code", ""))
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
        "country_code": "",
        "phone_number_code": "",
        "validation_regex": "",
        "format_example": "",
        "format_regex": "",
      }->toJson,
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
  }, valueDropDown)

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
    />
  </RenderIf>
}
