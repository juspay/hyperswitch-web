open Utils
external toNullable: JSON.t => Js.Nullable.t<JSON.t> = "%identity"
external eventToJson: Types.eventData => JSON.t = "%identity"
let safeParseOpt = st => {
  try {
    JSON.parseExn(st)->Some
  } catch {
  | _e => None
  }
}
let safeParse = st => {
  safeParseOpt(st)->Option.getOr(JSON.Encode.null)
}

let rec flattenObject = (obj, addIndicatorForObject) => {
  let newDict = Js.Dict.empty()
  switch obj->JSON.Decode.object {
  | Some(obj) =>
    obj
    ->Js.Dict.entries
    ->Js.Array2.forEach(entry => {
      let (key, value) = entry

      if value->toNullable->Js.Nullable.isNullable {
        Js.Dict.set(newDict, key, value)
      } else {
        switch value->JSON.Decode.object {
        | Some(_valueObj) => {
            if addIndicatorForObject {
              Js.Dict.set(newDict, key, JSON.Encode.object(Js.Dict.empty()))
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
  switch obj->JSON.Decode.object {
  | Some(obj) =>
    obj
    ->Js.Dict.entries
    ->Js.Array2.forEach(entry => {
      let (key, value) = entry

      if value->toNullable->Js.Nullable.isNullable {
        Js.Dict.set(newDict, key, value)
      } else {
        switch value->JSON.Decode.string->Option.getOr("")->safeParse->JSON.Decode.object {
        | Some(_valueObj) => {
            if addIndicatorForObject {
              Js.Dict.set(newDict, key, JSON.Encode.object(Js.Dict.empty()))
            }

            let flattenedSubObj = flattenObjectWithStringifiedJson(
              value->JSON.Decode.string->Option.getOr("")->safeParse,
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
  switch obj->JSON.Classify.classify {
  | Object(obj) =>
    obj
    ->Js.Dict.entries
    ->Js.Array2.forEach(entry => {
      let (key, value) = entry

      if value->toNullable->Js.Nullable.isNullable {
        Js.Dict.set(newDict, key, value)
      } else {
        switch value->JSON.Classify.classify {
        | Object(_valueObjDict) => {
            if addIndicatorForObject {
              Js.Dict.set(newDict, key, JSON.Encode.object(Js.Dict.empty()))
            }

            let flattenedSubObj = flatten(value, addIndicatorForObject)

            flattenedSubObj
            ->Js.Dict.entries
            ->Js.Array2.forEach(subEntry => {
              let (subKey, subValue) = subEntry
              Js.Dict.set(newDict, `${key}.${subKey}`, subValue)
            })
          }

        | Array(dictArray) => {
            let stringArray = []
            let arrayArray = []
            dictArray->Js.Array2.forEachi((item, index) => {
              switch item->JSON.Classify.classify {
              | String(_str) =>
                let _ = stringArray->Js.Array2.push(item)
              | Object(_obj) => {
                  let flattenedSubObj = flatten(item, addIndicatorForObject)
                  flattenedSubObj
                  ->Js.Dict.entries
                  ->Js.Array2.forEach(
                    subEntry => {
                      let (subKey, subValue) = subEntry
                      Js.Dict.set(newDict, `${key}[${index->string_of_int}].${subKey}`, subValue)
                    },
                  )
                }

              | _ =>
                let _ = arrayArray->Js.Array2.push(item)
              }
            })
            if stringArray->Js.Array2.length > 0 {
              Js.Dict.set(newDict, key, stringArray->JSON.Encode.array)
            }
            if arrayArray->Js.Array2.length > 0 {
              Js.Dict.set(newDict, key, arrayArray->JSON.Encode.array)
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
  switch keys[0] {
  | Some(firstKey) =>
    if keys->Js.Array.length === 1 {
      Js.Dict.set(dict, firstKey, value)
    } else {
      let subDict = switch Js.Dict.get(dict, firstKey) {
      | Some(json) =>
        switch json->JSON.Decode.object {
        | Some(obj) => obj
        | None => dict
        }
      | None =>
        let subDict = Js.Dict.empty()
        dict->Dict.set(firstKey, subDict->JSON.Encode.object)
        subDict
      }
      let remainingKeys = keys->Js.Array2.sliceFrom(1)
      setNested(subDict, remainingKeys, value)
    }
  | None => ()
  }
}

let unflattenObject = obj => {
  let newDict = Js.Dict.empty()

  switch obj->JSON.Decode.object {
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
  ->JSON.Decode.object
  ->Option.flatMap(x => x->Js.Dict.get("data"))
  ->Option.getOr(Js.Dict.empty()->JSON.Encode.object)
}

let getStrValueFromEventDataObj = (ev, key) => {
  let obj = ev->getEventDataObj
  obj
  ->JSON.Decode.object
  ->Option.flatMap(x => x->Js.Dict.get(key))
  ->Option.flatMap(JSON.Decode.string)
  ->Option.getOr("")
}

let getBoolValueFromEventDataObj = (ev, key) => {
  let obj = ev->getEventDataObj
  obj
  ->JSON.Decode.object
  ->Option.flatMap(x => x->Js.Dict.get(key))
  ->Option.flatMap(JSON.Decode.bool)
  ->Option.getOr(false)
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
      | OneClickConfirmPayment
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
  ev->getEventDataObj->JSON.Decode.object->Option.getOr(Js.Dict.empty())->Js.Dict.get(str)
}

let getOptionalJsonFromJson = (ev, str) => {
  ev->JSON.Decode.object->Option.getOr(Js.Dict.empty())->Js.Dict.get(str)
}

let getStringfromOptionaljson = (json: option<JSON.t>, default: string) => {
  json->Option.flatMap(JSON.Decode.string)->Option.getOr(default)
}

let getBoolfromjson = (json: option<JSON.t>, default: bool) => {
  json->Option.flatMap(JSON.Decode.bool)->Option.getOr(default)
}

let getFloatfromjson = (json: option<JSON.t>, default: float) => {
  json->Option.flatMap(JSON.Decode.float)->Option.getOr(default)
}

let getStringfromjson = (json: JSON.t, default: string) => {
  json->JSON.Decode.string->Option.getOr(default)
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
  ->JSON.Encode.object
  ->unflattenObject
}

let getArrayOfTupleFromDict = dict => {
  dict
  ->Js.Dict.keys
  ->Belt.Array.map(key => (key, Js.Dict.get(dict, key)->Option.getOr(JSON.Encode.null)))
}

let makeOneClickHandlerPromise = sdkHandleOneClickConfirmPayment => {
  open EventListenerManager
  Js.Promise.make((~resolve, ~reject as _) => {
    if sdkHandleOneClickConfirmPayment {
      resolve(. JSON.Encode.bool(true))
    } else {
      let handleMessage = (event: Types.event) => {
        let json = event.data->eventToJson->getStringfromjson("")->safeParse

        let dict = json->Utils.getDictFromJson
        if dict->Js.Dict.get("oneClickDoSubmit")->Option.isSome {
          resolve(. dict->Js.Dict.get("oneClickDoSubmit")->Option.getOr(true->JSON.Encode.bool))
        }
      }
      addSmartEventListener("message", handleMessage, "onOneClickHandlerPaymentConfirm")
      Utils.handleOnConfirmPostMessage(~targetOrigin="*", ~isOneClick=true, ())
    }
  })
}
