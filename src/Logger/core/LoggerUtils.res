// Keep TextEncoder and the ReScript 12 exception/iterator adapters here.
// Shared normalization and budget limits still come from this host config.
include SharedLogger.Utils.Make(LoggerConfig)

let utf8Length=SharedLoggerCapabilities.makeWebByteCounter()

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
