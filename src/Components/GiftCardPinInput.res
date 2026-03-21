@react.component
let make = (~name="giftCardPin") => {
  open RecoilAtoms

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let giftCardPinRef = React.useRef(Nullable.null)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let field: ReactFinalForm.Field.fieldProps = ReactFinalForm.useField(
    name,
    ~config={validate: createValidator(Validation.GiftCardPin)},
  )

  let giftCardPinValue = field.input.value->Option.getOr("")

  let changeGiftCardPin = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    field.input.onChange(val)
  }

  let onBlur = (_ev: JsxEventU.Focus.t) => {
    field.input.onBlur()
  }

  <PaymentField
    fieldName={localeString.giftCardPinLabel}
    setValue={_ => ()}
    value={
      RecoilAtomTypes.value: giftCardPinValue,
      isValid: Some(field.meta.valid),
      errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
    }
    onChange=changeGiftCardPin
    onBlur
    type_="text"
    name="giftCardPin"
    inputRef=giftCardPinRef
    placeholder={localeString.giftCardPinPlaceholder}
    maxLength=12
    paymentType=Payment
  />
}
