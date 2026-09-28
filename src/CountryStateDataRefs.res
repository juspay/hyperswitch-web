/*
 Starts empty on purpose: the real country/state data is fetched from S3 by
 S3Utils.initializeCountryData, and the bundled Country table is only the offline fallback,
 reached through a dynamic import there. Seeding this ref from Country.country would drag the
 25.8 KB table into every bundle that touches Utils.
 */
let countryDataRef: ref<array<CountryDefault.timezoneType>> = ref([])
let stateDataRef: ref<JSON.t> = ref(JSON.Encode.null)
