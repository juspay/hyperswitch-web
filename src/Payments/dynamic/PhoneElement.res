open SuperpositionTypes
open Validation
open DynamicFieldsSuperpositonUtils

module PhoneField = {
  @react.component
  let make = (~countryCodeConfig, ~phoneNumberConfig) => {
    let phoneRef = React.useRef(Nullable.null)
    let clientTimeZone = CardUtils.dateTimeFormat().resolvedOptions().timeZone
    let clientCountry = Utils.getClientCountry(clientTimeZone)
    let currentCountryCode = Utils.getCountryCode(clientCountry.countryName)
    let (displayValue, setDisplayValue) = React.useState(_ => "")

    let defaultCountryCodeFilteredValue = {
      let defaultCountryData =
        countryAndCodeCodeList
        ->Array.filter(countryObj => {
          countryObj->Utils.getDictFromJson->Utils.getString("country_code", "") ===
            currentCountryCode.isoAlpha2
        })
        ->Array.get(0)
        ->Option.getOr(
          {
            "phone_number_code": "",
            "country_flag": "",
          }->Identity.anyTypeToJson,
        )
        ->Utils.getDictFromJson

      let phoneCode = defaultCountryData->Utils.getString("phone_number_code", "")
      let countryFlag = defaultCountryData->Utils.getString("country_flag", "")
      `${countryFlag}#${phoneCode}`
    }

    let (valueDropDown, setValueDropDown) = React.useState(_ => defaultCountryCodeFilteredValue)

    let createFieldValidator = rule =>
      createFieldValidator(rule, ~enabledCardSchemes=[], ~localeObject=LocaleDataType.defaultLocale)

    let {input: countryCodeInput, meta: countryCodeMeta} = ReactFinalForm.useField(
      countryCodeConfig.outputPath,
      ~config={
        initialValue: Some(valueDropDown->getCountryCodeSplitValue),
        validate: createFieldValidator(Required),
      },
    )

    let {input: phoneNumberInput, meta: phoneNumberMeta} = ReactFinalForm.useField(
      phoneNumberConfig.outputPath,
      ~config={
        initialValue: Some(""),
        validate: createFieldValidator(Phone),
      },
    )

    let changePhone = ev => {
      let val = ReactEvent.Form.target(ev)["value"]->String.replaceRegExp(%re("/\D|\s/g"), "")
      phoneNumberInput.onChange(val)
    }

    let handleCountryCodeChange = fn => {
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
    }, [valueDropDown])

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
  if fields->Array.length == 5 {
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
