open LoggerTypes

include SharedLoggerEvent

let truncateTo = SharedLoggerFormatting.truncateTo

let truncate = value => value->truncateTo(LoggerConfig.maxTextLength)

let sanitizeUrl = SharedLoggerFormatting.sanitizeUrl

let redact = SharedLoggerFormatting.redact

let safeRun = action =>
  try action() catch {
  | error => Console.error2("hyper logging internals failed:", error)
  }

let jsonKind = SharedLoggerFormatting.jsonKind
let asArray = SharedLoggerFormatting.asArray
let asDict = SharedLoggerFormatting.asDict
let normalize = (key, value) =>
  SharedLoggerFormatting.normalize(key, value, ~maxTextLength=LoggerConfig.maxTextLength)
let normalizeDetails = entries =>
  SharedLoggerFormatting.normalizeDetails(entries, ~maxTextLength=LoggerConfig.maxTextLength)
let eventDetails = event =>
  SharedLoggerFormatting.eventDetails(event, ~maxTextLength=LoggerConfig.maxTextLength)

let maskAll = SharedLoggerFormatting.maskAll
let maskNone = SharedLoggerFormatting.maskNone
let configSnapshot = SharedLoggerFormatting.configSnapshot

let mergeDetails = SharedLoggerFormatting.mergeDetails

let fitToBudget = entries =>
  SharedLoggerFormatting.fitToBudget(entries, ~maxDetailBytes=LoggerConfig.maxDetailBytes)

let payloadDetails = body =>
  SharedLoggerFormatting.payloadDetails(body, ~maxPayloadFields=LoggerConfig.maxPayloadFields)

let firstString = SharedLoggerFormatting.firstString

let summary = (~name, ~message=?, ~details=[]) => {name, message, details}

let summarizeExn = error => {
  let summary = switch error {
  | JsExn(jsError) =>
    SharedLoggerFormatting.summary(
      ~name=jsError->JsExn.name->Option.getOr("ERROR")->SharedLoggerEvent.screamingSnakeCase,
      ~message=?jsError->JsExn.message,
    )
  | _ => error->SharedLoggerFormatting.summarizeExn
  }
  {...summary, message: summary.message->Option.map(truncate)}
}

let summarizeUnknown = value => value->JsExn.anyToExnInternal->summarizeExn

let stringDetails = SharedLoggerFormatting.stringDetails

let summarizeErrorResponse = result =>
  result
  ->SharedLoggerFormatting.summarizeErrorResponse
  ->Option.map(summary => {...summary, message: summary.message->Option.map(truncate)})

let httpDetails = response => [("status_code", response->Fetch.Response.status->JSON.Encode.int)]

let httpError = response =>
  summary(~name="HTTP_ERROR", ~message=response->Fetch.Response.status->Int.toString)

let httpFailure = response => response->Fetch.Response.ok ? None : Some(response->httpError)

let errorDetails = SharedLoggerFormatting.errorDetails

let isAborted = SharedLoggerFormatting.isAborted
