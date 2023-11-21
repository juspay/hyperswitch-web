open Utils
external toNullable: Js.Json.t => Js.Nullable.t<Js.Json.t> = "%identity"
let safeParseOpt = st => {
  try {
    Js.Json.parseExn(st)->Some
  } catch {
  | _e => None
  }
}
let safeParse = st => {
  safeParseOpt(st)->Belt.Option.getWithDefault(Js.Json.null)
}

let rec flattenObject = (obj, addIndicatorForObject) => {
  let newDict = Js.Dict.empty()
  switch obj->Js.Json.decodeObject {
  | Some(obj) =>
    obj
    ->Js.Dict.entries
    ->Js.Array2.forEach(entry => {
      let (key, value) = entry

      if value->toNullable->Js.Nullable.isNullable {
        Js.Dict.set(newDict, key, value)
      } else {
        switch value->Js.Json.decodeObject {
        | Some(_valueObj) => {
            if addIndicatorForObject {
              Js.Dict.set(newDict, key, Js.Json.object_(Js.Dict.empty()))
            }

            let flattenedSubObj = flattenObject(value, addIndicatorForObject)

            flattenedSubObj
            ->Js.Dict.entries
            ->Js.Array2.forEach(subEntry => {
              let (subKey, subValue) = subEntry
              Js.Dict.set(newDict, `${key}.${subKey}`, subValue)
            })
          }

        | None => Js.Dict.set(newDict, key, value)
        }
      }
    })
  | _ => ()
  }
  newDict
}

let rec flattenObjectWithStringifiedJson = (obj, addIndicatorForObject, keepParent) => {
  let newDict = Js.Dict.empty()
  switch obj->Js.Json.decodeObject {
  | Some(obj) =>
    obj
    ->Js.Dict.entries
    ->Js.Array2.forEach(entry => {
      let (key, value) = entry

      if value->toNullable->Js.Nullable.isNullable {
        Js.Dict.set(newDict, key, value)
      } else {
        switch value
        ->Js.Json.decodeString
        ->Belt.Option.getWithDefault("")
        ->safeParse
        ->Js.Json.decodeObject {
        | Some(_valueObj) => {
            if addIndicatorForObject {
              Js.Dict.set(newDict, key, Js.Json.object_(Js.Dict.empty()))
            }

            let flattenedSubObj = flattenObjectWithStringifiedJson(
              value->Js.Json.decodeString->Belt.Option.getWithDefault("")->safeParse,
              addIndicatorForObject,
              keepParent,
            )

            flattenedSubObj
            ->Js.Dict.entries
            ->Js.Array2.forEach(subEntry => {
              let (subKey, subValue) = subEntry
              let keyN = keepParent ? `${key}.${subKey}` : subKey
              Js.Dict.set(newDict, keyN, subValue)
            })
          }

        | None => Js.Dict.set(newDict, key, value)
        }
      }
    })
  | _ => ()
  }
  newDict
}
let rec flatten = (obj, addIndicatorForObject) => {
  let newDict = Js.Dict.empty()
  switch obj->Js.Json.classify {
  | JSONObject(obj) =>
    obj
    ->Js.Dict.entries
    ->Js.Array2.forEach(entry => {
      let (key, value) = entry

      if value->toNullable->Js.Nullable.isNullable {
        Js.Dict.set(newDict, key, value)
      } else {
        switch value->Js.Json.classify {
        | JSONObject(_valueObjDict) => {
            if addIndicatorForObject {
              Js.Dict.set(newDict, key, Js.Json.object_(Js.Dict.empty()))
            }

            let flattenedSubObj = flatten(value, addIndicatorForObject)

            flattenedSubObj
            ->Js.Dict.entries
            ->Js.Array2.forEach(subEntry => {
              let (subKey, subValue) = subEntry
              Js.Dict.set(newDict, `${key}.${subKey}`, subValue)
            })
          }

        | JSONArray(dictArray) => {
            let stringArray = []
            let arrayArray = []
            dictArray->Js.Array2.forEachi((item, index) => {
              switch item->Js.Json.classify {
              | JSONString(_str) =>
                let _ = stringArray->Js.Array2.push(item)
              | JSONObject(_obj) => {
                  let flattenedSubObj = flatten(item, addIndicatorForObject)
                  flattenedSubObj
                  ->Js.Dict.entries
                  ->Js.Array2.forEach(subEntry => {
                    let (subKey, subValue) = subEntry
                    Js.Dict.set(newDict, `${key}[${index->string_of_int}].${subKey}`, subValue)
                  })
                }

              | _ =>
                let _ = arrayArray->Js.Array2.push(item)
              }
            })
            if stringArray->Js.Array2.length > 0 {
              Js.Dict.set(newDict, key, stringArray->Js.Json.array)
            }
            if arrayArray->Js.Array2.length > 0 {
              Js.Dict.set(newDict, key, arrayArray->Js.Json.array)
            }
          }

        | _ => Js.Dict.set(newDict, key, value)
        }
      }
    })
  | _ => ()
  }
  newDict
}

let rec setNested = (dict, keys, value) => {
  if keys->Js.Array.length === 0 {
    ()
  } else if keys->Js.Array.length === 1 {
    Js.Dict.set(dict, keys[0], value)
  } else {
    let key = keys[0]
    let subDict = switch Js.Dict.get(dict, key) {
    | Some(json) =>
      switch json->Js.Json.decodeObject {
      | Some(obj) => obj
      | None => dict
      }
    | None => {
        let subDict = Js.Dict.empty()
        Js.Dict.set(dict, key, subDict->Js.Json.object_)
        subDict
      }
    }
    let remainingKeys = keys->Js.Array2.sliceFrom(1)
    setNested(subDict, remainingKeys, value)
  }
}

let unflattenObject = obj => {
  let newDict = Js.Dict.empty()

  switch obj->Js.Json.decodeObject {
  | Some(dict) =>
    dict
    ->Js.Dict.entries
    ->Js.Array2.forEach(entry => {
      let (key, value) = entry
      setNested(newDict, key->Js.String2.split("."), value)
    })
  | None => ()
  }
  newDict
}

let getEventDataObj = ev => {
  ev
  ->Js.Json.decodeObject
  ->Belt.Option.flatMap(x => x->Js.Dict.get("data"))
  ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
}

let getStrValueFromEventDataObj = (ev, key) => {
  let obj = ev->getEventDataObj
  obj
  ->Js.Json.decodeObject
  ->Belt.Option.flatMap(x => x->Js.Dict.get(key))
  ->Belt.Option.flatMap(Js.Json.decodeString)
  ->Belt.Option.getWithDefault("")
}

let getBoolValueFromEventDataObj = (ev, key) => {
  let obj = ev->getEventDataObj
  obj
  ->Js.Json.decodeObject
  ->Belt.Option.flatMap(x => x->Js.Dict.get(key))
  ->Belt.Option.flatMap(Js.Json.decodeBoolean)
  ->Belt.Option.getWithDefault(false)
}

let getClasses = (options, key) => {
  let classes = options->getDictFromObj("classes")
  classes->getString(key, "")
}

let eventHandlerFunc = (
  condition: Types.event => bool,
  eventHandler,
  evType: Types.eventType,
  activity,
) => {
  let changeHandler = ev => {
    if ev->condition {
      switch evType {
      | Change
      | Click
      | Ready
      | Focus
      | ConfirmPayment
      | Blur =>
        switch eventHandler {
        | Some(eH) => eH(Some(ev.data))
        | None => ()
        }
      | _ => ()
      }
    }
  }
  EventListenerManager.addSmartEventListener("message", changeHandler, activity)
}

let makeIframe = (element, url) => {
  open Types
  Js.Promise.make((~resolve, ~reject as _) => {
    let iframe = createElement("iframe")
    iframe.id = "orca-fullscreen"
    iframe.src = url
    iframe.name = "fullscreen"
    iframe.style = "position: fixed; inset: 0; width: 100vw; height: 100vh; border: 0; z-index: 422222133323; "
    iframe.onload = () => {
      resolve(. Js.Dict.empty())
    }
    element->appendChild(iframe)
  })
}

let getOptionalJson = (ev, str) => {
  ev
  ->getEventDataObj
  ->Js.Json.decodeObject
  ->Belt.Option.getWithDefault(Js.Dict.empty())
  ->Js.Dict.get(str)
}

let getOptionalJsonFromJson = (ev, str) => {
  ev->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())->Js.Dict.get(str)
}

let getStringfromOptionaljson = (json: option<Js.Json.t>, default: string) => {
  json->Belt.Option.flatMap(Js.Json.decodeString)->Belt.Option.getWithDefault(default)
}

let getBoolfromjson = (json: option<Js.Json.t>, default: bool) => {
  json->Belt.Option.flatMap(Js.Json.decodeBoolean)->Belt.Option.getWithDefault(default)
}

let getFloatfromjson = (json: option<Js.Json.t>, default: float) => {
  json->Belt.Option.flatMap(Js.Json.decodeNumber)->Belt.Option.getWithDefault(default)
}

let getStringfromjson = (json: Js.Json.t, default: string) => {
  json->Js.Json.decodeString->Belt.Option.getWithDefault(default)
}

let getThemePromise = dict => {
  let theme =
    dict
    ->Utils.getJsonObjectFromDict("appearance")
    ->Utils.getDictFromJson
    ->Utils.getString("theme", "default")

  switch theme {
  | "default" => None
  | "brutal" => Some(ThemeImporter.importTheme("../BrutalTheme.bs.js"))
  | "midnight" => Some(ThemeImporter.importTheme("../MidnightTheme.bs.js"))
  | "charcoal" => Some(ThemeImporter.importTheme("../CharcoalTheme.bs.js"))
  | "soft" => Some(ThemeImporter.importTheme("../SoftTheme.bs.js"))
  | "none" => Some(ThemeImporter.importTheme("../NoTheme.bs.js"))
  | _ => None
  }
}

let mergeTwoFlattenedJsonDicts = (dict1, dict2) => {
  dict1
  ->Js.Dict.entries
  ->Js.Array2.concat(dict2->Js.Dict.entries)
  ->Js.Dict.fromArray
  ->Js.Json.object_
  ->unflattenObject
}

let getArrayOfTupleFromDict = dict => {
  dict
  ->Js.Dict.keys
  ->Belt.Array.map(key => (key, Js.Dict.get(dict, key)->Belt.Option.getWithDefault(Js.Json.null)))
}
