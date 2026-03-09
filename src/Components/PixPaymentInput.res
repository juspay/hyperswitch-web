@react.component
let make = (~name: string, ~fieldType: string) => {
  open RecoilAtoms

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let inputRef = React.useRef(Nullable.null)

  let validatePixKey = (val): option<string> =>
    if val->String.length > 0 {
      None
    } else {
      Some(localeString.pixKeyEmptyText)
    }

  let validatePixCNPJ = (val): option<string> => {
    let isCNPJValid = %re("/^\d*$/")->RegExp.test(val) && val->String.length === 14
    if isCNPJValid {
      None
    } else if val->String.length === 0 {
      Some(localeString.pixCNPJEmptyText)
    } else {
      Some(localeString.pixCNPJInvalidText)
    }
  }

  let validatePixCPF = (val): option<string> => {
    let isCPFValid = %re("/^\d*$/")->RegExp.test(val) && val->String.length === 11
    if isCPFValid {
      None
    } else if val->String.length === 0 {
      Some(localeString.pixCPFEmptyText)
    } else {
      Some(localeString.pixCPFInvalidText)
    }
  }

  let (fieldName, placeholder, maxLength, validationFn) = switch fieldType {
  | "pixKey" => (localeString.pixKeyLabel, localeString.pixKeyPlaceholder, None, validatePixKey)
  | "pixCPF" => (localeString.pixCPFLabel, localeString.pixCPFPlaceholder, Some(11), validatePixCPF)
  | "pixCNPJ" => (
      localeString.pixCNPJLabel,
      localeString.pixCNPJPlaceholder,
      Some(14),
      validatePixCNPJ,
    )
  | _ => ("", "", None, _ => None)
  }

  let field: ReactFinalForm.fieldProps<ReactEvent.Focus.t> = ReactFinalForm.useField(
    name,
    ~config={
      validate: validationFn,
    },
  )

  let pixValue = field.input.value->Option.getOr("")

  let onChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    field.input.onChange(val)
  }

  let onBlur = ev => {
    field.input.onBlur(ev)
  }

  <PaymentField
    fieldName
    setValue={_ => ()}
    value={
      RecoilAtomTypes.value: pixValue,
      isValid: Some(field.meta.valid),
      errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
    }
    onChange
    onBlur
    type_=fieldType
    name=fieldType
    inputRef
    placeholder
    ?maxLength
    paymentType=Payment
  />
}
