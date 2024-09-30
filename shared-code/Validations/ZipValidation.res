let isValidZip = (~zipCode, ~country) => {
  let countryObj =
    Country.country
    ->Array.find(item => item.countryName === country)
    ->Option.getOr(Country.defaultTimeZone)
  let postalCode =
    PostalCodes.postalCode
    ->Array.find(item => item.iso == countryObj.isoAlpha2)
    ->Option.getOr(PostalCodes.defaultPostalCode)

  let isZipCodeValid = RegExp.test(postalCode.regex->Js.Re.fromString, zipCode)
  zipCode->String.length > 0 && isZipCodeValid
}
