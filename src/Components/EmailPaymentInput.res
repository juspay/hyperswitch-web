open RecoilAtoms
open Utils

@react.component
let make = (~name="email") => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)

  let showDetails = PaymentType.getShowDetails(~billingDetails=fields.billingDetails)

  let emailRef = React.useRef(Nullable.null)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let field = ReactFinalForm.useField(name, ~config={validate: createValidator(Validation.Email)})

  let emailValue = field.input.value->Option.getOr("")

  let changeEmail = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    field.input.onChange(val)
  }

  let onBlur = (_ev: JsxEventU.Focus.t) => {
    field.input.onBlur()
  }

  <RenderIf condition={showDetails.email == Auto}>
    <PaymentField
      fieldName=localeString.emailLabel
      value={
        RecoilAtomTypes.value: emailValue,
        isValid: Some(field.meta.valid),
        errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
      }
      onChange=changeEmail
      onBlur
      type_="email"
      inputRef=emailRef
      placeholder="Eg: johndoe@gmail.com"
      name=TestUtils.emailInputTestId
    />
  </RenderIf>
}
