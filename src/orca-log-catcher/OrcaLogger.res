type apiLogType = Request | Response | NoResponse | Method | Err
type logType = DEBUG | INFO | ERROR | WARNING | SILENT
type logCategory = API | USER_ERROR | USER_EVENT | MERCHANT_EVENT

type eventName =
  | APP_RENDERED
  | PAYMENT_METHOD_CHANGED
  | PAYMENT_DATA_FILLED
  | PAYMENT_ATTEMPT
  | PAYMENT_SUCCESS
  | PAYMENT_FAILED
  | INPUT_FIELD_CHANGED
  | RETRIEVE_CALL_INIT
  | RETRIEVE_CALL
  | AUTHENTICATION_CALL_INIT
  | AUTHENTICATION_CALL
  | CONFIRM_CALL_INIT
  | CONFIRM_CALL
  | SESSIONS_CALL_INIT
  | SESSIONS_CALL
  | PAYMENT_METHODS_CALL_INIT
  | PAYMENT_METHODS_CALL
  | CUSTOMER_PAYMENT_METHODS_CALL_INIT
  | CUSTOMER_PAYMENT_METHODS_CALL
  | TRUSTPAY_SCRIPT
  | GOOGLE_PAY_SCRIPT
  | APPLE_PAY_FLOW
  | GOOGLE_PAY_FLOW
  | PAYPAL_FLOW
  | PAYPAL_SDK_FLOW
  | APP_INITIATED
  | APP_REINITIATED
  | LOG_INITIATED
  | LOADER_CALLED
  | ORCA_ELEMENTS_CALLED
  | PAYMENT_OPTIONS_PROVIDED
  | BLUR
  | FOCUS
  | CLEAR
  | CONFIRM_PAYMENT
  | CONFIRM_CARD_PAYMENT
  | SDK_CRASH
  | INVALID_PK
  | DEPRECATED_LOADSTRIPE
  | REQUIRED_PARAMETER
  | UNKNOWN_KEY
  | UNKNOWN_VALUE
  | TYPE_BOOL_ERROR
  | TYPE_INT_ERROR
  | TYPE_STRING_ERROR
  | INVALID_FORMAT
  | SDK_CONNECTOR_WARNING
  | VALUE_OUT_OF_RANGE
  | HTTP_NOT_ALLOWED
  | INTERNAL_API_DOWN
  | REDIRECTING_USER
  | DISPLAY_BANK_TRANSFER_INFO_PAGE
  | DISPLAY_QR_CODE_INFO_PAGE
  | DISPLAY_VOUCHER
  | DISPLAY_THREE_DS_SDK
  | THREE_DS_METHOD
  | THREE_DS_METHOD_RESULT
  | PAYMENT_METHODS_RESPONSE
  | LOADER_CHANGED
  | PAYMENT_SESSION_INITIATED
  | POLL_STATUS_INIT
  | POLL_STATUS_CALL

let eventNameToStrMapper = eventName => {
  switch eventName {
  | APP_RENDERED => "APP_RENDERED"
  | PAYMENT_METHOD_CHANGED => "PAYMENT_METHOD_CHANGED"
  | PAYMENT_DATA_FILLED => "PAYMENT_DATA_FILLED"
  | PAYMENT_ATTEMPT => "PAYMENT_ATTEMPT"
  | PAYMENT_SUCCESS => "PAYMENT_SUCCESS"
  | PAYMENT_FAILED => "PAYMENT_FAILED"
  | INPUT_FIELD_CHANGED => "INPUT_FIELD_CHANGED"
  | RETRIEVE_CALL_INIT => "RETRIEVE_CALL_INIT"
  | RETRIEVE_CALL => "RETRIEVE_CALL"
  | AUTHENTICATION_CALL_INIT => "AUTHENTICATION_CALL_INIT"
  | AUTHENTICATION_CALL => "AUTHENTICATION_CALL"
  | CONFIRM_CALL_INIT => "CONFIRM_CALL_INIT"
  | CONFIRM_CALL => "CONFIRM_CALL"
  | SESSIONS_CALL_INIT => "SESSIONS_CALL_INIT"
  | SESSIONS_CALL => "SESSIONS_CALL"
  | PAYMENT_METHODS_CALL => "PAYMENT_METHODS_CALL"
  | PAYMENT_METHODS_CALL_INIT => "PAYMENT_METHODS_CALL_INIT"
  | CUSTOMER_PAYMENT_METHODS_CALL => "CUSTOMER_PAYMENT_METHODS_CALL"
  | CUSTOMER_PAYMENT_METHODS_CALL_INIT => "CUSTOMER_PAYMENT_METHODS_CALL_INIT"
  | TRUSTPAY_SCRIPT => "TRUSTPAY_SCRIPT"
  | GOOGLE_PAY_SCRIPT => "GOOGLE_PAY_SCRIPT"
  | APPLE_PAY_FLOW => "APPLE_PAY_FLOW"
  | GOOGLE_PAY_FLOW => "GOOGLE_PAY_FLOW"
  | PAYPAL_FLOW => "PAYPAL_FLOW"
  | PAYPAL_SDK_FLOW => "PAYPAL_SDK_FLOW"
  | APP_INITIATED => "APP_INITIATED"
  | APP_REINITIATED => "APP_REINITIATED"
  | LOG_INITIATED => "LOG_INITIATED"
  | LOADER_CALLED => "LOADER_CALLED"
  | ORCA_ELEMENTS_CALLED => "ORCA_ELEMENTS_CALLED"
  | PAYMENT_OPTIONS_PROVIDED => "PAYMENT_OPTIONS_PROVIDED"
  | BLUR => "BLUR"
  | FOCUS => "FOCUS"
  | CLEAR => "CLEAR"
  | CONFIRM_PAYMENT => "CONFIRM_PAYMENT"
  | CONFIRM_CARD_PAYMENT => "CONFIRM_CARD_PAYMENT"
  | SDK_CRASH => "SDK_CRASH"
  | INVALID_PK => "INVALID_PK"
  | DEPRECATED_LOADSTRIPE => "DEPRECATED_LOADSTRIPE"
  | REQUIRED_PARAMETER => "REQUIRED_PARAMETER"
  | UNKNOWN_KEY => "UNKNOWN_KEY"
  | UNKNOWN_VALUE => "UNKNOWN_VALUE"
  | TYPE_BOOL_ERROR => "TYPE_BOOL_ERROR"
  | TYPE_INT_ERROR => "TYPE_INT_ERROR"
  | TYPE_STRING_ERROR => "TYPE_STRING_ERROR"
  | INVALID_FORMAT => "INVALID_FORMAT"
  | SDK_CONNECTOR_WARNING => "SDK_CONNECTOR_WARNING"
  | VALUE_OUT_OF_RANGE => "VALUE_OUT_OF_RANGE"
  | HTTP_NOT_ALLOWED => "HTTP_NOT_ALLOWED"
  | INTERNAL_API_DOWN => "INTERNAL_API_DOWN"
  | REDIRECTING_USER => "REDIRECTING_USER"
  | DISPLAY_BANK_TRANSFER_INFO_PAGE => "DISPLAY_BANK_TRANSFER_INFO_PAGE"
  | DISPLAY_QR_CODE_INFO_PAGE => "DISPLAY_QR_CODE_INFO_PAGE"
  | DISPLAY_VOUCHER => "DISPLAY_VOUCHER"
  | DISPLAY_THREE_DS_SDK => "DISPLAY_THREE_DS_SDK"
  | THREE_DS_METHOD => "THREE_DS_METHOD"
  | THREE_DS_METHOD_RESULT => "THREE_DS_METHOD_RESULT"
  | PAYMENT_METHODS_RESPONSE => "PAYMENT_METHODS_RESPONSE"
  | LOADER_CHANGED => "LOADER_CHANGED"
  | PAYMENT_SESSION_INITIATED => "PAYMENT_SESSION_INITIATED"
  | POLL_STATUS_INIT => "POLL_STATUS_INIT"
  | POLL_STATUS_CALL => "POLL_STATUS_CALL"
  }
}

let convertToScreamingSnakeCase = text => {
  text->String.trim->String.replaceRegExp(%re("/ /g"), "_")->String.toUpperCase
}

type maskableDetails = Email | CardDetails
type source = Loader | Elements | Headless
let logInfo = log => {
  Window.isProd ? () : log
}

type logFile = {
  timestamp: string,
  logType: logType,
  category: logCategory,
  source: string,
  version: string,
  value: string,
  internalMetadata: string,
  sessionId: string,
  merchantId: string,
  paymentId: string,
  appId: string,
  platform: string,
  browserName: string,
  browserVersion: string,
  userAgent: string,
  eventName: eventName,
  latency: string,
  firstEvent: bool,
  paymentMethod: string,
  metadata: JSON.t,
}

type setlogApiValueType =
  | ArrayType(array<(string, JSON.t)>)
  | StringValue(string)

type setLogInfo = (
  ~value: string,
  ~internalMetadata: string=?,
  ~eventName: eventName,
  ~timestamp: string=?,
  ~latency: float=?,
  ~logType: logType=?,
  ~logCategory: logCategory=?,
  ~paymentMethod: string=?,
  unit,
) => unit

type loggerMake = {
  setLogInfo: setLogInfo,
  setLogError: setLogInfo,
  setLogApi: (
    ~value: setlogApiValueType,
    ~internalMetadata: setlogApiValueType,
    ~eventName: eventName,
    ~timestamp: string=?,
    ~logType: logType=?,
    ~logCategory: logCategory=?,
    ~paymentMethod: string=?,
    ~apiLogType: apiLogType=?,
    ~isPaymentSession: bool=?,
    unit,
  ) => unit,
  setLogInitiated: unit => unit,
  setConfirmPaymentValue: (~paymentType: string) => JSON.t,
  sendLogs: unit => unit,
  setSessionId: string => unit,
  setClientSecret: string => unit,
  setMerchantId: string => unit,
  setMetadata: JSON.t => unit,
}

let defaultLoggerConfig = {
  sendLogs: () => (),
  setClientSecret: _x => (),
  setConfirmPaymentValue: (~paymentType as _) => {Dict.make()->JSON.Encode.object},
  setLogError: (
    ~value as _,
    ~internalMetadata as _=?,
    ~eventName as _,
    ~timestamp as _=?,
    ~latency as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
    (),
  ) => (),
  setLogApi: (
    ~value as _,
    ~internalMetadata as _,
    ~eventName as _,
    ~timestamp as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
    ~apiLogType as _=?,
    ~isPaymentSession as _=?,
    (),
  ) => (),
  setLogInfo: (
    ~value as _,
    ~internalMetadata as _=?,
    ~eventName as _,
    ~timestamp as _=?,
    ~latency as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
    (),
  ) => (),
  setLogInitiated: () => (),
  setMerchantId: _x => (),
  setSessionId: _x => (),
  setMetadata: _x => (),
}

let logFileToObj = logFile => {
  [
    ("timestamp", logFile.timestamp->JSON.Encode.string),
    (
      "log_type",
      switch logFile.logType {
      | DEBUG => "DEBUG"
      | INFO => "INFO"
      | ERROR => "ERROR"
      | WARNING => "WARNING"
      | SILENT => "SILENT"
      }->JSON.Encode.string,
    ),
    ("component", "WEB"->JSON.Encode.string),
    (
      "category",
      switch logFile.category {
      | API => "API"
      | USER_ERROR => "USER_ERROR"
      | USER_EVENT => "USER_EVENT"
      | MERCHANT_EVENT => "MERCHANT_EVENT"
      }->JSON.Encode.string,
    ),
    ("source", logFile.source->convertToScreamingSnakeCase->JSON.Encode.string),
    ("version", logFile.version->JSON.Encode.string), // repoversion of orca-android
    ("value", logFile.value->JSON.Encode.string),
    ("internal_metadata", logFile.internalMetadata->JSON.Encode.string),
    ("session_id", logFile.sessionId->JSON.Encode.string),
    ("merchant_id", logFile.merchantId->JSON.Encode.string),
    ("payment_id", logFile.paymentId->JSON.Encode.string),
    ("app_id", logFile.appId->JSON.Encode.string),
    ("platform", logFile.platform->convertToScreamingSnakeCase->JSON.Encode.string),
    ("user_agent", logFile.userAgent->JSON.Encode.string),
    ("event_name", logFile.eventName->eventNameToStrMapper->JSON.Encode.string),
    ("browser_name", logFile.browserName->convertToScreamingSnakeCase->JSON.Encode.string),
    ("browser_version", logFile.browserVersion->JSON.Encode.string),
    ("latency", logFile.latency->JSON.Encode.string),
    ("first_event", (logFile.firstEvent ? "true" : "false")->JSON.Encode.string),
    ("payment_method", logFile.paymentMethod->convertToScreamingSnakeCase->JSON.Encode.string),
  ]
  ->Dict.fromArray
  ->JSON.Encode.object
}

let getRefFromOption = val => {
  let innerValue = val->Option.getOr("")
  ref(innerValue)
}
let getSourceString = source => {
  switch source {
  | Loader => "orca-loader"
  | Elements => "orca-element"
  | Headless => "headless"
  }
}

let findVersion = (re, content) => {
  let result = Js.Re.exec_(re, content)
  let version = switch result {
  | Some(val) => Js.Re.captures(val)
  | None => []
  }
  version
}

let browserDetect = content => {
  if RegExp.test("Edg"->RegExp.fromString, content) {
    let re = %re("/Edg\/([\d]+\.[\w]?\.?[\w]+)/ig")
    let version = switch findVersion(re, content)
    ->Array.get(1)
    ->Option.getOr(Nullable.null)
    ->Nullable.toOption {
    | Some(a) => a
    | None => ""
    }
    `Microsoft Edge-${version}`
  } else if RegExp.test("Chrome"->RegExp.fromString, content) {
    let re = %re("/Chrome\/([\d]+\.[\w]?\.?[\w]+)/ig")
    let version = switch findVersion(re, content)
    ->Array.get(1)
    ->Option.getOr(Nullable.null)
    ->Nullable.toOption {
    | Some(a) => a
    | None => ""
    }
    `Chrome-${version}`
  } else if RegExp.test("Safari"->RegExp.fromString, content) {
    let re = %re("/Safari\/([\d]+\.[\w]?\.?[\w]+)/ig")
    let version = switch findVersion(re, content)
    ->Array.get(1)
    ->Option.getOr(Nullable.null)
    ->Nullable.toOption {
    | Some(a) => a
    | None => ""
    }
    `Safari-${version}`
  } else if RegExp.test("opera"->RegExp.fromString, content) {
    let re = %re("/Opera\/([\d]+\.[\w]?\.?[\w]+)/ig")
    let version = switch findVersion(re, content)
    ->Array.get(1)
    ->Option.getOr(Nullable.null)
    ->Nullable.toOption {
    | Some(a) => a
    | None => ""
    }
    `Opera-${version}`
  } else if (
    RegExp.test("Firefox"->RegExp.fromString, content) ||
    RegExp.test("fxios"->RegExp.fromString, content)
  ) {
    if RegExp.test("Firefox"->RegExp.fromString, content) {
      let re = %re("/Firefox\/([\d]+\.[\w]?\.?[\w]+)/ig")
      let version = switch findVersion(re, content)
      ->Array.get(1)
      ->Option.getOr(Nullable.null)
      ->Nullable.toOption {
      | Some(a) => a
      | None => ""
      }
      `Firefox-${version}`
    } else {
      let re = %re("/fxios\/([\d]+\.[\w]?\.?[\w]+)/ig")
      let version = switch findVersion(re, content)
      ->Array.get(1)
      ->Option.getOr(Nullable.null)
      ->Nullable.toOption {
      | Some(a) => a
      | None => ""
      }
      `Firefox-${version}`
    }
  } else {
    "Others-0"
  }
}

let arrayOfNameAndVersion = String.split(Window.userAgent->browserDetect, "-")

let make = (
  ~sessionId=?,
  ~source: option<source>=?,
  ~clientSecret=?,
  ~merchantId=?,
  ~metadata=?,
  (),
) => {
  let loggingLevel = switch GlobalVars.loggingLevelStr {
  | "DEBUG" => DEBUG
  | "INFO" => INFO
  | "WARNING" => WARNING
  | "ERROR" => ERROR
  | "SILENT"
  | _ =>
    SILENT
  }
  let mainLogFile: array<logFile> = []
  let sessionId = getRefFromOption(sessionId)
  let setSessionId = value => {
    sessionId := value
  }
  let sourceString = switch source {
  | Some(val) => val->getSourceString
  | None => GlobalVars.repoName
  }

  let events = ref(Dict.make())
  let eventsCounter = ref(Dict.make())

  let timeOut = ref(None)

  let merchantId = getRefFromOption(merchantId)
  let setMerchantId = value => {
    merchantId := value
  }

  let metadata = ref(metadata->Option.getOr(JSON.Encode.null))

  let setMetadata = value => {
    metadata := value
  }

  let calculateAndUpdateCounterHook = eventName => {
    let updatedCounter = switch eventsCounter.contents->Dict.get(eventName) {
    | Some(num) => num + 1
    | None => 1
    }
    eventsCounter.contents->Dict.set(eventName, updatedCounter)
    updatedCounter
  }

  let conditionalLogPush = (log: logFile) => {
    let maxLogsPushedPerEventName = GlobalVars.maxLogsPushedPerEventName
    let conditionalEventName = switch log.eventName {
    | INPUT_FIELD_CHANGED => log.value // to enforce rate limiting for each input field independently
    | _ => ""
    }
    let eventName = log.eventName->eventNameToStrMapper ++ conditionalEventName

    let counter = eventName->calculateAndUpdateCounterHook
    if GlobalVars.enableLogging && counter <= maxLogsPushedPerEventName {
      switch loggingLevel {
      | DEBUG => log->Array.push(mainLogFile, _)->ignore
      | INFO =>
        [INFO, WARNING, ERROR]->Array.includes(log.logType)
          ? log->Array.push(mainLogFile, _)->ignore
          : ()
      | WARNING =>
        [WARNING, ERROR]->Array.includes(log.logType) ? log->Array.push(mainLogFile, _)->ignore : ()
      | ERROR => [ERROR]->Array.includes(log.logType) ? log->Array.push(mainLogFile, _)->ignore : ()
      | SILENT => ()
      }
    }
  }

  let beaconApiCall = data => {
    if data->Array.length > 0 {
      let logData = data->Array.map(logFileToObj)->JSON.Encode.array->JSON.stringify
      Window.sendBeacon(GlobalVars.logEndpoint, logData)
    }
  }

  let clientSecret = getRefFromOption(clientSecret)
  let setClientSecret = value => {
    clientSecret := value
  }

  let rec sendLogs = () => {
    switch timeOut.contents {
    | Some(val) => {
        clearTimeout(val)
        timeOut := Some(setTimeout(() => sendLogs(), 20000))
      }
    | None => timeOut := Some(setTimeout(() => sendLogs(), 20000))
    }
    beaconApiCall(mainLogFile)
    let len = mainLogFile->Array.length
    for _ in 0 to len - 1 {
      mainLogFile->Array.pop->ignore
    }
  }

  let checkForPriorityEvents = (arrayOfLogs: array<logFile>) => {
    let priorityEventNames = [
      APP_RENDERED,
      ORCA_ELEMENTS_CALLED,
      PAYMENT_DATA_FILLED,
      PAYMENT_ATTEMPT,
      CONFIRM_CALL,
      AUTHENTICATION_CALL,
      THREE_DS_METHOD_RESULT,
      SDK_CRASH,
      REDIRECTING_USER,
      DISPLAY_BANK_TRANSFER_INFO_PAGE,
      DISPLAY_QR_CODE_INFO_PAGE,
      DISPLAY_VOUCHER,
      LOADER_CHANGED,
      SESSIONS_CALL,
      RETRIEVE_CALL,
      DISPLAY_THREE_DS_SDK,
      APPLE_PAY_FLOW,
    ]
    arrayOfLogs
    ->Array.find(log => {
      [ERROR, DEBUG]->Array.includes(log.logType) ||
        (priorityEventNames->Array.includes(log.eventName) && log.firstEvent)
    })
    ->Option.isSome || arrayOfLogs->Array.length > 8
  }

  let checkLogSizeAndSendData = () => {
    switch timeOut.contents {
    | Some(val) => {
        clearTimeout(val)
        timeOut := Some(setTimeout(() => sendLogs(), 20000))
      }
    | None => timeOut := Some(setTimeout(() => sendLogs(), 20000))
    }

    if mainLogFile->checkForPriorityEvents {
      sendLogs()
    }
  }

  let calculateLatencyHook = (~eventName, ~apiLogType=Method, ()) => {
    let currentTimestamp = Date.now()
    let latency = switch eventName {
    | PAYMENT_ATTEMPT => {
        let appRenderedTimestamp = events.contents->Dict.get(APP_RENDERED->eventNameToStrMapper)
        switch appRenderedTimestamp {
        | Some(float) => currentTimestamp -. float
        | _ => -1.
        }
      }
    | AUTHENTICATION_CALL
    | RETRIEVE_CALL
    | CONFIRM_CALL
    | SESSIONS_CALL
    | PAYMENT_METHODS_CALL
    | CUSTOMER_PAYMENT_METHODS_CALL => {
        let logRequestTimestamp =
          events.contents->Dict.get(eventName->eventNameToStrMapper ++ "_INIT")
        switch (logRequestTimestamp, apiLogType) {
        | (Some(_), Request) => 0.
        | (Some(float), _) => currentTimestamp -. float
        | _ => 0.
        }
      }
    | _ => 0.
    }
    latency > 0. ? latency->Belt.Float.toString : ""
  }

  let setLogInfo = (
    ~value,
    ~internalMetadata="",
    ~eventName,
    ~timestamp=?,
    ~latency=?,
    ~logType=INFO,
    ~logCategory=USER_EVENT,
    ~paymentMethod="",
    (),
  ) => {
    let eventNameStr = eventName->eventNameToStrMapper
    let firstEvent = events.contents->Dict.get(eventNameStr)->Option.isNone
    let latency = switch latency {
    | Some(lat) => lat->Float.toString
    | None => calculateLatencyHook(~eventName, ())
    }
    let localTimestamp = timestamp->Option.getOr(Date.now()->Belt.Float.toString)
    let localTimestampFloat = localTimestamp->Belt.Float.fromString->Option.getOr(Date.now())
    {
      logType,
      timestamp: localTimestamp,
      sessionId: sessionId.contents,
      source: sourceString,
      version: GlobalVars.repoVersion,
      value,
      internalMetadata,
      category: logCategory,
      paymentId: String.split(clientSecret.contents, "_secret_")->Array.get(0)->Option.getOr(""),
      merchantId: merchantId.contents,
      browserName: arrayOfNameAndVersion->Array.get(0)->Option.getOr("Others"),
      browserVersion: arrayOfNameAndVersion->Array.get(1)->Option.getOr("0"),
      platform: Window.platform,
      userAgent: Window.userAgent,
      appId: "",
      eventName,
      latency,
      paymentMethod,
      firstEvent,
      metadata: metadata.contents,
    }
    ->conditionalLogPush
    ->ignore
    checkLogSizeAndSendData()
    events.contents->Dict.set(eventNameStr, localTimestampFloat)
  }

  let setConfirmPaymentValue = (~paymentType) => {
    [("method", "confirmPayment"->JSON.Encode.string), ("type", paymentType->JSON.Encode.string)]
    ->Dict.fromArray
    ->JSON.Encode.object
  }

  let setLogApi = (
    ~value: setlogApiValueType,
    ~internalMetadata: setlogApiValueType,
    ~eventName,
    ~timestamp=?,
    ~logType=INFO,
    ~logCategory=API,
    ~paymentMethod="",
    ~apiLogType=Request,
    ~isPaymentSession=false,
    (),
  ) => {
    let eventNameStr = eventName->eventNameToStrMapper
    let firstEvent = events.contents->Dict.get(eventNameStr)->Option.isNone
    let latency = calculateLatencyHook(~eventName, ~apiLogType, ())
    let localTimestamp = timestamp->Option.getOr(Date.now()->Belt.Float.toString)
    let localTimestampFloat = localTimestamp->Belt.Float.fromString->Option.getOr(Date.now())
    {
      logType,
      timestamp: localTimestamp,
      sessionId: sessionId.contents,
      source: isPaymentSession ? getSourceString(Headless) : sourceString,
      version: GlobalVars.repoVersion,
      value: switch value {
      | ArrayType(a) => a->Dict.fromArray->JSON.Encode.object->JSON.stringify
      | StringValue(a) => a
      },
      internalMetadata: switch internalMetadata {
      | ArrayType(a) => a->Dict.fromArray->JSON.Encode.object->JSON.stringify
      | StringValue(a) => a
      },
      category: logCategory,
      paymentId: String.split(clientSecret.contents, "_secret_")->Array.get(0)->Option.getOr(""),
      merchantId: merchantId.contents,
      browserName: arrayOfNameAndVersion->Array.get(0)->Option.getOr("Others"),
      browserVersion: arrayOfNameAndVersion->Array.get(1)->Option.getOr("0"),
      platform: Window.platform,
      userAgent: Window.userAgent,
      appId: "",
      eventName,
      latency,
      paymentMethod,
      firstEvent,
      metadata: metadata.contents,
    }
    ->conditionalLogPush
    ->ignore
    checkLogSizeAndSendData()
    events.contents->Dict.set(eventNameStr, localTimestampFloat)
  }

  let setLogError = (
    ~value,
    ~internalMetadata="",
    ~eventName,
    ~timestamp=?,
    ~latency=?,
    ~logType=ERROR,
    ~logCategory=USER_ERROR,
    ~paymentMethod="",
    (),
  ) => {
    let eventNameStr = eventName->eventNameToStrMapper
    let firstEvent = events.contents->Dict.get(eventNameStr)->Option.isNone
    let latency = switch latency {
    | Some(lat) => lat->Float.toString
    | None => calculateLatencyHook(~eventName, ())
    }
    let localTimestamp = timestamp->Option.getOr(Date.now()->Belt.Float.toString)
    let localTimestampFloat = localTimestamp->Belt.Float.fromString->Option.getOr(Date.now())
    {
      logType,
      timestamp: localTimestamp,
      sessionId: sessionId.contents,
      source: sourceString,
      version: GlobalVars.repoVersion,
      value,
      internalMetadata,
      category: logCategory,
      paymentId: String.split(clientSecret.contents, "_secret_")->Array.get(0)->Option.getOr(""),
      merchantId: merchantId.contents,
      browserName: arrayOfNameAndVersion->Array.get(0)->Option.getOr("Others"),
      browserVersion: arrayOfNameAndVersion->Array.get(1)->Option.getOr("0"),
      platform: Window.platform,
      userAgent: Window.userAgent,
      appId: "",
      eventName,
      latency,
      paymentMethod,
      firstEvent,
      metadata: metadata.contents,
    }
    ->conditionalLogPush
    ->ignore
    checkLogSizeAndSendData()
    events.contents->Dict.set(eventNameStr, localTimestampFloat)
  }

  let setLogInitiated = () => {
    let eventName: eventName = LOG_INITIATED
    let eventNameStr = eventName->eventNameToStrMapper
    let firstEvent = events.contents->Dict.get(eventNameStr)->Option.isNone
    let latency = calculateLatencyHook(~eventName, ())
    {
      logType: INFO,
      eventName,
      timestamp: Date.now()->Belt.Float.toString,
      sessionId: sessionId.contents,
      source: sourceString,
      version: GlobalVars.repoVersion,
      category: USER_EVENT,
      value: "log initiated",
      internalMetadata: "",
      paymentId: String.split(clientSecret.contents, "_secret_")->Array.get(0)->Option.getOr(""),
      merchantId: merchantId.contents,
      browserName: arrayOfNameAndVersion->Array.get(0)->Option.getOr("Others"),
      browserVersion: arrayOfNameAndVersion->Array.get(1)->Option.getOr("0"),
      platform: Window.platform,
      userAgent: Window.userAgent,
      appId: "",
      latency,
      paymentMethod: "",
      firstEvent,
      metadata: metadata.contents,
    }
    ->conditionalLogPush
    ->ignore
    checkLogSizeAndSendData()
    events.contents->Dict.set(eventNameStr, Date.now())
  }

  let handleBeforeUnload = _event => {
    //event->Window.preventDefault()
    sendLogs()
    switch timeOut.contents {
    | Some(val) => clearTimeout(val)
    | None => ()
    }
  }
  Window.addEventListener("beforeunload", handleBeforeUnload)

  {
    setLogInfo,
    setLogInitiated,
    setConfirmPaymentValue,
    sendLogs,
    setSessionId,
    setClientSecret,
    setMerchantId,
    setMetadata,
    setLogApi,
    setLogError,
  }
}
