@react.component
let make = (~label="") => {
  open RecoilAtoms
  open Utils

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (pixCNPJ, setPixCNPJ) = Recoil.useRecoilState(userPixCNPJ)
  let (pixCPF, setPixCPF) = Recoil.useRecoilState(userPixCPF)
  let (pixKey, setPixKey) = Recoil.useRecoilState(userPixKey)
  let (sourceBankAccountId, setSourceBankAccountId) = Recoil.useRecoilState(sourceBankAccountId)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  let pixKeyRef = React.useRef(Nullable.null)
  let pixCPFRef = React.useRef(Nullable.null)
  let pixCNPJRef = React.useRef(Nullable.null)

  let changePixKey = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setPixKey(prev => {
      ...prev,
      value: val,
    })
  }

  let changePixCNPJ = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setPixCNPJ(prev => {
      ...prev,
      value: val,
    })
  }

  let changePixCPF = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setPixCPF(prev => {
      ...prev,
      value: val,
    })
  }

  let onBlurPixKey = _ => {
    if pixKey.value->String.length > 0 {
      setPixKey(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else {
      setPixKey(prev => {
        ...prev,
        isValid: None,
        errorString: "",
      })
    }
  }

  let onBlurPixCNPJ = ev => {
    let pixCNPJNumber = ReactEvent.Focus.target(ev)["value"]

    if %re("/^\d*$/")->RegExp.test(pixCNPJNumber) && pixCNPJNumber->String.length === 14 {
      setPixCNPJ(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else if pixCNPJNumber->String.length == 0 {
      setPixCNPJ(prev => {
        ...prev,
        isValid: None,
        errorString: "",
      })
    } else {
      setPixCNPJ(prev => {
        ...prev,
        isValid: Some(false),
        errorString: localeString.pixCNPJInvalidText,
      })
    }
  }

  let onBlurPixCPF = ev => {
    let pixCPFNumber = ReactEvent.Focus.target(ev)["value"]

    if %re("/^\d*$/")->RegExp.test(pixCPFNumber) && pixCPFNumber->String.length === 11 {
      setPixCPF(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else if pixCPFNumber->String.length == 0 {
      setPixCPF(prev => {
        ...prev,
        isValid: None,
        errorString: "",
      })
    } else {
      setPixCPF(prev => {
        ...prev,
        isValid: Some(false),
        errorString: localeString.pixCPFInvalidText,
      })
    }
  }

  React.useEffect(() => {
    if %re("/^\d*$/")->RegExp.test(pixCNPJ.value) {
      setPixCNPJ(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else {
      setPixCNPJ(prev => {
        ...prev,
        isValid: Some(false),
        errorString: localeString.pixCNPJInvalidText,
      })
    }
    None
  }, [pixCNPJ.value])

  React.useEffect(() => {
    if %re("/^\d*$/")->RegExp.test(pixCPF.value) {
      setPixCPF(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else {
      setPixCPF(prev => {
        ...prev,
        isValid: Some(false),
        errorString: localeString.pixCPFInvalidText,
      })
    }

    None
  }, [pixCPF.value])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if isGiftCardOnlyPayment {
        ()
      } else {
        if pixKey.value == "" {
          setPixKey(prev => {
            ...prev,
            errorString: localeString.pixKeyEmptyText,
          })
        }
        if pixCNPJ.value == "" {
          setPixCNPJ(prev => {
            ...prev,
            errorString: localeString.pixCNPJEmptyText,
          })
        }
        if pixCPF.value == "" {
          setPixCPF(prev => {
            ...prev,
            errorString: localeString.pixCPFEmptyText,
          })
        }
        if sourceBankAccountId.value == "" {
          setSourceBankAccountId(prev => {
            ...prev,
            errorString: localeString.sourceBankAccountIdEmptyText,
          })
        }
      }
    }
  }, (pixCNPJ.value, pixKey.value, pixCPF.value, isGiftCardOnlyPayment))

  useSubmitPaymentData(submitCallback)

  <>
    <RenderIf condition={label === "pixKey"}>
      <PaymentField
        fieldName={localeString.pixKeyLabel}
        setValue=setPixKey
        value=pixKey
        onChange=changePixKey
        onBlur=onBlurPixKey
        type_="pixKey"
        name="pixKey"
        inputRef=pixKeyRef
        placeholder={localeString.pixKeyPlaceholder}
        paymentType=Payment
      />
    </RenderIf>
    <RenderIf condition={label === "pixCPF"}>
      <PaymentField
        fieldName={localeString.pixCPFLabel}
        setValue=setPixCPF
        value=pixCPF
        onChange=changePixCPF
        onBlur=onBlurPixCPF
        type_="pixCPF"
        name="pixCPF"
        inputRef=pixCPFRef
        placeholder={localeString.pixCPFPlaceholder}
        maxLength=11
        paymentType=Payment
      />
    </RenderIf>
    <RenderIf condition={label === "pixCNPJ"}>
      <PaymentField
        fieldName={localeString.pixCNPJLabel}
        setValue=setPixCNPJ
        value=pixCNPJ
        onChange=changePixCNPJ
        onBlur=onBlurPixCNPJ
        type_="pixCNPJ"
        name="pixCNPJ"
        inputRef=pixCNPJRef
        placeholder={localeString.pixCNPJPlaceholder}
        maxLength=14
        paymentType=Payment
      />
    </RenderIf>
  </>
}
