open LoggerTypes

let maxTextLength = 256
let maxRowTextLength = 1024
let maxDetailBytes = 8192
let maxPayloadFields = 120

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

let isVariantConstructor = value => value->String.match(/^[A-Z][A-Za-z0-9]*$/)->Option.isSome

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

let variantValue = value => value->variantConstructor->screamingSnakeCase

let spec = (event, ~action=Fact, ~outcome=?): eventSpec => {
  action,
  subject: event->variantName,
  outcome,
}

let categorySegment = category => category->categoryName->String.toLowerCase

let eventName = (~category, ~action, ~subject, ~outcome) => {
  let step = switch (action->actionWord, outcome) {
  | (Some(action), Some(outcome)) => Some(`${action}_${outcome->outcomeName}`)
  | (Some(action), None) => Some(action)
  | (None, Some(outcome)) => Some(outcome->outcomeName)
  | (None, None) => None
  }
  [Some(category->categorySegment), step, Some(subject)]
  ->Array.filterMap(segment => segment)
  ->Array.join(".")
}

let truncateTo = (value, limit) =>
  value->String.length > limit ? value->String.slice(~start=0, ~end=limit) : value

let truncate = value => value->truncateTo(maxTextLength)

let utf8Length = value => {
  let bytes = ref(0)
  for index in 0 to value->String.length - 1 {
    let code = value->String.charCodeAt(index)
    bytes :=
      bytes.contents + if code < 128. {
        1
      } else if code < 2048. || (code >= 55296. && code < 57344.) {
        2
      } else {
        3
      }
  }
  bytes.contents
}

let sanitizeUrl = url => url->String.replaceRegExp(/[?#].*$/, "")

let isUrlKey = key =>
  ["url", "href", "uri"]->Array.some(suffix =>
    key === suffix || key->String.endsWith("_" ++ suffix)
  )

let isFreeTextKey = key => key === "message" || key->String.endsWith("_message")

let redact = text =>
  text
  ->String.replaceRegExp(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, "[email]")
  ->String.replaceRegExp(/\d(?:[ -]?\d){5,}/g, "[digits]")

let safeRun = action =>
  try action() catch {
  | error => Console.error2("hyper logging internals failed:", error)
  }

let stringOfBool = value => value ? "true" : "false"

let rec normalizeJson = json =>
  switch Type.Classify.classify(json) {
  | Undefined => JSON.Encode.null
  | _ =>
    switch JSON.Classify.classify(json) {
    | String(value) => value->truncate->JSON.Encode.string
    | Array(values) => values->Array.map(normalizeJson)->JSON.Encode.array
    | Object(object) =>
      object
      ->Dict.toArray
      ->Array.filterMap(((key, value)) =>
        switch Type.Classify.classify(value) {
        | Undefined => None
        | _ => {
            let key = key->snakeCase
            Some((key, normalizeValue(key, value)))
          }
        }
      )
      ->Dict.fromArray
      ->JSON.Encode.object
    | _ => json
    }
  }
and normalizeValue = (key, value) =>
  switch (key, value->JSON.Decode.string) {
  | (key, Some(text)) if key->isUrlKey => text->sanitizeUrl->truncate->JSON.Encode.string
  | (key, Some(text)) if key->isFreeTextKey => text->redact->truncate->JSON.Encode.string
  | (_, Some(text)) if text->isVariantConstructor => text->screamingSnakeCase->JSON.Encode.string
  | _ => value->normalizeJson
  }

let normalizeDetails = (entries: details): details =>
  entries->Array.map(((key, value)) => {
    let key = key->snakeCase
    (key, normalizeValue(key, value))
  })

let eventDetails = (event): details =>
  switch event->Identity.anyTypeToJson->JSON.Decode.object {
  | None => []
  | Some(object) =>
    object
    ->Dict.get("_0")
    ->Option.flatMap(payload => payload->normalizeJson->JSON.Decode.object)
    ->Option.map(Dict.toArray)
    ->Option.getOr([])
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
  let valueSize = ((_, value)) => value->JSON.stringify->String.length
  if entries->sizeOf <= maxDetailBytes {
    entries
  } else {
    let remaining = entries->Array.copy
    let dropped = []
    while remaining->Array.length > 0 && remaining->sizeOf > maxDetailBytes {
      let (largest, _) = remaining->Array.reduceWithIndex((0, -1), (
        (largest, largestSize),
        entry,
        index,
      ) => {
        let size = entry->valueSize
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
  switch JSON.Classify.classify(json) {
  | Object(object) =>
    object
    ->Dict.toArray
    ->Array.forEach(((key, value)) => {
      let path = prefix === "" ? key->snakeCase : prefix ++ "." ++ key->snakeCase
      switch JSON.Classify.classify(value) {
      | Object(_) | Array(_) => value->collectFields(~prefix=path, ~into)
      | _ => into->Array.push(path)
      }
    })
  | Array(values) =>
    values->Array.forEach(value => value->collectFields(~prefix=prefix ++ "[]", ~into))
  | _ => prefix === "" ? () : into->Array.push(prefix)
  }

let payloadFields = body =>
  switch body->JSON.parseExn {
  | json => {
      let into = []
      json->collectFields(~prefix="", ~into)
      let unique =
        into->Array.reduce([], (acc, path) =>
          acc->Array.includes(path) ? acc : acc->Array.concat([path])
        )
      unique->Array.length > maxPayloadFields
        ? unique->Array.slice(~start=0, ~end=maxPayloadFields)
        : unique
    }
  | exception _ => []
  }

let payloadDetails = body =>
  switch body->payloadFields {
  | [] => []
  | fields => [
      ("request_fields", fields->Array.map(JSON.Encode.string)->JSON.Encode.array),
      ("request_field_count", fields->Array.length->JSON.Encode.int),
    ]
  }

let firstString = (object, keys) =>
  keys->Array.findMap(key => object->Dict.get(key)->Option.flatMap(JSON.Decode.string))

let summarizeValue = value => {
  let json = value->Identity.anyTypeToJson
  switch JSON.Classify.classify(json) {
  | String(value) => {name: "THROWN_VALUE", message: Some(value->truncate), details: []}
  | Object(object) => {
      name: object
      ->firstString(["name", "code", "type", "reason"])
      ->Option.getOr("UNKNOWN_ERROR")
      ->screamingSnakeCase,
      message: object
      ->firstString(["message", "description", "statusMessage"])
      ->Option.map(truncate),
      details: [],
    }
  | _ => {name: "UNKNOWN_ERROR", message: None, details: []}
  }
}

let summarizeExn = error =>
  switch error {
  | JsExn(jsError) =>
    switch jsError->JsExn.name {
    | Some(name) => {
        name: name->screamingSnakeCase,
        message: jsError->JsExn.message->Option.map(truncate),
        details: [],
      }
    | None => jsError->summarizeValue
    }
  | _ => error->summarizeValue
  }

let summarizeUnknown = value => value->JsExn.anyToExnInternal->summarizeExn

let summarizeErrorResponse = result =>
  result
  ->Identity.anyTypeToJson
  ->JSON.Decode.object
  ->Option.flatMap(object => object->Dict.get("error"))
  ->Option.flatMap(json =>
    switch JSON.Classify.classify(json) {
    | Null => None
    | String(message) =>
      Some({name: "ERROR_RESPONSE", message: Some(message->truncate), details: []})
    | Object(object) =>
      Some({
        name: object
        ->firstString(["type", "code", "reason"])
        ->Option.getOr("ERROR_RESPONSE")
        ->screamingSnakeCase,
        message: object->firstString(["message"])->Option.map(truncate),
        details: [
          ("error_code", object->firstString(["code"])),
          ("error_reason", object->firstString(["reason"])),
        ]->Array.filterMap(((key, value)) =>
          value->Option.map(value => (key, value->JSON.Encode.string))
        ),
      })
    | _ => Some({name: "ERROR_RESPONSE", message: None, details: []})
    }
  )

let httpFailure = response =>
  response->Fetch.Response.ok
    ? None
    : Some({
        name: "HTTP_ERROR",
        message: Some(response->Fetch.Response.status->Int.toString),
        details: [],
      })

let httpDetails = response => [("status_code", response->Fetch.Response.status->JSON.Encode.int)]

let httpBodyFailure = ((response, data)) =>
  response->Fetch.Response.ok
    ? None
    : Some(
        data
        ->summarizeErrorResponse
        ->Option.getOr({
          name: "HTTP_ERROR",
          message: Some(response->Fetch.Response.status->Int.toString),
          details: [],
        }),
      )

let httpBodyDetails = ((response, _)) => response->httpDetails

let intentErrorDetails = value =>
  switch value->Identity.anyTypeToJson->JSON.Decode.object {
  | None => []
  | Some(object) =>
    [
      ("error_message", object->firstString(["error_message"])),
      ("error_code", object->firstString(["error_code"])),
      ("error_reason", object->firstString(["error_reason"])),
    ]->Array.filterMap(((key, value)) =>
      value->Option.map(value => (key, value->truncate->JSON.Encode.string))
    )
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
      switch object->firstString(["status"]) {
      | Some(status) => [("payment_status", status->JSON.Encode.string)]
      | None => []
      }
      ->Array.concat([("next_action_type", nextActionType)])
      ->Array.concat(data->intentErrorDetails)
    },
  )

let errorDetails = summary =>
  [("error_type", summary.name->JSON.Encode.string)]
  ->Array.concat(
    summary.message
    ->Option.map(message => [("error_message", message->JSON.Encode.string)])
    ->Option.getOr([]),
  )
  ->Array.concat(summary.details)

let isAborted = summary => summary.name === "ABORT_ERROR"

let outcomeDetails = operationOutcome => {
  let duration =
    operationOutcome
    ->durationOf
    ->Option.map(durationMs => [("duration_ms", durationMs->JSON.Encode.float)])
    ->Option.getOr([])
  duration->Array.concat(
    switch operationOutcome {
    | OpStarted | OpDone(_) | OpReturned(_) | OpTriggered(_) | OpReused(_) => []
    | OpFailed({class, error}) =>
      [("failure_class", class->variantValue->JSON.Encode.string)]->Array.concat(
        error->Option.map(errorDetails)->Option.getOr([]),
      )
    | OpTimedOut({timeoutMs}) => timeoutMs > 0 ? [("timeout_ms", timeoutMs->JSON.Encode.int)] : []
    },
  )
}

let outcomeSeverity = (operationOutcome, ~severity) =>
  severity->operationSeverityOf(
    ~outcome=operationOutcome,
    ~isAborted=switch operationOutcome {
    | OpFailed({error: Some(error)}) => error->isAborted
    | _ => false
    },
  )
