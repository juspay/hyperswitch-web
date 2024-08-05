open RecoilAtoms
open Utils

@react.component
let make = (~paymentType) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let (vpaId, setVpaId) = Recoil.useLoggedRecoilState(userVpaId, "vpaId", loggerState)

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
      if vpaId.value == "" {
        setVpaId(prev => {
          ...prev,
          errorString: localeString.vpaIdEmptyText,
        })
      }
    }
  }, [vpaId])
  useSubmitPaymentData(submitCallback)

  <PaymentField
    fieldName=localeString.vpaIdLabel
    setValue={setVpaId}
    value=vpaId
    onChange=changeVpaId
    onBlur
    paymentType
    type_="text"
    name="vpaId"
    inputRef=vpaIdRef
    placeholder="Eg: johndoe@upi"
  />
}
