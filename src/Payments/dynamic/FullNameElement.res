open SuperpositionTypes
open Validation

module FullNameField = {
  @react.component
  let make = (~firstNameConfig, ~lastNameConfig) => {
    let inputRef = React.useRef(Nullable.null)
    let (fullname, setFullname) = React.useState(_ => "")
    let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let createFieldValidator = rule =>
      createFieldValidator(rule, ~enabledCardSchemes=[], ~localeObject=LocaleDataType.defaultLocale)

    let {input: firstNameInput, meta: firstNameMeta} = ReactFinalForm.useField(
      firstNameConfig.outputPath,
      ~config={
        initialValue: Some(""),
        validate: createFieldValidator(FirstName),
      },
    )
    let {input: lastNameInput, meta: lastNameMeta} = ReactFinalForm.useField(
      lastNameConfig.outputPath,
      ~config={
        initialValue: Some(""),
        validate: createFieldValidator(LastName),
      },
    )

    let handleChange = ev => {
      let val: string = ReactEvent.Form.target(ev)["value"]
      setFullname(_ => val)
      let (firstNameVal, lastNameVal) = switch val->String.trim {
      | "" => (None, None)
      | fullName => {
          let names = fullName->String.split(" ")->Array.filter(name => name->String.trim !== "")
          switch names->Array.length {
          | 0 => (None, None)
          | 1 => (Some(names[0]->Option.getOr("")), None)
          | _ => {
              let firstName = names[0]->Option.getOr("")
              let lastName = names->Array.sliceToEnd(~start=1)->Array.join(" ")
              (Some(firstName), Some(lastName))
            }
          }
        }
      }
      firstNameInput.onChange(firstNameVal->Option.getOr(""))
      lastNameInput.onChange(lastNameVal->Option.getOr(""))
    }

    <PaymentField
      fieldName=localeString.fullNameLabel
      setValue={_ => ()}
      value={
        value: fullname,
        isValid: Some(true),
        errorString: "",
      }
      onChange={handleChange}
      onBlur={firstNameInput.onBlur}
      onFocus={firstNameInput.onFocus}
      type_="text"
      inputRef
      placeholder=localeString.fullNamePlaceholder
      name=TestUtils.fullNameInputTestId
    />
  }
}

@react.component
let make = (~fields: array<fieldConfig>) => {
  if fields->Array.length == 3 {
    switch fields {
    | [firstNameConfig, lastNameConfig] => <FullNameField firstNameConfig lastNameConfig />
    | _ => React.null
    }
  } else {
    fields
    ->Array.map(field => {
      <DynamicInputFields key={field.outputPath} field />
    })
    ->React.array
  }
}
