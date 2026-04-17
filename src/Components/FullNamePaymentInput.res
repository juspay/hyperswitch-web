open RecoilAtoms
open PaymentType

@react.component
let make = (~customFieldName, ~firstNamePath, ~lastNamePath) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)

  let (placeholder, fieldName) = switch customFieldName {
  | Some(val) => (val, val)
  | None => (localeString.fullNamePlaceholder, localeString.fullNameLabel)
  }

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let showDetails = getShowDetails(~billingDetails=fields.billingDetails)

  let firstField = ReactFinalForm.useField(
    firstNamePath,
    ~config={
      validate: createValidator(Validation.FirstName),
    },
  )
  let lastField = ReactFinalForm.useField(
    lastNamePath,
    ~config={
      validate: createValidator(Validation.LastName),
    },
  )

  // Local state: the combined display value shown in the single <input>.
  let (inputValue, setInputValue) = React.useState(() => "")

  let handleChange = ev => {
    let value: string = ReactEvent.Form.target(ev)["value"]
    setInputValue(_ => value)
    let spaceIndex = value->String.indexOf(" ")
    if spaceIndex === -1 {
      firstField.input.onChange(value)
      lastField.input.onChange("")
    } else {
      let firstName = value->String.substring(~start=0, ~end=spaceIndex)
      let lastName = value->String.substringToEnd(~start=spaceIndex + 1)
      firstField.input.onChange(firstName)
      lastField.input.onChange(lastName)
    }
  }

  let onBlur = (_ev: JsxEventU.Focus.t) => {
    firstField.input.onBlur()
    lastField.input.onBlur()
  }

  let nameRef = React.useRef(Nullable.null)

  let errorString = if (
    (firstField.meta.touched && !firstField.meta.active) ||
      (lastField.meta.touched && !lastField.meta.active)
  ) {
    switch (firstField.meta.error, lastField.meta.error) {
    | (Some(err), _) => err
    | (_, Some(err)) => err
    | _ => ""
    }
  } else {
    ""
  }

  let isValid =
    firstField.meta.valid &&
    (lastField.meta.valid || !lastField.meta.touched || lastField.meta.active)

  <RenderIf condition={showDetails.name == Auto}>
    <PaymentField
      fieldName
      value={
        value: inputValue,
        isValid: Some(isValid),
        errorString,
      }
      onChange=handleChange
      onBlur
      type_="text"
      inputRef=nameRef
      placeholder
      name=TestUtils.fullNameInputTestId
    />
  </RenderIf>
}
