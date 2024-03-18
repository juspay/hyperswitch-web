@react.component
let make = (~paymentType: CardThemeType.mode, ~value, ~setValue) => {
  let {config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let onChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    setValue(_ => val)
  }

  <PaymentInputField
    fieldName=localeString.nicknameLabel
    value
    onChange
    paymentType
    appearance=config.appearance
    inputRef={React.useRef(Js.Nullable.null)}
    placeholder=localeString.nicknamePlaceholder
  />
}
