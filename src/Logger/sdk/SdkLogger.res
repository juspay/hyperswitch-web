open LoggerTypes
include SdkLoggerEvents

let logLifecycle = (
  ~event: lifecycleEvent,
  ~details=?,
  ~exn=?,
  ~failure=?,
  ~durationMs=?,
  ~paymentMethod=?,
  ~source=?,
  ~message=?,
) =>
  LoggerRuntime.emit(
    ~category=Lifecycle,
    ~spec=event->LoggerUtils.spec,
    ~severity=event->lifecycleSeverity,
    ~data=event->LoggerUtils.eventDetails,
    ~details?,
    ~exn?,
    ~failure?,
    ~durationMs?,
    ~paymentMethod?,
    ~source?,
    ~message?,
  )

let logState = (
  ~event: stateEvent,
  ~details=?,
  ~failure=?,
  ~durationMs=?,
  ~paymentMethod=?,
  ~message=?,
) =>
  LoggerRuntime.emit(
    ~category=State,
    ~spec=event->LoggerUtils.spec,
    ~severity=event->stateSeverity,
    ~data=event->LoggerUtils.eventDetails,
    ~details?,
    ~failure?,
    ~durationMs?,
    ~paymentMethod?,
    ~message?,
  )

let namedField = field =>
  switch field->String.trim {
  | "" => "unnamed"
  | "cardNoInput" => "card_number"
  | "expiryInput" => "card_expiry"
  | "cvvInput" => "card_cvc"
  | field => field->LoggerUtils.snakeCase
  }

let logUser = (~event: userEvent, ~details=?, ~paymentMethod=?, ~message=?) => {
  let event = switch event {
  | FieldFocused({field}) => FieldFocused({field: field->namedField})
  | FieldBlurred({field}) => FieldBlurred({field: field->namedField})
  | FieldToggled({field, enabled}) => FieldToggled({field: field->namedField, enabled})
  | event => event
  }
  LoggerRuntime.emit(
    ~category=User,
    ~spec=event->LoggerUtils.spec,
    ~severity=event->userSeverity,
    ~data=event->LoggerUtils.eventDetails,
    ~details?,
    ~paymentMethod?,
    ~message?,
  )
}

let logCrash = (~origin: crashOrigin, ~exn=?, ~details=?, ~message=?) =>
  LoggerRuntime.emit(
    ~category=Crash,
    ~spec=origin->LoggerUtils.spec,
    ~severity=origin->crashSeverity,
    ~details?,
    ~exn?,
    ~message?,
  )

@val @scope("window") external parentWindow: Dom.element = "parent"

let adoptSessionFromParent = (~source) => {
  LoggerRuntime.configure(~source)
  Window.addEventListener("message", (ev: Window.event) =>
    if ev.source === parentWindow && ev.data->LoggerContext.mayCarryContext {
      switch JSON.parseExn(ev.data)->JSON.Decode.object {
      | Some(message) => message->LoggerContext.startSessionFromMessage
      | None => ()
      | exception _ => ()
      }
    }
  )
}

type crashEvent = {message?: JSON.t, filename?: JSON.t, reason?: JSON.t}

let describe: option<JSON.t> => string = %raw(`
  (v) => typeof v == "string" ? v : (v && typeof v.message == "string" ? v.message : "UNKNOWN")
`)

let stackUrl: option<JSON.t> => string = %raw(`
  (v) => (v && typeof v.stack == "string" && /(?:https?|blob|file):\/\/[^\s)]+/.exec(v.stack) || [""])[0]
`)

let catchGlobalCrashes = (~ownsDocument) => {
  let sdkOrigins =
    [GlobalVars.sdkUrl, GlobalVars.repoPublicPath]->Array.filter(value => value->String.trim !== "")
  let reporting = ref(false)

  let report = (~origin, ~message, ~source) =>
    if (
      !reporting.contents &&
      (ownsDocument ||
      (source->String.trim !== "" &&
        sdkOrigins->Array.some(origin => source->String.startsWith(origin))))
    ) {
      reporting := true
      logCrash(
        ~origin,
        ~details=[
          ("error_message", message->JSON.Encode.string),
          ("error_source", source->LoggerUtils.sanitizeUrl->JSON.Encode.string),
        ],
      )
      reporting := false
    }

  Window.addEventListener("error", (event: crashEvent) =>
    report(
      ~origin=UncaughtError,
      ~message=event.message->describe,
      ~source=event.filename->Option.flatMap(JSON.Decode.string)->Option.getOr(""),
    )
  )

  Window.addEventListener("unhandledrejection", (event: crashEvent) =>
    report(
      ~origin=UnhandledRejection,
      ~message=event.reason->describe,
      ~source=event.reason->stackUrl,
    )
  )
}

let observeApi = (
  ~event: apiEvent,
  ~url,
  ~details=?,
  ~failureOf,
  ~detailsOf,
  ~paymentMethod=?,
  ~message=?,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category=Api,
    ~spec=event->LoggerUtils.spec(~action=Request),
    ~severity=event->apiSeverity,
    ~data=event->LoggerUtils.eventDetails->Array.concat([("url", url->JSON.Encode.string)]),
    ~details?,
    ~failureOf,
    ~detailsOf,
    ~paymentMethod?,
    ~message?,
    ~call,
  )

let observeStaticAsset = (~event: staticAssetEvent, ~url, ~details=?, ~message=?, ~call) =>
  LoggerRuntime.observe(
    ~category=Resource,
    ~details?,
    ~spec=event->LoggerUtils.spec(~action=Load),
    ~severity=event->staticAssetSeverity,
    ~data=event
    ->LoggerUtils.eventDetails
    ->Array.concat([
      ("url", url->JSON.Encode.string),
      ("resource_type", "static_asset"->JSON.Encode.string),
    ]),
    ~failureOf=LoggerUtils.httpFailure,
    ~detailsOf=LoggerUtils.httpDetails,
    ~message?,
    ~call,
  )

let logApi = (
  ~event: apiEvent,
  ~outcome,
  ~details=?,
  ~startedAt=?,
  ~exn=?,
  ~paymentMethod=?,
  ~message=?,
) =>
  LoggerRuntime.emitPhase(
    ~category=Api,
    ~spec=event->LoggerUtils.spec(~action=Request),
    ~severity=event->apiSeverity,
    ~outcome,
    ~data=event->LoggerUtils.eventDetails,
    ~details?,
    ~startedAt?,
    ~exn?,
    ~paymentMethod?,
    ~message?,
  )

let logFunction = (
  ~event: functionEvent,
  ~outcome,
  ~details=?,
  ~startedAt=?,
  ~exn=?,
  ~paymentMethod=?,
  ~message=?,
) =>
  LoggerRuntime.emitPhase(
    ~category=Function,
    ~spec=event->LoggerUtils.spec(~action=Call),
    ~severity=event->functionSeverity,
    ~outcome,
    ~data=event->LoggerUtils.eventDetails,
    ~details?,
    ~startedAt?,
    ~exn?,
    ~paymentMethod?,
    ~message?,
  )

let observeFunction = (
  ~event: functionEvent,
  ~details=?,
  ~timeoutMs=?,
  ~paymentMethod=?,
  ~source=?,
  ~message=?,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category=Function,
    ~spec=event->LoggerUtils.spec(~action=Call),
    ~severity=event->functionSeverity,
    ~data=event->LoggerUtils.eventDetails,
    ~details?,
    ~timeoutMs?,
    ~paymentMethod?,
    ~source?,
    ~message?,
    ~call,
  )

let observeFunctionCallback = (
  ~event: functionCallbackEvent,
  ~details=?,
  ~timeoutMs=?,
  ~paymentMethod=?,
  ~message=?,
  ~callback,
) =>
  LoggerRuntime.observeCallback(
    ~category=Function,
    ~spec=event->LoggerUtils.spec(~action=Callback),
    ~severity=event->functionCallbackSeverity,
    ~data=event->LoggerUtils.eventDetails,
    ~details?,
    ~timeoutMs?,
    ~paymentMethod?,
    ~message?,
    ~callback,
  )

let observeResource = (
  ~event: resourceEvent,
  ~url,
  ~attributes=?,
  ~matchQuery=?,
  ~paymentMethod=?,
  ~abandoned=?,
  ~message=?,
  ~onLoad=?,
  ~onError=?,
) =>
  LoggerRuntime.observeResource(
    ~spec=event->LoggerUtils.spec(~action=Load),
    ~severity=event->resourceSeverity,
    ~url,
    ~resource=event->resourceKind,
    ~attributes?,
    ~matchQuery?,
    ~paymentMethod?,
    ~abandoned?,
    ~message?,
    ~onLoad?,
    ~onError?,
  )
