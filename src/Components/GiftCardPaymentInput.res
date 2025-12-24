@react.component
let make = (~fieldType="") => {
  open RecoilAtoms
  open Utils

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (giftCardNumber, setGiftCardNumber) = Recoil.useRecoilState(userGiftCardNumber)
  let (giftCardPin, setGiftCardPin) = Recoil.useRecoilState(userGiftCardCvc)

  let giftCardNumberRef = React.useRef(Nullable.null)
  let giftCardPinRef = React.useRef(Nullable.null)
  let updateGiftCardNumber = val => {
    setGiftCardNumber(_ => {
      value: val,
      isValid: Some(val !== ""),
      errorString: val !== "" ? "" : localeString.giftCardNumberEmptyText,
    })
  }

  let updateGiftCardPin = val => {
    setGiftCardPin(_ => {
      value: val,
      isValid: Some(val !== ""),
      errorString: val !== "" ? "" : localeString.giftCardPinEmptyText,
    })
  }

  let changeGiftCardNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]->Utils.filterAlphanumeric
    updateGiftCardNumber(val)
  }

  let changeGiftCardPin = ev => {
    let val = ReactEvent.Form.target(ev)["value"]->Utils.filterAlphanumeric
    updateGiftCardPin(val)
  }

  let onBlurGiftCardNumber = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]->Utils.filterAlphanumeric
    updateGiftCardNumber(val)
  }

  let onBlurGiftCardPin = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]->Utils.filterAlphanumeric
    updateGiftCardPin(val)
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
      if giftCardPin.value == "" {
        setGiftCardPin(prev => {
          ...prev,
          errorString: localeString.giftCardPinEmptyText,
        })
      }
    }
  }, [giftCardNumber.value, giftCardPin.value])

  useSubmitPaymentData(submitCallback)

  <>
    <RenderIf condition={fieldType === "giftCardNumber"}>
      <PaymentField
        fieldName={localeString.giftCardNumberLabel}
        setValue=setGiftCardNumber
        value=giftCardNumber
        onChange=changeGiftCardNumber
        onBlur=onBlurGiftCardNumber
        type_="text"
        name=fieldType
        inputRef=giftCardNumberRef
        placeholder={localeString.giftCardNumberPlaceholder}
        maxLength=32
        paymentType=Payment
      />
    </RenderIf>
    <RenderIf condition={fieldType === "giftCardPin"}>
      <PaymentField
        fieldName={localeString.giftCardPinLabel}
        setValue=setGiftCardPin
        value=giftCardPin
        onChange=changeGiftCardPin
        onBlur=onBlurGiftCardPin
        type_="text"
        name=fieldType
        inputRef=giftCardPinRef
        placeholder={localeString.giftCardPinPlaceholder}
        maxLength=12
        paymentType=Payment
      />
    </RenderIf>
  </>
}
