open Country
open Utils

let decodeCountryArray = data => {
  data->Array.map(item =>
    switch item->JSON.Decode.object {
    | Some(res) => {
        isoAlpha2: res->getString("isoAlpha2", ""),
        timeZones: res->getStrArray("timeZones"),
        countryName: res->getString("value", ""),
      }
    | None => defaultTimeZone
    }
  )
}

let decodeJsonTocountryStateData = jsonData => {
  switch jsonData->JSON.Decode.object {
  | Some(res) => {
      let countryArr = res->getArray("country")
      let statesDict = res->getJsonFromDict("states", JSON.Encode.null)
      Some({
        countries: decodeCountryArray(countryArr),
        states: statesDict,
      })
    }
  | None => None
  }
}

let getNormalizedLocale = locale => {
  if locale == "auto" {
    Window.Navigator.language
  } else if locale == "" {
    "en"
  } else {
    locale
  }
}

let fetchCountryStateFromS3 = endpoint => {
  open Promise
  Utils.fetchApi(endpoint, ~method=#GET)
  ->GZipUtils.extractJson
  ->then(data => {
    let val = decodeJsonTocountryStateData(data)
    switch val {
    | Some(res) => resolve(res)
    | None => reject(Exn.anyToExnInternal("Failed to decode country state data"))
    }
  })
  ->catch(_ => reject(Exn.anyToExnInternal("Failed to fetch country state data")))
}

let getBaseUrl = GlobalVars.isRunningLocally ? "" : GlobalVars.sdkUrl

let getCountryStateData = async (
  ~locale="en",
  ~logger=HyperLogger.make(~source=Elements(Payment)),
) => {
  let normalizedLocale = getNormalizedLocale(locale)
  let endpoint = `${getBaseUrl}}/assets/v1/location/${normalizedLocale}`

  try {
    await fetchCountryStateFromS3(endpoint)
  } catch {
  | _ =>
    try {
      await fetchCountryStateFromS3(`${getBaseUrl}/assets/v1/location/en`)
    } catch {
    | _ => {
        logger.setLogError(
          ~value="Failed to fetch country state data",
          ~eventName=S3_API,
          ~logType=ERROR,
          ~logCategory=USER_ERROR,
        )

        let fallbackCountries = country
        try {
          let fallbackStates = await AddressPaymentInput.importStates("./../States.json")
          {
            countries: fallbackCountries,
            states: fallbackStates.states,
          }
        } catch {
        | _ => {
            countries: fallbackCountries,
            states: JSON.Encode.null,
          }
        }
      }
    }
  }
}

let countryDataRef = ref(None)

let initializeCountryData = async () => {
  try {
    switch countryDataRef.contents {
    | Some(data) => data
    | None => {
        let data = await getCountryStateData()
        countryDataRef.contents = Some(data.countries)
        data.countries
      }
    }
  } catch {
  | _ => Country.country
  }
}
let _ = initializeCountryData()

let getCountryListData = () => {
  switch countryDataRef.contents {
  | Some(data) => data
  | None => country
  }
}
