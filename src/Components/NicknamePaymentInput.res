@react.component
let make = (~paymentType: CardThemeType.mode, ~nickNameValue="") => {
  open RecoilAtoms
  open Utils

  let (nickName, setNickName) = Recoil.useRecoilState(userCardNickName)
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  let onChange = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setNickName(prev => setNickNameState(val, prev, localeString))
  }

  let onBlur = ev => {
    let val: string = ReactEvent.Focus.target(ev)["value"]
    setNickName(prev => setNickNameState(val, prev, localeString))
  }

  <PaymentField
    fieldName=localeString.cardNickname
    value=nickName
    setValue=setNickName
    onChange
    onBlur
    paymentType
    type_="userCardNickName"
    name="userCardNickName"
    inputRef={React.useRef(Nullable.null)}
    placeholder=localeString.nicknamePlaceholder
    maxLength=12
  />
}
