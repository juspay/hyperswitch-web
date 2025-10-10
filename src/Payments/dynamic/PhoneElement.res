open SuperpositionTypes

module PhoneField = {
  @react.component
  let make = (~countryCodeConfig, ~phoneNumberConfig) => {
    let phoneRef = React.useRef(Nullable.null)
    let clientTimeZone = CardUtils.dateTimeFormat().resolvedOptions().timeZone
    let clientCountry = Utils.getClientCountry(clientTimeZone)
    let currentCountryCode = Utils.getCountryCode(clientCountry.countryName)
    let (displayValue, setDisplayValue) = React.useState(_ => "")

    let countryAndCodeCodeList =
      Utils.phoneNumberJson
      ->JSON.Decode.object
      ->Option.getOr(Dict.make())
      ->Utils.getArray("countries")

    let phoneNumberCodeOptions: array<
      DropdownField.optionType,
    > = countryAndCodeCodeList->Array.reduce([], (acc, countryObj) => {
      let countryObjDict = countryObj->Utils.getDictFromJson
      let countryFlag = countryObjDict->Utils.getString("country_flag", "")
      let phoneNumberCode = countryObjDict->Utils.getString("phone_number_code", "")
      let countryName = countryObjDict->Utils.getString("country_name", "")

      let phoneNumberOptionsValue: DropdownField.optionType = {
        label: `${countryFlag} ${countryName} ${phoneNumberCode}`,
        displayValue: `${countryFlag} ${phoneNumberCode}`,
        value: `${countryFlag}#${phoneNumberCode}`,
      }
      acc->Array.push(phoneNumberOptionsValue)
      acc
    })

    let defaultCountryCodeFilteredValue =
      countryAndCodeCodeList
      ->Array.filter(countryObj => {
        countryObj->Utils.getDictFromJson->Utils.getString("country_code", "") ===
          currentCountryCode.isoAlpha2
      })
      ->Array.get(0)
      ->Option.getOr(
        {
          "phone_number_code": "",
        }->Identity.anyTypeToJson,
      )
      ->Utils.getDictFromJson
      ->Utils.getString("phone_number_code", "")

    let (valueDropDown, setValueDropDown) = React.useState(_ => defaultCountryCodeFilteredValue)
    let getCountryCodeSplitValue = val => val->String.split("#")->Array.get(1)->Option.getOr("")

    let {input: countryCodeInput, meta: countryCodeMeta} = ReactFinalForm.useField(
      countryCodeConfig.name,
      ~config={
        initialValue: Some(valueDropDown->getCountryCodeSplitValue),
      },
    )

    let {input: phoneNumberInput, meta: phoneNumberMeta} = ReactFinalForm.useField(
      phoneNumberConfig.name,
      ~config={
        initialValue: Some(""),
      },
    )

    let changePhone = ev => {
      let val: string =
        ReactEvent.Form.target(ev)["value"]->String.replaceRegExp(%re("/\D|\s/g"), "")
      phoneNumberInput.onChange(val)
    }

    let handleCountryCodeChange = (fn: unit => string) => {
      let newValue = fn()
      setValueDropDown(_ => newValue)
      countryCodeInput.onChange(newValue->getCountryCodeSplitValue)
    }

    React.useEffect(() => {
      countryCodeInput.onChange(valueDropDown->getCountryCodeSplitValue)
      None
    }, [valueDropDown])

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

    let phoneErrorString = switch (phoneNumberMeta.touched, phoneNumberMeta.error) {
    | (true, Some(err)) => err
    | _ => ""
    }

    let isValid = Some(!(!phoneNumberMeta.valid && phoneNumberMeta.touched))

    <PaymentField
      fieldName="Phone Number"
      value={{
        value: phoneNumberInput.value->Option.getOr(""),
        isValid,
        errorString: phoneErrorString,
      }}
      onChange=changePhone
      onBlur=phoneNumberInput.onBlur
      onFocus=phoneNumberInput.onFocus
      type_="tel"
      name="phone"
      inputRef=phoneRef
      placeholder="000 000 000"
      maxLength=14
      dropDownOptions=phoneNumberCodeOptions
      valueDropDown
      setValueDropDown={fn => handleCountryCodeChange(fn)}
      displayValue
      setDisplayValue
    />
  }
}

@react.component
let make = (~fields: array<fieldConfig>) => {
  if fields->Array.length == 2 {
    switch fields {
    | [countryCodeConfig, phoneNumberConfig] => <PhoneField countryCodeConfig phoneNumberConfig />
    | _ => React.null
    }
  } else {
    fields
    ->Array.map(field => {
      <DynamicInputFields key={field.outputPath} field />
    })
    ->React.array
  }
}
