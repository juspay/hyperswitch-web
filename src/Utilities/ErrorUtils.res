type type_ = Error | Warning
type stringType = Dynamic(string => string) | Static(string)

type error = array<(OrcaLogger.eventName, type_, string)>

open OrcaLogger

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
    UNKNOWN_KEY,
    Warning,
    Dynamic(
      str => {
        `Unknown Key: ${str} is a unknown/invalid key, please provide a correct key. This might cause issue in the future`
      },
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
    UNKNOWN_VALUE,
    Warning,
    Dynamic(
      str => {
        `Unknown Value: ${str}. Please provide a correct value. This might cause issue in the future`
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
  key: OrcaLogger.eventName,
  ~dynamicStr="",
  ~logger: OrcaLogger.loggerMake,
  (),
) => {
  let entry = errorWarning->Array.find(((value, _, _)) => value == key)
  switch entry {
  | Some(value) => {
      let (eventName, type_, str) = value

      let value = switch str {
      | Static(string) => string
      | Dynamic(fn) => fn(dynamicStr)
      }
      let logType: OrcaLogger.logType = switch type_ {
      | Warning => WARNING
      | Error => ERROR
      }

      logger.setLogError(~value, ~eventName, ~logType, ~logCategory=USER_ERROR, ())

      switch type_ {
      | Warning => Console.warn(value)
      | Error =>
        Console.error(value)
        Exn.raiseError(value)
      }
    }
  | None => ()
  }
}

let unknownKeysWarning = (validKeysArr, dict: Dict.t<JSON.t>, dictType: string, ~logger) => {
  dict
  ->Dict.toArray
  ->Array.forEach(((key, _)) => {
    if validKeysArr->Array.includes(key) {
      ()
    } else {
      manageErrorWarning(UNKNOWN_KEY, ~dynamicStr=`'${key}' key in ${dictType}`, ~logger, ())
    }
  })
}

let unknownPropValueWarning = (
  inValidValue,
  validValueArr,
  dictType,
  ~logger: OrcaLogger.loggerMake,
) => {
  let expectedValues =
    validValueArr
    ->Array.map(item => {
      `'${item}'`
    })
    ->Array.joinWith(", ")
  manageErrorWarning(
    UNKNOWN_VALUE,
    ~dynamicStr=`'${inValidValue}' value in ${dictType}, Expected ${expectedValues}`,
    ~logger,
    (),
  )
}
let valueOutRangeWarning = (num: int, dictType, range, ~logger: OrcaLogger.loggerMake) => {
  manageErrorWarning(
    VALUE_OUT_OF_RANGE,
    ~dynamicStr=`${num->Belt.Int.toString} value in ${dictType} Expected value between ${range}`,
    ~logger: OrcaLogger.loggerMake,
    (),
  )
}
