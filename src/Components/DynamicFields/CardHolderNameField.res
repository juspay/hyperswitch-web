open SuperpositionTypes

// "John Doe" -> ("John", "Doe")   "John" -> ("John", "")
let splitName = (value: string): (string, string) =>
  switch value->String.indexOf(" ") {
  | -1 => (value, "")
  | i => (value->String.substring(~start=0, ~end=i), value->String.substringToEnd(~start=i + 1))
  }

module FullNameFieldInput = {
  @react.component
  let make = (~firstNameFieldConfig: fieldConfig, ~lastNameFieldConfig: fieldConfig) => {
    let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

    let firstValidator = DynamicFieldsUtils.resolveValidator(
      ~field=firstNameFieldConfig,
      ~localeObject=localeString,
    )
    let lastValidator = DynamicFieldsUtils.resolveValidator(
      ~field=lastNameFieldConfig,
      ~localeObject=localeString,
    )

    let firstProps = ReactFinalForm.useField(
      firstNameFieldConfig.confirmRequestWritePath,
      ~config={validate: firstValidator},
    )
    let lastProps = ReactFinalForm.useField(
      lastNameFieldConfig.confirmRequestWritePath,
      ~config={validate: lastValidator},
    )

    let inputRef = React.useRef(Nullable.null)
    let (name, setName) = React.useState(() => {
      let first = firstProps.input.value->Option.getOr("")
      let last = lastProps.input.value->Option.getOr("")
      [first, last]->Array.filter(val => val !== "")->Array.join(" ")
    })

    let {label, placeholder} = DynamicFieldsUtils.resolveFieldTexts(
      ~field=firstNameFieldConfig,
      ~localeObject=localeString,
    )
    let autocomplete = firstNameFieldConfig.htmlAutocompleteAttribute

    let handleChange = event => {
      let value: string = ReactEvent.Form.target(event)["value"]
      setName(_ => value)
      let (firstName, lastName) = splitName(value)
      firstProps.input.onChange(firstName)
      lastProps.input.onChange(lastName)
    }

    let handleBlur = _event => {
      firstProps.input.onBlur()
      lastProps.input.onBlur()
    }

    let showError =
      firstProps.meta.touched ||
      firstProps.meta.submitFailed ||
      lastProps.meta.touched ||
      lastProps.meta.submitFailed
    let allValid = firstProps.meta.valid && lastProps.meta.valid
    let isValid = showError ? Some(allValid) : None
    let errorString =
      showError && !allValid
        ? firstProps.meta.error->Option.getOr(lastProps.meta.error->Option.getOr(""))
        : ""

    <PaymentInputField
      fieldName={label}
      value={name}
      onChange={handleChange}
      onBlur={handleBlur}
      isValid
      errorString
      placeholder
      inputRef
      ?autocomplete
    />
  }
}

@react.component
let make = (~fields: array<fieldConfig>) => {
  let firstNameField = fields->Array.get(0)
  let lastNameField = fields->Array.get(1)

  switch (firstNameField, lastNameField) {
  | (Some(firstNameFieldConfig), None) => <GenericInputField fieldConfig=firstNameFieldConfig />
  | (None, Some(lastNameFieldConfig)) => <GenericInputField fieldConfig=lastNameFieldConfig />
  | (Some(firstNameFieldConfig), Some(lastNameFieldConfig)) =>
    <FullNameFieldInput firstNameFieldConfig lastNameFieldConfig />
  | (_, _) => React.null
  }
}
