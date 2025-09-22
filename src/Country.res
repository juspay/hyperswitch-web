type windowsTimeZones = {
  id: string,
  name: string,
}
type timezoneType = {
  isoAlpha3?: string,
  timeZones: array<string>,
  countryName: string,
  isoAlpha2: string,
}

type state = {
  name: string,
  code: string,
}

type countryStateData = {
  countries: array<timezoneType>,
  states: JSON.t,
}

let defaultTimeZone = {
  isoAlpha3: "",
  timeZones: [],
  countryName: "-",
  isoAlpha2: "",
}

let sofortCountries = [
  {
    isoAlpha3: "AUT",
    timeZones: ["Europe/Vienna"],
    countryName: "Austria",
    isoAlpha2: "AT",
  },
  {
    isoAlpha3: "BEL",
    timeZones: ["Europe/Brussels"],
    countryName: "Belgium",
    isoAlpha2: "BE",
  },
  {
    isoAlpha3: "DEU",
    timeZones: ["Europe/Berlin", "Europe/Busingen"],
    countryName: "Germany",
    isoAlpha2: "DE",
  },
  {
    isoAlpha3: "ITA",
    timeZones: ["Europe/Rome"],
    countryName: "Italy",
    isoAlpha2: "IT",
  },
  {
    isoAlpha3: "NLD",
    timeZones: ["Europe/Amsterdam"],
    countryName: "Netherlands",
    isoAlpha2: "NL",
  },
  {
    isoAlpha3: "ESP",
    timeZones: ["Europe/Madrid", "Africa/Ceuta", "Atlantic/Canary"],
    countryName: "Spain",
    isoAlpha2: "ES",
  },
]

let getCountry = (paymentMethodName, countryList: array<timezoneType>) => {
  switch paymentMethodName {
  | "sofort" => sofortCountries
  | _ => countryList
  }
}
