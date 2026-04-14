@react.component
let make = (~name="userCardNickName") => {
  open RecoilAtoms

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let field = ReactFinalForm.useField(
    name,
    ~config={validate: createValidator(Validation.Nickname)},
  )

  let nickNameValue = field.input.value->Option.getOr("")

  let onChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    field.input.onChange(val)
  }

  let onBlur = (_ev: JsxEventU.Focus.t) => {
    field.input.onBlur()
  }

  <PaymentField
    fieldName=localeString.cardNickname
    value={
      RecoilAtomTypes.value: nickNameValue,
      isValid: Some(field.meta.valid),
      errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
    }
    onChange
    onBlur
    type_="userCardNickName"
    name="userCardNickName"
    inputRef={React.useRef(Nullable.null)}
    placeholder=localeString.nicknamePlaceholder
    maxLength=12
  />
}
