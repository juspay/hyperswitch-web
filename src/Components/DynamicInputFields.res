open ReactFinalForm
open DynamicFieldsSuperpositonUtils

@react.component
let make = (~field: SuperpositionTypes.fieldConfig) => {
  let {config, localeString, themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced
  let inputRef = React.useRef(Nullable.null)
  let label = field.displayName
  let placeholder = field.displayName
  let createFieldValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=LocaleDataType.defaultLocale,
    )

  let options = DropdownField.updateArrayOfStringToOptionsTypeArray(
    field.options->Array.length > 0 ? field.options : [""],
  )
  let (countryCodeDisplayValue, setCountryCodeDisplayValue) = React.useState(_ => "")

  let countryList = CountryStateDataRefs.countryDataRef.contents

  let getCountryNames = () => {
    Utils.getCountryNames(Country.getCountry("", countryList))
  }

  let getStateNames = countryValue => {
    Utils.getStateNames({
      value: countryValue,
      isValid: None,
      errorString: "",
    })
  }

  let countryOptions = getCountryNames()->DropdownField.updateArrayOfStringToOptionsTypeArray
  let initialCountry = switch countryOptions->Array.get(0) {
  | Some(firstOption) => firstOption.value
  | None => ""
  }

  let initialStateOptions =
    getStateNames(initialCountry)->DropdownField.updateArrayOfStringToOptionsTypeArray
  let initialState = switch initialStateOptions->Array.get(0) {
  | Some(firstOption) => firstOption.value
  | None => ""
  }

  let (countryInput, currentCountry) = switch field.fieldType {
  | CountrySelect | StateSelect =>
    let {input: countryInput} = ReactFinalForm.useField(
      "billing.address.country",
      ~config={initialValue: Some(initialCountry)},
    )
    let currentCountry = countryInput.value->Option.getOr(initialCountry)
    (Some(countryInput), currentCountry)
  | _ => (None, initialCountry)
  }

  let dynamicOptions = switch field.fieldType {
  | StateSelect =>
    getStateNames(currentCountry)->DropdownField.updateArrayOfStringToOptionsTypeArray
  | CountrySelect => countryOptions
  | CountryCodeSelect => phoneNumberCodeOptions
  | MonthSelect => monthSelectOptions
  | DropdownSelect => getDynamicOptions(field)
  | _ => options
  }

  let getInitialValue = () => {
    switch field.fieldType {
    | StateSelect => initialState
    | CountrySelect => initialCountry
    | MonthSelect | CurrencySelect | CountryCodeSelect | YearSelect | DropdownSelect =>
      switch dynamicOptions->Array.get(0) {
      | Some(firstOption) => firstOption.value
      | None => ""
      }
    | _ => ""
    }
  }

  let {input, meta} = ReactFinalForm.useField(
    field.outputPath,
    ~config={
      initialValue: Some(getInitialValue()),
      validate: createFieldValidator(Required),
      format: switch field.fieldType {
      | CardNumberTextInput => Validation.formatValue(CardNumber)
      | TextInput if field.name->String.endsWith("card_cvc") => Validation.formatValue(CardCVC(""))
      | _ => (val, _name) => val
      },
    },
  )

  React.useEffect(() => {
    if field.fieldType === StateSelect {
      let newStateOptions =
        getStateNames(currentCountry)->DropdownField.updateArrayOfStringToOptionsTypeArray
      switch newStateOptions->Array.get(0) {
      | Some(firstState) =>
        let currentValue = input.value->Option.getOr("")
        let isCurrentValueValid =
          newStateOptions->Array.some(option => option.value === currentValue)
        if !isCurrentValueValid || currentValue === "" {
          input.onChange(firstState.value)
        }
      | None => input.onChange("")
      }
    }
    None
  }, [currentCountry])

  let errorString = switch (meta.touched, meta.error) {
  | (true, Some(err)) => err
  | _ => ""
  }

  let isValid = Some(!(!meta.valid && meta.touched))

  let handleChange = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    switch field.fieldType {
    | CardNumberTextInput => {
        let cleanValue = val->String.trim->String.replaceAll(" ", "")
        input.onChange(cleanValue)
      }
    | _ => input.onChange(val)
    }
  }

  let handlePhoneChange = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    let numericOnly =
      val
      ->String.split("")
      ->Array.filter(char => char >= "0" && char <= "9")
      ->Array.join("")
    input.onChange(numericOnly)
  }

  let handleStateChange = (fn: unit => string) => {
    let newValue = fn()
    input.onChange(newValue)
  }

  let handleCountryChange = (fn: unit => string) => {
    let newValue = fn()
    input.onChange(newValue)

    if field.fieldType === CountrySelect {
      switch countryInput {
      | Some(countryInput) => countryInput.onChange(newValue)
      | None => ()
      }
    }
  }

  let handleCountryCodeChange = fn => {
    let newValue = fn()
    setCountryCodeDisplayValue(_ => newValue)
    input.onChange(newValue->getCountryCodeSplitValue)
  }

  let fieldMaxLength = {
    switch field.fieldType {
    | EmailInput => 50
    | CardNumberTextInput => 28
    | _ => 60
    }
  }

  switch field.fieldType {
  | EmailInput =>
    <PaymentField
      fieldName=label
      value={{
        value: input.value->Option.getOr(""),
        isValid,
        errorString,
      }}
      onChange=handleChange
      onBlur={input.onBlur}
      onFocus=input.onFocus
      type_="email"
      inputRef
      placeholder
      maxLength=fieldMaxLength
    />
  | PasswordInput =>
    <PaymentField
      fieldName=label
      value={{
        value: input.value->Option.getOr(""),
        isValid,
        errorString,
      }}
      onChange=handleChange
      onBlur=input.onBlur
      onFocus=input.onFocus
      type_="password"
      inputRef
      placeholder
      maxLength=fieldMaxLength
    />

  | PhoneInput =>
    <PaymentInputField
      fieldName=label
      value={input.value->Option.getOr("")}
      onChange=handlePhoneChange
      errorString
      type_="tel"
      maxLength=16
      onBlur={input.onBlur}
      onFocus=input.onFocus
      inputRef
      isValid
      placeholder="234 567 8900"
    />
  | CountryCodeSelect =>
    <DropdownField
      appearance=config.appearance
      fieldName={label}
      value={countryCodeDisplayValue}
      setValue={handleCountryCodeChange}
      disabled=false
      options=dynamicOptions
      className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
    />
  | MonthSelect
  | CurrencySelect
  | YearSelect
  | DropdownSelect =>
    <DropdownField
      appearance=config.appearance
      fieldName={label}
      value={input.value->Option.getOr("")}
      setValue={fn => input.onChange(fn())}
      disabled=false
      options=dynamicOptions
      className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
    />
  | DatePicker if field.outputPath->String.includes("date_of_birth") =>
    <DateOfBirthElement field input meta />
  | DatePicker =>
    <PaymentField
      fieldName=label
      value={{
        value: input.value->Option.getOr(""),
        isValid,
        errorString,
      }}
      onChange=handleChange
      onBlur=input.onBlur
      onFocus=input.onFocus
      type_="date"
      inputRef
      placeholder
    />

  | StateSelect =>
    <DropdownField
      appearance=config.appearance
      fieldName={label}
      value={input.value->Option.getOr("")}
      setValue={fn => handleStateChange(fn)}
      disabled=false
      options=dynamicOptions
      className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
    />
  | CountrySelect =>
    <DropdownField
      appearance=config.appearance
      fieldName={label}
      value={input.value->Option.getOr("")}
      setValue={fn => handleCountryChange(fn)}
      disabled=false
      options=dynamicOptions
      className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
    />
  | CardNumberTextInput =>
    <PaymentField
      fieldName=label
      value={{
        value: input.value->Option.getOr(""),
        isValid,
        errorString,
      }}
      onChange=handleChange
      onBlur=input.onBlur
      onFocus=input.onFocus
      type_="text"
      inputRef
      placeholder
      maxLength=fieldMaxLength
    />
  | _ =>
    <PaymentField
      fieldName=label
      value={{
        value: input.value->Option.getOr(""),
        isValid,
        errorString,
      }}
      onChange=handleChange
      onBlur=input.onBlur
      onFocus=input.onFocus
      type_="text"
      inputRef
      placeholder
      maxLength=fieldMaxLength
    />
  // | _ => <div className="font-extrabold text-red-700 text-lg"> {label->React.string} </div>
  }
}
