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
    setFullName(.prev => {
      ...prev,
      value: val,
      errorString: "",
    })
  }
  let (placeholder, fieldName) = switch customFieldName {
  | Some(val) => (val, val)
  | None => (localeString.fullNamePlaceholder, localeString.fullNameLabel)
  }
  let nameRef = React.useRef(Js.Nullable.null)

  let submitCallback = React.useCallback1((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if fullName.value == "" {
        setFullName(.prev => {
          ...prev,
          errorString: `Please provide your ${fieldName}`,
        })
      } else {
        switch optionalRequiredFields {
        | Some(requiredFields) =>
          if !DynamicFieldsUtils.checkIfNameIsValid(requiredFields, FullName, fullName) {
            setFullName(.prev => {
              ...prev,
              errorString: `Please provide your complete ${fieldName}`,
            })
          }
        | None => ()
        }
      }
    }
  }, [fullName])
  submitPaymentData(submitCallback)

  <RenderIf condition={showDetails.name == Auto}>
    <PaymentField
      fieldName
      value=fullName
      onChange=changeName
      paymentType
      type_="text"
      name="name"
      inputRef=nameRef
      placeholder
    />
  </RenderIf>
}
