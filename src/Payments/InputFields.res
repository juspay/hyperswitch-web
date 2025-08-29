open Utils
open PaymentType

let months = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
]

let currentYear = Date.getFullYear(Date.make())
let length = 100
let cardExpiryYears = Array.fromInitializer(~length, i => currentYear + i)

let getDropdownOptions = fieldType => {
  switch fieldType {
  | "month_select" => months->DropdownField.updateArrayOfStringToOptionsTypeArray
  | "year_select" =>
    cardExpiryYears
    ->Array.map(val => val->Int.toString)
    ->DropdownField.updateArrayOfStringToOptionsTypeArray
  | _ => [DropdownField.defaultValue]
  }
}

module PhoneInput = {
  @react.component
  let make = (
    ~input: ReactFinalForm.fieldRenderPropsInput,
    ~meta: ReactFinalForm.fieldRenderPropsMeta,
    ~inputRef,
  ) => {
    let (displayValue, setDisplayValue) = React.useState(_ => "")

    let countryAndCodeCodeList =
      phoneNumberJson
      ->JSON.Decode.object
      ->Option.getOr(Dict.make())
      ->getArray("countries")
    let clientTimeZone = CardUtils.dateTimeFormat().resolvedOptions().timeZone
    let clientCountry = getClientCountry(clientTimeZone)
    let currentCountryCode = Utils.getCountryCode(clientCountry.countryName)
    let defaultCountryCodeFilteredValue =
      countryAndCodeCodeList
      ->Array.filter(countryObj => {
        countryObj->getDictFromJson->getString("country_code", "") === currentCountryCode.isoAlpha2
      })
      ->Array.get(0)
      ->Option.getOr(
        {
          "phone_number_code": "",
        }->Identity.anyTypeToJson,
      )
      ->getDictFromJson
      ->getString("phone_number_code", "")
    let (valueDropDown, setValueDropDown) = React.useState(_ => defaultCountryCodeFilteredValue)
    let phoneNumberCodeOptions: array<
      DropdownField.optionType,
    > = countryAndCodeCodeList->Array.reduce([], (acc, countryObj) => {
      let countryObjDict = countryObj->getDictFromJson
      let countryFlag = countryObjDict->getString("country_flag", "")
      let phoneNumberCode = countryObjDict->getString("phone_number_code", "")
      let countryName = countryObjDict->getString("country_name", "")

      let phoneNumberOptionsValue: DropdownField.optionType = {
        label: `${countryFlag} ${countryName} ${phoneNumberCode}`,
        displayValue: `${countryFlag} ${phoneNumberCode}`,
        value: `${countryFlag}#${phoneNumberCode}`,
      }
      acc->Array.push(phoneNumberOptionsValue)
      acc
    })

    let handlePhoneNumberChange = ev => {
      let typedInput = input->ReactFinalForm.toTypedField

      typedInput.onChange({
        "number": ReactEvent.Form.target(ev)["value"],
        "country_code": valueDropDown->String.split("#")->Array.get(1)->Option.getOr(""),
      })
    }

    React.useEffect(() => {
      let findDisplayValue =
        phoneNumberCodeOptions
        ->Array.find(ele => ele.value === valueDropDown)
        ->Option.getOr(DropdownField.defaultValue)
      setDisplayValue(_ =>
        findDisplayValue.displayValue->Option.getOr(
          findDisplayValue.label->Option.getOr(findDisplayValue.value),
        )
      )
      None
    }, [phoneNumberCodeOptions])

    React.useEffect(() => {
      let typedInput = input->ReactFinalForm.toTypedField

      typedInput.onChange({
        "number": input.value->Utils.getDictFromJson->getString("number", ""),
        "country_code": valueDropDown->String.split("#")->Array.get(1)->Option.getOr(""),
      })
      None
    }, [valueDropDown])

    <PaymentField
      fieldName="Phone Number"
      value={{
        value: input.value->Utils.getDictFromJson->getString("number", ""),
        isValid: Some(meta.valid),
        errorString: meta.error->Nullable.toOption->Option.getOr(""),
      }}
      onChange=handlePhoneNumberChange
      paymentType=Payment
      type_="tel"
      name="phone"
      inputRef
      placeholder="000 000 000"
      maxLength=14
      dropDownOptions=phoneNumberCodeOptions
      valueDropDown
      setValueDropDown
      displayValue
      setDisplayValue
      onBlur=input.onBlur
    />
  }
}

module InputFieldRendrer = {
  @react.component
  let make = (
    ~name: string,
    ~input: ReactFinalForm.fieldRenderPropsInput,
    ~meta: ReactFinalForm.fieldRenderPropsMeta,
    ~inputRef,
    ~label,
    ~placeholder,
    ~fieldType,
    ~options,
  ) => {
    let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let isSpacedInnerLayout = config.appearance.innerLayout === Spaced

    let getInputLabel = fieldType => {
      switch fieldType {
      | "country_select" => localeString.countryLabel
      | _ => label
      }
    }

    let errorString = switch (meta.touched, meta.error->Nullable.toOption) {
    | (true, Some(err)) => err
    | _ => ""
    }

    switch fieldType {
    | "email_input" =>
      <PaymentField
        fieldName=label
        value={{
          value: input.value->JSON.Decode.string->Option.getOr(""),
          isValid: errorString == "" ? Some(true) : Some(false),
          errorString,
        }}
        onChange=input.onChange
        onBlur=input.onBlur
        type_="email"
        inputRef
        placeholder
      />
    | "password_input" =>
      <PaymentField
        fieldName=label
        value={{
          value: input.value->JSON.Decode.string->Option.getOr(""),
          isValid: Some(meta.valid),
          errorString: meta.error->Nullable.toOption->Option.getOr(""),
        }}
        onChange=input.onChange
        onBlur=input.onBlur
        type_="password"
        inputRef
        placeholder
      />
    | "text_input"
    | "number" =>
      <PaymentField
        fieldName=label
        value={{
          value: input.value->JSON.Decode.string->Option.getOr(""),
          isValid: Some(meta.valid),
          errorString: meta.error->Nullable.toOption->Option.getOr(""),
        }}
        onChange=input.onChange
        onBlur=input.onBlur
        type_="text"
        inputRef
        placeholder
      />
    | "phone_input" => <PhoneInput input meta inputRef />
    | "month_select"
    | "currency_select"
    | "country_code_select"
    | "year_select"
    | "dropdown_select"
    | "country_select" =>
      let typedInput = input->ReactFinalForm.toTypedField
      let options = options->Array.length > 0 ? options : getDropdownOptions(fieldType)

      <DropdownField
        appearance=config.appearance
        fieldName={getInputLabel(fieldType)}
        value={typedInput.value}
        setValue={fn => typedInput.onChange(fn())}
        disabled=false
        options
        className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
      />

    | "date_picker" =>
      <PaymentField
        fieldName=label
        value={{
          value: input.value->JSON.Decode.string->Option.getOr(""),
          isValid: Some(meta.valid),
          errorString: meta.error->Nullable.toOption->Option.getOr(""),
        }}
        onChange=input.onChange
        onBlur=input.onBlur
        type_="date"
        inputRef
        placeholder
      />

    | _ => <div> {label->React.string} </div>
    }
  }
}
