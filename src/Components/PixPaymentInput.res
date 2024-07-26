open RecoilAtoms
open Utils

@react.component
let make = (~label="") => {
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
  let onBlurPixCNPJ = _ => {
    if pixCNPJ.value->String.length === 14 && pixCNPJ.isValid->Option.getOr(false) {
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
        errorString: "Invalid Pix CNPJ",
      })
    }
  }
  let onBlurPixCPF = _ => {
    if pixCPF.value->String.length === 11 && pixCPF.isValid->Option.getOr(false) {
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
        errorString: "Invalid Pix CPF",
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
        errorString: "Invalid Pix CPNJ",
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
        errorString: "Invalid Pix CPF",
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
          errorString: "Pix key cannot be empty",
        })
      }
      if pixCNPJ.value == "" {
        setPixCNPJ(prev => {
          ...prev,
          errorString: "Pix CNPJ cannot be empty",
        })
      }
      if pixCPF.value == "" {
        setPixCPF(prev => {
          ...prev,
          errorString: "Pix CPF cannot be empty",
        })
      }
    }
  }, [pixCNPJ.value, pixKey.value, pixCPF.value])
  useSubmitPaymentData(submitCallback)

  <>
    <RenderIf condition={label === "pixKey"}>
      <PaymentField
        fieldName="Pix key"
        setValue={setPixKey}
        value=pixKey
        onChange=changePixKey
        paymentType=Payment
        type_="pixKey"
        name="pixKey"
        inputRef=pixKeyRef
        placeholder="Enter pix key"
      />
    </RenderIf>
    <RenderIf condition={label === "pixCPF"}>
      <PaymentField
        fieldName="Pix CPF"
        setValue={setPixCPF}
        value=pixCPF
        onChange=changePixCPF
        onBlur=onBlurPixCPF
        paymentType=Payment
        type_="pixCPF"
        name="pixCPF"
        inputRef=pixCPFRef
        placeholder="Enter pix CPF"
        maxLength=11
      />
    </RenderIf>
    <RenderIf condition={label === "pixCNPJ"}>
      <PaymentField
        fieldName="Pix CNPJ"
        setValue={setPixCNPJ}
        value=pixCNPJ
        onChange=changePixCNPJ
        onBlur=onBlurPixCNPJ
        paymentType=Payment
        type_="pixCNPJ"
        name="pixCNPJ"
        inputRef=pixCNPJRef
        placeholder="Enter pix CNPJ"
        maxLength=14
      />
    </RenderIf>
  </>
}
