open LoggerTypes

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
  let json = value->Identity.anyTypeToJson
  switch json->JSON.Decode.string {
  | Some(name) => name
  | None =>
    json
    ->JSON.Decode.object
    ->Option.flatMap(object => object->Dict.get("TAG"))
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("unknown")
  }
}

let variantName = value => value->variantConstructor->snakeCase

let spec = (event, ~action=Fact, ~outcome=?): eventSpec => {
  action,
  subject: event->variantName,
  outcome,
}

let eventName = (~category: category, ~action: action, ~subject, ~outcome: option<outcome>) => {
  let word = switch (action, outcome) {
  | (Fact, Some(outcome)) => (outcome :> string)
  | (Fact, None) => ""
  | (action, Some(outcome)) => `${(action :> string)}_${(outcome :> string)}`
  | (action, None) => (action :> string)
  }
  let prefix = (category :> string)->String.toLowerCase
  word === "" ? `${prefix}.${subject}` : `${prefix}.${word}.${subject}`
}

let truncateTo = (value, limit) =>
  value->String.length > limit ? value->String.slice(~start=0, ~end=limit) : value

let truncate = value => value->truncateTo(LoggerConfig.maxTextLength)

type textEncoder
@new external makeTextEncoder: unit => textEncoder = "TextEncoder"
@send external encode: (textEncoder, string) => Uint8Array.t = "encode"

let encoder = makeTextEncoder()

let utf8Length = text => encoder->encode(text)->TypedArray.length

let sanitizeUrl = url => url->String.replaceRegExp(/[?#].*$/, "")

let redact = text =>
  text
  ->String.replaceRegExp(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, "[email]")
  ->String.replaceRegExp(/\d(?:[ -]?\d){5,}/g, "[digits]")

let safeRun = action =>
  try action() catch {
  | error => Console.error2("hyper logging internals failed:", error)
  }

let jsonKind: JSON.t => int = %raw(`
  (v) => {
    var t = Object.prototype.toString.call(v);
    return t == "[object Undefined]" ? 1 : t == "[object Array]" ? 2
      : t == "[object Null]" || t == "[object Number]" || t == "[object Boolean]" || t == "[object String]" ? 0 : 3;
  }
`)
external asArray: JSON.t => array<JSON.t> = "%identity"
external asDict: JSON.t => Dict.t<JSON.t> = "%identity"

let rec normalize = (key, value) =>
  switch value->JSON.Decode.string {
  | Some(text) =>
    if key === "" {
      text->truncate
    } else if (
      key === "url" || key === "href" || key === "uri" || /_(?:url|href|uri)$/->RegExp.test(key)
    ) {
      text->sanitizeUrl->truncate
    } else if key === "message" || key->String.endsWith("_message") {
      text->redact->truncate
    } else if /^[A-Z][A-Za-z0-9]*$/->RegExp.test(text) {
      text->screamingSnakeCase
    } else {
      text->truncate
    }->JSON.Encode.string
  | None =>
    switch value->jsonKind {
    | 1 => JSON.Encode.null
    | 2 => value->asArray->Array.map(item => normalize("", item))->JSON.Encode.array
    | 3 =>
      value
      ->asDict
      ->Dict.toArray
      ->Array.filterMap(((key, value)) =>
        value->jsonKind === 1
          ? None
          : {
              let key = key->snakeCase
              Some((key, normalize(key, value)))
            }
      )
      ->Dict.fromArray
      ->JSON.Encode.object
    | _ => value
    }
  }

let normalizeDetails = (entries: details): details =>
  entries->Array.map(((key, value)) => {
    let key = key->snakeCase
    (key, normalize(key, value))
  })

let eventDetails = (event): details =>
  event
  ->Identity.anyTypeToJson
  ->JSON.Decode.object
  ->Option.flatMap(object => object->Dict.get("_0"))
  ->Option.flatMap(payload => normalize("", payload)->JSON.Decode.object)
  ->Option.mapOr([], Dict.toArray)

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

let mergeDetails = (~data: details, ~details: details): details => {
  let typedKeys = data->Array.map(((key, _)) => key)
  data->Array.concat(
    details->Array.map(((key, value)) =>
      typedKeys->Array.includes(key) ? ("detail_" ++ key, value) : (key, value)
    ),
  )
}

let fitToBudget = (entries: details): details => {
  let sizeOf = (entries: details) =>
    entries->Dict.fromArray->JSON.Encode.object->JSON.stringify->String.length
  if entries->sizeOf <= LoggerConfig.maxDetailBytes {
    entries
  } else {
    let remaining = entries->Array.copy
    let dropped = []
    while remaining->Array.length > 0 && remaining->sizeOf > LoggerConfig.maxDetailBytes {
      let (largest, _) = remaining->Array.reduceWithIndex((0, -1), (
        (largest, largestSize),
        (_, value),
        index,
      ) => {
        let size = value->JSON.stringify->String.length
        size > largestSize ? (index, size) : (largest, largestSize)
      })
      remaining
      ->Array.get(largest)
      ->Option.forEach(((key, _)) => dropped->Array.push(key->JSON.Encode.string))
      remaining->Array.splice(~start=largest, ~remove=1, ~insert=[])
    }
    remaining->Array.concat([("dropped_details", dropped->JSON.Encode.array)])
  }
}

let rec collectFields = (json, ~prefix, ~into) =>
  switch json->jsonKind {
  | 3 =>
    json
    ->asDict
    ->Dict.toArray
    ->Array.forEach(((key, value)) => {
      let path = prefix === "" ? key->snakeCase : prefix ++ "." ++ key->snakeCase
      value->jsonKind >= 2 ? value->collectFields(~prefix=path, ~into) : into->Array.push(path)
    })
  | 2 => json->asArray->Array.forEach(value => value->collectFields(~prefix=prefix ++ "[]", ~into))
  | _ => prefix === "" ? () : into->Array.push(prefix)
  }

let payloadDetails = body =>
  switch body->JSON.parseExn {
  | json =>
    let into = []
    json->collectFields(~prefix="", ~into)
    switch into
    ->Set.fromArray
    ->Set.values
    ->Iterator.toArray
    ->Array.slice(~start=0, ~end=LoggerConfig.maxPayloadFields) {
    | [] => []
    | fields => [
        ("request_fields", fields->Array.map(JSON.Encode.string)->JSON.Encode.array),
        ("request_field_count", fields->Array.length->JSON.Encode.int),
      ]
    }
  | exception _ => []
  }

let firstString = (object, keys) =>
  keys->Array.findMap(key => object->Dict.get(key)->Option.flatMap(JSON.Decode.string))

let summary = (~name, ~message=?, ~details=[]) => {name, message, details}

let summarizeValue = value => {
  let json = value->Identity.anyTypeToJson
  switch JSON.Classify.classify(json) {
  | String(value) => summary(~name="THROWN_VALUE", ~message=value->truncate)
  | Object(object) =>
    summary(
      ~name=object
      ->firstString(["name", "code", "type", "reason", "statusCode"])
      ->Option.getOr("UNKNOWN_ERROR")
      ->screamingSnakeCase,
      ~message=?object
      ->firstString(["message", "description", "statusMessage"])
      ->Option.map(truncate),
    )
  | _ => summary(~name="UNKNOWN_ERROR")
  }
}

let summarizeExn = error =>
  switch error {
  | JsExn(jsError) =>
    switch jsError->JsExn.name {
    | Some(name) =>
      summary(
        ~name=name->screamingSnakeCase,
        ~message=?jsError->JsExn.message->Option.map(truncate),
      )
    | None => jsError->summarizeValue
    }
  | _ => error->summarizeValue
  }

let summarizeUnknown = value => value->JsExn.anyToExnInternal->summarizeExn

let stringDetails = pairs =>
  pairs->Array.filterMap(((key, value)) =>
    value->Option.map(value => (key, value->JSON.Encode.string))
  )

let summarizeErrorResponse = result =>
  result
  ->Identity.anyTypeToJson
  ->JSON.Decode.object
  ->Option.flatMap(object => object->Dict.get("error"))
  ->Option.flatMap(json =>
    switch JSON.Classify.classify(json) {
    | Null => None
    | String(message) => Some(summary(~name="ERROR_RESPONSE", ~message=message->truncate))
    | Object(object) =>
      Some(
        summary(
          ~name=object
          ->firstString(["type", "code", "reason"])
          ->Option.getOr("ERROR_RESPONSE")
          ->screamingSnakeCase,
          ~message=?object->firstString(["message"])->Option.map(truncate),
          ~details=[
            ("error_code", object->firstString(["code"])),
            ("error_reason", object->firstString(["reason"])),
          ]->stringDetails,
        ),
      )
    | _ => Some(summary(~name="ERROR_RESPONSE"))
    }
  )

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

let errorDetails = summary =>
  [("error_type", summary.name->JSON.Encode.string)]
  ->Array.concat([("error_message", summary.message)]->stringDetails)
  ->Array.concat(summary.details)

let isAborted = summary => summary.name === "ABORT_ERROR"
