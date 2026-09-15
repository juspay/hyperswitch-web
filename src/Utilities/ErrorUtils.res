type type_ = Error | Warning
type stringType = Dynamic(string => string) | Static(string)
type error = array<(SdkLogger.lifecycleEvent, type_, string)>

let errorWarning = [
  (
    SdkLogger.InvalidPublishableKey,
    Error,
    Static(
      "INTEGRATION ERROR: Invalid Publishable key, starts with pk_dev_(development), pk_snd_(sandbox/test) or pk_prd_(production/live)",
    ),
  ),
  (
    SdkLogger.DeprecatedLoadStripe,
    Warning,
    Static("loadStripe is deprecated. Please use loadHyper instead."),
  ),
  (
    SdkLogger.RequiredParameter,
    Error,
    Dynamic(
      str => {`INTEGRATION ERROR: ${str} is a required field/parameter or ${str} cannot be empty`},
    ),
  ),
  (
    SdkLogger.TypeBoolError,
    Error,
    Dynamic(
      str => {
        `Type Error: '${str}' Expected boolean`
      },
    ),
  ),
  (
    SdkLogger.TypeStringError,
    Error,
    Dynamic(
      str => {
        `Type Error: '${str}' Expected string`
      },
    ),
  ),
  (
    SdkLogger.TypeIntError,
    Error,
    Dynamic(
      str => {
        `Type Error: '${str}' Expected int`
      },
    ),
  ),
  (
    SdkLogger.ValueOutOfRange,
    Warning,
    Dynamic(
      str => {
        `Value out of range: '${str}'. Please provide a value inside the range`
      },
    ),
  ),
  (
    SdkLogger.SdkConnectorWarning,
    Warning,
    Dynamic(
      str => {
        `INTEGRATION ERROR: ${str}`
      },
    ),
  ),
  (SdkLogger.InvalidFormat, Error, Dynamic(str => {str})),
  (
    SdkLogger.HttpNotAllowed,
    Error,
    Dynamic(
      str =>
        `INTEGRATION ERROR: ${str} Serve your application over HTTPS. This is a requirement both in development and in production. One way to get up and running is to use a service like ngrok.`,
    ),
  ),
  (
    SdkLogger.InternalApiDown,
    Warning,
    Static(
      "LOAD ERROR: Something went wrong! Please try again or contact out dev support https://hyperswitch.io/docs/support",
    ),
  ),
]

let manageErrorWarning = (key: SdkLogger.lifecycleEvent, ~dynamicStr="") => {
  let entry = errorWarning->Array.find(((value, _, _)) => value == key)
  switch entry {
  | Some(value) => {
      let (event, type_, str) = value

      let value = switch str {
      | Static(string) => string
      | Dynamic(fn) => fn(dynamicStr)
      }

      SdkLogger.logLifecycle(
        ~event,
        ~details=dynamicStr === "" ? [] : [("param", dynamicStr->JSON.Encode.string)],
      )

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

let unknownKeysWarning = (validKeysArr, dict: Dict.t<JSON.t>, dictType: string) => {
  dict
  ->Dict.toArray
  ->Array.forEach(((key, _)) => {
    if validKeysArr->Array.includes(key) {
      ()
    } else {
      Console.warn(`Unknown Key: '${key}' key in ${dictType}`)
    }
  })
}

let unknownPropValueWarning = (inValidValue, validValueArr, dictType) => {
  let expectedValues =
    validValueArr
    ->Array.map(item => {
      `'${item}'`
    })
    ->Array.join(", ")
  Console.warn(`Unknown Value: '${inValidValue}' value in ${dictType}, Expected ${expectedValues}`)
}
let valueOutRangeWarning = (num: int, dictType, range) => {
  manageErrorWarning(
    SdkLogger.ValueOutOfRange,
    ~dynamicStr=`${num->Int.toString} value in ${dictType} Expected value between ${range}`,
  )
}
