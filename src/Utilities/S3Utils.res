open Country

let decodeCountryArray = data => {
  data->Array.map(item => {
    switch item->JSON.Decode.object {
    | Some(res) => {
        isoAlpha3: Utils.getString(res, "isoAlpha3", ""),
        isoAlpha2: Utils.getString(res, "isoAlpha2", ""),
        timeZones: Utils.getStrArray(res, "timeZones"),
        countryName: Utils.getString(res, "value", ""),
      }
    | None => defaultTimeZone
    }
  })
}

let decodeJsonTocountryStateData = jsonData => {
  switch jsonData->JSON.Decode.object {
  | Some(res) => {
      let countryArr =
        res
        ->Dict.get("country")
        ->Option.flatMap(JSON.Decode.array)
        ->Option.getOr([])

      let statesDict =
        res
        ->Dict.get("states")
        ->Option.getOr(JSON.Encode.object(Dict.make()))

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
  Utils.fetchApi(endpoint, ~method=#GET)
  ->GZipUtils.extractJson
  ->Promise.then(data => {
    let val = decodeJsonTocountryStateData(data)
    switch val {
    | Some(res) => Promise.resolve(res)
    | None => Promise.reject(Failure("Failed to decode country state data"))
    }
  })
}

let getBaseUrl = () => {
  GlobalVars.isRunningInLocal ? "" : GlobalVars.sdkUrl
}

let getCountryStateData = async (
  ~locale="en",
  ~logger=HyperLogger.make(~source=Elements(Payment)),
) => {
  try {
    let normalizedLocale = getNormalizedLocale(locale)
    let endpoint = `${getBaseUrl()}/assets/v1/location/${normalizedLocale}`

    try {
      await fetchCountryStateFromS3(endpoint)
    } catch {
    | _ =>
      try {
        await fetchCountryStateFromS3(`${getBaseUrl()}/assets/v1/location/en`)
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
              states: JSON.Encode.object(Dict.make()),
            }
          }
        }
      }
    }
  } catch {
  | error => {
      logger.setLogError(
        ~value=`Unexpected error in getCountryStateData: ${Js.String.make(error)}`,
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
          states: JSON.Encode.object(Dict.make()),
        }
      }
    }
  }
}

let countryDataRef = ref(None)

let initializeCountryData = async () => {
  switch countryDataRef.contents {
  | None => {
      let data = await getCountryStateData()
      countryDataRef.contents = Some(data)
      data
    }
  | Some(data) => data
  }
}
let _ = initializeCountryData()

let countryListData = switch countryDataRef.contents {
| Some(data) => data.countries
| None => country
}
