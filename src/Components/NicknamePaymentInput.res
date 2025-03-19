@react.component
let make = (~paymentType: CardThemeType.mode, ~nickNameValue="") => {
  open RecoilAtoms
  open Utils

  let (nickName, setNickName) = Recoil.useRecoilState(userCardNickName)
  let showAddScreen = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.showAddScreen)
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  let validateNickname = val => {
    let isValid = Some(val === "" || !(val->isDigitLimitExceeded(~digit=2)))
    let errorString =
      val !== "" && val->isDigitLimitExceeded(~digit=2) ? localeString.invalidNickNameError : ""

    (isValid, errorString)
  }

  let setNickNameState = (val, prevState: RecoilAtomTypes.field) => {
    let (isValid, errorString) = val->validateNickname
    {
      ...prevState,
      value: val,
      isValid,
      errorString,
    }
  }

  React.useEffect(() => {
    setNickName(prev => setNickNameState(nickNameValue, prev))

    None
  }, [])

  let onChange = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setNickName(prev => setNickNameState(val, prev))
  }

  let onBlur = ev => {
    let val: string = ReactEvent.Focus.target(ev)["value"]
    setNickName(prev => setNickNameState(val, prev))
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
