open LoggerTypes

include SharedLoggerEvent

let truncateTo = SharedLoggerFormatting.truncateTo

let truncate = value => value->truncateTo(LoggerConfig.maxTextLength)

type textEncoder
@new external makeTextEncoder: unit => textEncoder = "TextEncoder"
@send external encode: (textEncoder, string) => Uint8Array.t = "encode"

let encoder = makeTextEncoder()

let utf8Length = text => encoder->encode(text)->TypedArray.length

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

let maskAll = (_: string) => true
let maskNone = (_: string) => false

let redactedValue = text => (text === "" ? "***EMPTY***" : "***REDACTED***")->JSON.Encode.string

let configSnapshot = (
  config: JSON.t,
  ~isSensitive: string => bool,
  ~maxBytes=LoggerConfig.maxConfigBytes,
): details => {
  let budget = ref(maxBytes)
  let truncated = ref(false)
  let omitted = []
  let charge = cost =>
    cost <= budget.contents
      ? {
          budget := budget.contents - cost
          true
        }
      : false
  let omit = path => {
    truncated := true
    if omitted->Array.length < LoggerConfig.maxConfigOmitted {
      omitted->Array.push(path->JSON.Encode.string)
    }
    None
  }
  let rec walk = (value, path, depth) =>
    switch value->JSON.Decode.string {
    | Some(text) => {
        let text = isSensitive(path) ? redactedValue(text) : text->truncate->JSON.Encode.string
        charge(text->JSON.Decode.string->Option.getOr("")->String.length + 2)
          ? Some(text)
          : omit(path)
      }
    | None =>
      switch value->jsonKind {
      | 1 => None
      | 0 => charge(value->JSON.stringify->String.length) ? Some(value) : omit(path)
      | _ if typeof(value) === #function => None
      | _ if depth >= LoggerConfig.maxConfigDepth =>
        charge(9) ? Some("[depth]"->JSON.Encode.string) : omit(path)
      | 2 if charge(2) => {
          let items = value->asArray
          let out = []
          items->Array.forEachWithIndex((item, index) =>
            if index < LoggerConfig.maxConfigArrayItems && charge(1) {
              walk(item, path, depth + 1)->Option.forEach(item => out->Array.push(item))
            }
          )
          if items->Array.length > LoggerConfig.maxConfigArrayItems {
            omit(
              `${path}[${(items->Array.length - LoggerConfig.maxConfigArrayItems)
                  ->Int.toString} more]`,
            )->ignore
          }
          Some(out->JSON.Encode.array)
        }
      | 3 if charge(2) => {
          let out = Dict.make()
          value
          ->asDict
          ->Dict.forEachWithKey((item, key) => {
            let itemPath = path === "" ? key : `${path}.${key}`
            if charge(key->String.length + 4) {
              walk(item, itemPath, depth + 1)->Option.forEach(item => out->Dict.set(key, item))
            } else {
              omit(itemPath)->ignore
            }
          })
          Some(out->JSON.Encode.object)
        }
      | _ => omit(path)
      }
    }
  let snapshot = walk(config, "", 0)->Option.getOr(JSON.Encode.null)
  truncated.contents
    ? [
        ("config", snapshot),
        ("config_truncated", true->JSON.Encode.bool),
        ("config_omitted", omitted->JSON.Encode.array),
      ]
    : [("config", snapshot)]
}

let mergeDetails = SharedLoggerFormatting.mergeDetails

let fitToBudget = entries =>
  SharedLoggerFormatting.fitToBudget(entries, ~maxDetailBytes=LoggerConfig.maxDetailBytes)

let payloadDetails = body =>
  SharedLoggerFormatting.payloadDetails(body, ~maxPayloadFields=LoggerConfig.maxPayloadFields)

let firstString = SharedLoggerFormatting.firstString

let summary = (~name, ~message=?, ~details=[]) => {name, message, details}

let summarizeExn = error => {
  let summary = error->SharedLoggerFormatting.summarizeExn
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

let httpBodyFailure = ((response, data)) =>
  response->Fetch.Response.ok
    ? None
    : Some(data->summarizeErrorResponse->Option.getOr(response->httpError))

let httpBodyDetails = ((response, _)) => response->httpDetails

let intentErrorDetails = value =>
  switch value->Identity.anyTypeToJson->JSON.Decode.object {
  | None => []
  | Some(object) =>
    ["error_message", "error_code", "error_reason"]
    ->Array.map(key => (key, object->firstString([key])->Option.map(truncate)))
    ->stringDetails
  }

let intentResponseDetails = ((response, data)) =>
  response
  ->httpDetails
  ->Array.concat(
    switch data->Identity.anyTypeToJson->JSON.Decode.object {
    | None => []
    | Some(object) =>
      let nextActionType = switch object->Dict.get("next_action") {
      | None => "NOT_PRESENT"->JSON.Encode.string
      | Some(JSON.Null) => JSON.Encode.null
      | Some(nextAction) =>
        nextAction
        ->JSON.Decode.object
        ->Option.flatMap(action => action->Dict.get("type"))
        ->Option.getOr(JSON.Encode.null)
      }
      [("payment_status", object->firstString(["status"]))]
      ->stringDetails
      ->Array.concat([("next_action_type", nextActionType)])
      ->Array.concat(data->intentErrorDetails)
    },
  )

let errorDetails = SharedLoggerFormatting.errorDetails

let isAborted = SharedLoggerFormatting.isAborted
