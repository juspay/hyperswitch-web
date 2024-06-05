@val external document: 'a = "document"
type window
type parent
@val external window: window = "window"
@val @scope("window") external iframeParent: parent = "parent"
type event = {data: string}
external dictToObj: Dict.t<'a> => {..} = "%identity"

@module("./Phone_number.json")
external phoneNumberJson: JSON.t = "default"

type options = {timeZone: string}
type dateTimeFormat = {resolvedOptions: unit => options}
@val @scope("Intl") external dateTimeFormat: unit => dateTimeFormat = "DateTimeFormat"

@send external remove: Dom.element => unit = "remove"

@send external postMessage: (parent, JSON.t, string) => unit = "postMessage"
open ErrorUtils
let handlePostMessage = (~targetOrigin="*", messageArr) => {
  iframeParent->postMessage(messageArr->Dict.fromArray->JSON.Encode.object, targetOrigin)
}

let handleOnFocusPostMessage = (~targetOrigin="*", ()) => {
  handlePostMessage([("focus", true->JSON.Encode.bool)], ~targetOrigin)
}

let handleOnBlurPostMessage = (~targetOrigin="*", ()) => {
  handlePostMessage([("blur", true->JSON.Encode.bool)], ~targetOrigin)
}

let handleOnClickPostMessage = (~targetOrigin="*", ev) => {
  handlePostMessage(
    [("clickTriggered", true->JSON.Encode.bool), ("event", ev->JSON.stringify->JSON.Encode.string)],
    ~targetOrigin,
  )
}
let handleOnConfirmPostMessage = (~targetOrigin="*", ~isOneClick=false, ()) => {
  let message = isOneClick ? "oneClickConfirmTriggered" : "confirmTriggered"
  handlePostMessage([(message, true->JSON.Encode.bool)], ~targetOrigin)
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

let getInt = (dict, key, default: int) => {
  dict
  ->Dict.get(key)
  ->Option.flatMap(JSON.Decode.float)
  ->Option.getOr(default->Belt.Int.toFloat)
  ->Belt.Float.toInt
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
      val == "" ? manageErrorWarning(REQUIRED_PARAMETER, ~dynamicStr=key, ~logger, ()) : ()
      val
    }
  | None => {
      manageErrorWarning(REQUIRED_PARAMETER, ~dynamicStr=key, ~logger, ())
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
      manageErrorWarning(TYPE_STRING_ERROR, ~dynamicStr=key, ~logger, ())
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

let getDictfromDict = (dict, key) => {
  dict->getJsonObjectFromDict(key)->getDictFromJson
}

let getBool = (dict, key, default) => {
  getOptionBool(dict, key)->Option.getOr(default)
}

let getBoolWithWarning = (dict, key, default, ~logger) => {
  switch dict->Dict.get(key) {
  | Some(val) =>
    switch val->JSON.Decode.bool {
    | Some(val) => val
    | None =>
      manageErrorWarning(TYPE_BOOL_ERROR, ~dynamicStr=key, ~logger, ())
      default
    }
  | None => default
  }
}
let getNumberWithWarning = (dict, key, ~logger, default) => {
  switch dict->Dict.get(key) {
  | Some(val) =>
    switch val->JSON.Decode.float {
    | Some(val) => val->Belt.Float.toInt
    | None =>
      manageErrorWarning(TYPE_INT_ERROR, ~dynamicStr=key, ~logger, ())
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
  ->Array.joinWith("")
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
      setSize(_ => (Window.windowInnerWidth, Window.windowInnerHeight))
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
  handlePostMessage([
    ("submitSuccessful", false->JSON.Encode.bool),
    ("error", errorDict->JSON.Encode.object),
  ])
}
let postSubmitResponse = (~jsonData, ~url) => {
  handlePostMessage([
    ("submitSuccessful", true->JSON.Encode.bool),
    ("data", jsonData),
    ("url", url->JSON.Encode.string),
  ])
}

let getFailedSubmitResponse = (~errorType, ~message) => {
  [
    (
      "error",
      [("type", errorType->JSON.Encode.string), ("message", message->JSON.Encode.string)]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]
  ->Dict.fromArray
  ->JSON.Encode.object
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
    | Number(val) => (key->toCase, val->Belt.Float.toString->JSON.Encode.string)
    | _ => (key->toCase, value)
    }
    x
  })
  ->Dict.fromArray
  ->JSON.Encode.object
}

let getClientCountry = clientTimeZone => {
  Country.country
  ->Array.find(item => item.timeZones->Array.find(i => i == clientTimeZone)->Option.isSome)
  ->Option.getOr(Country.defaultTimeZone)
}

let removeDuplicate = arr => {
  arr->Array.filterWithIndex((item, i) => {
    arr->Array.indexOf(item) === i
  })
}

let isEmailValid = email => {
  switch email->String.match(
    %re(
      "/^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/"
    ),
  ) {
  | Some(_match) => Some(true)
  | None => email->String.length > 0 ? Some(false) : None
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
    if allBanks->Array.includes(item.hyperSwitch) {
      arr->Array.push(item.displayName)->ignore
    }
    arr
  })
}

let getBankKeys = (str, banks: Bank.bankList, default) => {
  let bank = banks->Array.find(item => item.displayName == str)->Option.getOr(default)
  bank.hyperSwitch
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
        `.${classname}${key} {${style->Array.joinWith(";")}}`

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
        `${key} {${style->Array.joinWith(";")}} `

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
    `${modifiedArr->Array.joinWith(";")} ${puseduoArr->Array.joinWith(" ")}`
  } else {
    `.${classname} {${modifiedArr->Array.joinWith(";")}} ${puseduoArr->Array.joinWith(" ")}`
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
  handlePostMessage([("openurl", url->JSON.Encode.string)])
}

let getArrofJsonString = (arr: array<string>) => {
  arr->Array.map(item => item->JSON.Encode.string)
}

let getPaymentDetails = (arr: array<string>) => {
  let finalArr = []
  arr
  ->Array.map(item => {
    let optionalVal = PaymentDetails.details->Array.find(i => i.type_ == item)
    switch optionalVal {
    | Some(val) => finalArr->Array.push(val)->ignore
    | None => ()
    }
  })
  ->ignore
  finalArr
}
let getOptionalArr = arr => {
  switch arr {
  | Some(val) => val
  | None => []
  }
}

let checkPriorityList = paymentMethodOrder => {
  paymentMethodOrder->getOptionalArr->Array.get(0)->Option.getOr("") == "card" ||
    paymentMethodOrder->Option.isNone
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
      ->Array.joinWith("")
      ->Belt.Float.fromString
      ->Option.getOr(0.0)
    (val +. value)->Belt.Float.toString ++ unitInString
  } else {
    str
  }
}
let toInt = val => val->Belt.Int.fromString->Option.getOr(0)

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
  ~loggerState: OrcaLogger.loggerMake,
  ~savedMethod=false,
) => {
  if complete && paymentType !== "" {
    let value =
      "Payment Data Filled" ++ (savedMethod ? ": Saved Payment Method" : ": New Payment Method")
    loggerState.setLogInfo(~value, ~eventName=PAYMENT_DATA_FILLED, ~paymentMethod=paymentType, ())
  }
  handlePostMessage([
    ("elementType", "payment"->JSON.Encode.string),
    ("complete", complete->JSON.Encode.bool),
    ("empty", empty->JSON.Encode.bool),
    ("value", [("type", paymentType->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object),
  ])
}

let onlyDigits = str => str->String.replaceRegExp(%re(`/\D/g`), "")

let getCountryCode = country => {
  Country.country
  ->Array.find(item => item.countryName == country)
  ->Option.getOr(Country.defaultTimeZone)
}

let getStateNames = (list: JSON.t, country: RecoilAtomTypes.field) => {
  let options =
    list
    ->getDictFromJson
    ->getOptionalArrayFromDict(getCountryCode(country.value).isoAlpha2)
    ->Option.getOr([])

  options->Array.reduce([], (arr, item) => {
    arr
    ->Array.push(
      item->getDictFromJson->Dict.get("name")->Option.flatMap(JSON.Decode.string)->Option.getOr(""),
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
  ->Array.joinWith(" ")
}

let logInfo = log => {
  Window.isProd ? () : log
}

let formatIBAN = iban => {
  let formatted = iban->String.replaceRegExp(%re(`/[^a-zA-Z0-9]/g`), "")
  let countryCode = formatted->String.substring(~start=0, ~end=2)->String.toUpperCase
  let codeLastTwo = formatted->String.substring(~start=2, ~end=4)
  let remaining = formatted->String.substringToEnd(~start=4)

  let chunks = switch remaining->String.match(%re(`/(.{1,4})/g`)) {
  | Some(matches) => matches
  | None => []
  }
  `${countryCode}${codeLastTwo} ${chunks->Array.joinWith(" ")}`->String.trim
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
let getHeaders = (~uri=?, ~token=?, ~headers=Dict.make(), ()) => {
  let headerObj =
    [
      ("Content-Type", "application/json"),
      ("X-Client-Version", Window.version),
      ("X-Payment-Confirm-Source", "sdk"),
    ]->Dict.fromArray

  switch (token, uri) {
  | (Some(tok), Some(_uriVal)) => headerObj->Dict.set("Authorization", tok)
  | _ => ()
  }

  Dict.toArray(headers)->Array.forEach(entries => {
    let (x, val) = entries
    Dict.set(headerObj, x, val)
  })
  Fetch.Headers.fromObject(headerObj->dictToObj)
}
let fetchApi = (uri, ~bodyStr: string="", ~headers=Dict.make(), ~method: Fetch.method, ()) => {
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
        headers: getHeaders(~headers, ~uri, ()),
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

let arrayJsonToCamelCase = arr => {
  arr->Array.map(item => {
    item->transformKeys(CamelCase)
  })
}
let formatException = exc => {
  exc->Identity.anyTypeToJson
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

let getBoolFromJson = (json, default) => {
  json->Option.flatMap(JSON.Decode.bool)->Option.getOr(default)
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

let mergeTwoFlattenedJsonDicts = (dict1, dict2) => {
  dict1
  ->Dict.toArray
  ->Array.concat(dict2->Dict.toArray)
  ->Dict.fromArray
  ->JSON.Encode.object
  ->unflattenObject
}

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
  | "none" => Some(ThemeImporter.importTheme("../NoTheme.bs.js"))
  | _ => None
  }
}

let makeOneClickHandlerPromise = sdkHandleOneClickConfirmPayment => {
  open EventListenerManager
  Promise.make((resolve, _) => {
    if sdkHandleOneClickConfirmPayment {
      resolve(JSON.Encode.bool(true))
    } else {
      let handleMessage = (event: Types.event) => {
        let json = event.data->anyTypeToJson->getStringFromJson("")->safeParse

        let dict = json->getDictFromJson
        if dict->Dict.get("oneClickDoSubmit")->Option.isSome {
          resolve(dict->Dict.get("oneClickDoSubmit")->Option.getOr(true->JSON.Encode.bool))
        }
      }
      addSmartEventListener("message", handleMessage, "onOneClickHandlerPaymentConfirm")
      handleOnConfirmPostMessage(~targetOrigin="*", ~isOneClick=true, ())
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
  | _ => wallets
  }
}

let expressCheckoutComponents = ["googlePay", "payPal", "applePay", "klarna", "expressCheckout"]

let componentsForPaymentElementCreate = ["payment"]->Array.concat(expressCheckoutComponents)

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
  KlarnaElement,
  ExpressCheckoutElement,
]

let getIsWalletElementPaymentType = (paymentType: CardThemeType.mode) => {
  walletElementPaymentType->Array.includes(paymentType)
}

let getUniqueArray = arr => arr->Array.map(item => (item, ""))->Dict.fromArray->Dict.keysToArray

let getJsonFromArrayOfJson = arr => arr->Dict.fromArray->JSON.Encode.object

let getStateNameFromStateCodeAndCountry = (list: JSON.t, stateCode: string, country: string) => {
  let options =
    list
    ->getDictFromJson
    ->getOptionalArrayFromDict(country)
    ->Option.getOr([])

  let val = options->Array.find(item =>
    item
    ->getDictFromJson
    ->getString("code", "") === stateCode
  )

  switch val {
  | Some(stateObj) =>
    stateObj
    ->getDictFromJson
    ->getString("name", stateCode)
  | None => stateCode
  }
}

let removeHyphen = str => str->String.replaceRegExp(%re("/-/g"), "")
