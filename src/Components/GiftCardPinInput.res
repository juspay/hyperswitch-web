@react.component
let make = () => {
  open RecoilAtoms
  open Utils

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (giftCardPin, setGiftCardPin) = Recoil.useRecoilState(userGiftCardPin)
  let giftCardPinRef = React.useRef(Nullable.null)

  let updateGiftCardPin = val => {
    setGiftCardPin(_ => {
      value: val,
      isValid: Some(val !== ""),
      errorString: val !== "" ? "" : localeString.giftCardPinEmptyText,
    })
  }

  let changeGiftCardPin = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    updateGiftCardPin(val)
  }

  let onBlurGiftCardPin = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]
    updateGiftCardPin(val)
  }

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if giftCardPin.value == "" {
        setGiftCardPin(prev => {
          ...prev,
          errorString: localeString.giftCardPinEmptyText,
        })
      }
    }
  }, [giftCardPin.value])

  useSubmitPaymentData(submitCallback)

  <>
    <PaymentField
      fieldName={localeString.giftCardPinLabel}
      setValue=setGiftCardPin
      value=giftCardPin
      onChange=changeGiftCardPin
      onBlur=onBlurGiftCardPin
      type_="text"
      name="giftCardPin"
      inputRef=giftCardPinRef
      placeholder={localeString.giftCardPinPlaceholder}
      maxLength=12
      paymentType=Payment
    />
  </>
}
