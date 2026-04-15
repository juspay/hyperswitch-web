open RecoilAtoms
open Utils

@react.component
let make = (~name: string) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let field = ReactFinalForm.useField(name, ~config={validate: createValidator(Validation.VpaId)})

  let vpaIdValue = field.input.value->Option.getOr("")
  let vpaIdRef = React.useRef(Nullable.null)

  let changeVpaId = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    field.input.onChange(val)
  }

  let onBlur = (_ev: JsxEventU.Focus.t) => {
    field.input.onBlur()
  }

  <PaymentField
    fieldName=localeString.vpaIdLabel
    value={
      RecoilAtomTypes.value: vpaIdValue,
      isValid: Some(field.meta.valid),
      errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
    }
    onChange=changeVpaId
    onBlur
    type_="text"
    name="vpaId"
    inputRef=vpaIdRef
    placeholder="Eg: johndoe@upi"
  />
}
