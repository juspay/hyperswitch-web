let countryAndCodeCodeList =
  Utils.phoneNumberJson
  ->JSON.Decode.object
  ->Option.getOr(Dict.make())
  ->Utils.getArray("countries")

let phoneNumberCodeOptions = countryAndCodeCodeList->Array.reduce([], (acc, countryObj) => {
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

let getCountryCodeSplitValue = val => val->String.split("#")->Array.get(1)->Option.getOr("")

let monthNames = [
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

let monthSelectOptions = monthNames->Array.mapWithIndex((monthName, index) => {
  let monthNumber = index + 1
  let monthString = if monthNumber < 10 {
    "0" ++ monthNumber->Int.toString
  } else {
    monthNumber->Int.toString
  }
  let displayText = `${monthName} (${monthString})`

  let monthOption: DropdownField.optionType = {
    label: displayText,
    displayValue: displayText,
    value: monthString,
  }
  monthOption
})

let convertBankTypeToOptionType = list => {
  list->Array.map((bank: Bank.bank) => {
    let option: DropdownField.optionType = {
      label: bank.displayName,
      displayValue: bank.displayName,
      value: bank.value,
    }
    option
  })
}

let getBanks = name => Bank.getBanks(name)->convertBankTypeToOptionType

let getDynamicOptions = (field: SuperpositionTypes.fieldConfig) => {
  switch field.name {
  | "bank_redirect.open_banking_czech_republic.issuer" => getBanks("online_banking_czech_republic")
  | "bank_redirect.open_banking_poland.issuer" => getBanks("online_banking_poland")
  | "bank_redirect.open_banking_slovakia.issuer" => getBanks("online_banking_slovakia")
  | "bank_redirect.open_banking_uk.issuer" => getBanks("online_banking_uk")
  | "bank_redirect.open_banking_fpx.issuer" => getBanks("online_banking_fpx")
  | "bank_redirect.open_banking_thailand.issuer" => getBanks("online_banking_thailand")
  | "bank_redirect.ideal.bank_name" => getBanks("ideal")
  | "bank_redirect.eps.bank_name" => getBanks("eps")
  | "bank_redirect.przelewy24.bank_name" => getBanks("przelewy24")
  | "card.card_network" =>
    Validation.cardPatterns
    ->Array.map(val => val.issuer)
    ->DropdownField.updateArrayOfStringToOptionsTypeArray
  | _ => field.options->DropdownField.updateArrayOfStringToOptionsTypeArray
  }
}
