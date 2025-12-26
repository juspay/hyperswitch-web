@val external document: 'a = "document"
@val external window: Dom.element = "window"
@val @scope("window") external iframeParent: Dom.element = "parent"
@send external body: ('a, Dom.element) => Dom.element = "body"

@val @scope("window") external topParent: Dom.element = "top"
type event = {data: string}
external dictToObj: Dict.t<'a> => {..} = "%identity"

@module("./Phone_number.json")
external phoneNumberJson: JSON.t = "default"

type options = {timeZone: string}
type dateTimeFormat = {resolvedOptions: unit => options}
@val @scope("Intl") external dateTimeFormat: unit => dateTimeFormat = "DateTimeFormat"

@send external remove: Dom.element => unit = "remove"

@send external postMessage: (Dom.element, JSON.t, string) => unit = "postMessage"

type dataModule = {states: JSON.t}

@val
external importStates: string => promise<dataModule> = "import"

open ErrorUtils

let getJsonFromArrayOfJson = arr => arr->Dict.fromArray->JSON.Encode.object

let messageWindow = (window, ~targetOrigin="*", messageArr) => {
  window->postMessage(messageArr->getJsonFromArrayOfJson, targetOrigin)
}

let messageTopWindow = (~targetOrigin="*", messageArr) => {
  topParent->messageWindow(~targetOrigin, messageArr)
}

let messageParentWindow = (~targetOrigin="*", messageArr) => {
  iframeParent->messageWindow(~targetOrigin, messageArr)
}

let messageCurrentWindow = (~targetOrigin="*", messageArr) => {
  window->messageWindow(~targetOrigin, messageArr)
}

let handleOnFocusPostMessage = (~targetOrigin="*") => {
  messageParentWindow([("focus", true->JSON.Encode.bool)], ~targetOrigin)
}

let handleOnCompleteDoThisMessage = (~targetOrigin="*") => {
  messageParentWindow([("completeDoThis", true->JSON.Encode.bool)], ~targetOrigin)
}

let handleOnBlurPostMessage = (~targetOrigin="*") => {
  messageParentWindow([("blur", true->JSON.Encode.bool)], ~targetOrigin)
}

let handleOnClickPostMessage = (~targetOrigin="*", ev) => {
  messageParentWindow(
    [("clickTriggered", true->JSON.Encode.bool), ("event", ev->JSON.stringify->JSON.Encode.string)],
    ~targetOrigin,
  )
}
let handleOnConfirmPostMessage = (~targetOrigin="*", ~isOneClick=false) => {
  let message = isOneClick ? "oneClickConfirmTriggered" : "confirmTriggered"
  messageParentWindow([(message, true->JSON.Encode.bool)], ~targetOrigin)
}

let handleBeforeRedirectPostMessage = (~targetOrigin="*") => {
  messageTopWindow([("disableBeforeUnloadEventListener", true->JSON.Encode.bool)], ~targetOrigin)
}

let getOptionString = (dict, key) => {
  dict->Dict.get(key)->Option.flatMap(JSON.Decode.string)
}

let getString = (dict, key, default) => {
  getOptionString(dict, key)->Option.getOr(default)
}

let getStringFromJson = (json, default) => {
  json->JSON.Decode.string->Option.getOr(default)
}

let convertDictToArrayOfKeyStringTuples = dict => {
  dict
  ->Dict.toArray
  ->Array.map(entries => {
    let (x, val) = entries
    (x, val->JSON.Decode.string->Option.getOr(""))
  })
}

let mergeHeadersIntoDict = (~dict, ~headers) => {
  headers->Array.forEach(entries => {
    let (x, val) = entries
    Dict.set(dict, x, val->JSON.Encode.string)
  })
}

let getInt = (dict, key, default: int) => {
  dict
  ->Dict.get(key)
  ->Option.flatMap(JSON.Decode.float)
  ->Option.getOr(default->Int.toFloat)
  ->Float.toInt
}

let getFloatFromString = (str, default) => str->Float.fromString->Option.getOr(default)

let getFloatFromJson = (json, default) => {
  switch json->JSON.Classify.classify {
  | String(str) => getFloatFromString(str, default)
  | Number(floatValue) => floatValue
  | _ => default
  }
}

let getFloat = (dict, key, default) => {
  dict->Dict.get(key)->Option.map(json => getFloatFromJson(json, default))->Option.getOr(default)
}

let getJsonBoolValue = (dict, key, default) => {
  dict->Dict.get(key)->Option.getOr(default->JSON.Encode.bool)
}

let getJsonStringFromDict = (dict, key, default) => {
  dict->Dict.get(key)->Option.getOr(default->JSON.Encode.string)
}

let getJsonArrayFromDict = (dict, key, default) => {
  dict->Dict.get(key)->Option.getOr(default->JSON.Encode.array)
}
let getJsonFromDict = (dict, key, default) => {
  dict->Dict.get(key)->Option.getOr(default)
}

let getJsonObjFromDict = (dict, key, default) => {
  dict->Dict.get(key)->Option.flatMap(JSON.Decode.object)->Option.getOr(default)
}
let getDecodedStringFromJson = (json, callbackFunc, defaultValue) => {
  json
  ->JSON.Decode.object
  ->Option.flatMap(callbackFunc)
  ->Option.flatMap(JSON.Decode.string)
  ->Option.getOr(defaultValue)
}

let getDecodedBoolFromJson = (json, callbackFunc, defaultValue) => {
  json
  ->JSON.Decode.object
  ->Option.flatMap(callbackFunc)
  ->Option.flatMap(JSON.Decode.bool)
  ->Option.getOr(defaultValue)
}

let getRequiredString = (dict, key, default, ~logger) => {
  let optionalStr = getOptionString(dict, key)
  switch optionalStr {
  | Some(val) => {
      val == "" ? manageErrorWarning(REQUIRED_PARAMETER, ~dynamicStr=key, ~logger) : ()
      val
    }
  | None => {
      manageErrorWarning(REQUIRED_PARAMETER, ~dynamicStr=key, ~logger)
      optionalStr->Option.getOr(default)
    }
  }
}

let getWarningString = (dict, key, default, ~logger) => {
  switch dict->Dict.get(key) {
  | Some(val) =>
    switch val->JSON.Decode.string {
    | Some(val) => val
    | None =>
      manageErrorWarning(TYPE_STRING_ERROR, ~dynamicStr=key, ~logger)
      default
    }
  | None => default
  }
}

let getDictFromObj = (dict, key) => {
  dict->Dict.get(key)->Option.flatMap(JSON.Decode.object)->Option.getOr(Dict.make())
}

let getJsonObjectFromDict = (dict, key) => {
  dict->Dict.get(key)->Option.getOr(JSON.Encode.object(Dict.make()))
}
let getOptionBool = (dict, key) => {
  dict->Dict.get(key)->Option.flatMap(JSON.Decode.bool)
}
let getDictFromJson = (json: JSON.t) => {
  json->JSON.Decode.object->Option.getOr(Dict.make())
}

let getDictFromDict = (dict, key) => {
  dict->getJsonObjectFromDict(key)->getDictFromJson
}

let getBool = (dict, key, default) => {
  getOptionBool(dict, key)->Option.getOr(default)
}

let getOptionsDict = options => options->Option.getOr(JSON.Encode.null)->getDictFromJson

let getBoolWithWarning = (dict, key, default, ~logger) => {
  switch dict->Dict.get(key) {
  | Some(val) =>
    switch val->JSON.Decode.bool {
    | Some(val) => val
    | None =>
      manageErrorWarning(TYPE_BOOL_ERROR, ~dynamicStr=key, ~logger)
      default
    }
  | None => default
  }
}
let getNumberWithWarning = (dict, key, ~logger, default) => {
  switch dict->Dict.get(key) {
  | Some(val) =>
    switch val->JSON.Decode.float {
    | Some(val) => val->Float.toInt
    | None =>
      manageErrorWarning(TYPE_INT_ERROR, ~dynamicStr=key, ~logger)
      default
    }
  | None => default
  }
}

let getOptionalArrayFromDict = (dict, key) => {
  dict->Dict.get(key)->Option.flatMap(JSON.Decode.array)
}
let getArray = (dict, key) => {
  dict->getOptionalArrayFromDict(key)->Option.getOr([])
}

let getArrayOfObjectsFromDict = (dict, key) => {
  dict
  ->getArray(key)
  ->Array.filterMap(JSON.Decode.object)
}

let getStrArray = (dict, key) => {
  dict
  ->getOptionalArrayFromDict(key)
  ->Option.getOr([])
  ->Array.map(json => json->getStringFromJson(""))
}
let getOptionalStrArray: (Dict.t<JSON.t>, string) => option<array<string>> = (dict, key) => {
  switch dict->getOptionalArrayFromDict(key) {
  | Some(val) =>
    val->Array.length === 0 ? None : Some(val->Array.map(json => json->getStringFromJson("")))
  | None => None
  }
}

let getBoolValue = val => val->Option.getOr(false)

let toKebabCase = str => {
  str
  ->String.split("")
  ->Array.mapWithIndex((item, i) => {
    if item->String.toUpperCase === item {
      `${i != 0 ? "-" : ""}${item->String.toLowerCase}`
    } else {
      item
    }
  })
  ->Array.join("")
}

let handleMessage = (fun, _errorMessage) => {
  let handle = (ev: Window.event) => {
    try {
      fun(ev)
    } catch {
    | _err => ()
    }
  }
  Window.addEventListener("message", handle)
  Some(() => Window.removeEventListener("message", handle))
}
let useSubmitPaymentData = callback => {
  React.useEffect(() => {handleMessage(callback, "")}, [callback])
}

let useWindowSize = () => {
  let (size, setSize) = React.useState(_ => (0, 0))
  React.useLayoutEffect1(() => {
    let updateSize = () => {
      setSize(_ => (Window.innerWidth, Window.innerHeight))
    }
    Window.addEventListener("resize", updateSize)
    updateSize()
    Some(_ => Window.removeEventListener("resize", updateSize))
  }, [])
  size
}
let mergeJsons = (json1, json2) => {
  let obj1 = json1->getDictFromJson
  let obj2 = json2->getDictFromJson
  let rec merge = (obj1, obj2) => {
    if obj1 != obj2 {
      obj2
      ->Dict.keysToArray
      ->Array.map(key => {
        let overrideProp = obj2->getJsonObjectFromDict(key)
        let defaultProp = obj1->getJsonObjectFromDict(key)
        if defaultProp->getDictFromJson->Dict.keysToArray->Array.length == 0 {
          obj1->Dict.set(key, overrideProp)
        } else if (
          overrideProp->JSON.Decode.object->Option.isSome &&
            defaultProp->JSON.Decode.object->Option.isSome
        ) {
          merge(defaultProp->getDictFromJson, overrideProp->getDictFromJson)
        } else if overrideProp !== defaultProp {
          obj1->Dict.set(key, overrideProp)
        }
      })
      ->ignore
      obj1
    } else {
      obj1
    }->ignore
  }
  merge(obj1, obj2)->ignore
  obj1->JSON.Encode.object
}

let postFailedSubmitResponse = (~errortype, ~message) => {
  let errorDict =
    [
      ("type", errortype->JSON.Encode.string),
      ("message", message->JSON.Encode.string),
    ]->Dict.fromArray
  messageParentWindow([
    ("submitSuccessful", false->JSON.Encode.bool),
    ("error", errorDict->JSON.Encode.object),
  ])
}

let postFailedSubmitResponseTop = (~errortype, ~message) => {
  let errorDict =
    [
      ("type", errortype->JSON.Encode.string),
      ("message", message->JSON.Encode.string),
    ]->Dict.fromArray
  messageTopWindow([
    ("submitSuccessful", false->JSON.Encode.bool),
    ("error", errorDict->JSON.Encode.object),
  ])
}

let postSubmitResponse = (~jsonData, ~url) => {
  messageParentWindow([
    ("submitSuccessful", true->JSON.Encode.bool),
    ("data", jsonData),
    ("url", url->JSON.Encode.string),
  ])
}

let getFailedSubmitResponse = (~errorType, ~message) => {
  [
    (
      "error",
      [
        ("type", errorType->JSON.Encode.string),
        ("message", message->JSON.Encode.string),
      ]->getJsonFromArrayOfJson,
    ),
  ]->getJsonFromArrayOfJson
}

let toCamelCase = str => {
  if str->String.includes(":") {
    str
  } else {
    str
    ->String.toLowerCase
    ->Js.String2.unsafeReplaceBy0(%re(`/([-_][a-z])/g`), (letter, _, _) => {
      letter->String.toUpperCase
    })
    ->String.replaceRegExp(%re(`/[^a-zA-Z]/g`), "")
  }
}

let toCamelCaseWithNumberSupport = str => {
  if str->String.includes(":") {
    str
  } else {
    str
    ->String.toLowerCase
    ->Js.String2.unsafeReplaceBy0(%re(`/([-_][a-z])/g`), (letter, _, _) => {
      letter->String.toUpperCase
    })
    ->String.replaceRegExp(%re(`/[^a-zA-Z0-9]/g`), "")
  }
}

let toSnakeCase = str => {
  str->Js.String2.unsafeReplaceBy0(%re("/[A-Z]/g"), (letter, _, _) =>
    `_${letter->String.toLowerCase}`
  )
}
type case = CamelCase | SnakeCase | KebabCase
let rec transformKeys = (json: JSON.t, to: case) => {
  let toCase = switch to {
  | CamelCase => toCamelCase
  | SnakeCase => toSnakeCase
  | KebabCase => toKebabCase
  }
  let dict = json->getDictFromJson
  dict
  ->Dict.toArray
  ->Array.map(((key, value)) => {
    let x = switch JSON.Classify.classify(value) {
    | Object(obj) => (key->toCase, obj->JSON.Encode.object->transformKeys(to))
    | Array(arr) => (
        key->toCase,
        {
          arr
          ->Array.map(item =>
            if item->JSON.Decode.object->Option.isSome {
              item->transformKeys(to)
            } else {
              item
            }
          )
          ->JSON.Encode.array
        },
      )
    | String(str) => {
        let val = if str == "Final" {
          "FINAL"
        } else if str == "example" || str == "Adyen" {
          "adyen"
        } else {
          str
        }
        (key->toCase, val->JSON.Encode.string)
      }
    | Number(val) => (key->toCase, val->Float.toString->JSON.Encode.string)
    | _ => (key->toCase, value)
    }
    x
  })
  ->getJsonFromArrayOfJson
}

let rec transformKeysWithoutModifyingValue = (json: JSON.t, to: case) => {
  let toCase = switch to {
  | CamelCase => toCamelCaseWithNumberSupport
  | SnakeCase => toSnakeCase
  | KebabCase => toKebabCase
  }
  let dict = json->getDictFromJson
  dict
  ->Dict.toArray
  ->Array.map(((key, value)) => {
    let x = switch JSON.Classify.classify(value) {
    | Object(obj) => (key->toCase, obj->JSON.Encode.object->transformKeys(to))
    | Array(arr) => (
        key->toCase,
        {
          arr
          ->Array.map(item =>
            if item->JSON.Decode.object->Option.isSome {
              item->transformKeys(to)
            } else {
              item
            }
          )
          ->JSON.Encode.array
        },
      )
    | String(str) => {
        let val = if str == "Final" {
          "FINAL"
        } else if str == "example" || str == "Adyen" {
          "adyen"
        } else {
          str
        }
        (key->toCase, val->JSON.Encode.string)
      }
    | Number(val) => (key->toCase, val->JSON.Encode.float)
    | _ => (key->toCase, value)
    }
    x
  })
  ->getJsonFromArrayOfJson
}

let getClientCountry = clientTimeZone => {
  CountryStateDataRefs.countryDataRef.contents
  ->Array.find(item => item.timeZones->Array.find(i => i == clientTimeZone)->Option.isSome)
  ->Option.getOr(Country.defaultTimeZone)
}

let removeDuplicate = arr => {
  arr->Array.filterWithIndex((item, i) => {
    arr->Array.indexOf(item) === i
  })
}

let isVpaIdValid = vpaId => {
  switch vpaId->String.match(
    %re("/^[a-zA-Z0-9]([a-zA-Z0-9.-]{1,50})[a-zA-Z0-9]@[a-zA-Z0-9]{2,}$/"),
  ) {
  | Some(_match) => Some(true)
  | None => vpaId->String.length > 0 ? Some(false) : None
  }
}

let checkEmailValid = (
  email: RecoilAtomTypes.field,
  fn: (RecoilAtomTypes.field => RecoilAtomTypes.field) => unit,
) => {
  switch email.value->String.match(
    %re(
      "/^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/"
    ),
  ) {
  | Some(_match) =>
    fn(prev => {
      ...prev,
      isValid: Some(true),
    })
  | None =>
    email.value->String.length > 0
      ? fn(prev => {
          ...prev,
          isValid: Some(false),
        })
      : fn(prev => {
          ...prev,
          isValid: None,
        })
  }
}

let validatePhoneNumber = (countryCode, number) => {
  let phoneNumberDict = phoneNumberJson->JSON.Decode.object->Option.getOr(Dict.make())
  let countriesArr =
    phoneNumberDict
    ->Dict.get("countries")
    ->Option.flatMap(JSON.Decode.array)
    ->Option.getOr([])
    ->Belt.Array.keepMap(JSON.Decode.object)

  let filteredArr = countriesArr->Array.filter(countryObj => {
    countryObj
    ->Dict.get("phone_number_code")
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("") == countryCode
  })
  switch filteredArr[0] {
  | Some(obj) =>
    let regex =
      obj->Dict.get("validation_regex")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
    RegExp.test(regex->RegExp.fromString, number)
  | None => false
  }
}

let sortBasedOnPriority = (sortArr: array<string>, priorityArr: array<string>) => {
  let finalPriorityArr = priorityArr->Array.filter(val => sortArr->Array.includes(val))
  sortArr
  ->Array.map(item => {
    if finalPriorityArr->Array.includes(item) {
      ()
    } else {
      finalPriorityArr->Array.push(item)->ignore
    }
  })
  ->ignore
  finalPriorityArr
}

let isAllValid = (
  card: option<bool>,
  cardSupported: option<bool>,
  cvc: option<bool>,
  expiry: option<bool>,
  zip: bool,
  paymentMode: string,
) => {
  card->getBoolValue &&
  cardSupported->getBoolValue &&
  cvc->getBoolValue &&
  expiry->getBoolValue &&
  (paymentMode == "payment" || zip)
}

let getCountryPostal = (countryCode, postalCodes: array<PostalCodeType.postalCodes>) => {
  postalCodes
  ->Array.find(item => item.iso == countryCode)
  ->Option.getOr(PostalCodeType.defaultPostalCode)
}

let getCountryNames = (list: array<Country.timezoneType>) => {
  list->Array.reduce([], (arr, item) => {
    arr->Array.push(item.countryName)->ignore
    arr
  })
}

let getBankNames = (list: Bank.bankList, allBanks: array<string>) => {
  list->Array.reduce([], (arr, item) => {
    if allBanks->Array.includes(item.value) {
      arr->Array.push(item.displayName)->ignore
    }
    arr
  })
}

let getBankKeys = (str, banks: Bank.bankList, default) => {
  (banks->Array.find(item => item.displayName == str)->Option.getOr(default)).value
}

let constructClass = (~classname, ~dict) => {
  let puseduoArr = []
  let modifiedArr = []

  dict
  ->Dict.toArray
  ->Array.map(entry => {
    let (key, value) = entry

    let class = if !(key->String.startsWith(":")) && !(key->String.startsWith(".")) {
      switch value->JSON.Decode.string {
      | Some(str) => `${key->toKebabCase}:${str}`
      | None => ""
      }
    } else if key->String.startsWith(":") {
      switch value->JSON.Decode.object {
      | Some(obj) =>
        let style =
          obj
          ->Dict.toArray
          ->Array.map(entry => {
            let (key, value) = entry
            switch value->JSON.Decode.string {
            | Some(str) => `${key->toKebabCase}:${str}`
            | None => ""
            }
          })
        `.${classname}${key} {${style->Array.join(";")}}`

      | None => ""
      }
    } else if key->String.startsWith(".") {
      switch value->JSON.Decode.object {
      | Some(obj) =>
        let style =
          obj
          ->Dict.toArray
          ->Array.map(entry => {
            let (key, value) = entry
            switch value->JSON.Decode.string {
            | Some(str) => `${key->toKebabCase}:${str}`
            | None => ""
            }
          })
        `${key} {${style->Array.join(";")}} `

      | None => ""
      }
    } else {
      ""
    }

    if !(key->String.startsWith(":")) && !(key->String.startsWith(".")) {
      modifiedArr->Array.push(class)->ignore
    } else if key->String.startsWith(":") || key->String.startsWith(".") {
      puseduoArr->Array.push(class)->ignore
    }
  })
  ->ignore

  if classname->String.length == 0 {
    `${modifiedArr->Array.join(";")} ${puseduoArr->Array.join(" ")}`
  } else {
    `.${classname} {${modifiedArr->Array.join(";")}} ${puseduoArr->Array.join(" ")}`
  }
}

let generateStyleSheet = (classname, dict, id) => {
  let createStyle = () => {
    let style = document["createElement"]("style")
    style["type"] = "text/css"
    style["id"] = id
    style["appendChild"](document["createTextNode"](constructClass(~classname, ~dict)))->ignore
    document["body"]["appendChild"](style)->ignore
  }
  switch Window.window->Window.document->Window.getElementById(id)->Nullable.toOption {
  | Some(val) => {
      val->remove
      createStyle()
    }
  | None => createStyle()
  }
}
let openUrl = url => {
  messageParentWindow([("openurl", url->JSON.Encode.string)])
}

let getArrofJsonString = (arr: array<string>) => {
  arr->Array.map(item => item->JSON.Encode.string)
}

let getOptionalArr = arr => {
  switch arr {
  | Some(val) => val
  | None => []
  }
}

let checkPriorityList = paymentMethodOrder => {
  paymentMethodOrder->getOptionalArr->Array.get(0)->Option.getOr("") == "card"
}
type sizeunit = Pixel | Rem | Em
let addSize = (str: string, value: float, unit: sizeunit) => {
  let getUnit = unit => {
    switch unit {
    | Pixel => "px"
    | Rem => "rem"
    | Em => "em"
    }
  }
  let unitInString = getUnit(unit)
  if str->String.endsWith(unitInString) {
    let arr = str->String.split("")
    let val =
      arr
      ->Array.slice(~start=0, ~end={arr->Array.length - unitInString->String.length})
      ->Array.join("")
      ->Float.fromString
      ->Option.getOr(0.0)
    (val +. value)->Float.toString ++ unitInString
  } else {
    str
  }
}
let toInt = val => val->Int.fromString->Option.getOr(0)

let validateRountingNumber = str => {
  if str->String.length != 9 {
    false
  } else {
    let firstWeight = 3
    let weights = [firstWeight, 7, 1, 3, 7, 1, 3, 7, 1]
    let sum =
      str
      ->String.split("")
      ->Array.mapWithIndex((item, i) => item->toInt * weights[i]->Option.getOr(firstWeight))
      ->Array.reduce(0, (acc, val) => {
        acc + val
      })
    mod(sum, 10) == 0
  }
}

let handlePostMessageEvents = (
  ~complete,
  ~empty,
  ~paymentType,
  ~loggerState: HyperLoggerTypes.loggerMake,
  ~savedMethod=false,
) => {
  if complete && paymentType !== "" {
    let value = `Payment Data Filled: ${savedMethod
        ? "Saved Payment Method"
        : "New Payment Method"}`
    loggerState.setLogInfo(~value, ~eventName=PAYMENT_DATA_FILLED, ~paymentMethod=paymentType)
  }
  messageParentWindow([
    ("elementType", "payment"->JSON.Encode.string),
    ("complete", complete->JSON.Encode.bool),
    ("empty", empty->JSON.Encode.bool),
    ("value", [("type", paymentType->JSON.Encode.string)]->getJsonFromArrayOfJson),
  ])
}

let onlyDigits = str => str->String.replaceRegExp(%re(`/\D/g`), "")

let getCountryCode = country => {
  CountryStateDataRefs.countryDataRef.contents
  ->Array.find(item => item.countryName == country)
  ->Option.getOr(Country.defaultTimeZone)
}

let getStateNames = (country: RecoilAtomTypes.field) => {
  let options =
    CountryStateDataRefs.stateDataRef.contents
    ->getDictFromJson
    ->getOptionalArrayFromDict(getCountryCode(country.value).isoAlpha2)
    ->Option.getOr([])

  options->Array.reduce([], (arr, item) => {
    arr
    ->Array.push(
      item
      ->getDictFromJson
      ->getString("value", ""),
    )
    ->ignore
    arr
  })
}

let isAddressComplete = (
  line1: RecoilAtomTypes.field,
  city: RecoilAtomTypes.field,
  postalCode: RecoilAtomTypes.field,
  country: RecoilAtomTypes.field,
  state: RecoilAtomTypes.field,
) =>
  line1.value != "" &&
  city.value != "" &&
  postalCode.value != "" &&
  country.value != "" &&
  state.value != ""

let deepCopyDict = dict => {
  let emptyDict = Dict.make()
  dict
  ->Dict.toArray
  ->Array.map(item => {
    let (key, value) = item
    emptyDict->Dict.set(key, value)
  })
  ->ignore
  emptyDict
}

let snakeToTitleCase = str => {
  let words = str->String.split("_")
  words
  ->Array.map(item => {
    item->String.charAt(0)->String.toUpperCase ++ item->String.sliceToEnd(~start=1)
  })
  ->Array.join(" ")
}

let formatIBAN = iban => {
  let formatted = iban->String.replaceRegExp(%re(`/[^a-zA-Z0-9]/g`), "")
  let countryCode = formatted->String.substring(~start=0, ~end=2)->String.toUpperCase
  let codeLastTwo = formatted->String.substring(~start=2, ~end=4)
  let remaining = formatted->String.substringToEnd(~start=4)

  let chunks = switch remaining->String.match(%re(`/(.{1,4})/g`)) {
  | Some(matches) => matches->Belt.Array.keepMap(x => x)
  | None => []
  }

  `${countryCode}${codeLastTwo} ${chunks->Array.join(" ")}`->String.trim
}

let formatBSB = bsb => {
  let formatted = bsb->String.replaceRegExp(%re("/\D+/g"), "")
  let firstPart = formatted->String.substring(~start=0, ~end=3)
  let secondPart = formatted->String.substring(~start=3, ~end=6)

  if formatted->String.length <= 3 {
    firstPart
  } else if formatted->String.length > 3 && formatted->String.length <= 6 {
    `${firstPart}-${secondPart}`
  } else {
    formatted
  }
}

let getDictIsSome = (dict, key) => {
  dict->Dict.get(key)->Option.isSome
}

let rgbaTorgb = bgColor => {
  let cleanBgColor = bgColor->String.trim
  if cleanBgColor->String.startsWith("rgba") || cleanBgColor->String.startsWith("rgb") {
    let start = cleanBgColor->String.indexOf("(")
    let end = cleanBgColor->String.indexOf(")")

    let colorArr = cleanBgColor->String.substring(~start=start + 1, ~end)->String.split(",")
    if colorArr->Array.length === 3 {
      cleanBgColor
    } else {
      let red = colorArr->Array.get(0)->Option.getOr("0")
      let green = colorArr->Array.get(1)->Option.getOr("0")
      let blue = colorArr->Array.get(2)->Option.getOr("0")
      `rgba(${red}, ${green}, ${blue})`
    }
  } else {
    cleanBgColor
  }
}

let delay = timeOut => {
  Promise.make((resolve, _reject) => {
    setTimeout(() => {
      resolve(Dict.make())
    }, timeOut)->ignore
  })
}

let getHeaders = (
  ~uri=?,
  ~token=?,
  ~customPodUri=None,
  ~headers=Dict.make(),
  ~publishableKey=None,
  ~clientSecret=None,
  ~profileId=None,
): Fetch.Headers.t => {
  let publishableKeyVal = publishableKey->Option.map(key => key)->Option.getOr("invalid_key")
  let profileIdVal = profileId->Option.getOr("invalid_key")
  let clientSecretVal = clientSecret->Option.getOr("invalid_key")

  let defaultHeaders = [
    ("Content-Type", "application/json"),
    ("X-Client-Version", Window.version),
    ("X-Payment-Confirm-Source", "sdk"),
    ("X-Browser-Name", HyperLogger.arrayOfNameAndVersion->Array.get(0)->Option.getOr("Others")),
    ("X-Browser-Version", HyperLogger.arrayOfNameAndVersion->Array.get(1)->Option.getOr("0")),
    ("X-Client-Platform", "web"),
  ]

  let authorizationHeaders = switch GlobalVars.sdkVersion {
  | V2 => [
      ("x-profile-id", profileIdVal),
      ("Authorization", `publishable-key=${publishableKeyVal},client-secret=${clientSecretVal}`),
    ]
  | V1 => [("api-key", publishableKey->Option.map(key => key)->Option.getOr("invalid_key"))]
  }

  let authHeader = switch (token, uri) {
  | (Some(tok), Some(_)) => [("Authorization", tok)]
  | _ => []
  }

  let customPodHeader = switch customPodUri {
  | Some("") | None => []
  | Some(uriVal) => [("x-feature", uriVal)]
  }

  let finalHeaders = [
    ...defaultHeaders,
    ...authorizationHeaders,
    ...authHeader,
    ...customPodHeader,
    ...Dict.toArray(headers),
  ]

  Fetch.Headers.fromObject(Dict.fromArray(finalHeaders)->dictToObj)
}

let formatException = exc =>
  switch exc {
  | Exn.Error(obj) =>
    let message = Exn.message(obj)
    let name = Exn.name(obj)
    let stack = Exn.stack(obj)
    let fileName = Exn.fileName(obj)

    if (
      message->Option.isSome ||
      name->Option.isSome ||
      stack->Option.isSome ||
      fileName->Option.isSome
    ) {
      [
        ("message", message->Option.getOr("Unknown Error")->JSON.Encode.string),
        ("type", name->Option.getOr("Unknown")->JSON.Encode.string),
        ("stack", stack->Option.getOr("Unknown")->JSON.Encode.string),
        ("fileName", fileName->Option.getOr("Unknown")->JSON.Encode.string),
      ]->getJsonFromArrayOfJson
    } else {
      exc->Identity.anyTypeToJson
    }
  | _ => exc->Identity.anyTypeToJson
  }

let fetchApi = (
  uri,
  ~bodyStr: string="",
  ~headers=Dict.make(),
  ~method: Fetch.method,
  ~customPodUri=None,
  ~publishableKey=None,
) => {
  open Promise
  let body = switch method {
  | #GET => resolve(None)
  | _ => resolve(Some(Fetch.Body.string(bodyStr)))
  }
  body->then(body => {
    Fetch.fetch(
      uri,
      {
        method,
        ?body,
        headers: getHeaders(~headers, ~uri, ~customPodUri, ~publishableKey),
      },
    )
    ->catch(err => {
      reject(err)
    })
    ->then(resp => {
      resolve(resp)
    })
  })
}

let fetchApiWithLogging = async (
  uri,
  ~eventName,
  ~logger,
  ~onSuccess,
  ~onFailure,
  ~bodyStr="",
  ~headers=?,
  ~method,
  ~customPodUri=None,
  ~publishableKey=None,
  ~isPaymentSession=false,
  ~onCatchCallback=None,
  ~clientSecret=None,
  ~profileId=None,
) => {
  open LoggerUtils

  // * Log request initiation
  if GlobalVars.sdkVersion != V2 {
    LogAPIResponse.logApiResponse(
      ~logger,
      ~uri,
      ~eventName=apiEventInitMapper(eventName),
      ~status=Request,
    )
  }

  try {
    let body = switch method {
    | #GET => None
    | _ => Some(Fetch.Body.string(bodyStr))
    }

    let resp = await Fetch.fetch(
      uri,
      {
        method,
        ?body,
        headers: getHeaders(
          ~headers=headers->Option.getOr(Dict.make()),
          ~uri,
          ~customPodUri,
          ~publishableKey,
          ~clientSecret,
          ~profileId,
        ),
      },
    )

    let statusCode = resp->Fetch.Response.status

    if resp->Fetch.Response.ok {
      let data = await Fetch.Response.json(resp)
      if GlobalVars.sdkVersion != V2 {
        LogAPIResponse.logApiResponse(
          ~logger,
          ~uri,
          ~eventName=Some(eventName),
          ~status=Success,
          ~statusCode,
          ~isPaymentSession,
        )
      }
      onSuccess(data)
    } else {
      let data = await resp->Fetch.Response.json
      if GlobalVars.sdkVersion != V2 {
        LogAPIResponse.logApiResponse(
          ~logger,
          ~uri,
          ~eventName=Some(eventName),
          ~status=Error,
          ~statusCode,
          ~data,
          ~isPaymentSession,
        )
      }
      onFailure(data)
    }
  } catch {
  | err => {
      let exceptionMessage = err->formatException
      Console.error2(
        "Unexpected error while making request:",
        {
          "uri": uri,
          "event": eventName,
          "error": exceptionMessage,
        },
      )
      if GlobalVars.sdkVersion != V2 {
        LogAPIResponse.logApiResponse(
          ~logger,
          ~uri,
          ~eventName=Some(eventName),
          ~status=Exception,
          ~data=exceptionMessage,
          ~isPaymentSession,
        )
      }
      switch onCatchCallback {
      | Some(fun) => fun(exceptionMessage)
      | None => onFailure(exceptionMessage)
      }
    }
  }
}

let arrayJsonToCamelCase = arr => {
  arr->Array.map(item => {
    item->transformKeys(CamelCase)
  })
}

let getArrayValFromJsonDict = (dict, key, arrayKey) => {
  dict
  ->Dict.get(key)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.getOr(Dict.make())
  ->Dict.get(arrayKey)
  ->Option.flatMap(JSON.Decode.array)
  ->Option.getOr([])
  ->Belt.Array.keepMap(JSON.Decode.string)
}

let isOtherElements = componentType => {
  componentType == "card" ||
  componentType == "cardNumber" ||
  componentType == "cardExpiry" ||
  componentType == "cardCvc"
}

let nbsp = `\u00A0`

let callbackFuncForExtractingValFromDict = key => {
  x => x->Dict.get(key)
}

let brandIconSize = 28

let getClasses = (options, key) => {
  let classes = options->getDictFromObj("classes")
  classes->getString(key, "")
}

let safeParseOpt = st => {
  try {
    JSON.parseExn(st)->Some
  } catch {
  | _ => None
  }
}
let safeParse = st => {
  safeParseOpt(st)->Option.getOr(JSON.Encode.null)
}

let getArrayOfTupleFromDict = dict => {
  dict
  ->Dict.keysToArray
  ->Array.map(key => (key, Dict.get(dict, key)->Option.getOr(JSON.Encode.null)))
}

let getOptionalJsonFromJson = (json, str) => {
  json->JSON.Decode.object->Option.getOr(Dict.make())->Dict.get(str)
}

let getStringFromOptionalJson = (json, default) => {
  json->Option.flatMap(JSON.Decode.string)->Option.getOr(default)
}

let getBoolFromOptionalJson = (json, default) => {
  json->Option.flatMap(JSON.Decode.bool)->Option.getOr(default)
}

let getBoolFromJson = (json, default) => {
  json->JSON.Decode.bool->Option.getOr(default)
}

let getOptionalJson = (json, str) => {
  json
  ->JSON.Decode.object
  ->Option.flatMap(x => x->Dict.get("data"))
  ->Option.getOr(Dict.make()->JSON.Encode.object)
  ->JSON.Decode.object
  ->Option.getOr(Dict.make())
  ->Dict.get(str)
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

let mergeTwoFlattenedJsonDicts = (dict1, dict2) =>
  [...dict1->Dict.toArray, ...dict2->Dict.toArray]->getJsonFromArrayOfJson->unflattenObject

open Identity

let rec flattenObject = (obj, addIndicatorForObject) => {
  let newDict = Dict.make()
  switch obj->JSON.Decode.object {
  | Some(obj) =>
    obj
    ->Dict.toArray
    ->Array.forEach(entry => {
      let (key, value) = entry

      if value->jsonToNullableJson->Js.Nullable.isNullable {
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

      if value->jsonToNullableJson->Js.Nullable.isNullable {
        Dict.set(newDict, key, value)
      } else {
        switch value->getStringFromJson("")->safeParse->JSON.Decode.object {
        | Some(_valueObj) => {
            if addIndicatorForObject {
              Dict.set(newDict, key, JSON.Encode.object(Dict.make()))
            }

            let flattenedSubObj = flattenObjectWithStringifiedJson(
              value->getStringFromJson("")->safeParse,
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

      if value->jsonToNullableJson->Js.Nullable.isNullable {
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
              | String(_str) => stringArray->Array.push(item)
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

              | _ => arrayArray->Array.push(item)
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
      | CompleteDoThis
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
  Promise.make((resolve, _) => {
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
  form.style = "display: hidden;"
  element->appendChild(form)
  form
}

let getThemePromise = dict => {
  let theme =
    dict
    ->getJsonObjectFromDict("appearance")
    ->getDictFromJson
    ->getString("theme", "default")

  switch theme {
  | "default" => None
  | "brutal" => Some(ThemeImporter.importTheme("../BrutalTheme.bs.js"))
  | "midnight" => Some(ThemeImporter.importTheme("../MidnightTheme.bs.js"))
  | "charcoal" => Some(ThemeImporter.importTheme("../CharcoalTheme.bs.js"))
  | "soft" => Some(ThemeImporter.importTheme("../SoftTheme.bs.js"))
  | "bubblegum" => Some(ThemeImporter.importTheme("../BubblegumTheme.bs.js"))
  | "none" => Some(ThemeImporter.importTheme("../NoTheme.bs.js"))
  | _ => None
  }
}

let makeOneClickHandlerPromise = sdkHandleIsThere => {
  Promise.make((resolve, _) => {
    if !sdkHandleIsThere {
      resolve(JSON.Encode.bool(true))
    } else {
      let handleMessage = (event: Window.event) => {
        let json = try {
          event.data->safeParse
        } catch {
        | _ => JSON.Encode.null
        }

        let dict = json->getDictFromJson

        if dict->Dict.get("walletClickEvent")->Option.isSome {
          resolve(dict->Dict.get("walletClickEvent")->Option.getOr(true->JSON.Encode.bool))
        }
      }
      Window.addEventListener("message", handleMessage)
      handleOnConfirmPostMessage(~targetOrigin="*", ~isOneClick=true)
    }
  })
}

let generateRandomString = length => {
  let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  let result = ref("")
  let charactersLength = characters->String.length
  Int.range(0, length)->Array.forEach(_ => {
    let charIndex = mod((Math.random() *. 100.0)->Float.toInt, charactersLength)
    result := result.contents ++ characters->String.charAt(charIndex)
  })
  result.contents
}

let getWalletPaymentMethod = (wallets, paymentType: CardThemeType.mode) => {
  switch paymentType {
  | GooglePayElement => wallets->Array.filter(item => item === "google_pay")
  | PayPalElement => wallets->Array.filter(item => item === "paypal")
  | ApplePayElement => wallets->Array.filter(item => item === "apple_pay")
  | KlarnaElement => wallets->Array.filter(item => item === "klarna")
  | PazeElement => wallets->Array.filter(item => item === "paze")
  | SamsungPayElement => wallets->Array.filter(item => item === "samsung_pay")
  | _ => wallets
  }
}

let expressCheckoutComponents = [
  "googlePay",
  "payPal",
  "applePay",
  "klarna",
  "paze",
  "samsungPay",
  "expressCheckout",
]

let spmComponents = ["paymentMethodCollect"]->Array.concat(expressCheckoutComponents)

let componentsForPaymentElementCreate =
  ["payment", "paymentMethodCollect", "paymentMethodsManagement"]->Array.concat(
    expressCheckoutComponents,
  )

let getIsExpressCheckoutComponent = componentType => {
  expressCheckoutComponents->Array.includes(componentType)
}

let getIsComponentTypeForPaymentElementCreate = componentType => {
  componentsForPaymentElementCreate->Array.includes(componentType)
}

let walletElementPaymentType: array<CardThemeType.mode> = [
  GooglePayElement,
  PayPalElement,
  ApplePayElement,
  SamsungPayElement,
  KlarnaElement,
  PazeElement,
  ExpressCheckoutElement,
]

let checkIsWalletElement = (paymentType: CardThemeType.mode) => {
  walletElementPaymentType->Array.includes(paymentType)
}

let getUniqueArray = arr => arr->Array.map(item => (item, ""))->Dict.fromArray->Dict.keysToArray

let getStateNameFromStateCodeAndCountry = (list: JSON.t, stateCode: string, country: string) => {
  let options =
    list
    ->getDictFromJson
    ->getOptionalArrayFromDict(country)

  options
  ->Option.flatMap(
    Array.find(_, item =>
      item
      ->getDictFromJson
      ->getString("code", "") === stateCode
    ),
  )
  ->Option.flatMap(stateObj =>
    stateObj
    ->getDictFromJson
    ->getOptionString("value")
  )
  ->Option.getOr(stateCode)
}

let getStateCodeFromStateName = (stateName: string, countryCode: string): string => {
  let countryStates =
    CountryStateDataRefs.stateDataRef.contents
    ->getDictFromJson
    ->getOptionalArrayFromDict(countryCode)

  let stateCode =
    countryStates
    ->Option.flatMap(states =>
      states->Array.find(state => {
        let stateDict = state->getDictFromJson
        let stateValue = stateDict->getString("value", "")
        stateValue === stateName
      })
    )
    ->Option.flatMap(foundState =>
      foundState
      ->getDictFromJson
      ->getOptionString("code")
    )

  stateCode->Option.getOr(stateName)
}
let removeHyphen = str => str->String.replaceRegExp(%re("/-/g"), "")

let compareLogic = (a, b) => {
  if a == b {
    0.
  } else if a > b {
    -1.
  } else {
    1.
  }
}

let currencyNetworksDict =
  [
    ("BTC", ["bitcoin", "bnb_smart_chain"]),
    ("LTC", ["litecoin", "bnb_smart_chain"]),
    ("ETH", ["ethereum", "bnb_smart_chain"]),
    ("XRP", ["ripple", "bnb_smart_chain"]),
    ("XLM", ["stellar", "bnb_smart_chain"]),
    ("BCH", ["bitcoin_cash", "bnb_smart_chain"]),
    ("ADA", ["cardano", "bnb_smart_chain"]),
    ("SOL", ["solana", "bnb_smart_chain"]),
    ("SHIB", ["ethereum", "bnb_smart_chain"]),
    ("TRX", ["tron", "bnb_smart_chain"]),
    ("DOGE", ["dogecoin", "bnb_smart_chain"]),
    ("BNB", ["bnb_smart_chain"]),
    ("USDT", ["ethereum", "tron", "bnb_smart_chain"]),
    ("USDC", ["ethereum", "tron", "bnb_smart_chain"]),
    ("DAI", ["ethereum", "bnb_smart_chain"]),
  ]->Dict.fromArray

let toSpacedUpperCase = (~str, ~delimiter) =>
  str
  ->String.toUpperCase
  ->String.split(delimiter)
  ->Array.join(" ")

let handleFailureResponse = (~message, ~errorType) =>
  [
    (
      "error",
      [
        ("type", errorType->JSON.Encode.string),
        ("message", message->JSON.Encode.string),
      ]->getJsonFromArrayOfJson,
    ),
  ]->getJsonFromArrayOfJson

let getPaymentId = clientSecret =>
  String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")

let checkIs18OrAbove = dateOfBirth => {
  let currentDate = Date.make()
  let year = currentDate->Date.getFullYear - 18
  let month = currentDate->Date.getMonth
  let date = currentDate->Date.getDate
  let compareDate = Date.makeWithYMD(~year, ~month, ~date)
  dateOfBirth <= compareDate
}

let getFirstAndLastNameFromFullName = fullName => {
  let nameStrings = fullName->String.split(" ")
  let firstName =
    nameStrings
    ->Array.get(0)
    ->Option.flatMap(x => Some(x->JSON.Encode.string))
    ->Option.getOr(JSON.Encode.null)
  let lastNameStr = nameStrings->Array.sliceToEnd(~start=1)->Array.join(" ")->String.trim
  let lastNameJson = lastNameStr === "" ? JSON.Encode.null : lastNameStr->JSON.Encode.string

  (firstName, lastNameJson)
}

let isKeyPresentInDict = (dict, key) => dict->Dict.get(key)->Option.isSome

let minorUnitToString = val => (val->Int.toFloat /. 100.)->Float.toString

let mergeAndFlattenToTuples = (body, requiredFieldsBody) =>
  body
  ->getJsonFromArrayOfJson
  ->flattenObject(true)
  ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
  ->getArrayOfTupleFromDict

let handleIframePostMessageForWallets = (msg, componentName, mountedIframeRef) => {
  let isMessageSent = ref(false)
  let iframes = Window.querySelectorAll("iframe")

  iframes->Array.forEach(iframe => {
    let iframeSrc = iframe->Window.getAttribute("src")->Nullable.toOption->Option.getOr("")
    if iframeSrc->String.includes(`componentName=${componentName}`) {
      iframe->Js.Nullable.return->Window.iframePostMessage(msg)
      isMessageSent := true
    }
  })

  if !isMessageSent.contents {
    mountedIframeRef->Window.iframePostMessage(msg)
  }
}

let isDigitLimitExceeded = (val, ~digit) => {
  switch val->String.match(%re("/\d/g")) {
  | Some(matches) => matches->Array.length > digit
  | None => false
  }
}

/* Redirect Handling */
let replaceRootHref = (href: string, redirectionFlags: RecoilAtomTypes.redirectionFlags) => {
  if redirectionFlags.shouldRemoveBeforeUnloadEvents {
    handleBeforeRedirectPostMessage()
  }
  switch redirectionFlags.shouldUseTopRedirection {
  | true =>
    try {
      setTimeout(() => {
        Window.Top.Location.replace(href)
      }, 100)->ignore
    } catch {
    | e => {
        Console.error3(
          "Failed to redirect root document",
          e,
          `Using [window.location.replace] for redirection`,
        )
        Window.Location.replace(href)
      }
    }
  | false => Window.Location.replace(href)
  }
}

let isValidHexColor = (color: string): bool => {
  let hexRegex = %re("/^#([0-9a-f]{6}|[0-9a-f]{3})$/i")
  Js.Re.test_(hexRegex, color)
}

let convertKeyValueToJsonStringPair = (key, value) => (key, JSON.Encode.string(value))

let validateName = (
  val: string,
  prev: RecoilAtomTypes.field,
  localeString: LocaleStringTypes.localeStrings,
) => {
  let isValid = val !== "" && %re("/^\D*$/")->RegExp.test(val)
  let errorString = if val === "" {
    prev.errorString
  } else if isValid {
    ""
  } else {
    localeString.invalidCardHolderNameError
  }
  {
    ...prev,
    value: val,
    isValid: Some(isValid),
    errorString,
  }
}

let validateNickname = (val: string, localeString: LocaleStringTypes.localeStrings) => {
  let isValid = Some(val === "" || !(val->isDigitLimitExceeded(~digit=2)))
  let errorString =
    val !== "" && val->isDigitLimitExceeded(~digit=2) ? localeString.invalidNickNameError : ""

  (isValid, errorString)
}

let setNickNameState = (
  val,
  prevState: RecoilAtomTypes.field,
  localeString: LocaleStringTypes.localeStrings,
) => {
  let (isValid, errorString) = val->validateNickname(localeString)
  {
    ...prevState,
    value: val,
    isValid,
    errorString,
  }
}

let getStringFromDict = (dict, key, defaultValue: string) => {
  dict
  ->Option.flatMap(x => x->Dict.get(key))
  ->Option.flatMap(JSON.Decode.string)
  ->Option.getOr(defaultValue)
}

let loadScriptIfNotExist = (~url, ~logger: HyperLoggerTypes.loggerMake, ~eventName) => {
  if Window.querySelectorAll(`script[src="${url}"]`)->Array.length === 0 {
    let script = Window.createElement("script")
    script->Window.elementSrc(url)
    script->Window.elementOnerror(_ => {
      logger.setLogError(~value="Script failed to load", ~eventName)
    })
    script->Window.elementOnload(() => {
      logger.setLogInfo(~value="Script loaded successfully", ~eventName)
    })
    Window.body->Window.appendChild(script)
  }
}

let defaultCountryCode = {
  let clientTimeZone = dateTimeFormat().resolvedOptions().timeZone
  let clientCountry = getClientCountry(clientTimeZone)
  clientCountry.isoAlpha2
}
