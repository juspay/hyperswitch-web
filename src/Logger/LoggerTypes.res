type details = array<(string, JSON.t)>

type errorSummary = {
  name: string,
  message: option<string>,
  details: details,
}

type severity =
  | Debug
  | Info
  | Warning
  | Error

type category =
  | Api
  | State
  | User
  | Crash
  | Resource
  | Merchant
  | Function
  | Lifecycle

type outcome =
  | Started
  | Done
  | Reused
  | Failed
  | TimedOut

type action = string

let call = "call"
let load = "load"
let request = "request"

type eventSpec = {
  action: option<action>,
  subject: string,
  outcome: option<outcome>,
}

type operationSpec = {
  action: action,
  subject: string,
}

let makeOperation = (action, subject) => {action, subject}

type failureClass =
  | Rejected
  | Threw
  | ReturnedFailure
  | Aborted
  | LoadFailed

type timing = {durationMs: float}

type failure = {
  durationMs: float,
  class: failureClass,
  error: option<errorSummary>,
}

type timeout = {durationMs: float, timeoutMs: int}

type operationOutcome =
  | OpStarted
  | OpDone(timing)
  | OpReused(timing)
  | OpFailed(failure)
  | OpTimedOut(timeout)

let outcomeOf = operationOutcome =>
  switch operationOutcome {
  | OpStarted => Started
  | OpDone(_) => Done
  | OpReused(_) => Reused
  | OpFailed(_) => Failed
  | OpTimedOut(_) => TimedOut
  }

let durationOf = operationOutcome =>
  switch operationOutcome {
  | OpStarted => None
  | OpDone({durationMs}) | OpReused({durationMs}) => Some(durationMs)
  | OpFailed({durationMs}) => Some(durationMs)
  | OpTimedOut({durationMs}) => Some(durationMs)
  }

type operationSeverity = {success: severity, failure: severity}

let operationSeverityOf = ({success, failure}, ~outcome: operationOutcome) =>
  switch outcome {
  | OpStarted | OpReused(_) => Debug
  | OpDone(_) => success
  | OpFailed(_) | OpTimedOut(_) => failure
  }

let severityName = severity =>
  switch severity {
  | Debug => "DEBUG"
  | Info => "INFO"
  | Warning => "WARNING"
  | Error => "ERROR"
  }

let categoryName = category =>
  switch category {
  | Api => "API"
  | State => "STATE"
  | User => "USER"
  | Crash => "CRASH"
  | Resource => "RESOURCE"
  | Merchant => "MERCHANT"
  | Function => "FUNCTION"
  | Lifecycle => "LIFECYCLE"
  }

let categorySegment = category => category->categoryName->String.toLowerCase

let outcomeName = outcome =>
  switch outcome {
  | Started => "init"
  | Done => "done"
  | Reused => "reused"
  | Failed => "failed"
  | TimedOut => "timed_out"
  }
