@react.component
let make = (~fieldType="") => {
  open Utils

  let {localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let (pixCNPJ, setPixCNPJ) = Jotai.useAtom(JotaiAtoms.userPixCNPJ)
  let (pixCPF, setPixCPF) = Jotai.useAtom(JotaiAtoms.userPixCPF)
  let (pixKey, setPixKey) = Jotai.useAtom(JotaiAtoms.userPixKey)
  let (sourceBankAccountId, setSourceBankAccountId) = Jotai.useAtom(JotaiAtoms.sourceBankAccountId)
  let inputRef = React.useRef(Nullable.null)

  let validatePixKey = (val): RecoilAtomTypes.field =>
    if val->String.length > 0 {
      {value: val, isValid: Some(true), errorString: ""}
    } else {
      {value: val, isValid: None, errorString: ""}
    }

  let validatePixCNPJ = (val): RecoilAtomTypes.field => {
    let isCNPJValid = CnpjValidation.isValidCNPJ(val)
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
    let isCPFValid = CpfValidation.isValidCPF(val)
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

  let (fieldName, setValue, value, placeholder, maxLength, validationFn) = switch fieldType {
  | "pixKey" => (
      localeString.pixKeyLabel,
      setPixKey,
      pixKey,
      localeString.pixKeyPlaceholder,
      None,
      validatePixKey,
    )
  | "pixCPF" => (
      localeString.pixCPFLabel,
      setPixCPF,
      pixCPF,
      localeString.pixCPFPlaceholder,
      Some(11),
      validatePixCPF,
    )
  | "pixCNPJ" => (
      localeString.pixCNPJLabel,
      setPixCNPJ,
      pixCNPJ,
      localeString.pixCNPJPlaceholder,
      Some(14),
      validatePixCNPJ,
    )
  | _ => ("", _ => (), JotaiAtoms.defaultFieldValues, "", None, _ => JotaiAtoms.defaultFieldValues)
  }

  let validateAndSetPixInputValue = val => setValue(_ => val->validationFn)

  let onChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]

    let transformedVal = switch fieldType {
    // Transforming to uppercase to allow lowercase input to reduce friction, as CNPJ can contain letters (when formatted with punctuation)
    | "pixCNPJ" => val->String.toUpperCase
    | "pixCPF" => val->CardValidations.clearSpaces
    | _ => val
    }
    validateAndSetPixInputValue(transformedVal)
  }

  let onBlur = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]
    validateAndSetPixInputValue(val)
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

  <PaymentField
    fieldName
    setValue
    value
    onChange
    onBlur
    type_=fieldType
    name=fieldType
    inputRef
    placeholder
    ?maxLength
    paymentType=Payment
  />
}
