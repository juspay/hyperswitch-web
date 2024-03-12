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

@val
external importPostalCode: string => Promise.t<themeDataModule> = "import"
