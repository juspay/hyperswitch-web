open ReactFinalForm

@react.component
let make = (~field: SuperpositionTypes.fieldConfig) => {
  let {config, localeString, themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced
  let inputRef = React.useRef(Nullable.null)
  let label = field.displayName
  let placeholder = field.displayName

  let options = DropdownField.updateArrayOfStringToOptionsTypeArray(
    field.options->Array.length > 0 ? field.options : [""],
  )

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

  let initialCountryOptions = getCountryNames()->DropdownField.updateArrayOfStringToOptionsTypeArray
  let initialCountry = switch initialCountryOptions->Array.get(0) {
  | Some(firstOption) => firstOption.value
  | None => ""
  }

  let initialStateOptions =
    getStateNames(initialCountry)->DropdownField.updateArrayOfStringToOptionsTypeArray
  let initialState = switch initialStateOptions->Array.get(0) {
  | Some(firstOption) => firstOption.value
  | None => ""
  }

  let {input: countryInput} = ReactFinalForm.useField(
    "billing.address.country",
    ~config={initialValue: Some(initialCountry)},
  )
  let currentCountry = countryInput.value->Option.getOr(initialCountry)

  let dynamicOptions = switch field.fieldType {
  | StateSelect =>
    getStateNames(currentCountry)->DropdownField.updateArrayOfStringToOptionsTypeArray
  | CountrySelect => initialCountryOptions
  | _ => options
  }

  let getInitialValue = () => {
    switch field.fieldType {
    | StateSelect => initialState
    | CountrySelect => initialCountry
    | MonthSelect | CurrencySelect | CountryCodeSelect | YearSelect | DropdownSelect =>
      switch options->Array.get(0) {
      | Some(firstOption) => firstOption.value
      | None => ""
      }
    | _ => ""
    }
  }

  let {input, meta} = ReactFinalForm.useField(
    field.name,
    ~config={
      initialValue: Some(getInitialValue()),
    },
  )

  React.useEffect(() => {
    let currentValue = input.value->Option.getOr("")
    if currentValue === "" {
      let initialVal = getInitialValue()
      if initialVal !== "" {
        input.onChange(initialVal)
      }
    }
    None
  }, [])

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
    input.onChange(val)
  }

  let handleStateChange = (fn: unit => string) => {
    let newValue = fn()
    input.onChange(newValue)
  }

  let handleCountryChange = (fn: unit => string) => {
    let newValue = fn()
    input.onChange(newValue)

    if field.fieldType === CountrySelect {
      countryInput.onChange(newValue)
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
    />
  | TextInput =>
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
    />
  // | PhoneInput => <PhoneInput input meta errorString inputRef isValid />
  | MonthSelect
  | CurrencySelect
  | CountryCodeSelect
  | YearSelect
  | DropdownSelect =>
    <DropdownField
      appearance=config.appearance
      fieldName={label}
      value={input.value->Option.getOr("")}
      setValue={fn => input.onChange(fn())}
      disabled=false
      options
      className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
    />
  | DatePicker if field.name->String.includes("date_of_birth") => <DateOfBirthElement field />
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
  | _ => <div> {label->React.string} </div>
  }
}
