open RecoilAtoms
open Utils
open EmailValidation

@react.component
let make = () => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (email, setEmail) = Recoil.useRecoilState(userEmailAddress)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  let showDetails = PaymentType.getShowDetails(~billingDetails=fields.billingDetails)

  let emailRef = React.useRef(Nullable.null)

  let changeEmail = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setEmail(prev => {
      value: val,
      isValid: val->isEmailValid,
      errorString: val->isEmailValid->Option.getOr(false) ? "" : prev.errorString,
    })
  }
  let onBlur = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]
    setEmail(prev => {
      ...prev,
      isValid: val->isEmailValid,
    })
  }

  React.useEffect(() => {
    setEmail(prev => {
      ...prev,
      errorString: switch prev.isValid {
      | Some(val) => val ? "" : localeString.emailInvalidText
      | None => ""
      },
    })
    None
  }, [email.isValid])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if isGiftCardOnlyPayment {
        ()
      } else if email.value == "" {
        setEmail(prev => {
          ...prev,
          errorString: localeString.emailEmptyText,
        })
      }
    }
  }, (email, isGiftCardOnlyPayment))
  useSubmitPaymentData(submitCallback)

  <RenderIf condition={showDetails.email == Auto}>
    <PaymentField
      fieldName=localeString.emailLabel
      setValue={setEmail}
      value=email
      onChange=changeEmail
      onBlur
      type_="email"
      inputRef=emailRef
      placeholder="Eg: johndoe@gmail.com"
      name=TestUtils.emailInputTestId
    />
  </RenderIf>
}
