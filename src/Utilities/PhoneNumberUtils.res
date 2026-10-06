@module("./Phone_number.json")
external phoneNumberJson: JSON.t = "default"

let validatePhoneNumber = (countryCode, number) => {
  let phoneNumberDict = phoneNumberJson->JSON.Decode.object->Option.getOr(Dict.make())
  let countriesArr =
    phoneNumberDict
    ->Dict.get("countries")
    ->Option.flatMap(JSON.Decode.array)
    ->Option.getOr([])
    ->Array.filterMap(JSON.Decode.object)

  let filteredArr = countriesArr->Array.filter(countryObj => {
    countryObj
    ->Dict.get("phone_number_code")
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("") == countryCode
  })
  switch filteredArr[0] {
  | Some(obj) =>
    let regex =
      obj->Dict.get("validation_regex")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
    RegExp.test(regex->RegExp.fromString, number)
  | None => false
  }
}
