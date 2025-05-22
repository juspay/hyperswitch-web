open Country
open Utils

type dataModule = {states: JSON.t}

@val
external importStates: string => promise<dataModule> = "import"

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
  let headers = Dict.make()
  headers->Dict.set("Accept-Encoding", "br, gzip")
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

let getBaseUrl = GlobalVars.isRunningLocally ? "" : GlobalVars.sdkUrl

let getCountryStateData = async (
  ~locale="en",
  ~logger=HyperLogger.make(~source=Elements(Payment)),
) => {
  let normalizedLocale = getNormalizedLocale(locale)
  let timestamp = Js.Date.now()->Float.toString
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
          ~eventName=S3_API,
          ~logType=ERROR,
          ~logCategory=USER_ERROR,
        )

        let fallbackCountries = country
        try {
          let fallbackStates = await importStates("./../States.json")
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
  Js.log("Initializing country data")
  try {
    switch GlobalVars.countryDataRef.contents {
    | Some(data) => data
    | None => {
        let data = await getCountryStateData(~locale, ~logger)
        GlobalVars.countryDataRef.contents = Some(data.countries)
        data.countries
      }
    }
  } catch {
  | _ => country
  }
}

let getCountryListData = () => {
  switch GlobalVars.countryDataRef.contents {
  | Some(data) => data
  | None => country
  }
}
