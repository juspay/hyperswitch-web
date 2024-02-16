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
      value: val,
      isValid: val->Utils.isEmailValid,
      errorString: val->Utils.isEmailValid->Belt.Option.getWithDefault(false)
        ? ""
        : prev.errorString,
    })
  }
  let onBlur = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]
    setEmail(.prev => {
      ...prev,
      isValid: val->Utils.isEmailValid,
    })
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
