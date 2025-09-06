open SuperpositionHelper
open SuperpositionTypes

@react.component
let make = (~field: fieldConfig, ~fieldIndex: string) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let dummyRef = React.useRef(Nullable.null)
  let getFieldNameFromLocale = fieldName => {
    switch fieldName {
    | Email => localeString.emailLabel
    | Line1 => localeString.line1Label
    | Line2 => localeString.line2Label
    | City => localeString.cityLabel
    | State => localeString.stateLabel
    | Zip => localeString.postalCodeLabel
    | Country => localeString.countryLabel
    | FullName => localeString.fullNameLabel
    | FirstName
    | LastName =>
      field.displayName
    | Number => localeString.formFieldPhoneNumberLabel
    | PhoneNumberWithCountryCode => localeString.formFieldPhoneNumberLabel
    | AccountNumber => localeString.accountNumberText
    | RoutingNumber => localeString.formFieldACHRoutingNumberLabel
    | SortCode => localeString.sortCodeText
    | BsbNumber => "BSB Number"
    | BecsSortCode => localeString.sortCodeText
    | Iban => "IBAN"
    | BlikCode => localeString.payment_methods_blik
    | BankName => localeString.formFieldBankNameLabel
    | Issuer => field.displayName
    | Cnpj => field.displayName
    | Cpf => field.displayName
    | Key => field.displayName
    | SourceBankAccountId => "Source Bank Account ID"
    | DateOfBirth => localeString.dateOfBirth
    | LanguagePreference => field.displayName
    | Network => field.displayName
    | PayCurrency => localeString.payment_methods_crypto_currency
    | VpaId => localeString.vpaIdLabel
    | SocialSecurityNumber => localeString.socialSecurityNumberLabel
    | Cvc => localeString.cvcTextLabel
    | ClientUid => field.displayName
    | Msisdn => field.displayName
    | ProductName => field.displayName
    | _ => field.displayName
    }
  }

  let getPlaceholderFromLocale = fieldName => {
    switch fieldName {
    | Email => "Eg: johndoe@gmail.com"
    | Line1 => localeString.line1Placeholder
    | Line2 => localeString.line2Placeholder
    | City => localeString.cityLabel
    | State => localeString.stateLabel
    | Zip => localeString.postalCodeLabel
    | Country => localeString.countryLabel
    | FullName => localeString.fullNamePlaceholder
    | FirstName => "First Name"
    | LastName => field.displayName
    | Number => localeString.formFieldPhoneNumberPlaceholder
    | PhoneNumberWithCountryCode => localeString.formFieldPhoneNumberPlaceholder
    | AccountNumber => "DE00 0000 0000 0000 0000 00"
    | RoutingNumber => "DE00 0000 0000 0000 0000 00"
    | SortCode => "10-80-00"
    | BsbNumber => "BSB Number"
    | BecsSortCode => "10-80-00"
    | Iban => "IBAN"
    | BlikCode => localeString.payment_methods_blik
    | BankName => localeString.formFieldBankNamePlaceholder
    | SourceBankAccountId => "DE00 0000 0000 0000 0000 00"
    | DateOfBirth => localeString.dateOfBirthPlaceholderText
    | PayCurrency => field.displayName
    | VpaId => "Eg: johndoe@upi"
    | SocialSecurityNumber => "000.000.000-00"
    | Cvc => localeString.cvcTextLabel
    | _ => field.displayName
    }
  }

  let fieldName = field.name->getFieldNameFromPath
  let parent = getFieldNameFromPath(field.name, ~level=2)
  let fieldNameType = SuperpositionTypes.stringToFieldName(fieldName)

  let name = switch fieldNameType {
  | PhoneNumberWithCountryCode
  | Number if parent == "phone" =>
    getParentPathFromOutputPath(field.name)
  | _ => field.name
  }

  let getFieldFromMergedFields = index =>
    field.mergedFields->Array.get(index)->Option.getOr(defaultFieldConfig)

  let validateField = (value, field) => {
    let res = switch value {
    | Some(val) =>
      switch (field.fieldType, field.fieldName) {
      | (EmailInput, _) =>
        if val->EmailValidation.isEmailValid->Option.getOr(false) {
          Nullable.null
        } else {
          Nullable.make(localeString.emailInvalidText)
        }
      | (PhoneInput, _) => {
          let phoneNo =
            val
            ->Identity.anyTypeToJson
            ->Utils.getDictFromJson
            ->Utils.getString("number", "")
            ->String.trim
          if phoneNo->String.length == 0 {
            Nullable.make("Invalid phone number")
          } else {
            Nullable.null
          }
        }
      | _ =>
        Console.log3("Validating generic field:", field.fieldName, val)
        if val != "adslg" {
          Nullable.make(localeString.emailInvalidText)
        } else {
          Nullable.null
        }
      }

    | None => Nullable.null
    }
    Promise.resolve(res)
  }

  switch fieldNameType {
  | CityStateMerged =>
    <div className="flex gap-4 w-full">
      {
        let field = getFieldFromMergedFields(0)
        let fieldName = getFieldNameFromPath(field.name)
        let fieldType = field.fieldType
        let options = field.options->DropdownField.updateArrayOfStringToOptionsTypeArray

        <ReactFinalForm.Field
          name=field.name key={fieldIndex ++ "city"} validate={(v, _) => validateField(v, field)}>
          {({input, meta}) => {
            <InputFields.InputFieldRendrer
              name={field.name}
              input
              meta
              inputRef=dummyRef
              label={getFieldNameFromLocale(SuperpositionTypes.stringToFieldName(fieldName))}
              placeholder={getPlaceholderFromLocale(
                SuperpositionTypes.stringToFieldName(fieldName),
              )}
              fieldType
              options
            />
          }}
        </ReactFinalForm.Field>
      }
      {
        let field = getFieldFromMergedFields(1)
        let fieldName = getFieldNameFromPath(field.name)
        let fieldType = field.fieldType
        let options = field.options->DropdownField.updateArrayOfStringToOptionsTypeArray

        <ReactFinalForm.Field
          name=field.name key={fieldIndex ++ "state"} validate={(v, _) => validateField(v, field)}>
          {({input, meta}) => {
            <InputFields.InputFieldRendrer
              name={field.name}
              input
              meta
              inputRef=dummyRef
              label={getFieldNameFromLocale(SuperpositionTypes.stringToFieldName(fieldName))}
              placeholder={getPlaceholderFromLocale(
                SuperpositionTypes.stringToFieldName(fieldName),
              )}
              fieldType
              options
            />
          }}
        </ReactFinalForm.Field>
      }
    </div>
  | ZipCountryMerged =>
    <div className="flex gap-4 w-full">
      {
        let field = getFieldFromMergedFields(0)
        let fieldName = getFieldNameFromPath(field.name)
        let fieldType = field.fieldType
        let options = field.options->DropdownField.updateArrayOfStringToOptionsTypeArray

        <ReactFinalForm.Field
          name=field.name key={fieldIndex ++ "zip"} validate={(v, _) => validateField(v, field)}>
          {({input, meta}) => {
            <InputFields.InputFieldRendrer
              name={field.name}
              input
              meta
              inputRef=dummyRef
              label={getFieldNameFromLocale(SuperpositionTypes.stringToFieldName(fieldName))}
              placeholder={getPlaceholderFromLocale(
                SuperpositionTypes.stringToFieldName(fieldName),
              )}
              fieldType
              options
            />
          }}
        </ReactFinalForm.Field>
      }
      {
        let field = getFieldFromMergedFields(1)
        let fieldName = getFieldNameFromPath(field.name)
        let fieldType = field.fieldType
        let options = field.options->DropdownField.updateArrayOfStringToOptionsTypeArray

        <ReactFinalForm.Field
          name=field.name
          key={fieldIndex ++ "country"}
          validate={(v, _) => validateField(v, field)}>
          {({input, meta}) => {
            <InputFields.InputFieldRendrer
              name={field.name}
              input
              meta
              inputRef=dummyRef
              label={getFieldNameFromLocale(SuperpositionTypes.stringToFieldName(fieldName))}
              placeholder={getPlaceholderFromLocale(
                SuperpositionTypes.stringToFieldName(fieldName),
              )}
              fieldType
              options
            />
          }}
        </ReactFinalForm.Field>
      }
    </div>
  | PhoneNumberWithCountryCode =>
    <ReactFinalForm.Field name key={fieldIndex} validate={(v, _) => validateField(v, field)}>
      {({input, meta}) => {
        let fieldType = field.fieldType
        let options = field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
        <InputFields.InputFieldRendrer
          name={fieldName}
          input
          meta
          inputRef=dummyRef
          label={getFieldNameFromLocale(SuperpositionTypes.stringToFieldName(fieldName))}
          placeholder={getPlaceholderFromLocale(SuperpositionTypes.stringToFieldName(fieldName))}
          fieldType
          options
        />
      }}
    </ReactFinalForm.Field>
  | _ =>
    <ReactFinalForm.Field name key={fieldIndex} validate={(v, _) => validateField(v, field)}>
      {({input, meta}) => {
        let fieldType = field.fieldType
        let options = field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
        <InputFields.InputFieldRendrer
          name={fieldName}
          input
          meta
          inputRef=dummyRef
          label={getFieldNameFromLocale(SuperpositionTypes.stringToFieldName(fieldName))}
          placeholder={getPlaceholderFromLocale(SuperpositionTypes.stringToFieldName(fieldName))}
          fieldType
          options
        />
      }}
    </ReactFinalForm.Field>
  }
}
