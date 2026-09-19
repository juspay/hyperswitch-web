open LoggerTypes

let maxTextLength = 256
let maxDetailBytes = 8192

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

let truncate = value =>
  value->String.length > maxTextLength ? value->String.slice(~start=0, ~end=maxTextLength) : value

let sanitizeUrl = url => url->String.replaceRegExp(/[?#].*$/, "")

let randomId = length => {
  let characters = "abcdefghijklmnopqrstuvwxyz0123456789"
  let charactersLength = characters->String.length
  let result = ref("")
  for _ in 1 to length {
    let index = (Math.random() *. charactersLength->Int.toFloat)->Float.toInt
    result := result.contents ++ characters->String.charAt(index)
  }
  result.contents
}

let safeRun = action =>
  try action() catch {
  | _ => ()
  }

let stringOfBool = value => value ? "true" : "false"

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

let isVariantConstructor = value => value->String.match(/^[A-Z][A-Za-z0-9]*$/)->Option.isSome

let deriveEvent = (value): eventSpec => {
  action: None,
  subject: value->variantConstructor->snakeCase,
  outcome: None,
}

let splitTrailingWord = constructor =>
  constructor
  ->String.match(/^([A-Z][A-Za-z0-9]*?)([A-Z][a-z0-9]*)$/)
  ->Option.flatMap(matches =>
    switch (matches->Array.get(1), matches->Array.get(2)) {
    | (Some(Some(subject)), Some(Some(action))) => Some((action->snakeCase, subject->snakeCase))
    | _ => None
    }
  )

let deriveNotification = (value): eventSpec => {
  let constructor = value->variantConstructor
  switch constructor->splitTrailingWord {
  | Some((action, subject)) => {action: Some(action), subject, outcome: None}
  | None => {action: None, subject: constructor->snakeCase, outcome: None}
  }
}

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
  | ("url" | "href" | "return_url", Some(text)) => text->sanitizeUrl->truncate->JSON.Encode.string

  | (_, Some(text)) if text->isVariantConstructor => text->screamingSnakeCase->JSON.Encode.string
  | _ => value->normalizeJson
  }

let normalizeDetails = (entries: details): details =>
  entries->Array.map(((key, value)) => {
    let key = key->snakeCase
    (key, normalizeValue(key, value))
  })

let recordDetails = (event): details =>
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

let maxPayloadFields = 120

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
      let unique = into->Array.reduce([], (acc, path) =>
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
  | Exn.Error(error) => {
      name: error->Exn.name->Option.getOr("UNKNOWN_ERROR")->screamingSnakeCase,
      message: error->Exn.message->Option.map(truncate),
      details: [],
    }
  | _ => error->summarizeValue
  }

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

let errorDetails = summary =>
  [("error_type", summary.name->JSON.Encode.string)]
  ->Array.concat(
    summary.message
    ->Option.map(message => [("error_message", message->JSON.Encode.string)])
    ->Option.getOr([]),
  )
  ->Array.concat(summary.details)

let isAborted = summary => summary.name === "ABORT_ERROR"

let outcomeDetails = operationOutcome =>
  switch operationOutcome {
  | OpStarted => []
  | OpDone({durationMs}) | OpReused({durationMs}) => [
      ("duration_ms", durationMs->JSON.Encode.float),
    ]
  | OpFailed({durationMs, class, error}) =>
    [
      ("duration_ms", durationMs->JSON.Encode.float),
      ("failure_class", class->variantValue->JSON.Encode.string),
    ]->Array.concat(error->Option.map(errorDetails)->Option.getOr([]))
  | OpTimedOut({durationMs, timeoutMs}) => [
      ("duration_ms", durationMs->JSON.Encode.float),
      ("timeout_ms", timeoutMs->JSON.Encode.int),
    ]
  }

let outcomeSeverity = (operationOutcome, ~severity) =>
  switch operationOutcome {
  | OpFailed({error: Some(error)}) if error->isAborted => Debug
  | operationOutcome => severity->operationSeverityOf(~outcome=operationOutcome)
  }
