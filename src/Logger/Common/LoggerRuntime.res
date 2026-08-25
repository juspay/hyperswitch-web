open LoggerCommonHelpers

type runtime = {
  component: string,
  source: string,
  rows: array<JSON.t>,
  eventCounts: Dict.t<int>,
  flushTimer: ref<option<timeoutId>>,
}

let runtime = {
  component: "WEB",
  source: "HYPER_LOADER",
  rows: [],
  eventCounts: Dict.make(),
  flushTimer: ref(None),
}

let capitalizeFirst = value =>
  value->String.length === 0
    ? "Event"
    : value->String.slice(~start=0, ~end=1)->String.toUpperCase ++
        value->String.slice(~start=1, ~end=value->String.length)

let defaultMessage = eventName =>
  eventName
  ->String.replaceRegExp(%re("/[_.]+/g"), " ")
  ->String.trim
  ->capitalizeFirst

let browser = UAParser.make().browser

let severityName = (severity: severity) => severity->variantValue

let categoryName = (category: category) => category->variantValue

let categorySegment = category => category->categoryName->String.toLowerCase

let shouldEmit = severity =>
  switch (GlobalVars.loggingLevelStr, severity) {
  | ("DEBUG", _) => true
  | ("INFO", Info | Warning | Error) => true
  | ("WARNING", Warning | Error) => true
  | ("ERROR", Error) => true
  | _ => false
  }

let clearRows = rows => {
  let count = rows->Array.length
  for _ in 1 to count {
    rows->Array.pop->ignore
  }
}

let flush = () => {
  switch runtime.flushTimer.contents {
  | Some(timer) => {
      clearTimeout(timer)
      runtime.flushTimer := None
    }
  | None => ()
  }

  if runtime.rows->Array.length > 0 {
    let body = runtime.rows->JSON.Encode.array->JSON.stringify
    Window.Navigator.sendBeacon(GlobalVars.logEndpoint, body)
    clearRows(runtime.rows)
  }
}

let scheduleFlush = () =>
  switch runtime.flushTimer.contents {
  | Some(_) => ()
  | None => runtime.flushTimer := Some(setTimeout(flush, 2000))
  }

Window.addEventListener("beforeunload", _ => flush())

let log = (
  ~category,
  ~severity,
  ~eventName,
  ~provider=?,
  ~providerDimension="provider",
  ~paymentMethod=?,
  ~message=?,
  ~defaultMessageName=?,
  ~details=[],
  ~taxonomyDetails=[],
  ~eventIdPrefix="evt_",
  ~context=LoggerContext.current(),
) => {
  let categorySegment = category->categorySegment
  let normalizedEventName = eventName->snakeCase
  let normalizedProvider = provider->Option.map(screamingSnakeCase)
  let normalizedProviderDimension = providerDimension->snakeCase
  let normalizedDetails = details->normalizeKeys
  let normalizedTaxonomyDetails = taxonomyDetails->normalizeKeys
  let latency =
    normalizedDetails
    ->Array.find(((key, _)) => key === "duration_ms")
    ->Option.flatMap(((_, value)) => value->JSON.Decode.float)
    ->Option.map(value => value->Float.toString)
    ->Option.getOr("")
  let qualifiedEventName = `${categorySegment}.${normalizedEventName}`
  let eventDiscriminator = normalizedProvider->Option.getOr("")
  let eventKey = `${context.sessionId}:${context.flowId}:${qualifiedEventName}:${eventDiscriminator}`
  let currentCount = runtime.eventCounts->Dict.get(eventKey)->Option.getOr(0)
  runtime.eventCounts->Dict.set(eventKey, currentCount + 1)

  if (
    GlobalVars.enableLogging &&
    shouldEmit(severity) &&
    currentCount < GlobalVars.maxLogsPushedPerEventName
  ) {
    let eventId = eventIdPrefix ++ Utils.generateRandomString(12)
    let providerDetails = switch normalizedProvider {
    | Some(provider) => [(normalizedProviderDimension, provider->JSON.Encode.string)]
    | None => []
    }
    let eventTaxonomy =
      normalizedTaxonomyDetails->Array.length === 0
        ? [("name", normalizedEventName->JSON.Encode.string)]
        : []
    let taxonomy =
      [("category", categorySegment->JSON.Encode.string)]
      ->Array.concat(eventTaxonomy)
      ->Array.concat(normalizedTaxonomyDetails)
      ->Array.concat(providerDetails)
      ->Dict.fromArray
      ->JSON.Encode.object
    let messageName = defaultMessageName->Option.getOr(normalizedEventName)
    let resolvedMessage = message->Option.getOr(messageName->defaultMessage)
    let valueContext =
      [
        ("flow_id", context.flowId->JSON.Encode.string),
        ("session_id", context.sessionId->JSON.Encode.string),
        ("payment_id", context.paymentId->JSON.Encode.string),
        ("authentication_id", context.authenticationId->JSON.Encode.string),
        ("merchant_id", context.merchantId->JSON.Encode.string),
        ("profile_id", context.profileId->JSON.Encode.string),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object
    let value =
      [
        ("schema_version", 2->JSON.Encode.int),
        ("event_version", 1->JSON.Encode.int),
        ("event_id", eventId->JSON.Encode.string),
        ("taxonomy", taxonomy),
        ("context", valueContext),
        ("message", resolvedMessage->JSON.Encode.string),
        ("details", normalizedDetails->Dict.fromArray->JSON.Encode.object),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object
      ->JSON.stringify

    let row =
      [
        ("timestamp", Date.now()->Float.toString->JSON.Encode.string),
        ("log_type", severity->severityName->JSON.Encode.string),
        ("component", runtime.component->JSON.Encode.string),
        ("category", category->categoryName->JSON.Encode.string),
        ("source", runtime.source->JSON.Encode.string),
        ("version", GlobalVars.repoVersion->JSON.Encode.string),
        ("value", value->JSON.Encode.string),
        ("session_id", context.sessionId->JSON.Encode.string),
        ("merchant_id", context.merchantId->JSON.Encode.string),
        ("payment_id", context.paymentId->JSON.Encode.string),
        ("authentication_id", context.authenticationId->JSON.Encode.string),
        ("app_id", ""->JSON.Encode.string),
        (
          "platform",
          Window.Navigator.platform->LoggerCommonHelpers.screamingSnakeCase->JSON.Encode.string,
        ),
        ("user_agent", Window.Navigator.userAgent->JSON.Encode.string),
        ("event_name", qualifiedEventName->JSON.Encode.string),
        (
          "browser_name",
          browser.name
          ->Option.getOr("Others")
          ->LoggerCommonHelpers.screamingSnakeCase
          ->JSON.Encode.string,
        ),
        ("browser_version", browser.version->Option.getOr("0")->JSON.Encode.string),
        ("latency", latency->JSON.Encode.string),
        ("first_event", (currentCount === 0 ? "true" : "false")->JSON.Encode.string),
        (
          "payment_method",
          paymentMethod
          ->Option.getOr("")
          ->LoggerCommonHelpers.screamingSnakeCase
          ->JSON.Encode.string,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object

    runtime.rows->Array.push(row)->ignore
    if severity === Error || runtime.rows->Array.length >= 8 {
      flush()
    } else {
      scheduleFlush()
    }
  }
}

let logEvent = (
  ~category,
  ~severity,
  ~event,
  ~providerDimension="provider",
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~eventIdPrefix="evt_",
) => {
  let (eventName, eventDetails) = event->variantEventMetadata
  safeRun(() =>
    log(
      ~category,
      ~severity,
      ~eventName,
      ~providerDimension,
      ~paymentMethod?,
      ~message?,
      ~details=eventDetails->Array.concat(details),
      ~eventIdPrefix,
    )
  )
}

let logProviderEvent = (
  ~category,
  ~severity,
  ~event,
  ~providerDimension="provider",
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~eventIdPrefix="evt_",
) => {
  let (eventName, provider, eventDetails) = event->providerEventMetadata
  safeRun(() =>
    log(
      ~category,
      ~severity,
      ~eventName,
      ~provider,
      ~providerDimension,
      ~paymentMethod?,
      ~message?,
      ~details=eventDetails->Array.concat(details),
      ~eventIdPrefix,
    )
  )
}

let asyncAction = category =>
  switch category {
  | Function | Merchant => "call"
  | Api => "request"
  | Resource => "load"
  | _ => "observe"
  }

let asyncOutcomeName = (category, outcome) =>
  switch (category, outcome) {
  | (Function | Merchant, Started) => "init"
  | (Function | Merchant, Done(_)) => "done"
  | (Function | Merchant, Failed(_) | TimedOut(_)) => "error"
  | _ => outcome->LoggerCommonHelpers.outcomeName
  }

let emitAsyncOutcome = (
  ~category,
  ~target,
  ~provider=?,
  ~providerDimension="provider",
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~failureName,
  ~eventIdPrefix="evt_",
  ~context=LoggerContext.current(),
  outcome,
) => {
  let action = category->asyncAction
  let normalizedTarget = target->snakeCase
  let outcomeName = asyncOutcomeName(category, outcome)
  let eventTarget = switch (category, provider) {
  | (Function, Some(provider)) => `${provider->snakeCase}.${normalizedTarget}`
  | _ => normalizedTarget
  }
  log(
    ~category,
    ~severity=outcome->LoggerCommonHelpers.outcomeSeverity,
    ~eventName=`${action}_${outcomeName}.${eventTarget}`,
    ~provider?,
    ~providerDimension,
    ~paymentMethod?,
    ~message?,
    ~defaultMessageName=`${category->categorySegment}_${action}_${outcomeName}`,
    ~details=details->Array.concat(outcome->LoggerCommonHelpers.outcomeDetails(~failureName)),
    ~taxonomyDetails=[
      ("action", action->JSON.Encode.string),
      ("target", normalizedTarget->JSON.Encode.string),
      ("outcome", outcomeName->JSON.Encode.string),
    ],
    ~eventIdPrefix,
    ~context,
  )
}

let observeAsync = (
  ~category,
  ~target,
  ~provider=?,
  ~providerDimension="provider",
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~eventIdPrefix="evt_",
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~resultFailure=?,
  ~resultDetails=?,
  ~call,
) => {
  let context = LoggerContext.current()
  let emit = outcome =>
    emitAsyncOutcome(
      ~category,
      ~target,
      ~provider?,
      ~providerDimension,
      ~paymentMethod?,
      ~message?,
      ~details,
      ~failureName=LoggerCommonHelpers.promiseFailureName,
      ~eventIdPrefix,
      outcome,
      ~context,
    )
  LoggerCommonHelpers.observeAsync(~timeoutMs, ~emit, ~resultFailure?, ~resultDetails?, ~call)
}

let observeEventAsync = (
  ~category,
  ~event,
  ~providerDimension="provider",
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~eventIdPrefix="evt_",
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~resultFailure=?,
  ~resultDetails=?,
  ~call,
) => {
  let (target, eventDetails) = event->variantEventMetadata
  observeAsync(
    ~category,
    ~target,
    ~providerDimension,
    ~paymentMethod?,
    ~message?,
    ~details=eventDetails->Array.concat(details),
    ~eventIdPrefix,
    ~timeoutMs,
    ~resultFailure?,
    ~resultDetails?,
    ~call,
  )
}

let observeProviderAsync = (
  ~category,
  ~event,
  ~providerDimension="provider",
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~eventIdPrefix="evt_",
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~resultFailure=?,
  ~resultDetails=?,
  ~call,
) => {
  let (target, provider, eventDetails) = event->providerEventMetadata
  observeAsync(
    ~category,
    ~target,
    ~provider,
    ~providerDimension,
    ~paymentMethod?,
    ~message?,
    ~details=eventDetails->Array.concat(details),
    ~eventIdPrefix,
    ~timeoutMs,
    ~resultFailure?,
    ~resultDetails?,
    ~call,
  )
}

let observeEventSync = (
  ~category,
  ~event,
  ~providerDimension="provider",
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~eventIdPrefix="evt_",
  ~call,
) => {
  let (target, eventDetails) = event->variantEventMetadata
  let context = LoggerContext.current()
  let emit = outcome =>
    emitAsyncOutcome(
      ~category,
      ~target,
      ~providerDimension,
      ~paymentMethod?,
      ~message?,
      ~details=eventDetails->Array.concat(details),
      ~failureName=LoggerCommonHelpers.promiseFailureName,
      ~eventIdPrefix,
      ~context,
      outcome,
    )
  LoggerCommonHelpers.observeSync(~emit, ~call)
}

let observeProviderResource = (
  ~event,
  ~url,
  ~resource,
  ~providerDimension="provider",
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~eventIdPrefix="evt_",
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~onLoad,
  ~onError,
) => {
  let (target, provider, eventDetails) = event->providerEventMetadata
  let resourceType = resource->ResourceLoader.resourceType
  let resourceDetails = ref(
    LoggerCommonHelpers.resourceRequestDetails(~url, ~resourceType, ~timeoutMs),
  )
  let context = LoggerContext.current()
  let emit = (outcome, outcomeDetails) =>
    emitAsyncOutcome(
      ~category=Resource,
      ~target,
      ~provider,
      ~providerDimension,
      ~paymentMethod?,
      ~message?,
      ~details=eventDetails
      ->Array.concat(resourceDetails.contents)
      ->Array.concat(details)
      ->Array.concat(outcomeDetails),
      ~failureName=LoggerCommonHelpers.resourceFailureName,
      ~eventIdPrefix,
      ~context,
      outcome,
    )
  let tracker = LoggerCommonHelpers.makeOperationTracker()
  let observedOnStart = loadMode => {
    resourceDetails :=
      LoggerCommonHelpers.resourceRequestDetails(
        ~url,
        ~resourceType,
        ~timeoutMs,
        ~loadMode=loadMode->LoggerCommonHelpers.variantValue,
      )
    emit(Started, [])
    LoggerCommonHelpers.scheduleOperationTimeout(tracker, ~timeoutMs, ~onTimeout=() =>
      emit(TimedOut({durationMs: LoggerCommonHelpers.operationDurationMs(tracker), timeoutMs}), [])
    )
  }
  let observedOnLoad = loadResult => {
    if LoggerCommonHelpers.finishOperation(tracker) {
      emit(
        Done({durationMs: LoggerCommonHelpers.operationDurationMs(tracker), details: []}),
        [("load_result", loadResult->LoggerCommonHelpers.variantValue->JSON.Encode.string)],
      )
    }
    onLoad()
  }
  let observedOnError = () => {
    if LoggerCommonHelpers.finishOperation(tracker) {
      emit(
        Failed({
          durationMs: LoggerCommonHelpers.operationDurationMs(tracker),
          failure: LoadFailed,
          errorSummary: None,
        }),
        [],
      )
    }
    onError()
  }

  try {
    ResourceLoader.load(
      ~url,
      ~resource,
      ~onStart=observedOnStart,
      ~onLoad=observedOnLoad,
      ~onError=observedOnError,
    )
  } catch {
  | error => {
      if LoggerCommonHelpers.finishOperation(tracker) {
        emit(
          Failed({
            durationMs: LoggerCommonHelpers.operationDurationMs(tracker),
            failure: LoaderThrew,
            errorSummary: Some(error->LoggerCommonHelpers.summarizeException),
          }),
          [],
        )
      }
      raise(error)
    }
  }
}
