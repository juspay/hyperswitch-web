@react.component
let make = (~fieldType="") => {
  open RecoilAtoms
  open Utils

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (pixCNPJ, setPixCNPJ) = Recoil.useRecoilState(userPixCNPJ)
  let (pixCPF, setPixCPF) = Recoil.useRecoilState(userPixCPF)
  let (pixKey, setPixKey) = Recoil.useRecoilState(userPixKey)
  let (sourceBankAccountId, setSourceBankAccountId) = Recoil.useRecoilState(sourceBankAccountId)
  let inputRef = React.useRef(Nullable.null)

  let validatePixKey = (val): RecoilAtomTypes.field =>
    if val->String.length > 0 {
      {value: val, isValid: Some(true), errorString: ""}
    } else {
      {value: val, isValid: None, errorString: ""}
    }

  let validatePixCNPJ = (val): RecoilAtomTypes.field => {
    let isCNPJValid = %re("/^\d*$/")->RegExp.test(val) && val->String.length === 14
    if isCNPJValid {
      {value: val, isValid: Some(true), errorString: ""}
    } else if val->String.length === 0 {
      {value: val, isValid: None, errorString: ""}
    } else {
      {
        value: val,
        isValid: Some(false),
        errorString: localeString.pixCNPJInvalidText,
      }
    }
  }

  let validatePixCPF = (val): RecoilAtomTypes.field => {
    let isCPFValid = %re("/^\d*$/")->RegExp.test(val) && val->String.length === 11
    if isCPFValid {
      {value: val, isValid: Some(true), errorString: ""}
    } else if val->String.length === 0 {
      {value: val, isValid: None, errorString: ""}
    } else {
      {
        value: val,
        isValid: Some(false),
        errorString: localeString.pixCPFInvalidText,
      }
    }
  }

  let validateAndSetPixValue = val => {
    switch fieldType {
    | "pixKey" => setPixKey(_ => val->validatePixKey)
    | "pixCNPJ" => setPixCNPJ(_ => val->validatePixCNPJ)
    | "pixCPF" => setPixCPF(_ => val->validatePixCPF)
    | _ => ()
    }
  }

  let onChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    val->validateAndSetPixValue
  }

  let onBlur = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]
    val->validateAndSetPixValue
  }

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
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
      if sourceBankAccountId.value == "" {
        setSourceBankAccountId(prev => {
          ...prev,
          errorString: localeString.sourceBankAccountIdEmptyText,
        })
      }
    }
  }, [pixCNPJ.value, pixKey.value, pixCPF.value])

  useSubmitPaymentData(submitCallback)

  <>
    <RenderIf condition={fieldType === "pixKey"}>
      <PaymentField
        fieldName={localeString.pixKeyLabel}
        setValue=setPixKey
        value=pixKey
        onChange
        onBlur
        type_="pixKey"
        name="pixKey"
        inputRef
        placeholder={localeString.pixKeyPlaceholder}
        paymentType=Payment
      />
    </RenderIf>
    <RenderIf condition={fieldType === "pixCPF"}>
      <PaymentField
        fieldName={localeString.pixCPFLabel}
        setValue=setPixCPF
        value=pixCPF
        onChange
        onBlur
        type_="pixCPF"
        name="pixCPF"
        inputRef
        placeholder={localeString.pixCPFPlaceholder}
        maxLength=11
        paymentType=Payment
      />
    </RenderIf>
    <RenderIf condition={fieldType === "pixCNPJ"}>
      <PaymentField
        fieldName={localeString.pixCNPJLabel}
        setValue=setPixCNPJ
        value=pixCNPJ
        onChange
        onBlur
        type_="pixCNPJ"
        name="pixCNPJ"
        inputRef
        placeholder={localeString.pixCNPJPlaceholder}
        maxLength=14
        paymentType=Payment
      />
    </RenderIf>
  </>
}
