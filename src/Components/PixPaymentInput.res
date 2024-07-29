@react.component
let make = (~label="") => {
  open RecoilAtoms
  open Utils

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (pixCNPJ, setPixCNPJ) = Recoil.useRecoilState(userPixCNPJ)
  let (pixCPF, setPixCPF) = Recoil.useRecoilState(userPixCPF)
  let (pixKey, setPixKey) = Recoil.useRecoilState(userPixKey)

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
    if pixKey.value->String.length > 0 && pixKey.isValid->Option.getOr(true) {
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

  let onBlurPixCNPJ = _ => {
    if pixCNPJ.value->String.length === 14 && pixCNPJ.isValid->Option.getOr(true) {
      setPixCNPJ(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else if pixCNPJ.value->String.length === 0 {
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

  let onBlurPixCPF = _ => {
    if pixCPF.value->String.length === 11 && pixCPF.isValid->Option.getOr(true) {
      setPixCPF(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else if pixCPF.value->String.length === 0 {
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
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
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
    }
  }, [pixCNPJ.value, pixKey.value, pixCPF.value])

  useSubmitPaymentData(submitCallback)

  <>
    <RenderIf condition={label === "pixKey"}>
      <PaymentField
        fieldName={localeString.pixKeyLabel}
        setValue=setPixKey
        value=pixKey
        onChange=changePixKey
        onBlur=onBlurPixKey
        paymentType=Payment
        type_="pixKey"
        name="pixKey"
        inputRef=pixKeyRef
        placeholder={localeString.pixKeyPlaceholder}
      />
    </RenderIf>
    <RenderIf condition={label === "pixCPF"}>
      <PaymentField
        fieldName={localeString.pixCPFLabel}
        setValue=setPixCPF
        value=pixCPF
        onChange=changePixCPF
        onBlur=onBlurPixCPF
        paymentType=Payment
        type_="pixCPF"
        name="pixCPF"
        inputRef=pixCPFRef
        placeholder={localeString.pixCPFPlaceholder}
        maxLength=11
      />
    </RenderIf>
    <RenderIf condition={label === "pixCNPJ"}>
      <PaymentField
        fieldName={localeString.pixCNPJLabel}
        setValue=setPixCNPJ
        value=pixCNPJ
        onChange=changePixCNPJ
        onBlur=onBlurPixCNPJ
        paymentType=Payment
        type_="pixCNPJ"
        name="pixCNPJ"
        inputRef=pixCNPJRef
        placeholder={localeString.pixCNPJPlaceholder}
        maxLength=14
      />
    </RenderIf>
  </>
}
