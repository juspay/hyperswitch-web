@val external document: 'a = "document"
type window
type parent
@val external window: window = "window"
@val @scope("window") external iframeParent: parent = "parent"
type event = {data: string}
external eventToJson: event => JSON.t = "%identity"
external toJson: 'a => JSON.t = "%identity"
external dictToObj: Js.Dict.t<'a> => {..} = "%identity"

@module("./Phone_number.json")
external phoneNumberJson: JSON.t = "default"

type options = {timeZone: string}
type dateTimeFormat = {resolvedOptions: (. unit) => options}
@val @scope("Intl") external dateTimeFormat: (. unit) => dateTimeFormat = "DateTimeFormat"

@send external remove: Dom.element => unit = "remove"

@send external postMessage: (parent, JSON.t, string) => unit = "postMessage"
open ErrorUtils
let handlePostMessage = (~targetOrigin="*", messageArr) => {
  iframeParent->postMessage(messageArr->Js.Dict.fromArray->JSON.Encode.object, targetOrigin)
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
  dict->Js.Dict.get(key)->Option.flatMap(JSON.Decode.string)
}

let getString = (dict, key, default) => {
  getOptionString(dict, key)->Option.getOr(default)
}

let getInt = (dict, key, default: int) => {
  dict
  ->Js.Dict.get(key)
  ->Option.flatMap(JSON.Decode.float)
  ->Option.getOr(default->Belt.Int.toFloat)
  ->Belt.Float.toInt
}

let getJsonBoolValue = (dict, key, default) => {
  dict->Js.Dict.get(key)->Option.getOr(default->JSON.Encode.bool)
}

let getJsonStringFromDict = (dict, key, default) => {
  dict->Js.Dict.get(key)->Option.getOr(default->JSON.Encode.string)
}

let getJsonArrayFromDict = (dict, key, default) => {
  dict->Js.Dict.get(key)->Option.getOr(default->JSON.Encode.array)
}
let getJsonFromDict = (dict, key, default) => {
  dict->Js.Dict.get(key)->Option.getOr(default)
}

let getJsonObjFromDict = (dict, key, default) => {
  dict->Js.Dict.get(key)->Option.flatMap(JSON.Decode.object)->Option.getOr(default)
}
let getDecodedStringFromJson = (json, callbackFunc, defaultValue) => {
  json
  ->JSON.Decode.object
  ->Option.flatMap(callbackFunc)
  ->Option.flatMap(JSON.Decode.string)
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
  switch dict->Js.Dict.get(key) {
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
  dict->Js.Dict.get(key)->Option.flatMap(JSON.Decode.object)->Option.getOr(Js.Dict.empty())
}

let getJsonObjectFromDict = (dict, key) => {
  dict->Js.Dict.get(key)->Option.getOr(JSON.Encode.object(Js.Dict.empty()))
}
let getOptionBool = (dict, key) => {
  dict->Js.Dict.get(key)->Option.flatMap(JSON.Decode.bool)
}
let getDictFromJson = (json: JSON.t) => {
  json->JSON.Decode.object->Option.getOr(Js.Dict.empty())
}

let getBool = (dict, key, default) => {
  getOptionBool(dict, key)->Option.getOr(default)
}

let getBoolWithWarning = (dict, key, default, ~logger) => {
  switch dict->Js.Dict.get(key) {
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
  switch dict->Js.Dict.get(key) {
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
  dict->Js.Dict.get(key)->Option.flatMap(JSON.Decode.array)
}
let getArray = (dict, key) => {
  dict->getOptionalArrayFromDict(key)->Option.getOr([])
}

let getStrArray = (dict, key) => {
  dict
  ->getOptionalArrayFromDict(key)
  ->Option.getOr([])
  ->Belt.Array.map(json => json->JSON.Decode.string->Option.getOr(""))
}
let getOptionalStrArray: (Js.Dict.t<JSON.t>, string) => option<array<string>> = (dict, key) => {
  switch dict->getOptionalArrayFromDict(key) {
  | Some(val) =>
    val->Array.length === 0
      ? None
      : Some(val->Belt.Array.map(json => json->JSON.Decode.string->Option.getOr("")))
  | None => None
  }
}

let getBoolValue = val => val->Option.getOr(false)

let toKebabCase = str => {
  str
  ->Js.String2.split("")
  ->Array.mapWithIndex((item, i) => {
    if item->Js.String2.toUpperCase === item {
      `${i != 0 ? "-" : ""}${item->Js.String2.toLowerCase}`
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
      ->Array.map(key => {
        let overrideProp = obj2->getJsonObjectFromDict(key)
        let defaultProp = obj1->getJsonObjectFromDict(key)
        if defaultProp->getDictFromJson->Js.Dict.keys->Array.length == 0 {
          obj1->Js.Dict.set(key, overrideProp)
        } else if (
          overrideProp->JSON.Decode.object->Option.isSome &&
            defaultProp->JSON.Decode.object->Option.isSome
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
  obj1->JSON.Encode.object
}

let postFailedSubmitResponse = (~errortype, ~message) => {
  let errorDict =
    [
      ("type", errortype->JSON.Encode.string),
      ("message", message->JSON.Encode.string),
    ]->Js.Dict.fromArray
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
let rec transformKeys = (json: JSON.t, to: case) => {
  let toCase = switch to {
  | CamelCase => toCamelCase
  | SnakeCase => toSnakeCase
  | KebabCase => toKebabCase
  }
  let dict = json->getDictFromJson
  dict
  ->Js.Dict.entries
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
  ->Js.Dict.fromArray
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
  let phoneNumberDict = phoneNumberJson->JSON.Decode.object->Option.getOr(Js.Dict.empty())
  let countriesArr =
    phoneNumberDict
    ->Js.Dict.get("countries")
    ->Option.flatMap(JSON.Decode.array)
    ->Option.getOr([])
    ->Belt.Array.keepMap(JSON.Decode.object)

  let filteredArr = countriesArr->Array.filter(countryObj => {
    countryObj
    ->Js.Dict.get("phone_number_code")
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("") == countryCode
  })
  switch filteredArr[0] {
  | Some(obj) =>
    let regex =
      obj->Js.Dict.get("validation_regex")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
    Js.Re.test_(regex->Js.Re.fromString, number)
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
  ->Js.Dict.entries
  ->Array.map(entry => {
    let (key, value) = entry

    let class = if !(key->Js.String2.startsWith(":")) && !(key->Js.String2.startsWith(".")) {
      switch value->JSON.Decode.string {
      | Some(str) => `${key->toKebabCase}:${str}`
      | None => ""
      }
    } else if key->Js.String2.startsWith(":") {
      switch value->JSON.Decode.object {
      | Some(obj) =>
        let style =
          obj
          ->Js.Dict.entries
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
    } else if key->Js.String2.startsWith(".") {
      switch value->JSON.Decode.object {
      | Some(obj) =>
        let style =
          obj
          ->Js.Dict.entries
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

    if !(key->Js.String2.startsWith(":")) && !(key->Js.String2.startsWith(".")) {
      modifiedArr->Array.push(class)->ignore
    } else if key->Js.String2.startsWith(":") || key->Js.String2.startsWith(".") {
      puseduoArr->Array.push(class)->ignore
    }
  })
  ->ignore

  if classname->Js.String2.length == 0 {
    `${modifiedArr->Array.joinWith(";")} ${puseduoArr->Array.joinWith(" ")}`
  } else {
    `.${classname} {${modifiedArr->Array.joinWith(";")}} ${puseduoArr->Array.joinWith(" ")}`
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
  paymentMethodOrder->getOptionalArr->Belt.Array.get(0)->Option.getOr("") == "card" ||
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
  if str->Js.String2.endsWith(unitInString) {
    let arr = str->Js.String2.split("")
    let val =
      arr
      ->Array.slice(~start=0, ~end={arr->Array.length - unitInString->Js.String2.length})
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
  if str->Js.String2.length != 9 {
    false
  } else {
    let firstWeight = 3
    let weights = [firstWeight, 7, 1, 3, 7, 1, 3, 7, 1]
    let sum =
      str
      ->Js.String2.split("")
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
    ("elementType", "payment"->JSON.Encode.string),
    ("complete", complete->JSON.Encode.bool),
    ("empty", empty->JSON.Encode.bool),
    ("value", [("type", paymentType->JSON.Encode.string)]->Js.Dict.fromArray->JSON.Encode.object),
  ])
}

let onlyDigits = str => str->Js.String2.replaceByRe(%re(`/\D/g`), "")

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
      item
      ->getDictFromJson
      ->Js.Dict.get("name")
      ->Option.flatMap(JSON.Decode.string)
      ->Option.getOr(""),
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
  let emptyDict = Js.Dict.empty()
  dict
  ->Js.Dict.entries
  ->Array.map(item => {
    let (key, value) = item
    emptyDict->Js.Dict.set(key, value)
  })
  ->ignore
  emptyDict
}

let snakeToTitleCase = str => {
  let words = str->Js.String2.split("_")
  words
  ->Array.map(item => {
    item->Js.String2.charAt(0)->Js.String2.toUpperCase ++ item->Js.String2.sliceToEnd(~from=1)
  })
  ->Array.joinWith(" ")
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
  dict->Js.Dict.get(key)->Option.isSome
}

let rgbaTorgb = bgColor => {
  let cleanBgColor = bgColor->Js.String2.trim
  if cleanBgColor->Js.String2.startsWith("rgba") || cleanBgColor->Js.String2.startsWith("rgb") {
    let start = cleanBgColor->Js.String2.indexOf("(")
    let end = cleanBgColor->Js.String2.indexOf(")")

    let colorArr =
      cleanBgColor->Js.String2.substring(~from=start + 1, ~to_=end)->Js.String2.split(",")
    if colorArr->Array.length === 3 {
      cleanBgColor
    } else {
      let red = colorArr->Belt.Array.get(0)->Option.getOr("0")
      let green = colorArr->Belt.Array.get(1)->Option.getOr("0")
      let blue = colorArr->Belt.Array.get(2)->Option.getOr("0")
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

  Js.Dict.entries(headers)->Array.forEach(entries => {
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
  arr->Array.map(item => {
    item->transformKeys(CamelCase)
  })
}
let formatException = exc => {
  exc->toJson
}

let getArrayValFromJsonDict = (dict, key, arrayKey) => {
  dict
  ->Js.Dict.get(key)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.getOr(Js.Dict.empty())
  ->Js.Dict.get(arrayKey)
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
