@react.component
let make = (~name="giftCardNumber") => {
  open RecoilAtoms

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let giftCardNumberRef = React.useRef(Nullable.null)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let field: ReactFinalForm.Field.fieldProps = ReactFinalForm.useField(
    name,
    ~config={validate: createValidator(Validation.GiftCardNumber)},
  )

  let giftCardNumberValue = field.input.value->Option.getOr("")

  let changeGiftCardNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    field.input.onChange(val)
  }

  let onBlur = (_ev: JsxEventU.Focus.t) => {
    field.input.onBlur()
  }

  <PaymentField
    fieldName={localeString.giftCardNumberLabel}
    setValue={_ => ()}
    value={
      RecoilAtomTypes.value: giftCardNumberValue,
      isValid: Some(field.meta.valid),
      errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
    }
    onChange=changeGiftCardNumber
    onBlur
    type_="text"
    name="giftCardNumber"
    inputRef=giftCardNumberRef
    placeholder={localeString.giftCardNumberPlaceholder}
    maxLength=32
    paymentType=Payment
  />
}
