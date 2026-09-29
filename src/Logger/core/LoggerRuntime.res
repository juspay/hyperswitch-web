open LoggerTypes

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

let currentSource = ref("HYPER_LOADER")

let configure = (~source) => currentSource := source->sourceName

let isMerchantWindow = () => currentSource.contents === "HYPER_LOADER"

let isNestedElement = () =>
  currentSource.contents === Elements(CardThemeType.PaymentMethodsSDK)->sourceName

type browserInfo = {name: string, version: string}

let detectBrowser: unit => browserInfo = %raw(`
  function () {
    var ua = typeof navigator !== "undefined" ? navigator.userAgent || "" : "";
    var rules = [
      [/Instagram[\/ ]([\d.]+)/, "Instagram"],
      [/FBAV\/([\d.]+)/, "Facebook"],
      [/LinkedInApp\/([\d.]+)/, "LinkedIn"],
      [/Edg(?:e|A|iOS)?\/([\d.]+)/, "Edge"],
      [/(?:OPR|Opera)\/([\d.]+)/, "Opera"],
      [/SamsungBrowser\/([\d.]+)/, "Samsung Internet"],
      [/FxiOS\/([\d.]+)/, "Mobile Firefox"],
      [/(?:Mobile|Tablet);.*Firefox\/([\d.]+)/, "Mobile Firefox"],
      [/Firefox\/([\d.]+)/, "Firefox"],
      [/CriOS\/([\d.]+)/, "Mobile Chrome"],
      [/ wv\).+Chrome\/([\d.]+)/, "Chrome WebView"],
      [/Chrome\/([\d.]+) Mobile/, "Mobile Chrome"],
      [/Chrome\/([\d.]+)/, "Chrome"],
      [/Version\/([\d.]+).*Mobile\/\w+ Safari/, "Mobile Safari"],
      [/Version\/([\d.]+).*Safari\//, "Safari"],
      [/AppleWebKit\/([\d.]+)/, "WebKit"],
    ];
    for (var i = 0; i < rules.length; i++) {
      var match = rules[i][0].exec(ua);
      if (match) return { name: rules[i][1], version: match[1] };
    }
    return { name: "Others", version: "0" };
  }
`)

let browser = detectBrowser()
let platformName = Window.Navigator.platform->LoggerUtils.screamingSnakeCase
let browserName = browser.name->LoggerUtils.screamingSnakeCase
let browserVersion = browser.version
let userAgent = Window.Navigator.userAgent->LoggerUtils.truncateTo(LoggerConfig.maxRowTextLength)
let pageHref = Window.hrefWithoutSearch->LoggerUtils.truncateTo(LoggerConfig.maxRowTextLength)

let rank = severity =>
  switch severity {
  | Debug => 0
  | Info => 1
  | Warning => 2
  | Error => 3
  }

let isEnabled = severity => LoggerConfig.enabled && severity->rank >= LoggerConfig.minimumRank

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
  ~data: option<details>=?,
  ~details: option<details>=?,
  ~verbatim: option<details>=?,
  ~exn: option<exn>=?,
  ~failure: option<'response>=?,
  ~durationMs: option<float>=?,
  ~paymentMethod: option<LoggerPaymentMethod.paymentMethod>=?,
  ~context: option<LoggerContext.t>=?,
  ~source: option<source>=?,
  ~limit: option<int>=?,
  ~message: option<string>=?,
  ~once=false,
) =>
  if severity->isEnabled {
    LoggerUtils.safeRun(() => {
      let data = data->Option.getOr([])
      let details = details->Option.getOr([])
      let context = switch context {
      | Some(started) => started->LoggerContext.fillFrom(LoggerContext.current())
      | None => LoggerContext.current()
      }
      let eventName = LoggerUtils.eventName(
        ~category,
        ~action=spec.action,
        ~subject=spec.subject,
        ~outcome=spec.outcome,
      )
      let limit = switch (limit, category) {
      | (None, User) => Some(LoggerConfig.maxUserEventsPerName)
      | _ => limit
      }
      let cap = limit->Option.getOr(LoggerConfig.maxRowsPerEventName)
      let eventSeen = emitCounts.contents->Dict.get(eventName)->Option.getOr(0)

      let capReached = limit->Option.isSome && eventSeen === cap
      let (name, severity, data, details, message) = capReached
        ? (
            LoggerUtils.eventName(
              ~category,
              ~action=Fact,
              ~subject="event_limit_reached",
              ~outcome=None,
            ),
            Warning,
            [("limited_event", eventName->JSON.Encode.string), ("limit", cap->JSON.Encode.int)],
            [],
            None,
          )
        : (eventName, severity, data, details, message)
      let seen = capReached ? 0 : eventSeen
      let onceKey = once
        ? name ++
          "#" ++
          data
          ->Array.concat(details)
          ->Array.concat(verbatim->Option.getOr([]))
          ->Dict.fromArray
          ->JSON.stringifyAny
          ->Option.getOr("")
        : ""
      let duplicateOfOnce = once && onceKeys.contents->Dict.get(onceKey)->Option.isSome
      if once {
        onceKeys.contents->Dict.set(onceKey, true)
      }

      if eventSeen <= cap && !duplicateOfOnce {
        emitCounts.contents->Dict.set(eventName, eventSeen + 1)
        let errorDetails = switch exn {
        | Some(exn) => Some(exn->LoggerUtils.summarizeExn)
        | None => failure->Option.flatMap(LoggerUtils.summarizeErrorResponse)
        }->Option.mapOr([], LoggerUtils.errorDetails)
        let details =
          LoggerUtils.mergeDetails(~data, ~details)
          ->Array.concat(errorDetails)
          ->LoggerUtils.normalizeDetails
          ->Array.concat(verbatim->Option.getOr([]))
        let counter = (key, counter) => {
          let count = counter.contents
          counter := 0
          if count > 0 {
            details->Array.push((key, count->JSON.Encode.int))
          }
        }
        counter("dropped_rows", LoggerQueue.droppedRows)
        counter("send_failures", LoggerQueue.sendFailures)
        if limit->Option.isNone && seen === cap {
          details->Array.push(("rate_limited", true->JSON.Encode.bool))
        }

        let value =
          {
            schemaVersion: LoggerConfig.schemaVersion,
            href: pageHref,
            occurrence: seen + 1,
            message: ?(
              message->Option.map(message => message->LoggerUtils.redact->LoggerUtils.truncate)
            ),
            details: details->LoggerUtils.fitToBudget->Dict.fromArray,
          }
          ->rowValueToJson
          ->JSON.stringify

        LoggerQueue.push(
          {
            timestamp: Date.now()->Float.toString,
            logType: (severity :> string),
            component: "WEB",
            category: (category :> string),
            source: source->Option.mapOr(currentSource.contents, sourceName),
            version: GlobalVars.repoVersion,
            value,
            sessionId: context.sessionId,
            merchantId: context.merchantId,
            paymentId: context.paymentId,
            authenticationId: context.authenticationId,
            appId: "",
            platform: platformName,
            userAgent,
            eventName: name,
            browserName,
            browserVersion,
            latency: durationMs->Option.mapOr("", value => value->Float.toString),
            firstEvent: seen === 0 ? "true" : "false",
            paymentMethod: paymentMethod->Option.mapOr("", LoggerPaymentMethod.qualifiedName),
          },
          ~isError=severity === Error,
        )
      }
    })
  }

let step = (~outcome, ~durationMs=?, ~failureClass=?, ~error=?, ~timeoutMs=0) => {
  outcome,
  durationMs,
  failureClass,
  error,
  timeoutMs,
}

let emitStep = (
  ~category,
  ~spec: eventSpec,
  ~severity: operationSeverity,
  ~data=?,
  ~details=?,
  ~paymentMethod=?,
  ~context=?,
  ~source=?,
  ~message=?,
  step,
) => {
  let severity = switch step.outcome {
  | Started => severity.start
  | Done | Returned | Triggered => severity.success
  | Reused => severity.reused
  | Failed | TimedOut =>
    step.error->Option.mapOr(false, LoggerUtils.isAborted) ? severity.aborted : severity.failure
  }
  let outcomeDetails = []
  step.durationMs->Option.forEach(durationMs =>
    outcomeDetails->Array.push(("duration_ms", durationMs->JSON.Encode.float))
  )
  step.failureClass->Option.forEach(class =>
    outcomeDetails->Array.push(("failure_class", (class :> string)->JSON.Encode.string))
  )
  step.error->Option.forEach(error =>
    outcomeDetails->Array.pushMany(error->LoggerUtils.errorDetails)
  )
  if step.timeoutMs > 0 {
    outcomeDetails->Array.push(("timeout_ms", step.timeoutMs->JSON.Encode.int))
  }
  emit(
    ~category,
    ~spec={...spec, outcome: Some(step.outcome)},
    ~severity,
    ~data=data->Option.getOr([])->Array.concat(outcomeDetails),
    ~details?,
    ~durationMs=?step.durationMs,
    ~paymentMethod?,
    ~context?,
    ~source?,
    ~message?,
  )
}

let emitPhase = (
  ~category,
  ~spec,
  ~severity,
  ~outcome,
  ~data=?,
  ~details=?,
  ~startedAt=?,
  ~exn=?,
  ~paymentMethod=?,
  ~message=?,
) => {
  let durationMs = startedAt->Option.mapOr(0., startedAt => Date.now() -. startedAt)
  switch outcome {
  | Started => step(~outcome)
  | Failed =>
    step(
      ~outcome,
      ~durationMs,
      ~failureClass=exn->Option.isSome ? Threw : ReturnedFailure,
      ~error=?exn->Option.map(LoggerUtils.summarizeUnknown),
    )
  | outcome => step(~outcome, ~durationMs)
  }->emitStep(~category, ~spec, ~severity, ~data?, ~details?, ~paymentMethod?, ~message?)
}

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
    tracker.timer->Option.forEach(clearTimeout)
    tracker.timer = None
    true
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
  ~data=?,
  ~details=?,
  ~timeoutMs=LoggerConfig.defaultTimeoutMs,
  ~failureOf: option<'result => option<errorSummary>>=?,
  ~detailsOf: option<'result => details>=?,
  ~paymentMethod=?,
  ~source=?,
  ~syncOutcome=Returned,
  ~message=?,
  ~call: unit => 'value,
): 'value => {
  let context = LoggerContext.current()
  let base = LoggerUtils.mergeDetails(
    ~data=data->Option.getOr([]),
    ~details=details->Option.getOr([]),
  )
  let tracker = makeTracker()
  let timedOut = ref(false)

  let emitStep = (step, ~details=[]) =>
    step->emitStep(
      ~category,
      ~spec,
      ~severity,
      ~data=base,
      ~details=timedOut.contents
        ? details->Array.concat([("settled_after_timeout", true->JSON.Encode.bool)])
        : details,
      ~paymentMethod?,
      ~context,
      ~source?,
      ~message?,
    )

  let failed = (failureClass, error) =>
    emitStep(step(~outcome=Failed, ~durationMs=tracker->elapsed, ~failureClass, ~error))

  let settleOrLate = () => tracker->settle || timedOut.contents

  let finish = (result, outcome) =>
    switch try failureOf->Option.flatMap(failureOf => failureOf(result)) catch {
    | error => Some(error->LoggerUtils.summarizeExn)
    } {
    | Some(error) => failed(ReturnedFailure, error)
    | None =>
      emitStep(
        step(~outcome, ~durationMs=tracker->elapsed),
        ~details=try detailsOf->Option.mapOr([], detailsOf => detailsOf(result)) catch {
        | _ => []
        },
      )
    }

  try {
    let value = call()
    if value->isThenable {
      emitStep(step(~outcome=Started))
      tracker.timer = Some(setTimeout(() =>
          if tracker->settle {
            timedOut := true
            emitStep(step(~outcome=TimedOut, ~durationMs=tracker->elapsed, ~timeoutMs))
          }
        , timeoutMs))
      value
      ->asPromise
      ->Promise.then(result => {
        if settleOrLate() {
          result->finish(Done)
        }
        Promise.resolve()
      })
      ->Promise.catch(error => {
        if settleOrLate() {
          let error = error->LoggerUtils.summarizeExn
          failed(error->LoggerUtils.isAborted ? Aborted : Rejected, error)
        }
        Promise.resolve()
      })
      ->ignore
    } else if tracker->settle {
      value->asResult->finish(syncOutcome)
    }
    value
  } catch {
  | error => {
      if tracker->settle {
        failed(Threw, error->LoggerUtils.summarizeExn)
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
  ~spec,
  ~severity,
  ~data=?,
  ~details=?,
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
      ~data?,
      ~details?,
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
  ~severity,
  ~url,
  ~resource,
  ~attributes=?,
  ~matchQuery=?,
  ~paymentMethod=?,
  ~source=?,
  ~abandoned=?,
  ~message=?,
  ~onLoad=?,
  ~onError=?,
) => {
  let onLoad = onLoad->Option.getOr(() => ())
  let onError = onError->Option.getOr(_ => ())
  let context = LoggerContext.current()
  let tracker = makeTracker()
  let started = ref(false)

  let emitStep = (step, ~details=[]) =>
    step->emitStep(
      ~category=Resource,
      ~spec,
      ~severity,
      ~data=[
        ("url", url->JSON.Encode.string),
        ("resource_type", resource->ResourceLoader.resourceName->JSON.Encode.string),
      ],
      ~details,
      ~paymentMethod?,
      ~context,
      ~source?,
      ~message?,
    )

  let start = () =>
    if !started.contents {
      started := true
      emitStep(step(~outcome=Started))
    }

  let failed = (~failureClass, error) =>
    if tracker->settle {
      start()
      emitStep(
        step(
          ~outcome=Failed,
          ~durationMs=tracker->elapsed,
          ~failureClass,
          ~error=error->LoggerUtils.summarizeExn,
        ),
      )
    }

  tracker.timer = Some(setTimeout(() =>
      if tracker->settle {
        start()
        emitStep(
          step(
            ~outcome=TimedOut,
            ~durationMs=tracker->elapsed,
            ~timeoutMs=LoggerConfig.defaultTimeoutMs,
          ),
          ~details=abandoned->Option.mapOr(false, abandoned => abandoned())
            ? [("abandoned", true->JSON.Encode.bool)]
            : [],
        )
      }
    , LoggerConfig.defaultTimeoutMs))

  try ResourceLoader.load(
    ~url,
    ~resource,
    ~attributes?,
    ~matchQuery?,
    ~onStart=start,
    ~onLoad=result => {
      if tracker->settle {
        switch result {
        | Reused => emitStep(step(~outcome=Reused, ~durationMs=tracker->elapsed))
        | Loaded => {
            start()
            emitStep(step(~outcome=Done, ~durationMs=tracker->elapsed))
          }
        }
      }
      onLoad()
    },
    ~onError=error => {
      failed(~failureClass=LoadFailed, error)
      onError(error)
    },
  ) catch {
  | error => {
      failed(~failureClass=Threw, error)
      rethrow(error)
    }
  }
}
