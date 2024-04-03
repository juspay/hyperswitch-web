open RecoilAtoms
open PaymentType
open Utils

@react.component
let make = (~paymentType, ~customFieldName=None, ~requiredFields as optionalRequiredFields=?) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let (billingName, setBillingName) = Recoil.useLoggedRecoilState(
    userBillingName,
    "billingName",
    loggerState,
  )

  let showDetails = getShowDetails(~billingDetails=fields.billingDetails, ~logger=loggerState)

  let changeName = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setBillingName(prev => {
      value: val,
      isValid: Some(val !== ""),
      errorString: val !== "" ? "" : prev.errorString,
    })
  }
  let onBlur = ev => {
    let val: string = ReactEvent.Focus.target(ev)["value"]
    setBillingName(prev => {
      ...prev,
      isValid: Some(val !== ""),
    })
  }
  let (placeholder, fieldName) = switch customFieldName {
  | Some(val) => (val, val)
  | None => (localeString.billingNamePlaceholder, localeString.billingNameLabel)
  }
  let nameRef = React.useRef(Nullable.null)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if billingName.value == "" {
        setBillingName(prev => {
          ...prev,
          errorString: fieldName->localeString.nameEmptyText,
        })
      } else {
        switch optionalRequiredFields {
        | Some(requiredFields) =>
          if !DynamicFieldsUtils.checkIfNameIsValid(requiredFields, BillingName, billingName) {
            setBillingName(prev => {
              ...prev,
              errorString: fieldName->localeString.completeNameEmptyText,
            })
          }
        | None => ()
        }
      }
    }
  }, [billingName])
  useSubmitPaymentData(submitCallback)

  <RenderIf condition={showDetails.name == Auto}>
    <PaymentField
      fieldName
      setValue=setBillingName
      value=billingName
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
