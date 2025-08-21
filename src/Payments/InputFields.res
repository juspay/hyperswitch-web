open Utils
open PaymentType

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
    let getCountryCodeSplitValue = val => val->String.split("#")->Array.get(1)->Option.getOr("")
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
    <PaymentField
      fieldName="Phone Number"
      value={{
        value: input.value->JSON.Decode.string->Option.getOr(""),
        isValid: Some(meta.valid),
        errorString: meta.error->Nullable.toOption->Option.getOr(""),
      }}
      onChange=input.onChange
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
    ~input: ReactFinalForm.fieldRenderPropsInput,
    ~meta: ReactFinalForm.fieldRenderPropsMeta,
    ~inputRef,
    ~fieldName,
    ~placeholder,
    ~fieldType,
    ~options,
  ) => {
    let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let isSpacedInnerLayout = config.appearance.innerLayout === Spaced

    let errorString = switch (meta.touched, meta.error->Nullable.toOption) {
    | (true, Some(err)) => err
    | _ => ""
    }

    switch fieldType {
    | "email_input" =>
      <PaymentField
        fieldName
        value={{
          value: input.value->JSON.Decode.string->Option.getOr(""),
          isValid: errorString == "" ? Some(true) : Some(false),
          errorString,
        }}
        onChange=input.onChange
        onBlur=input.onBlur
        type_="text"
        inputRef
        placeholder
      />
    | "password_input"
    | "number"
    | "text_input" =>
      <PaymentField
        fieldName
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

    | "country_select" =>
      <DropdownField
        appearance=config.appearance
        fieldName=localeString.countryLabel
        value={input.value->JSON.Decode.string->Option.getOr("")}
        onChange=input.onChange
        setValue={_ => ()}
        disabled=false
        options
        className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
      />

    | "dropdown_select" =>
      <DropdownField
        appearance=config.appearance
        fieldName
        value={input.value->JSON.Decode.string->Option.getOr("")}
        onChange=input.onChange
        setValue={_ => ()}
        disabled=false
        options
        className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
      />

    | _ => <div> {fieldName->React.string} </div>
    }
  }
}
