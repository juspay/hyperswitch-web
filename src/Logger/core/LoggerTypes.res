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
  | Returned
  | Triggered
  | Reused
  | Failed
  | TimedOut

type action =
  | Fact
  | Call
  | Callback
  | Load
  | Request
  | Prop
  | IntegrationIssue

type eventSpec = {
  action: action,
  subject: string,
  outcome: option<outcome>,
}

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
  | OpReturned(timing)
  | OpTriggered(timing)
  | OpReused(timing)
  | OpFailed(failure)
  | OpTimedOut(timeout)

let outcomeOf = operationOutcome =>
  switch operationOutcome {
  | OpStarted => Started
  | OpDone(_) => Done
  | OpReturned(_) => Returned
  | OpTriggered(_) => Triggered
  | OpReused(_) => Reused
  | OpFailed(_) => Failed
  | OpTimedOut(_) => TimedOut
  }

let durationOf = operationOutcome =>
  switch operationOutcome {
  | OpStarted => None
  | OpDone({durationMs})
  | OpReturned({durationMs})
  | OpTriggered({durationMs})
  | OpReused({durationMs}) =>
    Some(durationMs)
  | OpFailed({durationMs}) => Some(durationMs)
  | OpTimedOut({durationMs}) => Some(durationMs)
  }

type operationSeverity = {
  start: severity,
  success: severity,
  failure: severity,
  reused: severity,
  aborted: severity,
}

let defaultSeverity = {
  start: Debug,
  success: Info,
  failure: Error,
  reused: Debug,
  aborted: Debug,
}

let operationSeverityOf = (
  {start, success, failure, reused, aborted},
  ~outcome: operationOutcome,
  ~isAborted,
) =>
  switch outcome {
  | OpStarted => start
  | OpDone(_) | OpReturned(_) | OpTriggered(_) => success
  | OpReused(_) => reused
  | OpFailed(_) if isAborted => aborted
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

let actionWord = action =>
  switch action {
  | Fact => None
  | Call => Some("call")
  | Callback => Some("callback")
  | Load => Some("load")
  | Request => Some("request")
  | Prop => Some("prop")
  | IntegrationIssue => Some("integration_issue")
  }

let outcomeName = outcome =>
  switch outcome {
  | Started => "init"
  | Done => "done"
  | Returned => "returned"
  | Triggered => "triggered"
  | Reused => "reused"
  | Failed => "failed"
  | TimedOut => "timed_out"
  }
