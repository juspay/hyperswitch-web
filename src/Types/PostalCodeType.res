type postalCodes = {
  iso: string,
  format: string,
  regex: string,
}
let defaultPostalCode = {
  iso: "",
  format: "",
  regex: "",
}

type themeDataModule = {default: array<postalCodes>}
open Promise

@val
external importPostalCode: string => t<themeDataModule> = "import"
