@react.component
let make = () => {
  open RecoilAtoms
  open Utils

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (giftCardNumber, setGiftCardNumber) = Recoil.useRecoilState(userGiftCardNumber)
  let giftCardNumberRef = React.useRef(Nullable.null)

  let updateGiftCardNumber = val => {
    setGiftCardNumber(_ => {
      value: val,
      isValid: Some(val !== ""),
      errorString: val !== "" ? "" : localeString.giftCardNumberEmptyText,
    })
  }

  let changeGiftCardNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    updateGiftCardNumber(val)
  }

  let onBlurGiftCardNumber = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]
    updateGiftCardNumber(val)
  }

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if giftCardNumber.value == "" {
        setGiftCardNumber(prev => {
          ...prev,
          errorString: localeString.giftCardNumberEmptyText,
        })
      }
    }
  }, [giftCardNumber.value])

  useSubmitPaymentData(submitCallback)

  <PaymentField
    fieldName={localeString.giftCardNumberLabel}
    setValue=setGiftCardNumber
    value=giftCardNumber
    onChange=changeGiftCardNumber
    onBlur=onBlurGiftCardNumber
    type_="text"
    name="giftCardNumber"
    inputRef=giftCardNumberRef
    placeholder={localeString.giftCardNumberPlaceholder}
    maxLength=32
    paymentType=Payment
  />
}
