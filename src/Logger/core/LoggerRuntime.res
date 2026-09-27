open LoggerTypes

let schemaVersion = 8

type source =
  | HyperLoader
  | PreMountLoader
  | Headless
  | AuthenticationSession
  | Elements(CardThemeType.mode)
  | Fullscreen(string)

let sourceName = source =>
  switch source {
  | HyperLoader => "HYPER_LOADER"
  | PreMountLoader => "PRE_MOUNT_LOADER"
  | Headless => "HEADLESS"
  | AuthenticationSession => "AUTHENTICATION_SESSION"
  | Elements(mode) =>
    `ELEMENTS_${mode->CardThemeType.getPaymentModeToStrMapper->LoggerUtils.screamingSnakeCase}`
  | Fullscreen(overlay) => `FULLSCREEN_${overlay->LoggerUtils.screamingSnakeCase}`
  }

let currentSource = ref(HyperLoader->sourceName)

let configure = (~source) => currentSource := source->sourceName

let isMerchantWindow = () => currentSource.contents === HyperLoader->sourceName

let isNestedElement = () =>
  currentSource.contents === Elements(CardThemeType.PaymentMethodsSDK)->sourceName

let browser = UAParser.make().browser

let rank = severity =>
  switch severity {
  | Debug => 0
  | Info => 1
  | Warning => 2
  | Error => 3
  }

let minimumRank = switch GlobalVars.loggingLevelStr->String.trim->String.toUpperCase {
| "DEBUG" => Debug->rank
| "INFO" => Info->rank
| "WARNING" | "WARN" => Warning->rank
| "ERROR" => Error->rank
| "SILENT" => Error->rank + 1
| _ => Debug->rank
}

let isEnabled = severity => GlobalVars.enableLogging && severity->rank >= minimumRank

let emitCounts = ref(Dict.make())

let onceKeys = ref(Dict.make())

LoggerContext.onSessionChange :=
  (
    () => {
      emitCounts := Dict.make()
      onceKeys := Dict.make()
    }
  )

let emit = (
  ~category,
  ~spec: eventSpec,
  ~severity: severity,
  ~data: details=[],
  ~details: details=[],
  ~exn: option<exn>=?,
  ~failure: option<'response>=?,
  ~durationMs: option<float>=?,
  ~paymentMethod: option<LoggerPaymentMethod.paymentMethod>=?,
  ~context: option<LoggerContext.t>=?,
  ~source: option<source>=?,
  ~rateKey: option<string>=?,
  ~message: option<string>=?,
  ~once=false,
) =>
  if severity->isEnabled {
    LoggerUtils.safeRun(() => {
      let context = switch context {
      | Some(started) => started->LoggerContext.fillFrom(LoggerContext.current())
      | None => LoggerContext.current()
      }
      let name = LoggerUtils.eventName(
        ~category,
        ~action=spec.action,
        ~subject=spec.subject,
        ~outcome=spec.outcome,
      )
      let countKey = switch rateKey {
      | Some(rateKey) => `${name}#${rateKey}`
      | None => name
      }
      let limit = GlobalVars.maxLogsPushedPerEventName
      let seen = emitCounts.contents->Dict.get(countKey)->Option.getOr(0)

      let duplicateOfOnce = if once {
        let fact =
          data
          ->Array.concat(details)
          ->Dict.fromArray
          ->JSON.Encode.object
          ->JSON.stringify
        let onceKey = `${name}#${fact}`
        let alreadyLogged = onceKeys.contents->Dict.get(onceKey)->Option.isSome
        if !alreadyLogged {
          onceKeys.contents->Dict.set(onceKey, true)
        }
        alreadyLogged
      } else {
        false
      }

      if seen <= limit && !duplicateOfOnce {
        emitCounts.contents->Dict.set(countKey, seen + 1)
        let errorDetails =
          switch exn {
          | Some(exn) => Some(exn->LoggerUtils.summarizeExn)
          | None => failure->Option.flatMap(LoggerUtils.summarizeErrorResponse)
          }
          ->Option.map(LoggerUtils.errorDetails)
          ->Option.getOr([])
        let dropped = LoggerQueue.takeDroppedRows()
        let sendFailures = LoggerQueue.takeSendFailures()
        let details =
          LoggerUtils.mergeDetails(~data, ~details)
          ->Array.concat(errorDetails)
          ->LoggerUtils.normalizeDetails
          ->Array.concat(dropped > 0 ? [("dropped_rows", dropped->JSON.Encode.int)] : [])
          ->Array.concat(sendFailures > 0 ? [("send_failures", sendFailures->JSON.Encode.int)] : [])
          ->Array.concat(seen === limit ? [("rate_limited", true->JSON.Encode.bool)] : [])
          ->LoggerUtils.fitToBudget

        let value =
          [
            ("schema_version", schemaVersion->JSON.Encode.int),
            (
              "href",
              Window.hrefWithoutSearch
              ->LoggerUtils.truncateTo(LoggerUtils.maxRowTextLength)
              ->JSON.Encode.string,
            ),
            ("occurrence", (seen + 1)->JSON.Encode.int),
          ]
          ->Array.concat(
            switch message {
            | Some(message) => [
                ("message", message->LoggerUtils.redact->LoggerUtils.truncate->JSON.Encode.string),
              ]
            | None => []
            },
          )
          ->Array.concat([("details", details->Dict.fromArray->JSON.Encode.object)])
          ->Dict.fromArray
          ->JSON.Encode.object
          ->JSON.stringify

        let row =
          [
            ("timestamp", Date.now()->Float.toString),
            ("log_type", severity->severityName),
            ("component", "WEB"),
            ("category", category->categoryName),
            ("source", source->Option.mapOr(currentSource.contents, sourceName)),
            ("version", GlobalVars.repoVersion),
            ("value", value),
            ("session_id", context.sessionId),
            ("merchant_id", context.merchantId),
            ("payment_id", context.paymentId),
            ("authentication_id", context.authenticationId),
            ("app_id", ""),
            ("platform", Window.Navigator.platform->LoggerUtils.screamingSnakeCase),
            (
              "user_agent",
              Window.Navigator.userAgent->LoggerUtils.truncateTo(LoggerUtils.maxRowTextLength),
            ),
            ("event_name", name),
            ("browser_name", browser.name->Option.getOr("Others")->LoggerUtils.screamingSnakeCase),
            ("browser_version", browser.version->Option.getOr("0")),
            ("latency", durationMs->Option.map(value => value->Float.toString)->Option.getOr("")),
            ("first_event", (seen === 0)->LoggerUtils.stringOfBool),
            (
              "payment_method",
              paymentMethod->Option.map(LoggerPaymentMethod.qualifiedName)->Option.getOr(""),
            ),
          ]
          ->Array.map(((key, value)) => (key, value->JSON.Encode.string))
          ->Dict.fromArray
          ->JSON.Encode.object

        LoggerQueue.push(row, ~isError=severity === Error)
      }
    })
  }

let defaultTimeoutMs = 30000

let userGatedTimeoutMs = 600000

type tracker = {
  startedAt: float,
  mutable settled: bool,
  mutable timer: option<timeoutId>,
}

let makeTracker = () => {startedAt: Date.now(), settled: false, timer: None}

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

let emitOutcome = (
  ~category,
  ~spec: eventSpec,
  ~severity: operationSeverity,
  ~data: details=[],
  ~details: details=[],
  ~paymentMethod=?,
  ~context=?,
  ~source=?,
  ~message=?,
  operationOutcome,
) =>
  emit(
    ~category,
    ~spec={...spec, outcome: Some(operationOutcome->outcomeOf)},
    ~severity=operationOutcome->LoggerUtils.outcomeSeverity(~severity),
    ~data=data->Array.concat(operationOutcome->LoggerUtils.outcomeDetails),
    ~details,
    ~durationMs=?operationOutcome->durationOf,
    ~paymentMethod?,
    ~context?,
    ~source?,
    ~message?,
  )

let emitPhase = (
  ~category,
  ~spec: eventSpec,
  ~severity: operationSeverity,
  ~outcome: outcome,
  ~data=[],
  ~details=[],
  ~startedAt=?,
  ~exn=?,
  ~paymentMethod=?,
  ~message=?,
) => {
  let durationMs = startedAt->Option.map(startedAt => Date.now() -. startedAt)->Option.getOr(0.)
  let operationOutcome = switch outcome {
  | Started => OpStarted
  | Done => OpDone({durationMs: durationMs})
  | Returned => OpReturned({durationMs: durationMs})
  | Triggered => OpTriggered({durationMs: durationMs})
  | Reused => OpReused({durationMs: durationMs})
  | TimedOut => OpTimedOut({durationMs, timeoutMs: 0})
  | Failed =>
    OpFailed({
      durationMs,
      class: exn->Option.isSome ? Threw : ReturnedFailure,
      error: exn->Option.map(LoggerUtils.summarizeUnknown),
    })
  }
  operationOutcome->emitOutcome(
    ~category,
    ~spec,
    ~severity,
    ~data,
    ~details,
    ~paymentMethod?,
    ~message?,
  )
}

let isThenable: 'value => bool = %raw(`
  (value) => value != null && typeof value.then === "function"
`)

external asPromise: 'value => promise<'result> = "%identity"
external asResult: 'value => 'result = "%identity"

let rethrow = error =>
  switch error {
  | JsExn(jsError) => JsExn.throw(jsError)
  | error => throw(error)
  }

let observe = (
  ~category,
  ~spec: eventSpec,
  ~severity: operationSeverity,
  ~data: details=[],
  ~details: details=[],
  ~timeoutMs=defaultTimeoutMs,
  ~failureOf: option<'result => option<errorSummary>>=?,
  ~detailsOf: option<'result => details>=?,
  ~paymentMethod=?,
  ~source=?,
  ~syncOutcome=Returned,
  ~message=?,
  ~call: unit => 'value,
): 'value => {
  let context = LoggerContext.current()
  let base = LoggerUtils.mergeDetails(~data, ~details)
  let syncStep = timing =>
    switch syncOutcome {
    | Triggered => OpTriggered(timing)
    | _ => OpReturned(timing)
    }
  let tracker = makeTracker()
  let timedOut = ref(false)

  let emitStep = (operationOutcome, ~details=[]) =>
    operationOutcome->emitOutcome(
      ~category,
      ~spec,
      ~severity,
      ~data=base,
      ~details=details->Array.concat(
        timedOut.contents ? [("settled_after_timeout", true->JSON.Encode.bool)] : [],
      ),
      ~paymentMethod?,
      ~context,
      ~source?,
      ~message?,
    )

  let failed = (~class, ~error) =>
    emitStep(OpFailed({durationMs: tracker->elapsed, class, error: Some(error)}))

  let classify = result =>
    try failureOf->Option.flatMap(failureOf => failureOf(result)) catch {
    | error => Some(error->LoggerUtils.summarizeExn)
    }

  let describe = result =>
    try detailsOf->Option.map(detailsOf => detailsOf(result))->Option.getOr([]) catch {
    | _ => []
    }

  let finish = (result, ~outcome) =>
    switch result->classify {
    | Some(error) => failed(~class=ReturnedFailure, ~error)
    | None => emitStep(outcome({durationMs: tracker->elapsed}), ~details=result->describe)
    }

  try {
    let value = call()
    if value->isThenable {
      emitStep(OpStarted)
      tracker.timer = Some(setTimeout(() =>
          if !tracker.settled {
            tracker.settled = true
            tracker.timer = None
            timedOut := true
            emitStep(OpTimedOut({durationMs: tracker->elapsed, timeoutMs}))
          }
        , timeoutMs))
      value
      ->asPromise
      ->Promise.thenResolve(result =>
        if tracker->settle || timedOut.contents {
          result->finish(~outcome=timing => OpDone(timing))
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
    } else if tracker->settle {
      value->asResult->finish(~outcome=syncStep)
    }
    value
  } catch {
  | error => {
      if tracker->settle {
        failed(~class=Threw, ~error=error->LoggerUtils.summarizeExn)
      }
      rethrow(error)
    }
  }
}

// Returns a function with the same type as `fn` that forwards every argument
// (and `this`) through `run`. Arity-agnostic, so one wrapper serves handlers
// of any argument count. Non-functions are returned untouched, and the
// original `length` is preserved for SDKs that inspect handler arity.
let forwardInvocation: ('fn, (unit => 'value) => 'value) => 'fn = %raw(`
  function (fn, run) {
    if (typeof fn !== "function") {
      return fn;
    }
    var wrapped = function () {
      var self = this;
      var args = arguments;
      return run(function () {
        return fn.apply(self, args);
      });
    };
    try {
      Object.defineProperty(wrapped, "length", { value: fn.length });
    } catch (_) {}
    return wrapped;
  }
`)

let observeCallback = (
  ~category,
  ~spec: eventSpec,
  ~severity: operationSeverity,
  ~data: details=[],
  ~details: details=[],
  ~timeoutMs=?,
  ~failureOf=?,
  ~paymentMethod=?,
  ~source=?,
  ~message=?,
  ~callback: 'fn,
): 'fn =>
  callback->forwardInvocation(invoke =>
    observe(
      ~category,
      ~spec,
      ~severity,
      ~data,
      ~details,
      ~timeoutMs?,
      ~failureOf?,
      ~paymentMethod?,
      ~source?,
      ~syncOutcome=Triggered,
      ~message?,
      ~call=invoke,
    )
  )

let observeResource = (
  ~spec: eventSpec,
  ~severity: operationSeverity,
  ~url,
  ~resource,
  ~attributes=[],
  ~matchQuery=false,
  ~paymentMethod=?,
  ~source=?,
  ~abandoned=() => false,
  ~message=?,
  ~onLoad,
  ~onError,
) => {
  let context = LoggerContext.current()
  let tracker = makeTracker()

  let base = [
    ("url", url->JSON.Encode.string),
    ("resource_type", resource->ResourceLoader.resourceName->JSON.Encode.string),
    ("configured_timeout_ms", defaultTimeoutMs->JSON.Encode.int),
    ("deduped", true->JSON.Encode.bool),
  ]

  let emitStep = (operationOutcome, ~details=[]) =>
    operationOutcome->emitOutcome(
      ~category=Resource,
      ~spec,
      ~severity,
      ~data=base,
      ~details,
      ~paymentMethod?,
      ~context,
      ~source?,
      ~message?,
    )

  let failed = (~class, ~error) =>
    emitStep(
      OpFailed({
        durationMs: tracker->elapsed,
        class,
        error: Some(error->LoggerUtils.summarizeExn),
      }),
    )

  let started = ref(false)
  let start = () =>
    if !started.contents {
      started := true
      emitStep(OpStarted)
    }

  tracker.timer = Some(setTimeout(() =>
      if tracker->settle {
        start()
        emitStep(
          OpTimedOut({durationMs: tracker->elapsed, timeoutMs: defaultTimeoutMs}),
          ~details=abandoned() ? [("abandoned", true->JSON.Encode.bool)] : [],
        )
      }
    , defaultTimeoutMs))

  let handleLoad = (result: ResourceLoader.loadResult) => {
    if tracker->settle {
      let timing = {durationMs: tracker->elapsed}
      switch result {
      | Reused => emitStep(OpReused(timing))
      | Loaded => {
          start()
          emitStep(OpDone(timing))
        }
      }
    }
    onLoad()
  }

  let handleError = error => {
    if tracker->settle {
      start()
      failed(~class=LoadFailed, ~error)
    }
    onError(error)
  }

  try ResourceLoader.load(
    ~url,
    ~resource,
    ~attributes,
    ~matchQuery,
    ~onStart=start,
    ~onLoad=handleLoad,
    ~onError=handleError,
  ) catch {
  | error => {
      if tracker->settle {
        start()
        failed(~class=Threw, ~error)
      }
      rethrow(error)
    }
  }
}
