type message =
  | Static(string)
  | Dynamic(string => string)

type handling = Fatal | Recoverable

let describe = (issue: HyperLoaderLogger.merchantIssue) =>
  switch issue {
  | InvalidPublishableKey => (
      Fatal,
      Static(
        "INTEGRATION ERROR: Invalid Publishable key, starts with pk_dev_(development), pk_snd_(sandbox/test) or pk_prd_(production/live)",
      ),
    )
  | InsecureProtocol => (
      Fatal,
      Dynamic(
        value =>
          `INTEGRATION ERROR: ${value} Serve your application over HTTPS. This is a requirement both in development and in production. One way to get up and running is to use a service like ngrok.`,
      ),
    )
  | MissingParameter => (
      Fatal,
      Dynamic(
        value =>
          `INTEGRATION ERROR: ${value} is a required field/parameter or ${value} cannot be empty`,
      ),
    )
  | MalformedValue => (Fatal, Dynamic(value => value))
  | ExpectedBoolean => (Recoverable, Dynamic(value => `Type Error: '${value}' Expected boolean`))
  | ExpectedString => (Recoverable, Dynamic(value => `Type Error: '${value}' Expected string`))
  | ExpectedNumber => (Recoverable, Dynamic(value => `Type Error: '${value}' Expected int`))
  | ValueOutOfRange => (
      Recoverable,
      Dynamic(value => `Value out of range: '${value}'. Please provide a value inside the range`),
    )
  | ConnectorMisconfigured => (Recoverable, Dynamic(value => `INTEGRATION ERROR: ${value}`))
  | DeprecatedMethod => (
      Recoverable,
      Static("loadStripe is deprecated. Please use loadHyper instead."),
    )
  }

let manageErrorWarning = (issue: HyperLoaderLogger.merchantIssue, ~dynamicStr as param="") => {
  let (handling, message) = issue->describe
  let text = switch message {
  | Static(text) => text
  | Dynamic(build) => build(param)
  }

  HyperLoaderLogger.logMerchantIssue(
    ~issue,
    ~details=param === "" ? [] : [("param", param->JSON.Encode.string)],
  )

  switch handling {
  | Recoverable => Console.warn(text)
  | Fatal => {
      Console.error(text)
      Exn.raiseError(text)
    }
  }
}

let unknownKeysWarning = (validKeysArr, dict: Dict.t<JSON.t>, dictType: string) =>
  dict
  ->Dict.toArray
  ->Array.forEach(((key, _)) =>
    validKeysArr->Array.includes(key)
      ? ()
      : Console.warn(`Unknown Key: '${key}' key in ${dictType}`)
  )

let unknownPropValueWarning = (inValidValue, validValueArr, dictType) => {
  let expectedValues = validValueArr->Array.map(item => `'${item}'`)->Array.join(", ")
  Console.warn(`Unknown Value: '${inValidValue}' value in ${dictType}, Expected ${expectedValues}`)
}

let valueOutRangeWarning = (num: int, dictType, range) =>
  manageErrorWarning(
    ValueOutOfRange,
    ~dynamicStr=`${num->Int.toString} value in ${dictType} Expected value between ${range}`,
  )
