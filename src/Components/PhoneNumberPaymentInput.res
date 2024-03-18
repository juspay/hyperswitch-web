open RecoilAtoms
open PaymentType

@react.component
let make = () => {
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let (phone, setPhone) = Recoil.useLoggedRecoilState(userPhoneNumber, "phone", loggerState)

  let showDetails = getShowDetails(~billingDetails=fields.billingDetails, ~logger=loggerState)
  let formatBSB = bsb => {
    let formatted = bsb

    let secondPart = formatted->String.sliceToEnd(~start=4)->String.trim

    if formatted->String.length <= 4 {
      "+351 "
    } else if formatted->String.length > 4 {
      `+351 ${secondPart}`
    } else {
      formatted
    }
  }

  let changePhone = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]->String.replaceRegExp(%re("/\+D+/g"), "")
    setPhone(prev => {
      ...prev,
      value: val->formatBSB,
    })
  }

  let phoneRef = React.useRef(Nullable.null)

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
    />
  </RenderIf>
}
