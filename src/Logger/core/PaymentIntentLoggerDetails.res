open LoggerTypes

let intentErrorDetails = value =>
  switch value->Identity.anyTypeToJson->JSON.Decode.object {
  | None => []
  | Some(object) =>
    ["error_message", "error_code", "error_reason"]
    ->Array.map(key => (
      key,
      object->WebLoggerUtils.firstString([key])->Option.map(WebLoggerUtils.truncate),
    ))
    ->WebLoggerUtils.stringDetails
  }
