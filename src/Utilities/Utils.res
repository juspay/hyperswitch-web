@val external document: 'a = "document"
type window
type parent
@val external window: window = "window"
@val @scope("window") external iframeParent: parent = "parent"
type event = {data: string}
external eventToJson: event => Js.Json.t = "%identity"
external toJson: 'a => Js.Json.t = "%identity"
external dictToObj: Js.Dict.t<'a> => {..} = "%identity"

@module("./Phone_number.json")
external phoneNumberJson: Js.Json.t = "default"

type options = {timeZone: string}
type dateTimeFormat = {resolvedOptions: (. unit) => options}
@val @scope("Intl") external dateTimeFormat: (. unit) => dateTimeFormat = "DateTimeFormat"

@send external remove: Dom.element => unit = "remove"

@send external postMessage: (parent, Js.Json.t, string) => unit = "postMessage"
open ErrorUtils
let handlePostMessage = (~targetOrigin="*", messageArr) => {
  iframeParent->postMessage(messageArr->Js.Dict.fromArray->Js.Json.object_, targetOrigin)
}

let handleOnFocusPostMessage = (~targetOrigin="*", ()) => {
  handlePostMessage([("focus", true->Js.Json.boolean)], ~targetOrigin)
}

let handleOnBlurPostMessage = (~targetOrigin="*", ()) => {
  handlePostMessage([("blur", true->Js.Json.boolean)], ~targetOrigin)
}

let handleOnClickPostMessage = (~targetOrigin="*", ev) => {
  handlePostMessage(
    [("clickTriggered", true->Js.Json.boolean), ("event", ev->Js.Json.stringify->Js.Json.string)],
    ~targetOrigin,
  )
}
let handleOnConfirmPostMessage = (~targetOrigin="*", ~isOneClick=false, ()) => {
  let message = isOneClick ? "oneClickConfirmTriggered" : "confirmTriggered"
  handlePostMessage([(message, true->Js.Json.boolean)], ~targetOrigin)
}
let getOptionString = (dict, key) => {
  dict->Js.Dict.get(key)->Belt.Option.flatMap(Js.Json.decodeString)
}

let getString = (dict, key, default) => {
  getOptionString(dict, key)->Belt.Option.getWithDefault(default)
}

let getInt = (dict, key, default: int) => {
  dict
  ->Js.Dict.get(key)
  ->Belt.Option.flatMap(Js.Json.decodeNumber)
  ->Belt.Option.getWithDefault(default->Belt.Int.toFloat)
  ->Belt.Float.toInt
}

let getJsonBoolValue = (dict, key, default) => {
  dict->Js.Dict.get(key)->Belt.Option.getWithDefault(default->Js.Json.boolean)
}

let getJsonStringFromDict = (dict, key, default) => {
  dict->Js.Dict.get(key)->Belt.Option.getWithDefault(default->Js.Json.string)
}

let getJsonArrayFromDict = (dict, key, default) => {
  dict->Js.Dict.get(key)->Belt.Option.getWithDefault(default->Js.Json.array)
}
let getJsonFromDict = (dict, key, default) => {
  dict->Js.Dict.get(key)->Belt.Option.getWithDefault(default)
}

let getJsonObjFromDict = (dict, key, default) => {
  dict
  ->Js.Dict.get(key)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.getWithDefault(default)
}
let getDecodedStringFromJson = (json, callbackFunc, defaultValue) => {
  json
  ->Js.Json.decodeObject
  ->Belt.Option.flatMap(callbackFunc)
  ->Belt.Option.flatMap(Js.Json.decodeString)
  ->Belt.Option.getWithDefault(defaultValue)
}

let getDecodedBoolFromJson = (json, callbackFunc, defaultValue) => {
  json
  ->Js.Json.decodeObject
  ->Belt.Option.flatMap(callbackFunc)
  ->Belt.Option.flatMap(Js.Json.decodeBoolean)
  ->Belt.Option.getWithDefault(defaultValue)
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
      optionalStr->Belt.Option.getWithDefault(default)
    }
  }
}

let getWarningString = (dict, key, default, ~logger) => {
  switch dict->Js.Dict.get(key) {
  | Some(val) =>
    switch val->Js.Json.decodeString {
    | Some(val) => val
    | None =>
      manageErrorWarning(TYPE_STRING_ERROR, ~dynamicStr=key, ~logger, ())
      default
    }
  | None => default
  }
}

let getDictFromObj = (dict, key) => {
  dict
  ->Js.Dict.get(key)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.getWithDefault(Js.Dict.empty())
}

let getJsonObjectFromDict = (dict, key) => {
  dict->Js.Dict.get(key)->Belt.Option.getWithDefault(Js.Json.object_(Js.Dict.empty()))
}
let getOptionBool = (dict, key) => {
  dict->Js.Dict.get(key)->Belt.Option.flatMap(Js.Json.decodeBoolean)
}
let getDictFromJson = (json: Js.Json.t) => {
  json->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
}

let getBool = (dict, key, default) => {
  getOptionBool(dict, key)->Belt.Option.getWithDefault(default)
}

let getBoolWithWarning = (dict, key, default, ~logger) => {
  switch dict->Js.Dict.get(key) {
  | Some(val) =>
    switch val->Js.Json.decodeBoolean {
    | Some(val) => val
    | None =>
      manageErrorWarning(TYPE_BOOL_ERROR, ~dynamicStr=key, ~logger, ())
      default
    }
  | None => default
  }
}
let getNumberWithWarning = (dict, key, ~logger, default) => {
  switch dict->Js.Dict.get(key) {
  | Some(val) =>
    switch val->Js.Json.decodeNumber {
    | Some(val) => val->Belt.Float.toInt
    | None =>
      manageErrorWarning(TYPE_INT_ERROR, ~dynamicStr=key, ~logger, ())
      default
    }
  | None => default
  }
}

let getOptionalArrayFromDict = (dict, key) => {
  dict->Js.Dict.get(key)->Belt.Option.flatMap(Js.Json.decodeArray)
}
let getArray = (dict, key) => {
  dict->getOptionalArrayFromDict(key)->Belt.Option.getWithDefault([])
}

let getStrArray = (dict, key) => {
  dict
  ->getOptionalArrayFromDict(key)
  ->Belt.Option.getWithDefault([])
  ->Belt.Array.map(json => json->Js.Json.decodeString->Belt.Option.getWithDefault(""))
}
let getOptionalStrArray: (Js.Dict.t<Js.Json.t>, string) => option<array<string>> = (dict, key) => {
  switch dict->getOptionalArrayFromDict(key) {
  | Some(val) =>
    val->Js.Array2.length === 0
      ? None
      : Some(
          val->Belt.Array.map(json => json->Js.Json.decodeString->Belt.Option.getWithDefault("")),
        )
  | None => None
  }
}

let getBoolValue = val => val->Belt.Option.getWithDefault(false)

let toKebabCase = str => {
  str
  ->Js.String2.split("")
  ->Js.Array2.mapi((item, i) => {
    if item->Js.String2.toUpperCase === item {
      `${i != 0 ? "-" : ""}${item->Js.String2.toLowerCase}`
    } else {
      item
    }
  })
  ->Js.Array2.joinWith("")
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
let submitPaymentData = callback => {
  React.useEffect1(() => {handleMessage(callback, "")}, [callback])
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
      ->Js.Dict.keys
      ->Js.Array2.map(key => {
        let overrideProp = obj2->getJsonObjectFromDict(key)
        let defaultProp = obj1->getJsonObjectFromDict(key)
        if defaultProp->getDictFromJson->Js.Dict.keys->Js.Array.length == 0 {
          obj1->Js.Dict.set(key, overrideProp)
        } else if (
          overrideProp->Js.Json.decodeObject->Belt.Option.isSome &&
            defaultProp->Js.Json.decodeObject->Belt.Option.isSome
        ) {
          merge(defaultProp->getDictFromJson, overrideProp->getDictFromJson)
        } else if overrideProp !== defaultProp {
          obj1->Js.Dict.set(key, overrideProp)
        }
      })
      ->ignore
      obj1
    } else {
      obj1
    }->ignore
  }
  merge(obj1, obj2)->ignore
  obj1->Js.Json.object_
}

let postFailedSubmitResponse = (~errortype, ~message) => {
  let errorDict =
    [("type", errortype->Js.Json.string), ("message", message->Js.Json.string)]->Js.Dict.fromArray
  handlePostMessage([
    ("submitSuccessful", false->Js.Json.boolean),
    ("error", errorDict->Js.Json.object_),
  ])
}
let postSubmitResponse = (~jsonData, ~url) => {
  handlePostMessage([
    ("submitSuccessful", true->Js.Json.boolean),
    ("data", jsonData),
    ("url", url->Js.Json.string),
  ])
}

let toCamelCase = str => {
  if str->Js.String2.includes(":") {
    str
  } else {
    str
    ->Js.String2.toLowerCase
    ->Js.String2.unsafeReplaceBy0(%re(`/([-_][a-z])/g`), (letter, _, _) => {
      letter->Js.String2.toUpperCase
    })
    ->Js.String2.replaceByRe(%re(`/[^a-zA-Z]/g`), "")
  }
}
let toSnakeCase = str => {
  str->Js.String2.unsafeReplaceBy0(%re("/[A-Z]/g"), (letter, _, _) =>
    `_${letter->Js.String2.toLowerCase}`
  )
}
type case = CamelCase | SnakeCase | KebabCase
let rec transformKeys = (json: Js.Json.t, to: case) => {
  let toCase = switch to {
  | CamelCase => toCamelCase
  | SnakeCase => toSnakeCase
  | KebabCase => toKebabCase
  }
  let dict = json->getDictFromJson
  dict
  ->Js.Dict.entries
  ->Js.Array2.map(((key, value)) => {
    let x = switch Js.Json.classify(value) {
    | JSONObject(obj) => (key->toCase, obj->Js.Json.object_->transformKeys(to))
    | JSONArray(arr) => (
        key->toCase,
        {
          arr
          ->Js.Array2.map(item =>
            if item->Js.Json.decodeObject->Belt.Option.isSome {
              item->transformKeys(to)
            } else {
              item
            }
          )
          ->Js.Json.array
        },
      )
    | JSONString(str) => {
        let val = if str == "Final" {
          "FINAL"
        } else if str == "example" || str == "Adyen" {
          "adyen"
        } else {
          str
        }
        (key->toCase, val->Js.Json.string)
      }
    | JSONNumber(val) => (key->toCase, val->Belt.Float.toString->Js.Json.string)
    | _ => (key->toCase, value)
    }
    x
  })
  ->Js.Dict.fromArray
  ->Js.Json.object_
}

let getClientCountry = clientTimeZone => {
  Country.country
  ->Js.Array2.find(item =>
    item.timeZones->Js.Array2.find(i => i == clientTimeZone)->Belt.Option.isSome
  )
  ->Belt.Option.getWithDefault(Country.defaultTimeZone)
}

let removeDuplicate = arr => {
  arr->Js.Array2.filteri((item, i) => {
    arr->Js.Array2.indexOf(item) === i
  })
}

let isEmailValid = email => {
  switch email->Js.String2.match_(
    %re(
      "/^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/"
    ),
  ) {
  | Some(_match) => Some(true)
  | None => email->Js.String2.length > 0 ? Some(false) : None
  }
}

let checkEmailValid = (
  email: RecoilAtomTypes.field,
  fn: (. RecoilAtomTypes.field => RecoilAtomTypes.field) => unit,
) => {
  switch email.value->Js.String2.match_(
    %re(
      "/^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/"
    ),
  ) {
  | Some(_match) =>
    fn(.prev => {
      ...prev,
      isValid: Some(true),
    })
  | None =>
    email.value->Js.String2.length > 0
      ? fn(.prev => {
          ...prev,
          isValid: Some(false),
        })
      : fn(.prev => {
          ...prev,
          isValid: None,
        })
  }
}

let validatePhoneNumber = (countryCode, number) => {
  let phoneNumberDict =
    phoneNumberJson->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
  let countriesArr =
    phoneNumberDict
    ->Js.Dict.get("countries")
    ->Belt.Option.flatMap(Js.Json.decodeArray)
    ->Belt.Option.getWithDefault([])
    ->Belt.Array.keepMap(Js.Json.decodeObject)

  let filteredArr = countriesArr->Js.Array2.filter(countryObj => {
    countryObj
    ->Js.Dict.get("phone_number_code")
    ->Belt.Option.flatMap(Js.Json.decodeString)
    ->Belt.Option.getWithDefault("") == countryCode
  })
  switch filteredArr[0] {
  | Some(obj) =>
    let regex =
      obj
      ->Js.Dict.get("validation_regex")
      ->Belt.Option.flatMap(Js.Json.decodeString)
      ->Belt.Option.getWithDefault("")
    Js.Re.test_(regex->Js.Re.fromString, number)
  | None => false
  }
}

let sortBasedOnPriority = (sortArr: array<string>, priorityArr: array<string>) => {
  let finalPriorityArr = priorityArr->Js.Array2.filter(val => sortArr->Js.Array2.includes(val))
  sortArr
  ->Js.Array2.map(item => {
    if finalPriorityArr->Js.Array2.includes(item) {
      ()
    } else {
      finalPriorityArr->Js.Array2.push(item)->ignore
    }
  })
  ->ignore
  finalPriorityArr
}

let isAllValid = (
  card: option<bool>,
  cvc: option<bool>,
  expiry: option<bool>,
  zip: bool,
  paymentMode: string,
) => {
  card->getBoolValue &&
  cvc->getBoolValue &&
  expiry->getBoolValue && {paymentMode == "payment" ? true : zip}
}

let getCountryPostal = (countryCode, postalCodes: array<PostalCodeType.postalCodes>) => {
  postalCodes
  ->Js.Array2.find(item => item.iso == countryCode)
  ->Belt.Option.getWithDefault(PostalCodeType.defaultPostalCode)
}

let getCountryNames = (list: array<Country.timezoneType>) => {
  list->Js.Array2.reduce((arr, item) => {
    arr->Js.Array2.push(item.countryName)->ignore
    arr
  }, [])
}

let getBankNames = (list: Bank.bankList, allBanks: array<string>) => {
  list->Js.Array2.reduce((arr, item) => {
    if allBanks->Js.Array2.includes(item.hyperSwitch) {
      arr->Js.Array2.push(item.displayName)->ignore
    }
    arr
  }, [])
}

let getBankKeys = (str, banks: Bank.bankList, default) => {
  let bank =
    banks->Js.Array2.find(item => item.displayName == str)->Belt.Option.getWithDefault(default)
  bank.hyperSwitch
}

let constructClass = (~classname, ~dict) => {
  let puseduoArr = []
  let modifiedArr = []

  dict
  ->Js.Dict.entries
  ->Js.Array2.map(entry => {
    let (key, value) = entry

    let class = if !(key->Js.String2.startsWith(":")) && !(key->Js.String2.startsWith(".")) {
      switch value->Js.Json.decodeString {
      | Some(str) => `${key->toKebabCase}:${str}`
      | None => ""
      }
    } else if key->Js.String2.startsWith(":") {
      switch value->Js.Json.decodeObject {
      | Some(obj) =>
        let style =
          obj
          ->Js.Dict.entries
          ->Js.Array2.map(entry => {
            let (key, value) = entry
            switch value->Js.Json.decodeString {
            | Some(str) => `${key->toKebabCase}:${str}`
            | None => ""
            }
          })
        `.${classname}${key} {${style->Js.Array2.joinWith(";")}}`

      | None => ""
      }
    } else if key->Js.String2.startsWith(".") {
      switch value->Js.Json.decodeObject {
      | Some(obj) =>
        let style =
          obj
          ->Js.Dict.entries
          ->Js.Array2.map(entry => {
            let (key, value) = entry
            switch value->Js.Json.decodeString {
            | Some(str) => `${key->toKebabCase}:${str}`
            | None => ""
            }
          })
        `${key} {${style->Js.Array2.joinWith(";")}} `

      | None => ""
      }
    } else {
      ""
    }

    if !(key->Js.String2.startsWith(":")) && !(key->Js.String2.startsWith(".")) {
      modifiedArr->Js.Array2.push(class)->ignore
    } else if key->Js.String2.startsWith(":") || key->Js.String2.startsWith(".") {
      puseduoArr->Js.Array2.push(class)->ignore
    }
  })
  ->ignore

  if classname->Js.String2.length == 0 {
    `${modifiedArr->Js.Array2.joinWith(";")} ${puseduoArr->Js.Array2.joinWith(" ")}`
  } else {
    `.${classname} {${modifiedArr->Js.Array2.joinWith(";")}} ${puseduoArr->Js.Array2.joinWith(" ")}`
  }
}

let generateStyleSheet = (classname, dict, id) => {
  let createStyle = () => {
    let style = document["createElement"](. "style")
    style["type"] = "text/css"
    style["id"] = id
    style["appendChild"](. document["createTextNode"](. constructClass(~classname, ~dict)))->ignore
    document["body"]["appendChild"](. style)->ignore
  }
  switch Window.window->Window.document->Window.getElementById(id)->Js.Nullable.toOption {
  | Some(val) => {
      val->remove
      createStyle()
    }
  | None => createStyle()
  }
}
let openUrl = url => {
  handlePostMessage([("openurl", url->Js.Json.string)])
}

let getArrofJsonString = (arr: array<string>) => {
  arr->Js.Array2.map(item => item->Js.Json.string)
}

let getPaymentDetails = (arr: array<string>) => {
  let finalArr = []
  arr
  ->Js.Array2.map(item => {
    let optionalVal = PaymentDetails.details->Js.Array2.find(i => i.type_ == item)
    switch optionalVal {
    | Some(val) => finalArr->Js.Array2.push(val)->ignore
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
  paymentMethodOrder->getOptionalArr->Belt.Array.get(0)->Belt.Option.getWithDefault("") == "card" ||
    paymentMethodOrder->Belt.Option.isNone
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
  if str->Js.String2.endsWith(unitInString) {
    let arr = str->Js.String2.split("")
    let val =
      arr
      ->Js.Array2.slice(~start=0, ~end_={arr->Js.Array2.length - unitInString->Js.String2.length})
      ->Js.Array2.joinWith("")
      ->Belt.Float.fromString
      ->Belt.Option.getWithDefault(0.0)
    (val +. value)->Belt.Float.toString ++ unitInString
  } else {
    str
  }
}
let toInt = val => val->Belt.Int.fromString->Belt.Option.getWithDefault(0)

let validateRountingNumber = str => {
  if str->Js.String2.length != 9 {
    false
  } else {
    let firstWeight = 3
    let weights = [firstWeight, 7, 1, 3, 7, 1, 3, 7, 1]
    let sum =
      str
      ->Js.String2.split("")
      ->Js.Array2.mapi((item, i) => item->toInt * weights[i]->Option.getOr(firstWeight))
      ->Js.Array2.reduce((acc, val) => {
        acc + val
      }, 0)
    mod(sum, 10) == 0
  }
}

let handlePostMessageEvents = (
  ~complete,
  ~empty,
  ~paymentType,
  ~loggerState: OrcaPaymentPage.OrcaLogger.loggerMake,
) => {
  if complete && paymentType !== "" {
    loggerState.setLogInfo(
      ~value="Payment Data Filled",
      ~eventName=PAYMENT_DATA_FILLED,
      ~paymentMethod=paymentType,
      (),
    )
  }
  handlePostMessage([
    ("elementType", "payment"->Js.Json.string),
    ("complete", complete->Js.Json.boolean),
    ("empty", empty->Js.Json.boolean),
    ("value", [("type", paymentType->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_),
  ])
}

let onlyDigits = str => str->Js.String2.replaceByRe(%re(`/\D/g`), "")

let getCountryCode = country => {
  Country.country
  ->Js.Array2.find(item => item.countryName == country)
  ->Belt.Option.getWithDefault(Country.defaultTimeZone)
}

let getStateNames = (list: Js.Json.t, country: RecoilAtomTypes.field) => {
  let options =
    list
    ->getDictFromJson
    ->getOptionalArrayFromDict(getCountryCode(country.value).isoAlpha2)
    ->Belt.Option.getWithDefault([])

  options->Js.Array2.reduce((arr, item) => {
    arr
    ->Js.Array2.push(
      item
      ->getDictFromJson
      ->Js.Dict.get("name")
      ->Belt.Option.flatMap(Js.Json.decodeString)
      ->Belt.Option.getWithDefault(""),
    )
    ->ignore
    arr
  }, [])
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
  let emptyDict = Js.Dict.empty()
  dict
  ->Js.Dict.entries
  ->Js.Array2.map(item => {
    let (key, value) = item
    emptyDict->Js.Dict.set(key, value)
  })
  ->ignore
  emptyDict
}

let snakeToTitleCase = str => {
  let words = str->Js.String2.split("_")
  words
  ->Js.Array2.map(item => {
    item->Js.String2.charAt(0)->Js.String2.toUpperCase ++ item->Js.String2.sliceToEnd(~from=1)
  })
  ->Js.Array2.joinWith(" ")
}

let logInfo = log => {
  Window.isProd ? () : log
}

let formatIBAN = iban => {
  let formatted = iban->Js.String2.replaceByRe(%re(`/[^a-zA-Z0-9]/g`), "")
  let countryCode = formatted->Js.String2.substring(~from=0, ~to_=2)->Js.String2.toUpperCase
  let codeLastTwo = formatted->Js.String2.substring(~from=2, ~to_=4)
  let remaining = formatted->Js.String2.substr(~from=4)

  let chunks = switch remaining->Js.String2.match_(%re(`/(.{1,4})/g`)) {
  | Some(matches) => matches
  | None => []
  }
  `${countryCode}${codeLastTwo} ${chunks->Js.Array2.joinWith(" ")}`->Js.String2.trim
}

let formatBSB = bsb => {
  let formatted = bsb->Js.String2.replaceByRe(%re("/\D+/g"), "")
  let firstPart = formatted->Js.String2.substring(~from=0, ~to_=3)
  let secondPart = formatted->Js.String2.substring(~from=3, ~to_=6)

  if formatted->Js.String2.length <= 3 {
    firstPart
  } else if formatted->Js.String2.length > 3 && formatted->Js.String2.length <= 6 {
    `${firstPart}-${secondPart}`
  } else {
    formatted
  }
}

let getDictIsSome = (dict, key) => {
  dict->Js.Dict.get(key)->Belt.Option.isSome
}

let rgbaTorgb = bgColor => {
  let cleanBgColor = bgColor->Js.String2.trim
  if cleanBgColor->Js.String2.startsWith("rgba") || cleanBgColor->Js.String2.startsWith("rgb") {
    let start = cleanBgColor->Js.String2.indexOf("(")
    let end = cleanBgColor->Js.String2.indexOf(")")

    let colorArr =
      cleanBgColor->Js.String2.substring(~from=start + 1, ~to_=end)->Js.String2.split(",")
    if colorArr->Js.Array2.length === 3 {
      cleanBgColor
    } else {
      let red = colorArr->Belt.Array.get(0)->Belt.Option.getWithDefault("0")
      let green = colorArr->Belt.Array.get(1)->Belt.Option.getWithDefault("0")
      let blue = colorArr->Belt.Array.get(2)->Belt.Option.getWithDefault("0")
      `rgba(${red}, ${green}, ${blue})`
    }
  } else {
    cleanBgColor
  }
}

let delay = timeOut => {
  Promise.make((resolve, _reject) => {
    Js.Global.setTimeout(() => {
      resolve(. Js.Dict.empty())
    }, timeOut)->ignore
  })
}
let getHeaders = (~uri=?, ~token=?, ~headers=Js.Dict.empty(), ()) => {
  let headerObj =
    [("Content-Type", "application/json"), ("sdk-version", Window.version)]->Js.Dict.fromArray

  switch (token, uri) {
  | (Some(tok), Some(_uriVal)) => headerObj->Js.Dict.set("Authorization", tok)
  | _ => ()
  }

  Js.Dict.entries(headers)->Js.Array2.forEach(entries => {
    let (x, val) = entries
    Js.Dict.set(headerObj, x, val)
  })
  Fetch.HeadersInit.make(headerObj->dictToObj)
}
let fetchApi = (
  uri,
  ~bodyStr: string="",
  ~headers=Js.Dict.empty(),
  ~method_: Fetch.requestMethod,
  (),
) => {
  open Promise
  let body = switch method_ {
  | Get => resolve(None)
  | _ => resolve(Some(Fetch.BodyInit.make(bodyStr)))
  }

  body->then(body => {
    Fetch.fetchWithInit(
      uri,
      Fetch.RequestInit.make(~method_, ~body?, ~headers=getHeaders(~headers, ~uri, ()), ()),
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
  arr->Js.Array2.map(item => {
    item->transformKeys(CamelCase)
  })
}
let formatException = exc => {
  exc->toJson
}

let getArrayValFromJsonDict = (dict, key, arrayKey) => {
  dict
  ->Js.Dict.get(key)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.getWithDefault(Js.Dict.empty())
  ->Js.Dict.get(arrayKey)
  ->Belt.Option.flatMap(Js.Json.decodeArray)
  ->Belt.Option.getWithDefault([])
  ->Belt.Array.keepMap(Js.Json.decodeString)
}

let isOtherElements = componentType => {
  componentType == "card" ||
  componentType == "cardNumber" ||
  componentType == "cardExpiry" ||
  componentType == "cardCvc"
}

let nbsp = `\u00A0`

let callbackFuncForExtractingValFromDict = key => {
  x => x->Js.Dict.get(key)
}
