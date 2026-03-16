open RecoilAtoms
open PaymentType

// module FieldSpy = {
//   @react.component
//   let make = (~name) => {
//     let field = ReactFinalForm.useField(name)
//     let {submitFailed} = ReactFinalForm.useFormState()

//     React.useEffect(() => {
//       let fieldVal = field.input.value->Option.getOr("")
//       let fieldErr = field.meta.error->Option.getOr("None")
//       let fieldTouched = field.meta.touched ? "true" : "false"
//       let fieldSubmitFailed = submitFailed ? "true" : "false"
//       let fieldValid = field.meta.valid ? "true" : "false"

//       Console.log6(
//         `-- FieldSpy [${name}]:`,
//         `-- FieldSpy field.input.value: "${fieldVal}",`,
//         `-- FieldSpy field.meta.error: "${fieldErr}",`,
//         `-- FieldSpy field.meta.touched: ${fieldTouched},`,
//         `-- FieldSpy submitFailed: ${fieldSubmitFailed},`,
//         `-- FieldSpy field.meta.valid: ${fieldValid}`,
//       )
//       None
//     }, (field.input.value, field.meta.error, field.meta.touched, submitFailed))

//     React.null
//   }
// }

@react.component
module RffFullNamePaymentInput = {
  @react.component
  let make = (~customFieldName, ~firstNamePath, ~lastNamePath) => {
    let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
    let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
    let formState = ReactFinalForm.useFormState()
    let submitFailed = formState.submitFailed

    let (placeholder, fieldName) = switch customFieldName {
    | Some(val) => (val, val)
    | None => (localeString.fullNamePlaceholder, localeString.fullNameLabel)
    }

    let createValidator = rule =>
      Validation.createFieldValidator(
        rule,
        ~enabledCardSchemes=[],
        ~localeObject=localeString->Obj.magic,
      )

    // let (firstNamePath, lastNamePath) = React.useMemo(() => {
    //   switch optionalRequiredFields {
    //   | Some(requiredFields) =>
    //     let fullNameFields =
    //       requiredFields->Array.filter((r: PaymentMethodsRecord.required_fields) =>
    //         r.field_type === FullName
    //       )
    //     let findPath = suffix =>
    //       fullNameFields
    //       ->Array.find(r => r.required_field->String.endsWith(suffix))
    //       ->Option.map(r => r.required_field)
    //     (findPath("first_name"), findPath("last_name"))
    //   | None => (None, None)
    //   }
    // }, [optionalRequiredFields])

    let showDetails = getShowDetails(~billingDetails=fields.billingDetails)

    let firstField: ReactFinalForm.Field.fieldProps = ReactFinalForm.useField(
      firstNamePath,
      ~config={
        validate: createValidator(Validation.FirstName),
      },
    )
    let lastField: ReactFinalForm.Field.fieldProps = ReactFinalForm.useField(
      lastNamePath,
      ~config={
        validate: createValidator(Validation.LastName),
      },
    )

    // Local state: the combined display value shown in the single <input>.
    let (inputValue, setInputValue) = React.useState(() => "")

    let handleChange = ev => {
      let value: string = ReactEvent.Form.target(ev)["value"]
      setInputValue(_ => value)
      let spaceIndex = value->String.indexOf(" ")
      if spaceIndex === -1 {
        firstField.input.onChange(value)
        lastField.input.onChange("")
      } else {
        let firstName = value->String.substring(~start=0, ~end=spaceIndex)
        let lastName = value->String.substringToEnd(~start=spaceIndex + 1)
        firstField.input.onChange(firstName)
        lastField.input.onChange(lastName)
      }
    }

    let onBlur = (_ev: JsxEventU.Focus.t) => {
      firstField.input.onBlur()
      lastField.input.onBlur()
    }

    let nameRef = React.useRef(Nullable.null)

    // Show an error if either field has one and the user has touched the input.
    let errorString = if (
      // submitFailed ||
      firstField.meta.touched && !firstField.meta.active ||
      (lastField.meta.touched && !lastField.meta.active)
    ) {
      switch (firstField.meta.error, lastField.meta.error) {
      | (Some(err), _) => err
      | (_, Some(err)) => err
      | _ => ""
      }
    } else {
      ""
    }

    let isValid =
      // !submitFailed &&
      firstField.meta.valid &&
      (lastField.meta.valid || !lastField.meta.touched || lastField.meta.active)

    <RenderIf condition={showDetails.name == Auto}>
      // <FieldSpy name={firstNamePath} />
      // <FieldSpy name={lastNamePath} />
      <PaymentField
        fieldName
        setValue={_ => ()}
        value={
          value: inputValue,
          isValid: Some(isValid),
          errorString,
        }
        onChange=handleChange
        onBlur
        type_="text"
        inputRef=nameRef
        placeholder
        name=TestUtils.fullNameInputTestId
      />
    </RenderIf>
  }
}

// @react.component
// let make = (~name=?, ~customFieldName=None, ~firstNamePath=?, ~lastNamePath=?) => {
//   switch (name, firstNamePath, lastNamePath) {
//   | (Some(name), Some(fnPath), Some(lnPath)) =>
//     <RffFullNamePaymentInput
//       name
//       customFieldName
//       firstNamePath=fnPath
//       lastNamePath=lnPath
//     />
//   | _ =>
//     let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
//     let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
//     let (fullName, setFullName) = Recoil.useRecoilState(userFullName)
//     let showDetails = getShowDetails(~billingDetails=fields.billingDetails)

//     let changeName = ev => {
//       let val: string = ReactEvent.Form.target(ev)["value"]
//       setFullName(prev => validateName(val, prev, localeString))
//     }

//     let onBlur = ev => {
//       let val: string = ReactEvent.Focus.target(ev)["value"]
//       setFullName(prev => validateName(val, prev, localeString))
//     }

//     let (placeholder, fieldName) = switch customFieldName {
//     | Some(val) => (val, val)
//     | None => (localeString.fullNamePlaceholder, localeString.fullNameLabel)
//     }
//     let nameRef = React.useRef(Nullable.null)

//     React.useEffect(() => {
//       setFullName(prev => validateName(prev.value, prev, localeString))
//       None
//     }, [localeString])

//     let submitCallback = React.useCallback((ev: Window.event) => {
//       let json = ev.data->safeParse
//       let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
//       if confirm.doSubmit {
//         if fullName.value == "" {
//           setFullName(prev => {
//             ...prev,
//             errorString: localeString.nameEmptyText(fieldName),
//           })
//         } else if !(fullName.isValid->Option.getOr(false)) {
//           setFullName(prev => {
//             ...prev,
//             errorString: localeString.invalidCardHolderNameError,
//           })
//         } else {
//           switch optionalRequiredFields {
//           | Some(requiredFields) =>
//             if !DynamicFieldsUtils.checkIfNameIsValid(requiredFields, FullName, fullName) {
//               setFullName(prev => {
//                 ...prev,
//                 errorString: localeString.completeNameEmptyText(fieldName),
//               })
//             }
//           | None => ()
//           }
//         }
//       }
//     }, (fullName, localeString, fieldName, optionalRequiredFields))
//     useSubmitPaymentData(submitCallback)

//     <RenderIf condition={showDetails.name == Auto}>
//       <PaymentField
//         fieldName
//         setValue=setFullName
//         value=fullName
//         onChange=changeName
//         onBlur
//         type_="text"
//         inputRef=nameRef
//         placeholder
//         name=TestUtils.fullNameInputTestId
//       />
//     </RenderIf>
//   }
// }
