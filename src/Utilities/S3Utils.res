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

let fetchCountryStateFromS3 = async (endpoint, ~logger) => {
  let headers = [("Accept-Encoding", "br, gzip")]->Dict.fromArray

  let onSuccess = data => {
    switch decodeJsonTocountryStateData(data) {
    | Some(res) => res
    | None => Exn.raiseError("Failed to decode country state data")
    }
  }
  let onFailure = _ => Exn.raiseError("Failed to fetch country state data")

  await Utils.fetchApiWithLogging(
    endpoint,
    ~eventName=S3_API,
    ~logger,
    ~headers,
    ~method=#GET,
    ~onSuccess,
    ~onFailure,
  )
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
    await fetchCountryStateFromS3(endpoint, ~logger)
  } catch {
  | _ =>
    logger.setLogInfo(
      ~value="Falling back to default country state data locale",
      ~eventName=S3_API,
      ~logType=WARNING,
      ~logCategory=API,
    )
    try {
      await fetchCountryStateFromS3(
        `${getBaseUrl}/assets/v1/jsons/location/en?v=${timestamp}`,
        ~logger,
      )
    } catch {
    | _ => {
        logger.setLogError(
          ~value="Failed to fetch country state data",
          ~eventName=S3_API,
          ~logType=ERROR,
          ~logCategory=API,
        )

        let fallbackCountries = country
        try {
          let fallbackStates = await Utils.importStates("./../States.json")
          {
            countries: fallbackCountries,
            states: fallbackStates.states,
          }
        } catch {
        | err => {
            logger.setLogInfo(
              ~value=`Falling back to countries-only country state data after bundled states import failed: ${err
                ->Utils.formatException
                ->JSON.stringify}`,
              ~eventName=S3_API,
              ~logType=WARNING,
              ~logCategory=API,
            )
            {
              countries: fallbackCountries,
              states: JSON.Encode.null,
            }
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
  | err =>
    logger.setLogInfo(
      ~value=`Falling back to countries-only country state data after initialization failed: ${err
        ->Utils.formatException
        ->JSON.stringify}`,
      ~eventName=S3_API,
      ~logType=WARNING,
      ~logCategory=API,
    )
    {countries: country, states: JSON.Encode.null}
  }
}
