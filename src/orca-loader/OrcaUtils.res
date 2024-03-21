open Utils
external toNullable: JSON.t => Nullable.t<JSON.t> = "%identity"
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
  let newDict = Dict.make()
  switch obj->JSON.Decode.object {
  | Some(obj) =>
    obj
    ->Dict.toArray
    ->Array.forEach(entry => {
      let (key, value) = entry

      if value->toNullable->Js.Nullable.isNullable {
        Dict.set(newDict, key, value)
      } else {
        switch value->JSON.Decode.object {
        | Some(_valueObj) => {
            if addIndicatorForObject {
              Dict.set(newDict, key, JSON.Encode.object(Dict.make()))
            }

            let flattenedSubObj = flattenObject(value, addIndicatorForObject)

            flattenedSubObj
            ->Dict.toArray
            ->Array.forEach(subEntry => {
              let (subKey, subValue) = subEntry
              Dict.set(newDict, `${key}.${subKey}`, subValue)
            })
          }

        | None => Dict.set(newDict, key, value)
        }
      }
    })
  | _ => ()
  }
  newDict
}

let rec flattenObjectWithStringifiedJson = (obj, addIndicatorForObject, keepParent) => {
  let newDict = Dict.make()
  switch obj->JSON.Decode.object {
  | Some(obj) =>
    obj
    ->Dict.toArray
    ->Array.forEach(entry => {
      let (key, value) = entry

      if value->toNullable->Js.Nullable.isNullable {
        Dict.set(newDict, key, value)
      } else {
        switch value->JSON.Decode.string->Option.getOr("")->safeParse->JSON.Decode.object {
        | Some(_valueObj) => {
            if addIndicatorForObject {
              Dict.set(newDict, key, JSON.Encode.object(Dict.make()))
            }

            let flattenedSubObj = flattenObjectWithStringifiedJson(
              value->JSON.Decode.string->Option.getOr("")->safeParse,
              addIndicatorForObject,
              keepParent,
            )

            flattenedSubObj
            ->Dict.toArray
            ->Array.forEach(subEntry => {
              let (subKey, subValue) = subEntry
              let keyN = keepParent ? `${key}.${subKey}` : subKey
              Dict.set(newDict, keyN, subValue)
            })
          }

        | None => Dict.set(newDict, key, value)
        }
      }
    })
  | _ => ()
  }
  newDict
}
let rec flatten = (obj, addIndicatorForObject) => {
  let newDict = Dict.make()
  switch obj->JSON.Classify.classify {
  | Object(obj) =>
    obj
    ->Dict.toArray
    ->Array.forEach(entry => {
      let (key, value) = entry

      if value->toNullable->Js.Nullable.isNullable {
        Dict.set(newDict, key, value)
      } else {
        switch value->JSON.Classify.classify {
        | Object(_valueObjDict) => {
            if addIndicatorForObject {
              Dict.set(newDict, key, JSON.Encode.object(Dict.make()))
            }

            let flattenedSubObj = flatten(value, addIndicatorForObject)

            flattenedSubObj
            ->Dict.toArray
            ->Array.forEach(subEntry => {
              let (subKey, subValue) = subEntry
              Dict.set(newDict, `${key}.${subKey}`, subValue)
            })
          }

        | Array(dictArray) => {
            let stringArray = []
            let arrayArray = []
            dictArray->Array.forEachWithIndex((item, index) => {
              switch item->JSON.Classify.classify {
              | String(_str) =>
                let _ = stringArray->Array.push(item)
              | Object(_obj) => {
                  let flattenedSubObj = flatten(item, addIndicatorForObject)
                  flattenedSubObj
                  ->Dict.toArray
                  ->Array.forEach(
                    subEntry => {
                      let (subKey, subValue) = subEntry
                      Dict.set(newDict, `${key}[${index->Int.toString}].${subKey}`, subValue)
                    },
                  )
                }

              | _ =>
                let _ = arrayArray->Array.push(item)
              }
            })
            if stringArray->Array.length > 0 {
              Dict.set(newDict, key, stringArray->JSON.Encode.array)
            }
            if arrayArray->Array.length > 0 {
              Dict.set(newDict, key, arrayArray->JSON.Encode.array)
            }
          }

        | _ => Dict.set(newDict, key, value)
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
    if keys->Array.length === 1 {
      Dict.set(dict, firstKey, value)
    } else {
      let subDict = switch Dict.get(dict, firstKey) {
      | Some(json) =>
        switch json->JSON.Decode.object {
        | Some(obj) => obj
        | None => dict
        }
      | None =>
        let subDict = Dict.make()
        dict->Dict.set(firstKey, subDict->JSON.Encode.object)
        subDict
      }
      let remainingKeys = keys->Array.sliceToEnd(~start=1)
      setNested(subDict, remainingKeys, value)
    }
  | None => ()
  }
}

let unflattenObject = obj => {
  let newDict = Dict.make()

  switch obj->JSON.Decode.object {
  | Some(dict) =>
    dict
    ->Dict.toArray
    ->Array.forEach(entry => {
      let (key, value) = entry
      setNested(newDict, key->String.split("."), value)
    })
  | None => ()
  }
  newDict
}

let getEventDataObj = ev => {
  ev
  ->JSON.Decode.object
  ->Option.flatMap(x => x->Dict.get("data"))
  ->Option.getOr(Dict.make()->JSON.Encode.object)
}

let getStrValueFromEventDataObj = (ev, key) => {
  let obj = ev->getEventDataObj
  obj
  ->JSON.Decode.object
  ->Option.flatMap(x => x->Dict.get(key))
  ->Option.flatMap(JSON.Decode.string)
  ->Option.getOr("")
}

let getBoolValueFromEventDataObj = (ev, key) => {
  let obj = ev->getEventDataObj
  obj
  ->JSON.Decode.object
  ->Option.flatMap(x => x->Dict.get(key))
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
      resolve(Dict.make())
    }
    element->appendChild(iframe)
  })
}
let makeForm = (element, url, id) => {
  open Types
  let form = createElement("form")
  form.id = id
  form.name = id
  form.action = url
  form.method = "POST"
  form.enctype = "application/x-www-form-urlencoded;charset=UTF-8"
  form.style = "display: hidden; "
  element->appendChild(form)
  form
}

let getOptionalJson = (ev, str) => {
  ev->getEventDataObj->JSON.Decode.object->Option.getOr(Dict.make())->Dict.get(str)
}

let getOptionalJsonFromJson = (ev, str) => {
  ev->JSON.Decode.object->Option.getOr(Dict.make())->Dict.get(str)
}

let getStringfromOptionaljson = (json: option<JSON.t>, default: string) => {
  json->Option.flatMap(JSON.Decode.string)->Option.getOr(default)
}

let getBoolfromjson = (json: option<JSON.t>, default: bool) => {
  json->Option.flatMap(JSON.Decode.bool)->Option.getOr(default)
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
  ->Dict.toArray
  ->Array.concat(dict2->Dict.toArray)
  ->Dict.fromArray
  ->JSON.Encode.object
  ->unflattenObject
}

let getArrayOfTupleFromDict = dict => {
  dict
  ->Dict.keysToArray
  ->Array.map(key => (key, Dict.get(dict, key)->Option.getOr(JSON.Encode.null)))
}

let makeOneClickHandlerPromise = sdkHandleOneClickConfirmPayment => {
  open EventListenerManager
  Js.Promise.make((~resolve, ~reject as _) => {
    if sdkHandleOneClickConfirmPayment {
      resolve(JSON.Encode.bool(true))
    } else {
      let handleMessage = (event: Types.event) => {
        let json = event.data->eventToJson->getStringfromjson("")->safeParse

        let dict = json->Utils.getDictFromJson
        if dict->Dict.get("oneClickDoSubmit")->Option.isSome {
          resolve(dict->Dict.get("oneClickDoSubmit")->Option.getOr(true->JSON.Encode.bool))
        }
      }
      addSmartEventListener("message", handleMessage, "onOneClickHandlerPaymentConfirm")
      Utils.handleOnConfirmPostMessage(~targetOrigin="*", ~isOneClick=true, ())
    }
  })
}
