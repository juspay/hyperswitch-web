open HyperLoggerTypes

type type_ = Error | Warning
type stringType = Dynamic(string => string) | Static(string)
type error = array<(HyperLoggerTypes.eventName, type_, string)>

let errorWarning = [
  (
    INVALID_PK,
    Error,
    Static(
      "INTEGRATION ERROR: Invalid Publishable key, starts with pk_dev_(development), pk_snd_(sandbox/test) or pk_prd_(production/live)",
    ),
  ),
  (
    DEPRECATED_LOADSTRIPE,
    Warning,
    Static("loadStripe is deprecated. Please use loadHyper instead."),
  ),
  (
    REQUIRED_PARAMETER,
    Error,
    Dynamic(
      str => {`INTEGRATION ERROR: ${str} is a required field/parameter or ${str} cannot be empty`},
    ),
  ),
  (
    TYPE_BOOL_ERROR,
    Error,
    Dynamic(
      str => {
        `Type Error: '${str}' Expected boolean`
      },
    ),
  ),
  (
    TYPE_STRING_ERROR,
    Error,
    Dynamic(
      str => {
        `Type Error: '${str}' Expected string`
      },
    ),
  ),
  (
    TYPE_INT_ERROR,
    Error,
    Dynamic(
      str => {
        `Type Error: '${str}' Expected int`
      },
    ),
  ),
  (
    VALUE_OUT_OF_RANGE,
    Warning,
    Dynamic(
      str => {
        `Value out of range: '${str}'. Please provide a value inside the range`
      },
    ),
  ),
  (
    SDK_CONNECTOR_WARNING,
    Warning,
    Dynamic(
      str => {
        `INTEGRATION ERROR: ${str}`
      },
    ),
  ),
  (INVALID_FORMAT, Error, Dynamic(str => {str})),
  (
    HTTP_NOT_ALLOWED,
    Error,
    Dynamic(
      str =>
        `INTEGRATION ERROR: ${str} Serve your application over HTTPS. This is a requirement both in development and in production. One way to get up and running is to use a service like ngrok.`,
    ),
  ),
  (
    INTERNAL_API_DOWN,
    Warning,
    Static(
      "LOAD ERROR: Something went wrong! Please try again or contact out dev support https://hyperswitch.io/docs/support",
    ),
  ),
]

let manageErrorWarning = (
  key: HyperLoggerTypes.eventName,
  ~dynamicStr="",
  ~logger: HyperLoggerTypes.loggerMake,
) => {
  let entry = errorWarning->Array.find(((value, _, _)) => value == key)
  switch entry {
  | Some(value) => {
      let (eventName, type_, str) = value

      let value = switch str {
      | Static(string) => string
      | Dynamic(fn) => fn(dynamicStr)
      }
      let logType: HyperLoggerTypes.logType = switch type_ {
      | Warning => WARNING
      | Error => ERROR
      }

      logger.setLogError(~value, ~eventName, ~logType, ~logCategory=USER_ERROR)

      switch type_ {
      | Warning => ()
      | Error =>
        Console.error(value)
        Exn.raiseError(value)
      }
    }
  | None => ()
  }
}

let warnMerchantOption = (~logger=None, value) => {
  switch logger {
  | Some(logger) =>
    logger.setLogInfo(
      ~value,
      ~eventName=PAYMENT_ELEMENT_OPTIONS,
      ~logType=WARNING,
      ~logCategory=MERCHANT_EVENT,
    )
  | None => Console.warn(value)
  }
}

let unknownKeysWarning = (
  validKeysArr,
  dict: Dict.t<JSON.t>,
  dictType: string,
  ~logger: option<HyperLoggerTypes.loggerMake>=None,
) => {
  dict
  ->Dict.toArray
  ->Array.forEach(((key, _)) => {
    if validKeysArr->Array.includes(key) {
      ()
    } else {
      warnMerchantOption(~logger, `Unknown Key: '${key}' key in ${dictType}`)
    }
  })
}

let unknownPropValueWarning = (
  inValidValue,
  validValueArr,
  dictType,
  ~logger: option<HyperLoggerTypes.loggerMake>=None,
) => {
  let expectedValues =
    validValueArr
    ->Array.map(item => {
      `'${item}'`
    })
    ->Array.join(", ")
  warnMerchantOption(
    ~logger,
    `Unknown Value: '${inValidValue}' value in ${dictType}, Expected ${expectedValues}`,
  )
}
let valueOutRangeWarning = (num: int, dictType, range, ~logger: HyperLoggerTypes.loggerMake) => {
  warnMerchantOption(
    ~logger=Some(logger),
    `Value out of range: '${num->Int.toString} value in ${dictType} Expected value between ${range}'. Please provide a value inside the range`,
  )
}
