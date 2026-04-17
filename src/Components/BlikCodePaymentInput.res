open RecoilAtoms

@react.component
let make = (~name="blikCode") => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  let blikCodeRef = React.useRef(Nullable.null)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let formatBSB = bsb => {
    let formatted = bsb->String.replaceRegExp(%re("/\D+/g"), "")
    let firstPart = formatted->String.slice(~start=0, ~end=3)
    let secondPart = formatted->String.slice(~start=3, ~end=6)

    if formatted->String.length <= 3 {
      firstPart
    } else if formatted->String.length > 3 && formatted->String.length <= 6 {
      `${firstPart}-${secondPart}`
    } else {
      formatted
    }
  }

  let field = ReactFinalForm.useField(
    name,
    ~config={validate: createValidator(Validation.BlikCode)},
  )

  let blikValue = field.input.value->Option.getOr("")

  let changeblikCode = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    field.input.onChange(val->formatBSB)
  }

  let onBlur = (_ev: JsxEventU.Focus.t) => {
    field.input.onBlur()
  }

  <RenderIf condition={true}>
    <PaymentField
      fieldName="Blik code"
      value={
        RecoilAtomTypes.value: blikValue,
        isValid: Some(field.meta.valid),
        errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
      }
      onChange=changeblikCode
      onBlur
      paymentType=Payment
      type_="blikCode"
      name="blikCode"
      inputRef=blikCodeRef
      placeholder="000 000"
      maxLength=7
    />
  </RenderIf>
}
