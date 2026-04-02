@react.component
let make = (~name: string, ~validationRule=?, ~render) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let field: ReactFinalForm.Field.fieldProps = switch validationRule {
  | Some(rule) => ReactFinalForm.useField(name, ~config={validate: createValidator(rule)})
  | None => ReactFinalForm.useField(name)
  }

  render(field)
}
