type details = array<(string, JSON.t)>

type severity = Debug | Info | Warning | Error
type category = Merchant | Lifecycle | Function | User | Api | Resource | State | Crash

type exceptionSummary = {
  name: string,
  message: option<string>,
  details: details,
}

exception ObservedFailure(JSON.t, exceptionSummary)
type operationTiming = {durationMs: float, details: details}
type operationFailure<'failure> = {
  durationMs: float,
  failure: 'failure,
  errorSummary: option<exceptionSummary>,
}
type operationTimeout = {durationMs: float, timeoutMs: int}
type asyncOutcome<'failure> =
  | Started
  | Done(operationTiming)
  | Failed(operationFailure<'failure>)
  | TimedOut(operationTimeout)

type promiseFailure = PromiseRejected | SynchronousThrow | ReturnedFailure
type resourceFailure = LoadFailed | LoaderThrew

type operationTracker = {
  startedAtMs: float,
  settled: ref<bool>,
  timeout: ref<option<timeoutId>>,
}

let defaultOperationTimeoutMs = 30000

let generateRandomString = length => {
  let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  let result = ref("")
  let charactersLength = characters->String.length
  Int.range(0, length)->Array.forEach(_ => {
    let charIndex = mod((Math.random() *. 100.0)->Float.toInt, charactersLength)
    result := result.contents ++ characters->String.charAt(charIndex)
  })
  result.contents
}

let safeRun = action =>
  try {
    action()
  } catch {
  | _ => ()
  }

let snakeCase = value =>
  value
  ->String.replaceRegExp(/([A-Z]+)([A-Z][a-z])/g, "$1_$2")
  ->String.replaceRegExp(/([a-z0-9])([A-Z])/g, "$1_$2")
  ->String.toLowerCase

let screamingSnakeCase = value =>
  value
  ->snakeCase
  ->String.replaceRegExp(/[^a-zA-Z0-9]+/g, "_")
  ->String.replaceRegExp(/^_+|_+$/g, "")
  ->String.toUpperCase

let variantConstructor = value => {
  let valueJson = value->Identity.anyTypeToJson
  switch valueJson->JSON.Decode.string {
  | Some(constructorName) => constructorName
  | None =>
    valueJson
    ->JSON.Decode.object
    ->Option.flatMap(object => object->Dict.get("TAG"))
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("UnknownVariant")
  }
}

let variantName = value => value->variantConstructor->snakeCase

let variantValue = value => value->variantConstructor->screamingSnakeCase

let normalizeKeys = entries => entries->Array.map(((key, value)) => (key->snakeCase, value))

let rec normalizeDetailJson = json =>
  switch Type.Classify.classify(json) {
  | Undefined => JSON.Encode.null
  | _ =>
    switch JSON.Classify.classify(json) {
    | String(value) => value->screamingSnakeCase->JSON.Encode.string
    | Object(object) =>
      object
      ->Dict.toArray
      ->Array.filterMap(((key, value)) =>
        switch Type.Classify.classify(value) {
        | Undefined => None
        | _ => Some((key->snakeCase, value->normalizeDetailJson))
        }
      )
      ->Dict.fromArray
      ->JSON.Encode.object
    | Array(values) => values->Array.map(normalizeDetailJson)->JSON.Encode.array
    | _ => json
    }
  }

let recordDetails = (payload): details => {
  let normalizedPayload = payload->Identity.anyTypeToJson->normalizeDetailJson
  normalizedPayload->JSON.Decode.object->Option.map(Dict.toArray)->Option.getOr([])
}

let normalizeDetails = (entries: details): details =>
  entries->Array.map(((key, value)) => (key->snakeCase, value->normalizeDetailJson))

let variantEventMetadata = (event): (string, details) => {
  let eventJson = event->Identity.anyTypeToJson
  switch eventJson->JSON.Decode.object {
  | None => (event->variantName, [])
  | Some(eventObject) => {
      let eventName = event->variantName
      let details = switch eventObject->Dict.get("_0") {
      | Some(payload) => payload->recordDetails
      | None => []
      }
      (eventName, details)
    }
  }
}

let providerEventMetadata = (event): (string, string, details) => {
  let eventJson = event->Identity.anyTypeToJson
  let provider = event->variantValue
  let innerEvent =
    eventJson
    ->JSON.Decode.object
    ->Option.flatMap(object => object->Dict.get("_0"))
    ->Option.getOr(JSON.Encode.null)
  let (eventName, details) = innerEvent->variantEventMetadata
  (eventName, provider, details)
}

let truncateDiagnosticText = (value, ~maxLength) =>
  value->String.length > maxLength ? value->String.slice(~start=0, ~end=maxLength) : value

let summarizeException = caughtError =>
  switch caughtError {
  | ObservedFailure(_, summary) => summary
  | Exn.Error(error) => {
      name: error->Exn.name->Option.getOr("UNKNOWN_ERROR")->truncateDiagnosticText(~maxLength=64),
      message: error
      ->Exn.message
      ->Option.map(message => message->truncateDiagnosticText(~maxLength=256)),
      details: [],
    }
  | _ => {name: "UNKNOWN_ERROR", message: None, details: []}
  }

let exceptionSummaryDetails = summary => {
  let messageDetails = switch summary.message {
  | Some(message) => [("error_message", message->JSON.Encode.string)]
  | None => []
  }
  [("error_type", summary.name->screamingSnakeCase->JSON.Encode.string)]
  ->Array.concat(messageDetails)
  ->Array.concat(summary.details)
}

let errorResponseSummary = result => {
  let resultJson = result->Identity.anyTypeToJson
  resultJson
  ->JSON.Decode.object
  ->Option.flatMap(resultObject => resultObject->Dict.get("error"))
  ->Option.flatMap(errorJson => {
    switch JSON.Classify.classify(errorJson) {
    | Object(errorObject) => {
        let findString = keys =>
          keys->Array.findMap(key => errorObject->Dict.get(key)->Option.flatMap(JSON.Decode.string))
        let errorType = findString(["type", "code", "reason"])
        let message =
          findString(["message"])->Option.map(message =>
            message->truncateDiagnosticText(~maxLength=256)
          )
        let errorDetails =
          [
            ("error_code", findString(["code"])),
            ("error_reason", findString(["reason"])),
          ]->Array.filterMap(((key, value)) =>
            value->Option.map(value => (key, value->screamingSnakeCase->JSON.Encode.string))
          )
        Some({
          name: errorType->Option.getOr("RETURNED_ERROR_RESPONSE"),
          message,
          details: errorDetails,
        })
      }
    | String(message) =>
      Some({
        name: "RETURNED_ERROR_RESPONSE",
        message: Some(message->truncateDiagnosticText(~maxLength=256)),
        details: [],
      })
    | Null => None
    | _ => Some({name: "RETURNED_ERROR_RESPONSE", message: None, details: []})
    }
  })
}

let sanitizedUrl = url => url->String.replaceRegExp(/[?#].*$/, "")

let apiRequestDetails = (~url, ~method, ~maxAttempts, ~requestBodyPresent, ~retryPolicy) => [
  ("url", url->sanitizedUrl->JSON.Encode.string),
  ("http_method", method->screamingSnakeCase->JSON.Encode.string),
  ("max_attempts", maxAttempts->JSON.Encode.int),
  ("request_body_present", requestBodyPresent->JSON.Encode.bool),
  ("retry_policy", retryPolicy->screamingSnakeCase->JSON.Encode.string),
]

let resourceRequestDetails = (~url, ~resourceType, ~timeoutMs, ~loadMode=?) => {
  let loadModeDetails =
    loadMode
    ->Option.map(loadMode => [("load_mode", loadMode->screamingSnakeCase->JSON.Encode.string)])
    ->Option.getOr([])
  [
    ("url", url->sanitizedUrl->JSON.Encode.string),
    ("resource_type", resourceType->screamingSnakeCase->JSON.Encode.string),
    ("configured_timeout_ms", timeoutMs->JSON.Encode.int),
  ]->Array.concat(loadModeDetails)
}

let httpStatusClass = statusCode =>
  if statusCode >= 100 && statusCode < 200 {
    "INFORMATIONAL"
  } else if statusCode >= 200 && statusCode < 300 {
    "SUCCESS"
  } else if statusCode >= 300 && statusCode < 400 {
    "REDIRECTION"
  } else if statusCode >= 400 && statusCode < 500 {
    "CLIENT_ERROR"
  } else if statusCode >= 500 && statusCode < 600 {
    "SERVER_ERROR"
  } else {
    "UNKNOWN"
  }

let apiResultDetails = (~attemptCount, ~statusCode=?) => {
  let retryCount = attemptCount > 0 ? attemptCount - 1 : 0
  let statusDetails = switch statusCode {
  | Some(statusCode) => [
      ("status_code", statusCode->JSON.Encode.int),
      ("status_class", statusCode->httpStatusClass->JSON.Encode.string),
    ]
  | None => []
  }
  [
    ("attempt_count", attemptCount->JSON.Encode.int),
    ("retry_count", retryCount->JSON.Encode.int),
  ]->Array.concat(statusDetails)
}

let promiseFailureName = (failure: promiseFailure) => failure->variantValue

let resourceFailureName = (failure: resourceFailure) => failure->variantValue

let outcomeName = outcome =>
  switch outcome {
  | Started => "started"
  | Done(_) => "done"
  | Failed(_) => "failed"
  | TimedOut(_) => "timed_out"
  }

let outcomeSeverity = outcome =>
  switch outcome {
  | Started => Debug
  | Done(_) => Info
  | Failed(_) => Error
  | TimedOut(_) => Warning
  }

let outcomeDetails = (outcome, ~failureName) =>
  switch outcome {
  | Started => []
  | Done({durationMs, details}) =>
    [("duration_ms", durationMs->JSON.Encode.float)]->Array.concat(details)
  | Failed({durationMs, failure, errorSummary}) => {
      let errorDetails = errorSummary->Option.map(exceptionSummaryDetails)->Option.getOr([])
      [
        ("duration_ms", durationMs->JSON.Encode.float),
        ("failure_class", failure->failureName->JSON.Encode.string),
      ]->Array.concat(errorDetails)
    }
  | TimedOut({durationMs, timeoutMs}) => [
      ("duration_ms", durationMs->JSON.Encode.float),
      ("timeout_ms", timeoutMs->JSON.Encode.int),
    ]
  }

let makeOperationTracker = () => {
  startedAtMs: Date.now(),
  settled: ref(false),
  timeout: ref(None),
}

let operationDurationMs = tracker => Date.now() -. tracker.startedAtMs

let emitSafely = (emit, outcome) => safeRun(() => emit(outcome))

let scheduleOperationTimeout = (tracker, ~timeoutMs, ~onTimeout) => {
  let timeout = setTimeout(() => {
    if !tracker.settled.contents {
      tracker.settled := true
      tracker.timeout := None
      onTimeout()
    }
  }, timeoutMs)
  tracker.timeout := Some(timeout)
}

let finishOperation = tracker =>
  if tracker.settled.contents {
    false
  } else {
    tracker.settled := true
    switch tracker.timeout.contents {
    | Some(timeout) => {
        clearTimeout(timeout)
        tracker.timeout := None
      }
    | None => ()
    }
    true
  }

let observeAsync = (
  ~timeoutMs,
  ~emit: asyncOutcome<promiseFailure> => unit,
  ~resultFailure=?,
  ~resultDetails=?,
  ~call,
) => {
  let tracker = makeOperationTracker()
  let emitOutcome = outcome => emitSafely(emit, outcome)

  emitOutcome(Started)
  scheduleOperationTimeout(tracker, ~timeoutMs, ~onTimeout=() =>
    emitOutcome(TimedOut({durationMs: operationDurationMs(tracker), timeoutMs}))
  )

  try {
    let original = call()
    original
    ->Promise.thenResolve(result => {
      if finishOperation(tracker) {
        let returnedFailure = try {
          resultFailure->Option.flatMap(classify => classify(result))
        } catch {
        | _ => None
        }
        switch returnedFailure {
        | Some(errorSummary) =>
          emitOutcome(
            Failed({
              durationMs: operationDurationMs(tracker),
              failure: ReturnedFailure,
              errorSummary: Some(errorSummary),
            }),
          )
        | None => {
            let details = try {
              resultDetails->Option.map(getDetails => getDetails(result))->Option.getOr([])
            } catch {
            | _ => []
            }
            emitOutcome(Done({durationMs: operationDurationMs(tracker), details}))
          }
        }
      }
    })
    ->Promise.catch(error => {
      if finishOperation(tracker) {
        emitOutcome(
          Failed({
            durationMs: operationDurationMs(tracker),
            failure: PromiseRejected,
            errorSummary: Some(error->summarizeException),
          }),
        )
      }
      Promise.resolve()
    })
    ->ignore
    original
  } catch {
  | error => {
      if finishOperation(tracker) {
        emitOutcome(
          Failed({
            durationMs: operationDurationMs(tracker),
            failure: SynchronousThrow,
            errorSummary: Some(error->summarizeException),
          }),
        )
      }
      raise(error)
    }
  }
}

let observeSync = (~emit: asyncOutcome<promiseFailure> => unit, ~call) => {
  let tracker = makeOperationTracker()
  let emitOutcome = outcome => emitSafely(emit, outcome)

  emitOutcome(Started)

  try {
    let result = call()
    if finishOperation(tracker) {
      emitOutcome(Done({durationMs: operationDurationMs(tracker), details: []}))
    }
    result
  } catch {
  | error => {
      if finishOperation(tracker) {
        emitOutcome(
          Failed({
            durationMs: operationDurationMs(tracker),
            failure: SynchronousThrow,
            errorSummary: Some(error->summarizeException),
          }),
        )
      }
      raise(error)
    }
  }
}
