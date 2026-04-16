open RecoilAtoms

@react.component
let make = (~emailFields: array<SuperpositionTypes.fieldConfig>) => {
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

  let formEmailFields = emailFields->Array.map(fc =>
    ReactFinalForm.useField(
      fc.outputPath,
      ~config={
        validate: createValidator(Validation.Email),
      },
    )
  )

  let changeEmail = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    formEmailFields->Array.forEach(field => field.input.onChange(val))
  }

  switch formEmailFields->Array.get(0) {
  | Some(primaryField) =>
    let onBlur = (_) => {
      primaryField.input.onBlur()
    }
    let emailValue = primaryField.input.value->Option.getOr("")
    let errorString =
      primaryField.meta.touched ? primaryField.meta.error->Option.getOr("") : ""

    <RenderIf condition={showDetails.email == Auto}>
      <PaymentField
        fieldName=localeString.emailLabel
        value={
          value: emailValue,
          isValid: Some(primaryField.meta.valid),
          errorString,
        }
        onChange=changeEmail
        onBlur
        type_="email"
        inputRef=emailRef
        placeholder="Eg: johndoe@gmail.com"
        name=TestUtils.emailInputTestId
      />
    </RenderIf>
  | None => React.null
  }
}
