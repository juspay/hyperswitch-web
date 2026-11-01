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
    `ELEMENTS_${mode->CardThemeType.getPaymentModeToStrMapper->WebLoggerUtils.screamingSnakeCase}`
  | Fullscreen(overlay) => `FULLSCREEN_${overlay->WebLoggerUtils.screamingSnakeCase}`
  }

let currentSource = ref("UNKNOWN")

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
let platformName = Window.Navigator.platform->WebLoggerUtils.screamingSnakeCase
let browserName = browser.name->WebLoggerUtils.screamingSnakeCase
let browserVersion = browser.version
let userAgent = Window.Navigator.userAgent->WebLoggerUtils.truncateTo(LoggerConfig.maxRowTextLength)
let pageHref = Window.hrefWithoutSearch->WebLoggerUtils.truncateTo(LoggerConfig.maxRowTextLength)

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
    WebLoggerUtils.safeRun(() => {
      let data = data->Option.getOr([])
      let details = details->Option.getOr([])
      let context = switch context {
      | Some(started) => started->LoggerContext.fillFrom(LoggerContext.current())
      | None => LoggerContext.current()
      }
      let eventName = WebLoggerUtils.eventName(
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
            WebLoggerUtils.eventName(
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
        | Some(exn) => Some(exn->WebLoggerUtils.summarizeExn)
        | None => failure->Option.flatMap(WebLoggerUtils.summarizeErrorResponse)
        }->Option.mapOr([], WebLoggerUtils.errorDetails)
        let details =
          WebLoggerUtils.mergeDetails(~data, ~details)
          ->Array.concat(errorDetails)
          ->WebLoggerUtils.normalizeDetails
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
              message->Option.map(message => message->WebLoggerUtils.redact->WebLoggerUtils.truncate)
            ),
            details: details->WebLoggerUtils.fitToBudget->Dict.fromArray,
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
          ~backfill=!context.scoped,
          ~pmSessionId=context.pmSessionId,
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
    step.error->Option.mapOr(false, WebLoggerUtils.isAborted) ? severity.aborted : severity.failure
  }
  let outcomeDetails = []
  step.durationMs->Option.forEach(durationMs =>
    outcomeDetails->Array.push(("duration_ms", durationMs->JSON.Encode.float))
  )
  step.failureClass->Option.forEach(class =>
    outcomeDetails->Array.push(("failure_class", (class :> string)->JSON.Encode.string))
  )
  step.error->Option.forEach(error =>
    outcomeDetails->Array.pushMany(error->WebLoggerUtils.errorDetails)
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
  ~context=?,
  ~source=?,
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
      ~error=?exn->Option.map(WebLoggerUtils.summarizeUnknown),
    )
  | outcome => step(~outcome, ~durationMs)
  }->emitStep(
    ~category,
    ~spec,
    ~severity,
    ~data?,
    ~details?,
    ~paymentMethod?,
    ~context?,
    ~source?,
    ~message?,
  )
}

let makeTracker = SharedLoggerOperation.makeTracker
let elapsed = SharedLoggerOperation.elapsed
let settle = SharedLoggerOperation.settle
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
  ~context=LoggerContext.current(),
  ~source=?,
  ~syncOutcome=Returned,
  ~message=?,
  ~call: unit => 'value,
): 'value => {
  let base = WebLoggerUtils.mergeDetails(
    ~data=data->Option.getOr([]),
    ~details=details->Option.getOr([]),
  )
  SharedLoggerOperation.observe(
    ~timeoutMs,
    ~summarizeExn=WebLoggerUtils.summarizeExn,
    ~rethrow,
    ~failureOf?,
    ~detailsOf?,
    ~syncOutcome,
    ~onStep=(step, outcomeDetails) =>
      step->emitStep(
      ~category,
      ~spec,
      ~severity,
      ~data=base,
      ~details=outcomeDetails,
      ~paymentMethod?,
      ~context,
      ~source?,
      ~message?,
      ),
    ~call,
  )
}

let forwardInvocation = SharedLoggerOperation.forwardInvocation

let observeCallback = (
  ~category,
  ~spec,
  ~severity,
  ~data=?,
  ~details=?,
  ~timeoutMs=?,
  ~failureOf=?,
  ~paymentMethod=?,
  ~context=?,
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
      ~context?,
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
  ~context=LoggerContext.current(),
  ~source=?,
  ~abandoned=?,
  ~message=?,
  ~onLoad=?,
  ~onError=?,
) => {
  let onLoad = onLoad->Option.getOr(() => ())
  let onError = onError->Option.getOr(_ => ())
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
          ~error=error->WebLoggerUtils.summarizeExn,
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
