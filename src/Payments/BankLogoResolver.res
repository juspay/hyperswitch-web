// Bank name (from a saved payment method) -> logo symbol id in public/icons/orca.svg.
//
// Lookup data lives in src/BankLogoMapping.json, generated from docs/Banks_list.json
// (the TrueLayer provider catalogue the backend's bank_name values come from).
// Resolution is exact + case-sensitive on purpose: a wrong brand is worse than a
// generic glyph. Unknown/missing names fall back to `defaultIcon` ("generic-bank").

@module("../BankLogoMapping.json")
external bankLogoMappingJson: JSON.t = "default"

let mappingDict = bankLogoMappingJson->Utils.getDictFromJson

let banksByName = mappingDict->Utils.getDictFromDict("banksByName")

let defaultIcon = mappingDict->Utils.getString("defaultIcon", "generic-bank")

let lookupIcon = bankName => banksByName->Dict.get(bankName)->Option.flatMap(JSON.Decode.string)

let resolveIconName = (~bankName: string): string => {
  switch lookupIcon(bankName) {
  | Some(iconName) => iconName
  | None =>
    // Light retry with trimmed/collapsed whitespace only — still an exact,
    // case-sensitive key lookup (no casefolding, no fuzzy/contains matching).
    let trimmedName = bankName->String.trim->String.replaceRegExp(/\s+/g, " ")
    lookupIcon(trimmedName)->Option.getOr(defaultIcon)
  }
}
