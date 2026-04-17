open RecoilAtoms
open PaymentType
open Utils

@react.component
let make = (~customFieldName=None) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let (fullName, setFullName) = Recoil.useRecoilState(userFullName)
  let showDetails = getShowDetails(~billingDetails=fields.billingDetails)

  let changeName = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setFullName(prev => validateName(val, prev, localeString))
  }

  let onBlur = ev => {
    let val: string = ReactEvent.Focus.target(ev)["value"]
    setFullName(prev => validateName(val, prev, localeString))
  }

  let (placeholder, fieldName) = switch customFieldName {
  | Some(val) => (val, val)
  | None => (localeString.fullNamePlaceholder, localeString.fullNameLabel)
  }

  let nameRef = React.useRef(Nullable.null)

  <RenderIf condition={showDetails.name == Auto}>
    <PaymentField
      fieldName
      setValue=setFullName
      value=fullName
      onChange=changeName
      onBlur
      type_="text"
      inputRef=nameRef
      placeholder
      name=TestUtils.fullNameInputTestId
    />
  </RenderIf>
}
