open RecoilAtoms
open PaymentType
open Utils

@react.component
let make = (~customFieldName=None, ~optionalRequiredFields=None) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let (fullName, setFullName) = Recoil.useRecoilState(userFullName)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()
  let showDetails = getShowDetails(~billingDetails=fields.billingDetails)

  let changeName = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setFullName(prev => validateName(val, prev, localeString))
  }

  let onBlur = ev => {
    let val: string = ReactEvent.Focus.target(ev)["value"]
    setFullName(prev => validateName(val, prev, localeString))
  }

  let (placeholder, fieldName) = switch customFieldName {
  | Some(val) => (val, val)
  | None => (localeString.fullNamePlaceholder, localeString.fullNameLabel)
  }
  let nameRef = React.useRef(Nullable.null)

  React.useEffect(() => {
    setFullName(prev => validateName(prev.value, prev, localeString))
    None
  }, [])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit && !isGiftCardOnlyPayment {
      if fullName.value == "" {
        setFullName(prev => {
          ...prev,
          errorString: fieldName->localeString.nameEmptyText,
        })
      } else if !(fullName.isValid->Option.getOr(false)) {
        setFullName(prev => {
          ...prev,
          errorString: localeString.invalidCardHolderNameError,
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
  }, (fullName, isGiftCardOnlyPayment))
  useSubmitPaymentData(submitCallback)

  <RenderIf condition={showDetails.name == Auto}>
    <PaymentField
      fieldName
      setValue=setFullName
      value=fullName
      onChange=changeName
      onBlur
      type_="text"
      inputRef=nameRef
      placeholder
      name=TestUtils.fullNameInputTestId
    />
  </RenderIf>
}
