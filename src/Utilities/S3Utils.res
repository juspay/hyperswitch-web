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

let fetchCountryStateFromS3 = async (endpoint, ~fallbackFor=?) => {
  let event: SdkLoggerEvents.staticAssetEvent = switch fallbackFor {
  | Some(_) => CountryStateDataFallback
  | None => CountryStateData
  }
  let headers = [("Accept-Encoding", "br, gzip")]->Dict.fromArray
  let decoded = ref(None)
  let response = await SdkLogger.observeStaticAsset(
    ~event,
    ~url=endpoint,
    ~details=?fallbackFor->Option.map(locale => [
      ("fallback_for_locale", locale->JSON.Encode.string),
    ]),
    ~call=async () => {
      let response = await Utils.fetchApi(endpoint, ~method=#GET, ~headers)
      if response->Fetch.Response.ok {
        switch (await response->Fetch.Response.json)->decodeJsonTocountryStateData {
        | Some(data) => decoded := Some(data)
        | None => JsError.throwWithMessage("Failed to decode country state data")
        }
      }
      response
    },
  )
  switch decoded.contents {
  | Some(data) => data
  | None =>
    JsError.throwWithMessage(
      `Country state data request failed with status ${response
        ->Fetch.Response.status
        ->Int.toString}`,
    )
  }
}

let getBaseUrl = GlobalVars.isLocal ? "" : GlobalVars.sdkUrl

let pendingByLocale: Dict.t<promise<Country.countryStateData>> = Dict.make()

let loadCountryStateData = async (~locale) => {
  let normalizedLocale = getNormalizedLocale(locale)
  let timestamp = Date.now()->Float.toString
  let endpoint = `${getBaseUrl}/assets/v1/jsons/location/${normalizedLocale}?v=${timestamp}`

  try {
    try {
      await fetchCountryStateFromS3(endpoint)
    } catch {
    | _ =>
      await fetchCountryStateFromS3(
        `${getBaseUrl}/assets/v1/jsons/location/en?v=${timestamp}`,
        ~fallbackFor=normalizedLocale,
      )
    }
  } catch {
  | _ => {
      let fallbackCountries = country
      try {
        let fallbackStates = await Utils.importStates("./../States.json")
        SdkLogger.logLifecycle(~event=CountryDataServedFromBundle)
        {
          countries: fallbackCountries,
          states: fallbackStates.states,
        }
      } catch {
      | exn => {
          SdkLogger.logLifecycle(~event=CountryDataUnavailable, ~exn)
          {
            countries: fallbackCountries,
            states: JSON.Encode.null,
          }
        }
      }
    }
  }
}

let getCountryStateData = async (~locale="en") => {
  let key = locale->getNormalizedLocale
  switch pendingByLocale->Dict.get(key) {
  | Some(pending) => await pending
  | None => {
      let pending = loadCountryStateData(~locale)
      pendingByLocale->Dict.set(key, pending)
      await pending
    }
  }
}

let initializeCountryData = async (~locale="en") => {
  try {
    open CountryStateDataRefs
    let data = await getCountryStateData(~locale)
    countryDataRef.contents = data.countries
    stateDataRef.contents = data.states
    data
  } catch {
  | _ => {countries: country, states: JSON.Encode.null}
  }
}
