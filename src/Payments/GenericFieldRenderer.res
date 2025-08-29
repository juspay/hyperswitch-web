open SuperpositionHelper

@react.component
let make = (
  ~field: fieldConfig,
  ~fieldIndex: string,
  ~validateField: (option<'a>, fieldConfig) => promise<Nullable.t<string>>,
) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let dummyRef = React.useRef(Nullable.null)
  let getFieldNameFromLocale = (name: string): string => {
    switch name {
    | "email" => localeString.emailLabel
    | "line1" => localeString.line1Label
    | "line2" => localeString.line2Label
    | "city" => localeString.cityLabel
    | "state" => localeString.stateLabel
    | "zip" => localeString.postalCodeLabel
    | "country" => localeString.countryLabel
    | "full_name" => localeString.fullNameLabel
    | "first_name"
    | "last_name" =>
      field.displayName
    | "number" => localeString.formFieldPhoneNumberLabel
    | "phone_number_with_country_code" => localeString.formFieldPhoneNumberLabel
    | "account_number" => localeString.accountNumberText
    | "routing_number" => localeString.formFieldACHRoutingNumberLabel
    | "sort_code" => localeString.sortCodeText
    | "bsb_number" => "BSB Number"
    | "becs_sort_code" => localeString.sortCodeText
    | "iban" => "IBAN"
    | "blik_code" => localeString.payment_methods_blik
    | "bank_name" => localeString.formFieldBankNameLabel
    | "issuer" => field.displayName
    | "cnpj" => field.displayName
    | "cpf" => field.displayName
    | "key" => field.displayName
    | "source_bank_account_id" => "Source Bank Account ID"
    | "date_of_birth" => localeString.dateOfBirth
    | "language_preference" => field.displayName
    | "network" => field.displayName
    | "pay_currency" => localeString.payment_methods_crypto_currency
    | "vpa_id" => localeString.vpaIdLabel
    | "social_security_number" => localeString.socialSecurityNumberLabel
    | "cvc" => localeString.cvcTextLabel
    | "client_uid" => field.displayName
    | "msisdn" => field.displayName
    | "product_name" => field.displayName
    | _ => field.displayName
    }
  }

  let getPlaceholderFromLocale = (name: string): string => {
    switch name {
    | "email" => "Eg: johndoe@gmail.com"
    | "line1" => localeString.line1Placeholder
    | "line2" => localeString.line2Placeholder
    | "city" => localeString.cityLabel
    | "state" => localeString.stateLabel
    | "zip" => localeString.postalCodeLabel
    | "country" => localeString.countryLabel
    | "full_name" => localeString.fullNamePlaceholder
    | "first_name" => "First Name"
    | "last_name" => field.displayName
    | "number" => localeString.formFieldPhoneNumberPlaceholder
    | "phone_number_with_country_code" => localeString.formFieldPhoneNumberPlaceholder
    | "account_number" => "DE00 0000 0000 0000 0000 00"
    | "routing_number" => "DE00 0000 0000 0000 0000 00"
    | "sort_code" => "10-80-00"
    | "bsb_number" => "BSB Number"
    | "becs_sort_code" => "10-80-00"
    | "iban" => "IBAN"
    | "blik_code" => localeString.payment_methods_blik
    | "bank_name" => localeString.formFieldBankNamePlaceholder
    | "source_bank_account_id" => "DE00 0000 0000 0000 0000 00"
    | "date_of_birth" => localeString.dateOfBirthPlaceholderText
    | "pay_currency" => field.displayName
    | "vpa_id" => "Eg: johndoe@upi"
    | "social_security_number" => "000.000.000-00"
    | "cvc" => localeString.cvcTextLabel
    | _ => field.displayName
    }
  }

  let fieldName = getFieldNameFromOutputPath(field.name)
  let parent = getFieldNameFromOutputPath(field.name, ~level=2)

  let name = switch fieldName {
  | "phone_number_with_country_code" => getParentPathFromOutputPath(field.name)
  | "number" if parent == "phone" => getParentPathFromOutputPath(field.name)
  | _ => field.name
  }

  let fieldType = field.fieldType
  let options = field.options->DropdownField.updateArrayOfStringToOptionsTypeArray

  let getFieldFromMergedFields = index =>
    field.mergedFields->Array.get(index)->Option.getOr(defaultFieldConfig)

  switch fieldName {
  | "city_state_merged" =>
    <div className="flex gap-4 w-full">
      {
        let field = getFieldFromMergedFields(0)
        let fieldName = getFieldNameFromOutputPath(field.name)
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
              label={getFieldNameFromLocale(fieldName)}
              placeholder={getPlaceholderFromLocale(fieldName)}
              fieldType
              options
            />
          }}
        </ReactFinalForm.Field>
      }
      {
        let field = getFieldFromMergedFields(1)
        let fieldName = getFieldNameFromOutputPath(field.name)
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
              label={getFieldNameFromLocale(fieldName)}
              placeholder={getPlaceholderFromLocale(fieldName)}
              fieldType
              options
            />
          }}
        </ReactFinalForm.Field>
      }
    </div>
  | "zip_country_merged" =>
    <div className="flex gap-4 w-full">
      {
        let field = getFieldFromMergedFields(0)
        let fieldName = getFieldNameFromOutputPath(field.name)
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
              label={getFieldNameFromLocale(fieldName)}
              placeholder={getPlaceholderFromLocale(fieldName)}
              fieldType
              options
            />
          }}
        </ReactFinalForm.Field>
      }
      {
        let field = getFieldFromMergedFields(1)
        let fieldName = getFieldNameFromOutputPath(field.name)
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
              label={getFieldNameFromLocale(fieldName)}
              placeholder={getPlaceholderFromLocale(fieldName)}
              fieldType
              options
            />
          }}
        </ReactFinalForm.Field>
      }
    </div>
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
          label={getFieldNameFromLocale(fieldName)}
          placeholder={getPlaceholderFromLocale(fieldName)}
          fieldType
          options
        />
      }}
    </ReactFinalForm.Field>
  }
}
