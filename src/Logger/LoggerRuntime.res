open LoggerTypes

let schemaVersion = 6

type source =
  | HyperLoader
  | Elements(CardThemeType.mode)

let sourceName = source =>
  switch source {
  | HyperLoader => "HYPER_LOADER"
  | Elements(mode) =>
    `ELEMENTS_${mode->CardThemeType.getPaymentModeToStrMapper->LoggerUtils.screamingSnakeCase}`
  }

let currentSource = ref(HyperLoader->sourceName)

let configure = (~source) => currentSource := source->sourceName

let browser = UAParser.make().browser

let minimumSeverity = switch GlobalVars.loggingLevelStr->String.trim->String.toUpperCase {
| "DEBUG" => Debug
| "INFO" => Info
| "WARNING" | "WARN" => Warning
| "ERROR" => Error
| _ => Debug
}

let rank = severity =>
  switch severity {
  | Debug => 0
  | Info => 1
  | Warning => 2
  | Error => 3
  }

let isEnabled = severity => GlobalVars.enableLogging && severity->rank >= minimumSeverity->rank

let emitCounts = ref(Dict.make())

LoggerContext.onSessionChange := (() => emitCounts := Dict.make())

let eventName = (~category, ~action, ~subject, ~outcome) => {
  let step = switch (action, outcome) {
  | (Some(action), Some(outcome)) => Some(`${action}_${outcome->outcomeName}`)
  | (Some(action), None) => Some(action)
  | (None, Some(outcome)) => Some(outcome->outcomeName)
  | (None, None) => None
  }
  [Some(category->categorySegment), step, Some(subject)]
  ->Array.filterMap(segment => segment)
  ->Array.join(".")
}

let emitRow = (
  ~category,
  ~severity,
  ~action: option<action>=?,
  ~subject: string,
  ~outcome,
  ~details: details,
  ~durationMs: option<float>,
  ~paymentMethod: option<LoggerTaxonomy.paymentMethod>,
  ~context: LoggerContext.t,
) =>
  if severity->isEnabled {
    let name = eventName(~category, ~action, ~subject, ~outcome)
    let limit = GlobalVars.maxLogsPushedPerEventName
    let seen = emitCounts.contents->Dict.get(name)->Option.getOr(0)

    if seen <= limit {
      emitCounts.contents->Dict.set(name, seen + 1)
      let paymentMethod = switch paymentMethod {
      | Some(_) as paymentMethod => paymentMethod
      | None => context.paymentMethod
      }
      let dropped = LoggerQueue.takeDroppedRows()
      let details =
        details
        ->LoggerUtils.normalizeDetails
        ->Array.concat(dropped > 0 ? [("dropped_rows", dropped->JSON.Encode.int)] : [])
        ->Array.concat(seen === limit ? [("rate_limited", true->JSON.Encode.bool)] : [])
        ->LoggerUtils.fitToBudget

      let value =
        [
          ("schema_version", schemaVersion->JSON.Encode.int),
          ("profile_id", context.profileId->JSON.Encode.string),
          ("authentication_id", context.authenticationId->JSON.Encode.string),
          ("href", Window.hrefWithoutSearch->JSON.Encode.string),
          ("occurrence", (seen + 1)->JSON.Encode.int),
          ("details", details->Dict.fromArray->JSON.Encode.object),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
        ->JSON.stringify

      let row =
        [
          ("timestamp", Date.now()->Float.toString),
          ("log_type", severity->severityName),
          ("component", "WEB"),
          ("category", category->categoryName),
          ("source", currentSource.contents),
          ("version", GlobalVars.repoVersion),
          ("value", value),
          ("session_id", context.sessionId),
          ("merchant_id", context.merchantId),
          ("payment_id", context.paymentId),
          ("app_id", ""),
          ("platform", Window.Navigator.platform->LoggerUtils.screamingSnakeCase),
          ("user_agent", Window.Navigator.userAgent),
          ("event_name", name),
          ("browser_name", browser.name->Option.getOr("Others")->LoggerUtils.screamingSnakeCase),
          ("browser_version", browser.version->Option.getOr("0")),
          ("latency", durationMs->Option.map(value => value->Float.toString)->Option.getOr("")),
          ("first_event", (seen === 0)->LoggerUtils.stringOfBool),
          (
            "payment_method",
            paymentMethod->Option.map(LoggerTaxonomy.qualifiedName)->Option.getOr(""),
          ),
        ]
        ->Array.map(((key, value)) => (key, value->JSON.Encode.string))
        ->Dict.fromArray
        ->JSON.Encode.object

      LoggerQueue.push(row, ~isError=severity === Error)
    }
  }

let emit = (
  ~category,
  ~spec: eventSpec,
  ~severity: severity,
  ~data: details=[],
  ~details: details=[],
  ~exn: option<exn>=?,
  ~failure: option<'response>=?,
  ~paymentMethod=?,
) =>
  LoggerUtils.safeRun(() => {
    let errorDetails =
      switch exn {
      | Some(exn) => Some(exn->LoggerUtils.summarizeExn)
      | None => failure->Option.flatMap(LoggerUtils.summarizeErrorResponse)
      }
      ->Option.map(LoggerUtils.errorDetails)
      ->Option.getOr([])
    emitRow(
      ~category,
      ~severity,
      ~action=?spec.action,
      ~subject=spec.subject,
      ~outcome=spec.outcome,
      ~details=LoggerUtils.mergeDetails(~data, ~details)->Array.concat(errorDetails),
      ~durationMs=None,
      ~paymentMethod,
      ~context=LoggerContext.current(),
    )
  })

let record = (~category, ~spec: operationSpec, ~severity: severity, ~details: details=[]) =>
  LoggerUtils.safeRun(() =>
    emitRow(
      ~category,
      ~severity,
      ~action=spec.action,
      ~subject=spec.subject,
      ~outcome=None,
      ~details,
      ~durationMs=None,
      ~paymentMethod=None,
      ~context=LoggerContext.current(),
    )
  )

let defaultTimeoutMs = 30000

let userGatedTimeoutMs = 600000

type tracker = {
  startedAt: float,
  mutable settled: bool,
  mutable timer: option<timeoutId>,
}

let elapsed = tracker => Date.now() -. tracker.startedAt

let settle = tracker =>
  if tracker.settled {
    false
  } else {
    tracker.settled = true
    switch tracker.timer {
    | Some(timer) => {
        clearTimeout(timer)
        tracker.timer = None
      }
    | None => ()
    }
    true
  }

let recordOutcome = (
  ~category,
  ~spec: operationSpec,
  ~severity: operationSeverity,
  ~details: details,
  ~extra: details=[],
  ~paymentMethod,
  ~context,
  operationOutcome,
) =>
  LoggerUtils.safeRun(() =>
    emitRow(
      ~category,
      ~severity=operationOutcome->LoggerUtils.outcomeSeverity(~severity),
      ~action=spec.action,
      ~subject=spec.subject,
      ~outcome=Some(operationOutcome->outcomeOf),
      ~details=details
      ->Array.concat(operationOutcome->LoggerUtils.outcomeDetails)
      ->Array.concat(extra),
      ~durationMs=operationOutcome->durationOf,
      ~paymentMethod,
      ~context,
    )
  )

let observe = (
  ~category,
  ~spec: operationSpec,
  ~severity: operationSeverity,
  ~data: details=[],
  ~details: details=[],
  ~timeoutMs=defaultTimeoutMs,
  ~failureOf: option<'result => option<errorSummary>>=?,
  ~detailsOf: option<'result => details>=?,
  ~paymentMethod=?,
  ~call,
) => {
  let context = LoggerContext.current()
  let base = LoggerUtils.mergeDetails(~data, ~details)
  let tracker = {startedAt: Date.now(), settled: false, timer: None}
  let timedOut = ref(false)

  let record = (operationOutcome, ~details=[]) =>
    operationOutcome->recordOutcome(
      ~category,
      ~spec,
      ~severity,
      ~details=base,
      ~extra=details->Array.concat(
        timedOut.contents ? [("settled_after_timeout", true->JSON.Encode.bool)] : [],
      ),
      ~paymentMethod,
      ~context,
    )

  let failed = (~class, ~error) =>
    record(OpFailed({durationMs: tracker->elapsed, class, error: Some(error)}))

  record(OpStarted)
  tracker.timer = Some(setTimeout(() =>
      if !tracker.settled {
        tracker.settled = true
        tracker.timer = None
        timedOut := true
        record(OpTimedOut({durationMs: tracker->elapsed, timeoutMs}))
      }
    , timeoutMs))

  let classify = result =>
    try failureOf->Option.flatMap(failureOf => failureOf(result)) catch {
    | error => Some(error->LoggerUtils.summarizeExn)
    }

  let describe = result =>
    try detailsOf->Option.map(detailsOf => detailsOf(result))->Option.getOr([]) catch {
    | _ => []
    }

  try {
    let promise = call()
    promise
    ->Promise.thenResolve(result =>
      if tracker->settle || timedOut.contents {
        switch result->classify {
        | Some(error) => failed(~class=ReturnedFailure, ~error)
        | None => record(OpDone({durationMs: tracker->elapsed}), ~details=result->describe)
        }
      }
    )
    ->Promise.catch(error => {
      if tracker->settle || timedOut.contents {
        let error = error->LoggerUtils.summarizeExn
        failed(~class=error->LoggerUtils.isAborted ? Aborted : Rejected, ~error)
      }
      Promise.resolve()
    })
    ->ignore
    promise
  } catch {
  | error => {
      if tracker->settle {
        failed(~class=Threw, ~error=error->LoggerUtils.summarizeExn)
      }
      raise(error)
    }
  }
}

let observeSync = (
  ~category,
  ~spec: operationSpec,
  ~severity: operationSeverity,
  ~details=[],
  ~paymentMethod=?,
  ~call,
) => {
  let context = LoggerContext.current()
  let startedAt = Date.now()
  let elapsed = () => Date.now() -. startedAt
  let record = operationOutcome =>
    operationOutcome->recordOutcome(~category, ~spec, ~severity, ~details, ~paymentMethod, ~context)
  try {
    let result = call()
    record(OpDone({durationMs: elapsed()}))
    result
  } catch {
  | error => {
      record(
        OpFailed({
          durationMs: elapsed(),
          class: Threw,
          error: Some(error->LoggerUtils.summarizeExn),
        }),
      )
      raise(error)
    }
  }
}

let observeResource = (
  ~spec: operationSpec,
  ~severity: operationSeverity,
  ~url,
  ~resource,
  ~attributes=[],
  ~matchQuery=false,
  ~dedupe=true,
  ~timeoutMs=defaultTimeoutMs,
  ~paymentMethod=?,
  ~abandoned=() => false,
  ~onLoad,
  ~onError,
) => {
  let context = LoggerContext.current()
  let tracker = {startedAt: Date.now(), settled: false, timer: None}

  let base = [
    ("url", url->JSON.Encode.string),
    ("resource_type", resource->ResourceLoader.resourceName->JSON.Encode.string),
    ("configured_timeout_ms", timeoutMs->JSON.Encode.int),
    ("deduped", dedupe->JSON.Encode.bool),
  ]

  let record = operationOutcome =>
    operationOutcome->recordOutcome(
      ~category=Resource,
      ~spec,
      ~severity,
      ~details=base,
      ~paymentMethod,
      ~context,
    )

  let failed = (~class, ~error) =>
    record(
      OpFailed({
        durationMs: tracker->elapsed,
        class,
        error: Some(error->LoggerUtils.summarizeExn),
      }),
    )

  record(OpStarted)

  tracker.timer = Some(setTimeout(() =>
      if tracker->settle && !abandoned() {
        record(OpTimedOut({durationMs: tracker->elapsed, timeoutMs}))
      }
    , timeoutMs))

  let handleLoad = (result: ResourceLoader.loadResult) => {
    if tracker->settle {
      let timing = {durationMs: tracker->elapsed}
      record(
        switch result {
        | Reused => OpReused(timing)
        | Loaded => OpDone(timing)
        },
      )
    }
    onLoad()
  }

  let handleError = error => {
    if tracker->settle {
      failed(~class=LoadFailed, ~error)
    }
    onError(error)
  }

  try ResourceLoader.load(
    ~url,
    ~resource,
    ~attributes,
    ~matchQuery,
    ~dedupe,
    ~onLoad=handleLoad,
    ~onError=handleError,
  ) catch {
  | error => {
      if tracker->settle {
        failed(~class=Threw, ~error)
      }
      raise(error)
    }
  }
}
