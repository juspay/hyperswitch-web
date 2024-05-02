open RecoilAtoms
open PaymentType
open Utils

@react.component
let make = (~paymentType, ~customFieldName=None, ~optionalRequiredFields=None) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let (fullName, setFullName) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)

  let showDetails = getShowDetails(~billingDetails=fields.billingDetails, ~logger=loggerState)

  let changeName = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setFullName(prev => {
      value: val,
      isValid: Some(val !== ""),
      errorString: val !== "" ? "" : prev.errorString,
    })
  }

  let onBlur = ev => {
    let val: string = ReactEvent.Focus.target(ev)["value"]
    setFullName(prev => {
      ...prev,
      isValid: Some(val !== ""),
    })
  }

  let (placeholder, fieldName) = switch customFieldName {
  | Some(val) => (val, val)
  | None => (localeString.fullNamePlaceholder, localeString.fullNameLabel)
  }
  let nameRef = React.useRef(Nullable.null)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if fullName.value == "" {
        setFullName(prev => {
          ...prev,
          errorString: fieldName->localeString.nameEmptyText,
        })
      } else {
        switch optionalRequiredFields {
        | Some(requiredFields) =>
          if !DynamicFieldsUtils.checkIfNameIsValid(requiredFields, FullName, fullName) {
            setFullName(prev => {
              ...prev,
              errorString: fieldName->localeString.completeNameEmptyText,
            })
          }
        | None => ()
        }
      }
    }
  }, [fullName])
  useSubmitPaymentData(submitCallback)

  <RenderIf condition={showDetails.name == Auto}>
    <PaymentField
      fieldName
      setValue=setFullName
      value=fullName
      onChange=changeName
      paymentType
      onBlur
      type_="text"
      name="name"
      inputRef=nameRef
      placeholder
    />
  </RenderIf>
}
