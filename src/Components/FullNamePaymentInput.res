open RecoilAtoms
open PaymentType
open Utils

@react.component
module RffFullNamePaymentInput = {
  @react.component
  let make = (~name, ~customFieldName, ~optionalRequiredFields) => {
    let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
    let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
    let (placeholder, fieldName) = switch customFieldName {
    | Some(val) => (val, val)
    | None => (localeString.fullNamePlaceholder, localeString.fullNameLabel)
    }

    let field: ReactFinalForm.fieldProps<ReactEvent.Focus.t> = ReactFinalForm.useField(
      name,
      ~config={
        validate: val => {
          let val = val->Option.getOr("")
          let isValid = val !== "" && %re("/^\D*$/")->RegExp.test(val)
          if val === "" {
            None
          } else if isValid {
            switch optionalRequiredFields {
            | Some(requiredFields) =>
              if (
                !DynamicFieldsUtils.checkIfNameIsValid(
                  requiredFields,
                  FullName,
                  {value: val, isValid: Some(true), errorString: ""},
                )
              ) {
                Some(fieldName->localeString.completeNameEmptyText)
              } else {
                None
              }
            | None => None
            }
          } else {
            Some(localeString.invalidCardHolderNameError)
          }
        },
      },
    )

    let fullNameValue = field.input.value->Option.getOr("")
    let showDetails = getShowDetails(~billingDetails=fields.billingDetails)

    let changeName = ev => {
      let val: string = ReactEvent.Form.target(ev)["value"]
      field.input.onChange(val)
    }

    let onBlur = ev => {
      field.input.onBlur(ev)
    }

    let nameRef = React.useRef(Nullable.null)

    <RenderIf condition={showDetails.name == Auto}>
      <PaymentField
        fieldName
        setValue={_ => ()}
        value={
          RecoilAtomTypes.value: fullNameValue,
          isValid: Some(field.meta.valid),
          errorString: field.meta.touched ? field.meta.error->Option.getOr("") : "",
        }
        onChange=changeName
        onBlur
        type_="text"
        inputRef=nameRef
        placeholder
        name=TestUtils.fullNameInputTestId
      />
    </RenderIf>
  }
}

@react.component
let make = (~name=?, ~customFieldName=None, ~optionalRequiredFields=None) => {
  switch name {
  | Some(name) => <RffFullNamePaymentInput name customFieldName optionalRequiredFields />
  | None =>
    let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
    let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
    let (fullName, setFullName) = Recoil.useRecoilState(userFullName)
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
        onBlur
        type_="text"
        inputRef=nameRef
        placeholder
        name=TestUtils.fullNameInputTestId
      />
    </RenderIf>
  }
}
