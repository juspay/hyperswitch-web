open RecoilAtoms
open PaymentType
open Utils

@react.component
let make = (~paymentType) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let (email, setEmail) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)

  let showDetails = getShowDetails(~billingDetails=fields.billingDetails, ~logger=loggerState)

  let emailRef = React.useRef(Js.Nullable.null)

  let changeEmail = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setEmail(.prev => {
      ...prev,
      value: val,
    })
  }
  let onBlur = _ => {
    Utils.checkEmailValid(email, setEmail)
  }

  React.useEffect1(() => {
    setEmail(.prev => {
      ...prev,
      errorString: switch prev.isValid {
      | Some(val) => val ? "" : "Invalid email address"
      | None => ""
      },
    })
    None
  }, [email.isValid])

  let submitCallback = React.useCallback1((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if email.value == "" {
        setEmail(.prev => {
          ...prev,
          errorString: "Email cannot be empty",
        })
      }
    }
  }, [email])
  submitPaymentData(submitCallback)

  <RenderIf condition={showDetails.email == Auto}>
    <PaymentField
      fieldName=localeString.emailLabel
      setValue={setEmail}
      value=email
      onChange=changeEmail
      onBlur
      paymentType
      type_="email"
      name="email"
      inputRef=emailRef
      placeholder="Eg: johndoe@gmail.com"
    />
  </RenderIf>
}
