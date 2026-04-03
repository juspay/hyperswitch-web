@react.component
let make = (~fieldType="") => {
  open RecoilAtoms
  open Utils

  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (pixCNPJ, setPixCNPJ) = Recoil.useRecoilState(userPixCNPJ)
  let (pixCPF, setPixCPF) = Recoil.useRecoilState(userPixCPF)
  let (pixKey, setPixKey) = Recoil.useRecoilState(userPixKey)
  let (sourceBankAccountId, setSourceBankAccountId) = Recoil.useRecoilState(sourceBankAccountId)
  let (bankAccountNumber, setBankAccountNumber) = Recoil.useRecoilState(userBankAccountNumber)
  let (branchCode, setBranchCode) = Recoil.useRecoilState(userBranchCode)
  let (bankIdentifier, setBankIdentifier) = Recoil.useRecoilState(userBankIdentifier)
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
  | _ => (
      "",
      _ => (),
      RecoilAtoms.defaultFieldValues,
      "",
      None,
      _ => RecoilAtoms.defaultFieldValues,
    )
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
      if bankAccountNumber.value == "" {
        setBankAccountNumber(prev => {
          ...prev,
          errorString: localeString.ibanEmptyText,
        })
      }
      if branchCode.value == "" {
        setBranchCode(prev => {
          ...prev,
          errorString: localeString.branchCodeEmptyText,
        })
      }
      if bankIdentifier.value == "" {
        setBankIdentifier(prev => {
          ...prev,
          errorString: localeString.bankIdentifierEmptyText,
        })
      }
    }
  }, [pixCNPJ.value, pixKey.value, pixCPF.value, sourceBankAccountId.value, bankAccountNumber.value, branchCode.value, bankIdentifier.value])

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
