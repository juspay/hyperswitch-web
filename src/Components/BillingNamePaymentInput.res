open RecoilAtoms
open PaymentType

@react.component
let make = (
  ~name="billingName",
  ~customFieldName=None,
  ~requiredFields as _optionalRequiredFields=?,
) => {
  let {config, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)

  let showDetails = getShowDetails(~billingDetails=fields.billingDetails)

  let (placeholder, fieldName) = switch customFieldName {
  | Some(val) => (val, val)
  | None => (localeString.billingNamePlaceholder, localeString.billingNameLabel)
  }
  let nameRef = React.useRef(Nullable.null)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let field = ReactFinalForm.useField(
    name,
    ~config={validate: createValidator(Validation.Required)},
  )

  let billingNameValue = field.input.value->Option.getOr("")

  let changeName = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    field.input.onChange(val)
  }

  let onBlur = (_ev: JsxEventU.Focus.t) => {
    field.input.onBlur()
  }

  <RenderIf condition={showDetails.name == Auto}>
    <PaymentField
      fieldName
      value={
        RecoilAtomTypes.value: billingNameValue,
        isValid: Some(field.meta.valid),
        errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
      }
      onChange=changeName
      onBlur
      type_="text"
      inputRef=nameRef
      placeholder
      className={config.appearance.innerLayout === Spaced ? "" : "!border-b-0"}
      name=TestUtils.cardHolderNameInputTestId
    />
  </RenderIf>
}
