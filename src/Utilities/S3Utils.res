open Country

let decodeCountryArray = data => {
  open Utils
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
  open Utils
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
  switch locale {
  | "auto" => Window.Navigator.language
  | "" => "en"
  | _ => locale
  }
}

let fetchCountryStateFromS3 = endpoint => {
  open Promise

  let headers = [("Accept-Encoding", "br, gzip")]->Dict.fromArray

  Utils.fetchApi(endpoint, ~method=#GET, ~headers)
  ->Promise.then(resp => resp->Fetch.Response.json)
  ->then(data => {
    let val = decodeJsonTocountryStateData(data)
    switch val {
    | Some(res) => resolve(res)
    | None => reject(Exn.anyToExnInternal("Failed to decode country state data"))
    }
  })
  ->catch(_ => reject(Exn.anyToExnInternal("Failed to fetch country state data")))
}

let getBaseUrl = GlobalVars.isLocal ? "" : GlobalVars.sdkUrl

let getCountryStateData = async (
  ~locale="en",
  ~logger=HyperLogger.make(~source=Elements(Payment)),
) => {
  let normalizedLocale = getNormalizedLocale(locale)
  let timestamp = Date.now()->Float.toString
  let endpoint = `${getBaseUrl}/assets/v1/jsons/location/${normalizedLocale}?v=${timestamp}`

  try {
    await fetchCountryStateFromS3(endpoint)
  } catch {
  | _ =>
    try {
      await fetchCountryStateFromS3(`${getBaseUrl}/assets/v1/jsons/location/en?v=${timestamp}`)
    } catch {
    | _ => {
        logger.setLogError(
          ~value="Failed to fetch country state data",
          ~eventName=S3_FETCH_COUNTRY_STATE_DATA,
          ~logType=ERROR,
          ~logCategory=USER_ERROR,
        )

        let fallbackCountries = country
        try {
          let fallbackStates = await Utils.importStates("./../States.json")
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

let initializeCountryData = async (
  ~locale="en",
  ~logger=HyperLogger.make(~source=Elements(Payment)),
) => {
  try {
    open CountryStateDataRefs
    let data = await getCountryStateData(~locale, ~logger)
    countryDataRef.contents = data.countries
    stateDataRef.contents = data.states
    data
  } catch {
  | _ => {countries: country, states: JSON.Encode.null}
  }
}
