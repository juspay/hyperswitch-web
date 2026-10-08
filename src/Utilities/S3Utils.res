open CountryDefault

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

let getCountryStateData = async (~logger=HyperLogger.make(~source=Elements(Payment))) => {
  let timestamp = Date.now()->Float.toString
  let endpoint = `${getBaseUrl}/assets/v1/jsons/location/en?v=${timestamp}`

  try {
    await fetchCountryStateFromS3(endpoint)
  } catch {
  | _ =>
    try {
      await fetchCountryStateFromS3(endpoint)
    } catch {
    | _ => {
        logger.setLogError(
          ~value="Failed to fetch country state data",
          ~eventName=S3_API,
          ~logType=ERROR,
          ~logCategory=USER_ERROR,
        )

        let fallbackCountries = await import(Country.country)
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

let initializeCountryData = async (~logger=HyperLogger.make(~source=Elements(Payment))) => {
  open CountryStateDataRefs
  try {
    let data = await getCountryStateData(~logger)
    countryDataRef.contents = data.countries
    stateDataRef.contents = data.states
    data
  } catch {
  | _ =>
    if countryDataRef.contents->Array.length > 0 {
      {countries: countryDataRef.contents, states: stateDataRef.contents}
    } else {
      let fallbackCountries = try {
        await import(Country.country)
      } catch {
      | _ => []
      }
      countryDataRef.contents = fallbackCountries
      stateDataRef.contents = JSON.Encode.null
      {countries: fallbackCountries, states: JSON.Encode.null}
    }
  }
}
