type details = array<(string, JSON.t)>

type errorSummary = {
  name: string,
  message: option<string>,
  details: details,
}

type severity =
  | @as("DEBUG") Debug
  | @as("INFO") Info
  | @as("WARNING") Warning
  | @as("ERROR") Error

type category =
  | @as("API") Api
  | @as("STATE") State
  | @as("USER") User
  | @as("CRASH") Crash
  | @as("RESOURCE") Resource
  | @as("MERCHANT") Merchant
  | @as("FUNCTION") Function
  | @as("LIFECYCLE") Lifecycle

type outcome =
  | @as("init") Started
  | @as("done") Done
  | @as("returned") Returned
  | @as("triggered") Triggered
  | @as("reused") Reused
  | @as("failed") Failed
  | @as("timed_out") TimedOut

type action =
  | @as("") Fact
  | @as("call") Call
  | @as("callback") Callback
  | @as("load") Load
  | @as("request") Request
  | @as("prop") Prop
  | @as("integration_issue") IntegrationIssue

type eventSpec = {
  action: action,
  subject: string,
  outcome: option<outcome>,
}

type failureClass =
  | @as("REJECTED") Rejected
  | @as("THREW") Threw
  | @as("RETURNED_FAILURE") ReturnedFailure
  | @as("ABORTED") Aborted
  | @as("LOAD_FAILED") LoadFailed

type step = {
  outcome: outcome,
  durationMs: option<float>,
  failureClass: option<failureClass>,
  error: option<errorSummary>,
  timeoutMs: int,
}

type operationSeverity = {
  start: severity,
  success: severity,
  failure: severity,
  reused: severity,
  aborted: severity,
}

let severities = (~success, ~failure) => {
  start: Debug,
  success,
  failure,
  reused: Debug,
  aborted: Debug,
}

let defaultSeverity = severities(~success=Info, ~failure=Error)
let quietSuccess = severities(~success=Debug, ~failure=Error)
let softFailure = severities(~success=Info, ~failure=Warning)
let quietSuccessSoftFailure = severities(~success=Debug, ~failure=Warning)
let quietAll = severities(~success=Debug, ~failure=Debug)

type context = {
  sessionId: string,
  merchantId: string,
  paymentId: string,
  authenticationId: string,
}

type row = {
  timestamp: string,
  @as("log_type") logType: string,
  component: string,
  category: string,
  source: string,
  version: string,
  value: string,
  @as("session_id") mutable sessionId: string,
  @as("merchant_id") mutable merchantId: string,
  @as("payment_id") mutable paymentId: string,
  @as("authentication_id") mutable authenticationId: string,
  @as("app_id") appId: string,
  platform: string,
  @as("user_agent") userAgent: string,
  @as("event_name") eventName: string,
  @as("browser_name") browserName: string,
  @as("browser_version") browserVersion: string,
  latency: string,
  @as("first_event") firstEvent: string,
  @as("payment_method") paymentMethod: string,
}

type rowValue = {
  @as("schema_version") schemaVersion: int,
  href: string,
  occurrence: int,
  message?: string,
  details: Dict.t<JSON.t>,
}

external rowValueToJson: rowValue => JSON.t = "%identity"
