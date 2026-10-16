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
