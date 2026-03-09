open RecoilAtoms
open Utils

@react.component
let make = (~name: string) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let field: ReactFinalForm.fieldProps<ReactEvent.Focus.t> = ReactFinalForm.useField(
    name,
    ~config={
      validate: val => {
        let val = val->Option.getOr("")
        if val === "" {
          Some(localeString.vpaIdEmptyText)
        } else {
          let isValid = val->isVpaIdValid
          switch isValid {
          | Some(true) => None
          | Some(false) => Some(localeString.vpaIdInvalidText)
          | None => None
          }
        }
      },
    },
  )

  let vpaIdValue = field.input.value->Option.getOr("")
  let vpaIdRef = React.useRef(Nullable.null)

  let changeVpaId = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    field.input.onChange(val)
  }

  let onBlur = ev => {
    field.input.onBlur(ev)
  }

  <PaymentField
    fieldName=localeString.vpaIdLabel
    setValue={_ => ()}
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
