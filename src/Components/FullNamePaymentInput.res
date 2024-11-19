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

  let validateName = (
    val: string,
    prev: RecoilAtomTypes.field,
    localeString: LocaleStringTypes.localeStrings,
  ) => {
    let isValid = val !== "" && %re("/^\D*$/")->RegExp.test(val)
    let errorString = if val === "" {
      prev.errorString
    } else if isValid {
      ""
    } else {
      localeString.invalidCardHolderNameError
    }
    {
      ...prev,
      value: val,
      isValid: Some(isValid),
      errorString,
    }
  }

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

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
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
      inputRef=nameRef
      placeholder
      name=TestUtils.fullNameInputTestId
    />
  </RenderIf>
}
