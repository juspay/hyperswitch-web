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

    let secondPart = formatted->Js.String2.sliceToEnd(~from=4)->Js.String2.trim

    if formatted->Js.String2.length <= 4 {
      "+351 "
    } else if formatted->Js.String2.length > 4 {
      `+351 ${secondPart}`
    } else {
      formatted
    }
  }

  let changePhone = ev => {
    let val: string =
      ReactEvent.Form.target(ev)["value"]->Js.String2.replaceByRe(%re("/\+D+/g"), "")
    setPhone(.prev => {
      ...prev,
      value: val->formatBSB,
    })
  }

  let phoneRef = React.useRef(Js.Nullable.null)

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
