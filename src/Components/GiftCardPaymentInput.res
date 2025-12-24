@react.component
let make = (~label="") => {
  open RecoilAtoms
  open Utils

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (giftCardNumber, setGiftCardNumber) = Recoil.useRecoilState(userGiftCardNumber)
  let (giftCardCvc, setGiftCardCvc) = Recoil.useRecoilState(userGiftCardCvc)

  let giftCardNumberRef = React.useRef(Nullable.null)
  let giftCardCvcRef = React.useRef(Nullable.null)
  let updateCardNumber = val => {
    setGiftCardNumber(_ => {
      value: val,
      isValid: Some(val !== ""),
      errorString: val !== "" ? "" : localeString.giftCardNumberEmptyText,
    })
  }

  let updateCardCvc = val => {
    setGiftCardCvc(_ => {
      value: val,
      isValid: Some(val !== ""),
      errorString: val !== "" ? "" : localeString.giftCardCvcEmptyText,
    })
  }

  let changeGiftCardNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]->Utils.filterAlphanumeric
    updateCardNumber(val)
  }

  let changeGiftCardCvc = ev => {
    let val = ReactEvent.Form.target(ev)["value"]->Utils.filterAlphanumeric
    updateCardCvc(val)
  }

  let onBlurGiftCardNumber = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]->Utils.filterAlphanumeric
    updateCardNumber(val)
  }

  let onBlurGiftCardCvc = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]->Utils.filterAlphanumeric
    updateCardCvc(val)
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
      if giftCardCvc.value == "" {
        setGiftCardCvc(prev => {
          ...prev,
          errorString: localeString.giftCardCvcEmptyText,
        })
      }
    }
  }, [giftCardNumber.value, giftCardCvc.value])

  useSubmitPaymentData(submitCallback)

  <>
    <RenderIf condition={label === "giftCardNumber"}>
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
    </RenderIf>
    <RenderIf condition={label === "giftCardCvc"}>
      <PaymentField
        fieldName={localeString.giftCardCvcLabel}
        setValue=setGiftCardCvc
        value=giftCardCvc
        onChange=changeGiftCardCvc
        onBlur=onBlurGiftCardCvc
        type_="text"
        name="giftCardCvc"
        inputRef=giftCardCvcRef
        placeholder={localeString.giftCardCvcPlaceholder}
        maxLength=12
        paymentType=Payment
      />
    </RenderIf>
  </>
}
