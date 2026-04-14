@react.component
let make = (~name: string, ~fieldType: string) => {
  open RecoilAtoms

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let inputRef = React.useRef(Nullable.null)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let (fieldName, placeholder, maxLength, validationRule) = switch fieldType {
  | "pixKey" => (localeString.pixKeyLabel, localeString.pixKeyPlaceholder, None, Validation.PixKey)
  | "pixCPF" => (
      localeString.pixCPFLabel,
      localeString.pixCPFPlaceholder,
      Some(11),
      Validation.PixCPF,
    )
  | "pixCNPJ" => (
      localeString.pixCNPJLabel,
      localeString.pixCNPJPlaceholder,
      Some(14),
      Validation.PixCNPJ,
    )
  | _ => ("", "", None, Validation.Required)
  }

  let field = ReactFinalForm.useField(
    name,
    ~config={validate: createValidator(validationRule)},
  )

  let pixValue = field.input.value->Option.getOr("")

  let onChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]

    let transformedVal = switch fieldType {
    // Transforming to uppercase to allow lowercase input to reduce friction, as CNPJ can contain letters (when formatted with punctuation)
    | "pixCNPJ" => val->String.toUpperCase
    | "pixCPF" => val->CardValidations.clearSpaces
    | _ => val
    }
    field.input.onChange(transformedVal)
  }

  let onBlur = (_ev: JsxEventU.Focus.t) => {
    field.input.onBlur()
  }

  <PaymentField
    fieldName
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
