open SuperpositionTypes

@react.component
let make = (~firstNameField: fieldConfig, ~lastNameField: fieldConfig) => {
  let fieldRef = React.useRef(Nullable.null)
  let firstNamePath = firstNameField.confirmRequestWritePath
  let lastNamePath = lastNameField.confirmRequestWritePath
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label, placeholder} = DynamicFieldsUtils.resolveFieldTexts(
    ~field=firstNameField,
    ~localeObject=localeString,
  )

  let firstValidator = DynamicFieldsUtils.resolveValidator(
    ~field=firstNameField,
    ~localeObject=localeString,
  )
  let lastValidator = DynamicFieldsUtils.resolveValidator(
    ~field=lastNameField,
    ~localeObject=localeString,
  )

  let firstField = ReactFinalForm.useField(firstNamePath, ~config={validate: firstValidator})
  let lastField = ReactFinalForm.useField(lastNamePath, ~config={validate: lastValidator})

  let (inputValue, setInputValue) = React.useState(_ => "")

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

  <PaymentInputField
    fieldName={label}
    value={inputValue}
    onChange={handleChange}
    onBlur={_ev => {
      firstField.input.onBlur()
      lastField.input.onBlur()
    }}
    isValid={Some(isValid)}
    errorString
    placeholder
    inputRef={fieldRef}
    autocomplete="cc-name"
  />
}
