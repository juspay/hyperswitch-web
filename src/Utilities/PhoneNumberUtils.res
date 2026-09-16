/*
 Phone_number.json (62 KB raw) and the helpers that read it, split out of Utils.res: Utils.res
 is imported by ~80 modules, so a static @module import there put the table in every bundle.
 Only the three phone fields read it, and they sit behind lazy boundaries.
 */@module("./Phone_number.json")
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
