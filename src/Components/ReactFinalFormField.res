@react.component
let make = (~name: string, ~validationRule=?, ~initialValue="", ~render) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let hasInitialValue = initialValue !== ""

  let field: ReactFinalForm.Field.fieldProps = switch (validationRule, hasInitialValue) {
  | (Some(rule), true) =>
    ReactFinalForm.useField(
      name,
      ~config={validate: createValidator(rule), initialValue: Some(initialValue)},
    )
  | (Some(rule), false) =>
    ReactFinalForm.useField(name, ~config={validate: createValidator(rule)})
  | (None, true) =>
    ReactFinalForm.useField(name, ~config={initialValue: Some(initialValue)})
  | (None, false) => ReactFinalForm.useField(name)
  }

  render(field)
}
