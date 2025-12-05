open RecoilAtoms
open Utils

@react.component
let make = () => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (vpaId, setVpaId) = Recoil.useRecoilState(userVpaId)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  let vpaIdRef = React.useRef(Nullable.null)

  let changeVpaId = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setVpaId(prev => {
      value: val,
      isValid: val->isVpaIdValid,
      errorString: val->isVpaIdValid->Option.getOr(false) ? "" : prev.errorString,
    })
  }
  let onBlur = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]
    let isValid = val->isVpaIdValid
    let errorString = switch isValid {
    | Some(val) => val ? "" : localeString.vpaIdInvalidText
    | None => ""
    }

    setVpaId(prev => {
      ...prev,
      isValid,
      errorString,
    })
  }

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if isGiftCardOnlyPayment {
        ()
      } else if vpaId.value == "" {
        setVpaId(prev => {
          ...prev,
          errorString: localeString.vpaIdEmptyText,
        })
      }
    }
  }, (vpaId, isGiftCardOnlyPayment))
  useSubmitPaymentData(submitCallback)

  <PaymentField
    fieldName=localeString.vpaIdLabel
    setValue={setVpaId}
    value=vpaId
    onChange=changeVpaId
    onBlur
    type_="text"
    name="vpaId"
    inputRef=vpaIdRef
    placeholder="Eg: johndoe@upi"
  />
}
