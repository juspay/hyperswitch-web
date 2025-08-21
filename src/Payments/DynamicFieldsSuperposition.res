open SuperpositionHelper

@react.component
let make = (~componentWiseRequiredFields: array<(string, array<fieldConfig>)>, ~cardProps) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let dummyRef = React.useRef(Nullable.null)

  let validateField = (value, field) => {
    switch value {
    | Some(val) =>
      if val->String.trim == "" {
        Promise.resolve(Nullable.null)
      } else {
        switch field.fieldType {
        | "email_input" =>
          Console.log2("Validating email:", val)
          if val->EmailValidation.isEmailValid->Option.getOr(false) {
            Promise.resolve(Nullable.null)
          } else {
            Promise.resolve(Nullable.make(localeString.emailInvalidText))
          }
        | _ => Promise.resolve(Nullable.null)
        }
      }
    | None => Promise.resolve(Nullable.null)
    }
  }

  <>
    <ReactFinalForm.Form
      key="dynamic-fields-form"
      onSubmit={(_, _) => Promise.resolve(Nullable.null)}
      render={({handleSubmit}) =>
        <form onSubmit={handleSubmit}>
          {componentWiseRequiredFields
          ->Array.mapWithIndex((componentWithField, index) => {
            let (componentName, fields) = componentWithField
            switch componentName {
            | "card" =>
              <div key={index->Int.toString}>
                {fields
                ->Array.mapWithIndex((field, fieldIndex) => {
                  <ReactFinalForm.Field name=field.name key={fieldIndex->Int.toString}>
                    {({input, meta}) => {
                      let name = getFieldNameFromOutputPath(field.outputPath)
                      let fieldType = field.fieldType
                      let options =
                        field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                      switch name {
                      | "card_network" =>
                        let typedInput = ReactFinalForm.toTypedField(input)
                        <PaymentInputField
                          fieldName=localeString.cardNumberLabel
                          isValid=Some(true)
                          setIsValid={_ => ()}
                          value={input.value->JSON.Decode.string->Option.getOr("")}
                          onChange=typedInput.onChange
                          onBlur=input.onBlur
                          rightIcon={<Icon size=28 name="visa-light" />}
                          errorString={meta.error
                          ->Nullable.toOption
                          ->Option.getOr("")}
                          type_="tel"
                          maxLength=16
                          inputRef=dummyRef
                          placeholder="1234 1234 1234 1234"
                          autocomplete="cc-number"
                        />
                      | _ => React.null
                      }
                    }}
                  </ReactFinalForm.Field>
                })
                ->React.array}
              </div>
            | "billing"
            | "shipping" =>
              <div key={index->Int.toString}>
                {fields
                ->Array.mapWithIndex((field, fieldIndex) => {
                  <ReactFinalForm.Field
                    name=field.name
                    key={fieldIndex->Int.toString}
                    validate={(v, _) => validateField(v, field)}>
                    {({input, meta}) => {
                      let name = getFieldNameFromOutputPath(field.outputPath)
                      let fieldType = field.fieldType
                      let options =
                        field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                      switch name {
                      | "email" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.emailLabel
                          placeholder="Eg: johndoe@gmail.com"
                          fieldType
                          options
                        />
                      | "line1" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.line1Label
                          placeholder=localeString.line1Placeholder
                          fieldType
                          options
                        />
                      | "line2" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.line2Label
                          placeholder=localeString.line2Placeholder
                          fieldType
                          options
                        />
                      | "city" =>
                        <div>
                          <InputFields.InputFieldRendrer
                            input
                            meta
                            inputRef=dummyRef
                            fieldName=localeString.cityLabel
                            placeholder=localeString.cityLabel
                            fieldType
                            options
                          />
                        </div>
                      | "state" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.stateLabel
                          placeholder=localeString.stateLabel
                          fieldType
                          options
                        />
                      | "zip" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.postalCodeLabel
                          placeholder=localeString.postalCodeLabel
                          fieldType
                          options
                        />
                      | "country" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.countryLabel
                          placeholder=localeString.countryLabel
                          fieldType
                          options
                        />
                      | "first_name" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName="first_name"
                          placeholder="First Name"
                          fieldType
                          options
                        />
                      | "last_name" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName="last_name"
                          placeholder="Last Name"
                          fieldType
                          options
                        />
                      //TODO
                      | "number" if fieldType == "phone_input" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName="Phone Number"
                          placeholder="000 000 000"
                          fieldType
                          options
                        />
                      | _ => React.null
                      }
                    }}
                  </ReactFinalForm.Field>
                })
                ->React.array}
              </div>
            | "bank" =>
              <div key={index->Int.toString}>
                {fields
                ->Array.mapWithIndex((field, fieldIndex) => {
                  <ReactFinalForm.Field name=field.name key={fieldIndex->Int.toString}>
                    {({input, meta}) => {
                      let name = getFieldNameFromOutputPath(field.outputPath)
                      let fieldType = field.fieldType
                      let options =
                        field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                      switch name {
                      | "account_number" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.accountNumberText
                          placeholder="DE00 0000 0000 0000 0000 00"
                          fieldType
                          options
                        />
                      | "routing_number" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.formFieldACHRoutingNumberLabel
                          placeholder="DE00 0000 0000 0000 0000 00"
                          fieldType
                          options
                        />
                      | "sort_code" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.sortCodeText
                          placeholder="10-80-00"
                          fieldType
                          options
                        />
                      | "bsb_number" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName="BSB Number"
                          placeholder="BSB Number"
                          fieldType
                          options
                        />
                      | "becs_sort_code" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.sortCodeText
                          placeholder="10-80-00"
                          fieldType
                          options
                        />
                      | "iban" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName="IBAN"
                          placeholder="IBAN"
                          fieldType
                          options
                        />
                      //TODO
                      | "card_exp_month" =>
                        <InputFields.InputFieldRendrer
                          input meta inputRef=dummyRef fieldName="" placeholder="" fieldType options
                        />
                      //TODO
                      | "card_exp_year" =>
                        <InputFields.InputFieldRendrer
                          input meta inputRef=dummyRef fieldName="" placeholder="" fieldType options
                        />
                      //TODO
                      | "card_number" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.cardNumberLabel
                          placeholder=localeString.cardNumberLabel
                          fieldType
                          options
                        />
                      | "blik_code" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.payment_methods_blik
                          placeholder=localeString.payment_methods_blik
                          fieldType
                          options
                        />
                      //TODO
                      | "bank_name" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      //TODO
                      | "issuer" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      //TODO
                      | "cnpj" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      //TODO
                      | "cpf" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      //TODO
                      | "key" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      | "source_bank_account_id" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName="Source Bank Account ID"
                          placeholder="DE00 0000 0000 0000 0000 00"
                          fieldType
                          options
                        />
                      | _ => React.null
                      }
                    }}
                  </ReactFinalForm.Field>
                })
                ->React.array}
              </div>
            | "wallet" =>
              <div key={index->Int.toString}>
                {fields
                ->Array.mapWithIndex((field, fieldIndex) => {
                  <ReactFinalForm.Field name=field.name key={fieldIndex->Int.toString}>
                    {({input, meta}) => {
                      let name = getFieldNameFromOutputPath(field.outputPath)
                      let fieldType = field.fieldType
                      let options =
                        field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                      switch name {
                      | "date_of_birth" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.dateOfBirth
                          placeholder=localeString.dateOfBirthPlaceholderText
                          fieldType
                          options
                        />
                      //TODO
                      | "language_preference" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      | _ => React.null
                      }
                    }}
                  </ReactFinalForm.Field>
                })
                ->React.array}
              </div>
            | "crypto" =>
              <div key={index->Int.toString}>
                {fields
                ->Array.mapWithIndex((field, fieldIndex) => {
                  <ReactFinalForm.Field name=field.name key={fieldIndex->Int.toString}>
                    {({input, meta}) => {
                      let name = getFieldNameFromOutputPath(field.outputPath)
                      let fieldType = field.fieldType
                      let options =
                        field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                      switch name {
                      //TODO: is this same as card network?
                      | "network" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      //TODO
                      | "pay_currency" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.payment_methods_crypto_currency
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      | _ => React.null
                      }
                    }}
                  </ReactFinalForm.Field>
                })
                ->React.array}
              </div>
            | "upi" =>
              <div key={index->Int.toString}>
                {fields
                ->Array.mapWithIndex((field, fieldIndex) => {
                  <ReactFinalForm.Field name=field.name key={fieldIndex->Int.toString}>
                    {({input, meta}) => {
                      let name = getFieldNameFromOutputPath(field.outputPath)
                      let fieldType = field.fieldType
                      let options =
                        field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                      switch name {
                      | "vpa_id" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.vpaIdLabel
                          placeholder="Eg: johndoe@upi"
                          fieldType
                          options
                        />
                      | _ => React.null
                      }
                    }}
                  </ReactFinalForm.Field>
                })
                ->React.array}
              </div>
            | "voucher" =>
              <div key={index->Int.toString}>
                {fields
                ->Array.mapWithIndex((field, fieldIndex) => {
                  <ReactFinalForm.Field name=field.name key={fieldIndex->Int.toString}>
                    {({input, meta}) => {
                      let name = getFieldNameFromOutputPath(field.outputPath)
                      let fieldType = field.fieldType
                      let options =
                        field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                      switch name {
                      | "social_security_number" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.socialSecurityNumberLabel
                          placeholder="000.000.000-00"
                          fieldType
                          options
                        />
                      | _ => React.null
                      }
                    }}
                  </ReactFinalForm.Field>
                })
                ->React.array}
              </div>
            | "gift_card" =>
              <div key={index->Int.toString}>
                {fields
                ->Array.mapWithIndex((field, fieldIndex) => {
                  <ReactFinalForm.Field name=field.name key={fieldIndex->Int.toString}>
                    {({input, meta}) => {
                      let name = getFieldNameFromOutputPath(field.outputPath)
                      let fieldType = field.fieldType
                      let options =
                        field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                      switch name {
                      | "cvc" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.cvcTextLabel
                          placeholder=localeString.cvcTextLabel
                          fieldType
                          options
                        />
                      //TODO
                      | "number" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />

                      | _ => React.null
                      }
                    }}
                  </ReactFinalForm.Field>
                })
                ->React.array}
              </div>
            | "mobile_payment" =>
              <div key={index->Int.toString}>
                {fields
                ->Array.mapWithIndex((field, fieldIndex) => {
                  <ReactFinalForm.Field name=field.name key={fieldIndex->Int.toString}>
                    {({input, meta}) => {
                      let name = getFieldNameFromOutputPath(field.outputPath)
                      let fieldType = field.fieldType
                      let options =
                        field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                      switch name {
                      //TODO
                      | "client_uid" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      | "msisdn" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      | _ =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      }
                    }}
                  </ReactFinalForm.Field>
                })
                ->React.array}
              </div>
            | "other" =>
              <div key={index->Int.toString}>
                {fields
                ->Array.mapWithIndex((field, fieldIndex) => {
                  <ReactFinalForm.Field name=field.name key={fieldIndex->Int.toString}>
                    {({input, meta}) => {
                      let name = getFieldNameFromOutputPath(field.outputPath)
                      let fieldType = field.fieldType
                      let options =
                        field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
                      switch name {
                      | "email" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=localeString.emailLabel
                          placeholder="Eg: johndoe@gmail.com"
                          fieldType
                          options
                        />
                      //TODO
                      | "product_name" =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      //TODO
                      | _ =>
                        <InputFields.InputFieldRendrer
                          input
                          meta
                          inputRef=dummyRef
                          fieldName=field.displayName
                          placeholder=field.displayName
                          fieldType
                          options
                        />
                      }
                    }}
                  </ReactFinalForm.Field>
                })
                ->React.array}
              </div>
            | _ => React.null
            }
          })
          ->React.array}
          <ReactFinalForm.FormValuesSpy />
        </form>}
    />
  </>
}
