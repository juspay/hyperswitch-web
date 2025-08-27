open SuperpositionHelper

@react.component
let make = (
  ~componentWiseRequiredFields: array<(string, array<fieldConfig>)>,
  ~cardProps=?,
  ~expiryProps=?,
  ~cvcProps=?,
) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let dummyRef = React.useRef(Nullable.null)
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let (cardBrand, setCardBrand) = React.useState(_ => "")
  let (isCardValid, setIsCardValid) = React.useState(_ => None)
  let (isExpiryValid, setIsExpiryValid) = React.useState(_ => None)
  let (isCVCValid, setIsCVCValid) = React.useState(_ => None)
  let (currentCVC, setCurrentCVC) = React.useState(_ => "")

  let handleCardNumberChange = (originalOnChange, ev) => {
    let val = ReactEvent.Form.target(ev)["value"]
    let currentCardType = cardBrand->CardUtils.getCardType

    let formattedCard = val->CardUtils.formatCardNumber(currentCardType)
    let detectedBrand = formattedCard->CardUtils.getCardBrand

    setCardBrand(_ => detectedBrand)
    let clearValue = formattedCard->CardValidations.clearSpaces
    CardUtils.setCardValid(clearValue, detectedBrand, setIsCardValid)

    let target = ReactEvent.Form.target(ev)
    target["value"] = formattedCard

    originalOnChange({
      "card_number": formattedCard,
      "card_brand": detectedBrand,
    })
  }

  let getDynamicCardIcon = () => {
    let cardType = cardBrand->CardUtils.getCardType
    CardUtils.getCardBrandIcon(cardType, CardThemeType.Payment)
  }

  let getDynamicMaxLength = () => {
    CardUtils.getMaxLength(cardBrand)
  }

  let handleExpiryChange = (originalOnChange, ev) => {
    let val = ReactEvent.Form.target(ev)["value"]
    let formattedExpiry = val->CardValidations.formatCardExpiryNumber
    CardUtils.setExpiryValid(formattedExpiry, setIsExpiryValid)

    let target = ReactEvent.Form.target(ev)
    target["value"] = formattedExpiry

    originalOnChange(ev)
  }

  let handleCVCChange = (originalOnChange, ev) => {
    let val = ReactEvent.Form.target(ev)["value"]

    let formattedCVC = val->CardValidations.formatCVCNumber(cardBrand)

    setCurrentCVC(_ => formattedCVC)

    if (
      formattedCVC->String.length > 0 &&
        CardUtils.cvcNumberInRange(formattedCVC, cardBrand)->Array.includes(true)
    ) {
      setIsCVCValid(_ => Some(true))
    } else {
      setIsCVCValid(_ => None)
    }

    let target = ReactEvent.Form.target(ev)
    target["value"] = formattedCVC

    originalOnChange(ev)
  }

  let getDynamicCVCIcon = () => {
    let isCvcValidValue = CardUtils.getBoolOptionVal(isCVCValid)
    let (cardEmpty, cardComplete, cardInvalid) = CardUtils.useCardDetails(
      ~cvcNumber=currentCVC,
      ~isCvcValidValue,
      ~isCVCValid,
    )
    CardUtils.setRightIconForCvc(~cardEmpty, ~cardInvalid, ~color="#ff0000", ~cardComplete)
  }

  let validateField = (value, field) => {
    switch value {
    | Some(val) =>
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
    | None => Promise.resolve(Nullable.null)
    }
  }
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced

  let submitCallback = (ev: Window.event, form: ReactFinalForm.formApi) => {
    let json = ev.data->Utils.safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      let _ = form.submit()
    }
  }

  let handleFormSubmit = (values, form) => {
    Console.log2("Form values:", values)
    Console.log2("Form api:", form)
    Promise.resolve(Nullable.null)
  }

  <>
    <ReactFinalForm.Form
      key="dynamic-fields-form"
      onSubmit={handleFormSubmit}
      render={({handleSubmit, form}) => {
        Utils.useSubmitPaymentData(ev => submitCallback(ev, form))
        <form onSubmit={handleSubmit}>
          <div
            className="flex flex-col w-full place-content-between"
            style={
              gridColumnGap: themeObj.spacingGridRow,
            }>
            <div
              className={`flex flex-col`}
              style={
                gap: isSpacedInnerLayout ? themeObj.spacingGridRow : "",
              }>
              {componentWiseRequiredFields
              ->Array.mapWithIndex((componentWithField, _index) => {
                let (componentName, fields) = componentWithField
                switch componentName {
                | "card" =>
                  fields
                  ->Array.mapWithIndex((field, fieldIndex) => {
                    let name = getFieldNameFromOutputPath(field.outputPath)
                    <ReactFinalForm.Field name=field.name key={fieldIndex->Int.toString}>
                      {({input, meta}) => {
                        switch name {
                        | "card_number" =>
                          let typedInput = ReactFinalForm.toTypedField(input)
                          <PaymentInputField
                            fieldName=localeString.cardNumberLabel
                            isValid=isCardValid
                            setIsValid=setIsCardValid
                            value={input.value
                            ->Utils.getDictFromJson
                            ->Utils.getString("card_number", "")}
                            onChange={ev => handleCardNumberChange(typedInput.onChange, ev)}
                            onBlur=input.onBlur
                            rightIcon={getDynamicCardIcon()}
                            errorString={meta.error
                            ->Nullable.toOption
                            ->Option.getOr("")}
                            type_="tel"
                            maxLength={getDynamicMaxLength()}
                            inputRef=dummyRef
                            placeholder="1234 1234 1234 1234"
                            autocomplete="cc-number"
                          />
                        | "card_number_network_merged" =>
                          let typedInput = ReactFinalForm.toTypedField(input)
                          <PaymentInputField
                            fieldName=localeString.cardNumberLabel
                            isValid=isCardValid
                            setIsValid=setIsCardValid
                            value={input.value
                            ->Utils.getDictFromJson
                            ->Utils.getString("card_number", "")}
                            onChange={ev => handleCardNumberChange(typedInput.onChange, ev)}
                            onBlur=input.onBlur
                            rightIcon={getDynamicCardIcon()}
                            errorString={meta.error
                            ->Nullable.toOption
                            ->Option.getOr("")}
                            type_="tel"
                            maxLength={getDynamicMaxLength()}
                            inputRef=dummyRef
                            placeholder="1234 1234 1234 1234"
                            autocomplete="cc-number"
                          />
                        | "card_exp_month" =>
                          let typedInput = ReactFinalForm.toTypedField(input)
                          <PaymentInputField
                            fieldName=localeString.validThruText
                            isValid=isExpiryValid
                            setIsValid=setIsExpiryValid
                            value={input.value->JSON.Decode.string->Option.getOr("")}
                            onChange={ev => handleExpiryChange(typedInput.onChange, ev)}
                            onBlur=input.onBlur
                            errorString={meta.error
                            ->Nullable.toOption
                            ->Option.getOr("")}
                            type_="tel"
                            maxLength=7
                            inputRef=dummyRef
                            placeholder=localeString.expiryPlaceholder
                            autocomplete="cc-exp"
                          />
                        | "card_expiry_cvc_merged" =>
                          let typedInput = ReactFinalForm.toTypedField(input)
                          <PaymentInputField
                            fieldName=localeString.validThruText
                            isValid=isExpiryValid
                            setIsValid=setIsExpiryValid
                            value={input.value->JSON.Decode.string->Option.getOr("")}
                            onChange={ev => handleExpiryChange(typedInput.onChange, ev)}
                            onBlur=input.onBlur
                            errorString={meta.error
                            ->Nullable.toOption
                            ->Option.getOr("")}
                            type_="tel"
                            maxLength=7
                            inputRef=dummyRef
                            placeholder=localeString.expiryPlaceholder
                            autocomplete="cc-exp"
                          />
                        | "card_cvc" =>
                          let typedInput = ReactFinalForm.toTypedField(input)
                          <PaymentInputField
                            fieldName=localeString.cvcTextLabel
                            isValid=isCVCValid
                            setIsValid=setIsCVCValid
                            value={input.value->JSON.Decode.string->Option.getOr("")}
                            onChange={ev => handleCVCChange(typedInput.onChange, ev)}
                            onBlur=input.onBlur
                            rightIcon={getDynamicCVCIcon()}
                            errorString={meta.error
                            ->Nullable.toOption
                            ->Option.getOr("")}
                            type_="tel"
                            className="tracking-widest w-full"
                            maxLength=4
                            inputRef=dummyRef
                            placeholder="123"
                            autocomplete="cc-csc"
                          />
                        | _ => React.null
                        }
                      }}
                    </ReactFinalForm.Field>
                  })
                  ->React.array
                | "billing"
                | "shipping" =>
                  fields
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
                        | "full_name" =>
                          <InputFields.InputFieldRendrer
                            input
                            meta
                            inputRef=dummyRef
                            fieldName=localeString.fullNameLabel
                            placeholder=localeString.fullNamePlaceholder
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
                            fieldName=field.displayName
                            placeholder=field.displayName
                            fieldType
                            options
                          />
                        | "number" =>
                          <InputFields.InputFieldRendrer
                            input
                            meta
                            inputRef=dummyRef
                            fieldName=localeString.formFieldPhoneNumberLabel
                            placeholder=localeString.formFieldPhoneNumberPlaceholder
                            fieldType
                            options
                          />
                        | "phone_number_with_country_code" =>
                          <InputFields.InputFieldRendrer
                            input
                            meta
                            inputRef=dummyRef
                            fieldName=localeString.formFieldPhoneNumberLabel
                            placeholder=localeString.formFieldPhoneNumberPlaceholder
                            fieldType="phone_input"
                            options
                          />
                        | _ => React.null
                        }
                      }}
                    </ReactFinalForm.Field>
                  })
                  ->React.array
                | "bank" =>
                  fields
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
                            input
                            meta
                            inputRef=dummyRef
                            fieldName=field.displayName
                            placeholder=field.displayName
                            fieldType
                            options
                          />
                        //TODO
                        | "card_exp_year" =>
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
                  ->React.array
                | "wallet" =>
                  fields
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
                  ->React.array
                | "crypto" =>
                  fields
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
                  ->React.array
                | "upi" =>
                  fields
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
                  ->React.array
                | "voucher" =>
                  fields
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
                  ->React.array
                | "gift_card" =>
                  fields
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
                  ->React.array
                | "mobile_payment" =>
                  fields
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
                  ->React.array
                | "other" =>
                  fields
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
                  ->React.array
                | _ => React.null
                }
              })
              ->React.array}
              <ReactFinalForm.FormValuesSpy />
            </div>
          </div>
        </form>
      }}
    />
  </>
}
