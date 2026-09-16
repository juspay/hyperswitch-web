/*
 The country/timezone *shapes* and the empty default row, split out of Country.res: real
 country/state data is fetched from S3 at runtime and the bundled 25.8 KB table is only its
 offline fallback, so everything needing the types or the "-" placeholder row imports this
 module instead and the table is pulled in by a dynamic import only when the S3 fetch fails.
 */type windowsTimeZones = {
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
