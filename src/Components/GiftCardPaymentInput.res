@react.component
let make = (~label="") => {
  open RecoilAtoms
  open Utils

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (giftCardNumber, setGiftCardNumber) = Recoil.useRecoilState(userGiftCardNumber)
  let (giftCardCvc, setGiftCardCvc) = Recoil.useRecoilState(userGiftCardCvc)

  let giftCardNumberRef = React.useRef(Nullable.null)
  let giftCardCvcRef = React.useRef(Nullable.null)

  let changeGiftCardNumber = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]->Utils.filterAlphanumeric
    setGiftCardNumber(prev => {
      ...prev,
      value: val,
    })
  }

  let changeGiftCardCvc = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]->Utils.filterAlphanumeric
    setGiftCardCvc(prev => {
      ...prev,
      value: val,
    })
  }

  let onBlurGiftCardNumber = _ => {
    if giftCardNumber.value->String.length > 0 {
      setGiftCardNumber(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else {
      setGiftCardNumber(prev => {
        ...prev,
        isValid: None,
        errorString: "",
      })
    }
  }

  let onBlurGiftCardCvc = _ => {
    if giftCardCvc.value->String.length > 0 {
      setGiftCardCvc(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else {
      setGiftCardCvc(prev => {
        ...prev,
        isValid: None,
        errorString: "",
      })
    }
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
